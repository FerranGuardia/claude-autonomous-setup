---
name: entity-framework-6
description: Entity Framework 6 Code-First patterns for .NET Framework 4.7. DbContext, migrations, querying, relationships, performance, bulk operations, Dapper coexistence. NOT EF Core.
---

# Entity Framework 6

**CRITICAL**: This skill covers Entity Framework 6 on .NET Framework. NOT EF Core. Key differences:
- Namespace: `System.Data.Entity` (not `Microsoft.EntityFrameworkCore`)
- `DbModelBuilder` in `OnModelCreating` (not `ModelBuilder`)
- `Database.SetInitializer<T>()` exists (EF Core has no equivalent)
- Lazy loading is ON by default (EF Core requires explicit opt-in)
- `CompiledQuery` only works with `ObjectContext`, not `DbContext`
- `Include()` cannot filter (EF Core 5+ can)

## DbContext

### Constructor Patterns

```csharp
// Convention: uses class name as database name
public class BlogContext : DbContext { }

// Named connection string from Web.config
public class BlogContext : DbContext
{
    public BlogContext() : base("name=BloggingDatabase") { }
}

// Existing connection (EF6 allows open connections)
public class BlogContext : DbContext
{
    public BlogContext(DbConnection conn, bool ownsConnection)
        : base(conn, ownsConnection) { }
}
```

### Configuration Properties

```csharp
public class MyContext : DbContext
{
    public MyContext()
    {
        Configuration.LazyLoadingEnabled = false;        // Default: true
        Configuration.ProxyCreationEnabled = false;       // Default: true
        Configuration.AutoDetectChangesEnabled = true;    // Default: true
    }

    public DbSet<Product> Products { get; set; }

    protected override void OnModelCreating(DbModelBuilder modelBuilder)
    {
        modelBuilder.Conventions.Remove<PluralizingTableNameConvention>();
        modelBuilder.HasDefaultSchema("dbo");
    }
}
```

### Lifetime: One context per request. Always use `using`. NOT thread-safe.

## Code-First Migrations

```
Enable-Migrations                                    # Creates Migrations/Configuration.cs
Add-Migration AddBlogUrl                             # Generates Up()/Down() migration
Update-Database                                      # Apply pending migrations
Update-Database -Verbose                             # Show SQL
Update-Database -TargetMigration: AddBlogUrl         # Migrate to specific version
Update-Database -TargetMigration: $InitialDatabase   # Roll back to empty
Update-Database -Script                              # Generate SQL script only
```

### Migration Class

```csharp
public partial class AddBlogUrl : DbMigration
{
    public override void Up()
    {
        AddColumn("dbo.Blogs", "Url", c => c.String());
        // Raw SQL in migrations
        Sql("UPDATE dbo.Blogs SET Url = 'http://default' WHERE Url IS NULL");
    }

    public override void Down()
    {
        DropColumn("dbo.Blogs", "Url");
    }
}
```

### Seed Method (Configuration.cs)

```csharp
internal sealed class Configuration : DbMigrationsConfiguration<MyContext>
{
    public Configuration()
    {
        AutomaticMigrationsEnabled = false;  // Explicit migrations recommended
    }

    protected override void Seed(MyContext context)
    {
        context.Blogs.AddOrUpdate(
            b => b.Name,                     // Match on this property
            new Blog { Name = "Default" }    // Insert or update
        );
    }
}
```

### Auto-migrate on startup

```csharp
Database.SetInitializer(new MigrateDatabaseToLatestVersion<MyContext, Configuration>());
```

## Entity States

| State | SaveChanges | How to set |
|-------|-------------|------------|
| Added | INSERT | `context.Set.Add(entity)` or `Entry(e).State = Added` |
| Unchanged | Skip | After `SaveChanges()` or `Attach()` |
| Modified | UPDATE | Change tracked property or `Entry(e).State = Modified` |
| Deleted | DELETE | `context.Set.Remove(entity)` or `Entry(e).State = Deleted` |
| Detached | Ignore | Before `Add`/`Attach`, or after `AsNoTracking()` |

### Insert-or-Update Pattern

```csharp
public void InsertOrUpdate(Blog blog)
{
    using (var context = new MyContext())
    {
        context.Entry(blog).State = blog.BlogId == 0
            ? EntityState.Added
            : EntityState.Modified;
        context.SaveChanges();
    }
}
```

## Loading Strategies

### Lazy Loading (ON by default — the #1 source of N+1 bugs)

```csharp
public class Blog
{
    public int BlogId { get; set; }
    public virtual ICollection<Post> Posts { get; set; }  // virtual = lazy loaded
}

// N+1 BUG:
var blogs = context.Blogs.ToList();       // 1 query
foreach (var blog in blogs)
    foreach (var post in blog.Posts)       // N queries!
        Console.WriteLine(post.Title);
```

### Eager Loading (Include)

```csharp
// Single level
var blogs = context.Blogs.Include(b => b.Posts).ToList();

// Multi-level
var blogs = context.Blogs
    .Include(b => b.Posts.Select(p => p.Comments))
    .ToList();

// String-based (for dynamic includes)
var blogs = context.Blogs.Include("Posts.Comments").ToList();
```

**LIMITATION**: `Include()` loads ALL related entities. Cannot filter. Unlike EF Core 5+.

### Explicit Loading

```csharp
var blog = context.Blogs.Find(1);

// Load collection
context.Entry(blog).Collection(b => b.Posts).Load();

// Load with filter
context.Entry(blog).Collection(b => b.Posts)
    .Query()
    .Where(p => p.IsPublished)
    .Load();

// Count without loading
var count = context.Entry(blog).Collection(b => b.Posts).Query().Count();

// Load reference
context.Entry(post).Reference(p => p.Blog).Load();
```

### AsNoTracking (read-only queries)

```csharp
var products = context.Products
    .AsNoTracking()
    .Where(p => p.IsActive)
    .ToList();
```

28% less memory, ~16% faster than tracked queries.

## Relationships

### One-to-Many (Fluent API)

```csharp
modelBuilder.Entity<Course>()
    .HasRequired(c => c.Department)       // Required FK
    .WithMany(d => d.Courses)             // Collection on other side
    .HasForeignKey(c => c.DepartmentID)   // FK property
    .WillCascadeOnDelete(false);

// Optional FK
modelBuilder.Entity<Course>()
    .HasOptional(c => c.Department)
    .WithMany(d => d.Courses)
    .HasForeignKey(c => c.DepartmentID);
```

### Many-to-Many

```csharp
modelBuilder.Entity<Course>()
    .HasMany(c => c.Instructors)
    .WithMany(i => i.Courses)
    .Map(m =>
    {
        m.ToTable("CourseInstructor");
        m.MapLeftKey("CourseID");
        m.MapRightKey("InstructorID");
    });
```

### One-to-One

```csharp
modelBuilder.Entity<OfficeAssignment>()
    .HasRequired(o => o.Instructor)
    .WithOptional(i => i.OfficeAssignment);
```

### Data Annotations

```csharp
[Key]                              // Primary key
[Column(Order = 0)]                // Composite key ordering
[Required]                         // Non-nullable
[MaxLength(50)]                    // Max length
[Table("MyTable")]                 // Table name
[Column("ColName")]                // Column name
[NotMapped]                        // Exclude from DB
[ForeignKey("NavigationProp")]     // Foreign key
[InverseProperty("PropertyName")]  // Disambiguate multiple relationships
[Index("IX_Name", IsUnique = true)] // Index (EF6.1+)
[ConcurrencyCheck]                 // Optimistic concurrency
[Timestamp]                        // Row version byte[]
[DatabaseGenerated(DatabaseGeneratedOption.Identity)] // Auto-increment
```

## Raw SQL

```csharp
// SqlQuery on DbSet — entities ARE tracked
var blogs = context.Blogs.SqlQuery("SELECT * FROM dbo.Blogs").ToList();

// SqlQuery on Database — NOT tracked
var names = context.Database.SqlQuery<string>("SELECT Name FROM dbo.Blogs").ToList();

// Parameterized (ALWAYS parameterize, never concatenate)
var blog = context.Blogs.SqlQuery("dbo.GetBlogById @p0", blogId).Single();

// Non-query
context.Database.ExecuteSqlCommand(
    "UPDATE dbo.Blogs SET Name = @p0 WHERE BlogId = @p1", newName, blogId);
```

## Performance

### Bulk Operations (EF6 has NO native bulk insert)

```csharp
// AddRange — reduces DetectChanges overhead but still individual INSERTs
context.Products.AddRange(listOfProducts);
context.SaveChanges();

// EntityFramework.BulkInsert (uses SqlBulkCopy)
using EntityFramework.BulkInsert.Extensions;
context.BulkInsert(hugeListOfEntities);

// Manual SqlBulkCopy
using (var bulkCopy = new SqlBulkCopy((SqlConnection)context.Database.Connection))
{
    bulkCopy.DestinationTableName = "dbo.Products";
    bulkCopy.WriteToServer(dataTable);
}

// Bulk update/delete — use raw SQL
context.Database.ExecuteSqlCommand(
    "DELETE FROM Logs WHERE CreatedDate < @p0", cutoffDate);
```

### Disable AutoDetectChanges for Bulk Adds

```csharp
try
{
    context.Configuration.AutoDetectChangesEnabled = false;
    context.Products.AddRange(products);
    context.SaveChanges();
}
finally
{
    context.Configuration.AutoDetectChangesEnabled = true;
}
```

## Dapper Alongside EF6

### When to use which

| Scenario | Use |
|----------|-----|
| CRUD with change tracking | EF6 |
| Complex read queries, reporting | Dapper |
| Bulk reads | Dapper or EF6 `AsNoTracking` |
| Stored procedures | Dapper (`Query`) or EF6 (`SqlQuery`) |
| Migrations, schema | EF6 |

### Sharing the Same Connection

```csharp
using Dapper;

using (var context = new MyContext())
{
    var connection = context.Database.Connection;

    // Dapper query on same connection
    var results = connection.Query<ProductDto>(
        "SELECT ProductId, Name, Price FROM Products WHERE CategoryId = @CategoryId",
        new { CategoryId = 5 });

    // EF6 still works on same context
    var category = context.Categories.Find(5);
    context.SaveChanges();
}
```

### Sharing a Transaction

```csharp
using (var context = new MyContext())
{
    context.Database.Connection.Open();

    using (var transaction = context.Database.BeginTransaction())
    {
        try
        {
            // EF6 operation
            context.Products.Add(new Product { Name = "New" });
            context.SaveChanges();

            // Dapper operation — same connection + transaction
            context.Database.Connection.Execute(
                "INSERT INTO AuditLog (Action) VALUES (@Action)",
                new { Action = "ProductCreated" },
                transaction.UnderlyingTransaction);

            transaction.Commit();
        }
        catch
        {
            transaction.Rollback();
            throw;
        }
    }
}
```

## Common Pitfalls

| Pitfall | Solution |
|---------|----------|
| N+1 queries from lazy loading | Use `Include()` for eager loading or disable lazy loading |
| `ObjectDisposedException` accessing nav props after context disposed | Eager load before disposing, or project to DTO inside `using` |
| Serializer triggers lazy load cascade (loads entire DB) | Disable lazy loading before serialization, use DTOs, use `[JsonIgnore]` |
| `DetectChanges` slow on large graphs | `AddRange`/`RemoveRange`, disable `AutoDetectChanges` for bulk ops |
| Dynamic queries fill query plan cache (800 limit) | Use parameterized lambdas: `.Skip(() => i)` not `.Skip(i)` |
| `Include()` loads ALL related entities | Use explicit loading with `.Query().Where()` for filtered loads |
| EF6 `CompiledQuery` only works with `ObjectContext` | Don't try to use it with `DbContext` |
| Composing over compiled queries bypasses cache | `.ToList()` the compiled query result before further LINQ |
| `MARS=True` missing causes "already an open DataReader" | Add `MultipleActiveResultSets=True` to connection string |

## Checklist

- [ ] Lazy loading decision made (enabled or disabled) and documented
- [ ] `Include()` used for all known eager loading paths
- [ ] `AsNoTracking()` used for read-only queries
- [ ] `MARS=True` in connection string if lazy loading enabled
- [ ] `AddRange`/`RemoveRange` used instead of loops for bulk operations
- [ ] Raw SQL uses parameterized queries (`@p0`, never string concatenation)
- [ ] DTOs used for API responses (not entities with navigation properties)
- [ ] Migrations use explicit mode (`AutomaticMigrationsEnabled = false`)
- [ ] Connection string in Web.config `<connectionStrings>` section
- [ ] No EF Core patterns in the codebase
