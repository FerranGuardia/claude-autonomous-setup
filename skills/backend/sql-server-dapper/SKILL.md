---
name: sql-server-dapper
description: SQL Server patterns + Dapper + ADO.NET for .NET Framework 4.7. Connection management, parameterized queries, query optimization, indexes, transactions, stored procedures, connection pooling, maintenance.
---

# SQL Server + Dapper + ADO.NET

## Connection Strings

### Format (Web.config)

```xml
<connectionStrings>
  <add name="DefaultConnection"
       providerName="System.Data.SqlClient"
       connectionString="Data Source=.\SQLEXPRESS;Initial Catalog=MyDb;User ID=app;Password=***;MultipleActiveResultSets=True;Max Pool Size=200;Connection Timeout=30" />
</connectionStrings>
```

### Key Parameters

| Parameter | Default | Notes |
|-----------|---------|-------|
| `Data Source` / `Server` | — | `.\INSTANCE` for named, `(local)` for local |
| `Initial Catalog` / `Database` | — | Database name |
| `Integrated Security` / `Trusted_Connection` | `false` | `true`/`SSPI` for Windows Auth |
| `MultipleActiveResultSets` (MARS) | `false` | Required for lazy loading in EF6 |
| `Max Pool Size` | `100` | Maximum pooled connections |
| `Min Pool Size` | `0` | Keep-alive connections |
| `Connection Timeout` | `15` | Seconds to wait for connection |
| `Application Name` | `.Net SqlClient` | Shows in SQL Profiler |

### Reading at Runtime

```csharp
using System.Configuration;
string connStr = ConfigurationManager.ConnectionStrings["DefaultConnection"].ConnectionString;
```

### Type-Safe Builder

```csharp
var builder = new SqlConnectionStringBuilder
{
    DataSource = "SQLSERVER01",
    InitialCatalog = "MyApp",
    IntegratedSecurity = true,
    MultipleActiveResultSets = true,
    MaxPoolSize = 200,
    ApplicationName = "MyLegacyApp"
};
```

## ADO.NET Basics

### Always use `using` — guarantees return to pool

```csharp
using (var connection = new SqlConnection(connectionString))
{
    connection.Open();

    const string sql = "SELECT ProductID, Name, Price FROM Products WHERE CategoryID = @CategoryID";
    using (var command = new SqlCommand(sql, connection))
    {
        // ALWAYS use explicit SqlParameter (not AddWithValue)
        command.Parameters.Add(new SqlParameter("@CategoryID", SqlDbType.Int) { Value = 5 });

        using (var reader = command.ExecuteReader())
        {
            while (reader.Read())
            {
                int id = reader.GetInt32(0);
                string name = reader.GetString(1);
                decimal price = reader.GetDecimal(2);
            }
        }
    }
}
```

**Why not `AddWithValue`**: It infers `nvarchar` for strings. If the column is `varchar`, SQL Server converts every row = index scan instead of seek.

### ExecuteNonQuery / ExecuteScalar

```csharp
int rowsAffected = command.ExecuteNonQuery();  // INSERT/UPDATE/DELETE
int count = (int)command.ExecuteScalar();        // Single value
```

## Dapper Patterns

### Query / QueryFirst / Execute

```csharp
using Dapper;

// Multiple rows
var products = connection.Query<Product>(
    "SELECT * FROM Products WHERE CategoryID = @CategoryID",
    new { CategoryID = 1 }).ToList();

// Single row (throws if none)
var product = connection.QueryFirst<Product>(
    "SELECT * FROM Products WHERE ProductID = @Id", new { Id = 1 });

// Single row or null
var product = connection.QueryFirstOrDefault<Product>(
    "SELECT * FROM Products WHERE ProductID = @Id", new { Id = 1 });

// Non-query
int rows = connection.Execute(
    "UPDATE Products SET Price = @Price WHERE ProductID = @Id",
    new { Price = 29.99m, Id = 42 });

// Bulk insert (executes once per item)
connection.Execute(
    "INSERT INTO Products (Name, Price) VALUES (@Name, @Price)",
    new[] { new { Name = "A", Price = 9.99m }, new { Name = "B", Price = 14.99m } });
```

| Method | 0 rows | 1 row | 2+ rows |
|--------|--------|-------|---------|
| `QueryFirst` | Exception | Returns | Returns first |
| `QueryFirstOrDefault` | `default(T)` | Returns | Returns first |
| `QuerySingle` | Exception | Returns | Exception |
| `QuerySingleOrDefault` | `default(T)` | Returns | Exception |

### Multiple Result Sets

```csharp
const string sql = @"
    SELECT * FROM Orders WHERE OrderID = @Id;
    SELECT * FROM OrderItems WHERE OrderID = @Id;";

using (var multi = connection.QueryMultiple(sql, new { Id = 1 }))
{
    var order = multi.ReadFirst<Order>();
    var items = multi.Read<OrderItem>().ToList();
}
```

### Multi-mapping (joins)

```csharp
var orders = connection.Query<Order, Customer, Order>(
    @"SELECT o.*, c.* FROM Orders o
      INNER JOIN Customers c ON o.CustomerID = c.CustomerID",
    (order, customer) => { order.Customer = customer; return order; },
    splitOn: "CustomerID").ToList();
```

### Stored Procedures

```csharp
var parameters = new DynamicParameters();
parameters.Add("@Name", "Widget");
parameters.Add("@NewId", dbType: DbType.Int32, direction: ParameterDirection.Output);

connection.Execute("dbo.usp_InsertProduct", parameters,
    commandType: CommandType.StoredProcedure);

int newId = parameters.Get<int>("@NewId");
```

### Transactions

```csharp
using (var connection = new SqlConnection(connectionString))
{
    connection.Open();
    using (var transaction = connection.BeginTransaction())
    {
        try
        {
            connection.Execute("INSERT INTO Orders ...", new { ... }, transaction: transaction);
            connection.Execute("INSERT INTO OrderItems ...", new { ... }, transaction: transaction);
            transaction.Commit();
        }
        catch { transaction.Rollback(); throw; }
    }
}
```

### When Dapper vs EF6

| Scenario | Use |
|----------|-----|
| CRUD with change tracking | EF6 |
| Complex read queries, reporting | Dapper (5-10x faster) |
| Stored procedures | Dapper (simpler API) |
| Bulk reads | Dapper or EF6 `AsNoTracking` |
| Migrations, schema management | EF6 |
| Hand-tuned SQL (CTEs, window functions) | Dapper |

## Query Optimization

### Index Strategies

```sql
-- Clustered: sorts actual data rows. ONE per table. Auto-created for PRIMARY KEY.
-- Non-clustered: separate structure, up to 999 per table.

-- Covering index (includes all columns query needs = no key lookup)
CREATE NONCLUSTERED INDEX IX_Orders_CustomerDate
ON Orders (CustomerID, OrderDate)
INCLUDE (TotalAmount, Status);

-- Always index foreign key columns
CREATE NONCLUSTERED INDEX IX_Orders_CustomerID ON Orders (CustomerID);
```

Composite index rules: most selective column first, equality before range.

### Query Plan Analysis

```sql
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
-- Run your query
SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
```

### Parameter Sniffing

```sql
-- Problem: plan optimized for first parameter value, bad for others
-- Fix: OPTION (RECOMPILE) for skewed distributions
SELECT * FROM Orders WHERE CustomerID = @CustomerID
OPTION (RECOMPILE);

-- Or: OPTIMIZE FOR UNKNOWN
OPTION (OPTIMIZE FOR (@CustomerID UNKNOWN));
```

### Sargable Predicates (can use indexes)

```sql
-- BAD (non-sargable — function on column prevents index seek)
WHERE ISNULL(ShipDate, '1900-01-01') > '2025-01-01'
WHERE LEFT(Name, 3) = 'Wid'
WHERE dbo.fn_GetYear(OrderDate) = 2025

-- GOOD (sargable)
WHERE ShipDate > '2025-01-01'
WHERE Name LIKE 'Wid%'
WHERE OrderDate >= '2025-01-01' AND OrderDate < '2026-01-01'
```

### N+1 Prevention

```csharp
// BAD: 1 query + N queries in loop
var orders = connection.Query<Order>("SELECT * FROM Orders").ToList();
foreach (var order in orders)
    order.Items = connection.Query<OrderItem>("SELECT * FROM OrderItems WHERE OrderID = @Id",
        new { Id = order.OrderID }).ToList();

// GOOD: 2 queries total
var sql = "SELECT * FROM Orders; SELECT * FROM OrderItems;";
using (var multi = connection.QueryMultiple(sql))
{
    var orders = multi.Read<Order>().ToList();
    var items = multi.Read<OrderItem>().ToList();
    foreach (var order in orders)
        order.Items = items.Where(i => i.OrderID == order.OrderID).ToList();
}
```

### Temp Tables vs Table Variables

| Feature | `#temp` | `@table` |
|---------|---------|----------|
| Statistics | Yes | No (before 2019) |
| Indexes | Any | Only PK/UNIQUE |
| Best for | Large sets (>100 rows) | Small sets (<100 rows) |

## Connection Pooling

- One pool per unique connection string (exact string match)
- `Max Pool Size` reached + new request = queue 15s then exception
- **ALWAYS close/dispose connections** — never rely on GC
- `SqlConnection.ClearAllPools()` after failover
- Integrated Security = separate pool per Windows identity

## Transactions

### SqlTransaction (single connection)

```csharp
var transaction = connection.BeginTransaction(IsolationLevel.ReadCommitted);
```

### TransactionScope (can span multiple connections — escalates to MSDTC)

```csharp
using (var scope = new TransactionScope())
{
    // connections auto-enlist
    scope.Complete(); // omit = rollback
}
```

### Isolation Levels

| Level | Dirty Reads | Non-repeatable | Phantoms |
|-------|-------------|----------------|----------|
| READ UNCOMMITTED | Yes | Yes | Yes |
| READ COMMITTED (default) | No | Yes | Yes |
| REPEATABLE READ | No | No | Yes |
| SNAPSHOT | No | No | No |
| SERIALIZABLE | No | No | No |

### Deadlock Retry Pattern

```csharp
const int MaxRetries = 3;
for (int attempt = 0; attempt < MaxRetries; attempt++)
{
    try
    {
        // ... transaction operations ...
        break;
    }
    catch (SqlException ex) when (ex.Number == 1205 && attempt < MaxRetries - 1)
    {
        Thread.Sleep(100 * (attempt + 1)); // brief backoff
    }
}
```

## Index Maintenance

```sql
-- Check fragmentation
SELECT OBJECT_NAME(ips.object_id), i.name, ips.avg_fragmentation_in_percent
FROM sys.dm_db_index_physical_stats(DB_ID(), DEFAULT, DEFAULT, DEFAULT, 'SAMPLED') ips
JOIN sys.indexes i ON ips.object_id = i.object_id AND ips.index_id = i.index_id
WHERE ips.page_count > 1000
ORDER BY ips.avg_fragmentation_in_percent DESC;

-- 10-30% fragmentation: REORGANIZE (online, lightweight)
ALTER INDEX IX_Name ON dbo.Table REORGANIZE;

-- >30% fragmentation: REBUILD (heavier, updates statistics)
ALTER INDEX IX_Name ON dbo.Table REBUILD WITH (ONLINE = ON);

-- Update statistics (often more impactful than rebuild)
UPDATE STATISTICS dbo.Orders WITH FULLSCAN;
```

## Anti-Patterns

| Anti-Pattern | Fix |
|---|---|
| `AddWithValue` sends `nvarchar` for `varchar` column | Use explicit `SqlParameter` with `SqlDbType` |
| `SELECT *` prevents covering index usage | Select only needed columns |
| Missing indexes on FK columns | Always index foreign keys |
| Scalar functions in WHERE | Rewrite as sargable expressions |
| Cursors for row-by-row processing | Use set-based operations |
| `NOLOCK` everywhere | Use READ COMMITTED SNAPSHOT |
| Missing `SET NOCOUNT ON` in stored procedures | Always add it |
| Not closing connections | Always use `using` blocks |

## Checklist

- [ ] Connection strings in Web.config `<connectionStrings>` (not hardcoded)
- [ ] `MARS=True` if using EF6 lazy loading
- [ ] Explicit `SqlParameter` with `SqlDbType` (not `AddWithValue`)
- [ ] All queries parameterized (NEVER string concatenation)
- [ ] FK columns indexed
- [ ] `SET NOCOUNT ON` in all stored procedures
- [ ] Dapper used for complex reads, EF6 for CRUD with tracking
- [ ] Deadlock retry logic for critical transactions
- [ ] Connection pool sized for workload (`Max Pool Size`)
- [ ] Index maintenance schedule (reorganize/rebuild)
