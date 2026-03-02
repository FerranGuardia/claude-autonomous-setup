---
name: unity-di
description: Unity 5.x dependency injection container for .NET Framework 4.7. Container setup, lifetime managers, MVC 5 + Web API 2 integration, registration patterns. NOT Microsoft.Extensions.DependencyInjection.
---

# Unity DI Container (5.x)

**CRITICAL**: This is the Unity DI container (`Unity.Container`), NOT `Microsoft.Extensions.DependencyInjection` (ASP.NET Core). Different API, different lifetime models, different registration patterns.

## Container Setup

```csharp
using Unity;
using Unity.Lifetime;

IUnityContainer container = new UnityContainer();

// Interface → Implementation
container.RegisterType<IService, MyService>();

// With lifetime
container.RegisterType<ILogger, FileLogger>(new ContainerControlledLifetimeManager());

// Existing instance
container.RegisterInstance<IAppConfig>(new AppConfig { ConnStr = "..." });

// Resolve
IService service = container.Resolve<IService>();
```

**Constructor selection**: Unity picks the constructor with the **longest parameter list** by default. Override with `InjectionConstructor`:

```csharp
container.RegisterType<ILogger, MockLogger>(
    new ContainerControlledLifetimeManager(),
    new InjectionConstructor()  // force parameterless constructor
);
```

## Lifetime Managers

| Manager | Behavior | Use For |
|---------|----------|---------|
| `TransientLifetimeManager` | **Default.** New instance every `Resolve()` | Stateless services |
| `ContainerControlledLifetimeManager` | Singleton within container + children | App-wide singletons |
| `SingletonLifetimeManager` | Global singleton across entire container tree | Truly global state |
| `HierarchicalLifetimeManager` | Per-scope singleton (child gets its own) | **Per-request in ASP.NET** |
| `PerResolveLifetimeManager` | Singleton within one `Resolve()` call graph | Shared dependency in one resolution |
| `ContainerControlledTransientManager` | Transient but container tracks + disposes | Disposable transients |
| `ExternallyControlledLifetimeManager` | Weak reference only | Externally managed objects |
| `PerThreadLifetimeManager` | One per thread | Thread-local state |

### Per-Request Pattern (ASP.NET)

```csharp
// HierarchicalLifetimeManager + child containers = per-request scope
container.RegisterType<IDbContext, MyContext>(new HierarchicalLifetimeManager());
```

The MVC/Web API integration creates a child container per request. `HierarchicalLifetimeManager` gives each child its own instance.

## ASP.NET MVC 5 Integration

Package: `Unity.Mvc` (v5.11.1)

```csharp
// App_Start/UnityConfig.cs
using Unity;
using Unity.Mvc;
using System.Web.Mvc;

public static class UnityConfig
{
    public static void RegisterComponents()
    {
        var container = new UnityContainer();

        container.RegisterType<IProductRepository, ProductRepository>();
        container.RegisterType<IOrderService, OrderService>(
            new HierarchicalLifetimeManager());

        DependencyResolver.SetResolver(new UnityDependencyResolver(container));
    }
}
```

## ASP.NET Web API 2 Integration

Package: `Unity.AspNet.WebApi` (v5.11.2)

```csharp
// App_Start/UnityWebApiActivator.cs
using Unity;
using Unity.AspNet.WebApi;
using System.Web.Http;

public static class UnityWebApiActivator
{
    public static void Start()
    {
        var container = new UnityContainer();

        container.RegisterType<IProductService, ProductService>();
        container.RegisterType<IUserRepository, UserRepository>(
            new HierarchicalLifetimeManager());

        GlobalConfiguration.Configuration.DependencyResolver =
            new UnityDependencyResolver(container);
    }
}
```

### Combined MVC + Web API

Share the same `UnityContainer` but set **two separate resolvers**:

```csharp
var container = new UnityContainer();
// ... registrations ...

// MVC resolver
System.Web.Mvc.DependencyResolver.SetResolver(new Unity.Mvc.UnityDependencyResolver(container));

// Web API resolver (different class, different namespace)
GlobalConfiguration.Configuration.DependencyResolver =
    new Unity.AspNet.WebApi.UnityDependencyResolver(container);
```

## Injection Patterns

### Constructor Injection (preferred)

```csharp
public class OrderService : IOrderService
{
    private readonly IRepository _repo;
    private readonly ILogger _logger;

    // Unity resolves both automatically
    public OrderService(IRepository repo, ILogger logger)
    {
        _repo = repo;
        _logger = logger;
    }
}
```

### Property Injection

```csharp
using Unity;

public class OrderService : IOrderService
{
    [Dependency]
    public ILogger Logger { get; set; }

    [Dependency("special")]    // Named dependency
    public ICache Cache { get; set; }
}

// Or via registration
container.RegisterType<IOrderService, OrderService>(
    new InjectionProperty("Logger"));
```

## Named Registrations

```csharp
container.RegisterType<INotifier, EmailNotifier>("email");
container.RegisterType<INotifier, SmsNotifier>("sms");

// Resolve specific
INotifier email = container.Resolve<INotifier>("email");

// Resolve ALL named (does NOT include default unnamed)
IEnumerable<INotifier> all = container.ResolveAll<INotifier>();

// Inject specific named dependency
container.RegisterType<AlertService>(
    new InjectionConstructor(new ResolvedParameter<INotifier>("sms")));
```

## Registration by Convention

```csharp
using Unity.RegistrationByConvention;

container.RegisterTypes(
    AllClasses.FromLoadedAssemblies()
        .Where(t => t.Namespace?.StartsWith("MyApp.Services") == true),
    WithMappings.FromMatchingInterface,  // IFoo → Foo
    WithName.Default,
    WithLifetime.Transient
);
```

## Common Pitfalls

| Pitfall | Problem | Solution |
|---------|---------|----------|
| Singleton holds per-request dependency | Captive dependency — scoped object lives forever | Use same or longer lifetime for dependencies |
| `IDisposable` with `TransientLifetimeManager` | Container doesn't track/dispose transients | Use `ContainerControlledTransientManager` or dispose manually |
| Forgetting to dispose child containers | Scoped singletons leak | Ensure MVC/WebAPI integration disposes per-request containers |
| Sharing `InjectionConstructor` instances | Runtime errors | Each `RegisterType` needs its own `InjectionConstructor` |
| `ContainerControlledLifetimeManager` + `IDisposable` | Object never disposed until container dies | Call `container.Dispose()` on app shutdown |
| v5.2.1 singleton sharing change | Two interfaces mapping to same impl no longer share instance | Register impl separately, then map both interfaces |

### v5.2.1 Breaking Change

```csharp
// Before 5.2.1: these share one MockLogger instance
container.RegisterType<ILogger, MockLogger>(new ContainerControlledLifetimeManager());
container.RegisterType<IDebugger, MockLogger>(new ContainerControlledLifetimeManager());

// After 5.2.1: these create SEPARATE instances. To share:
container.RegisterType<MockLogger>(new ContainerControlledLifetimeManager());
container.RegisterType<ILogger, MockLogger>();
container.RegisterType<IDebugger, MockLogger>();
```

## Checklist

- [ ] `HierarchicalLifetimeManager` used for per-request services (DbContext, UnitOfWork)
- [ ] `ContainerControlledLifetimeManager` used for true singletons only
- [ ] Both MVC and Web API resolvers set if using both frameworks
- [ ] `container.Dispose()` called in `Application_End`
- [ ] No captive dependencies (singleton holding scoped reference)
- [ ] Constructor injection preferred over `[Dependency]` property injection
- [ ] No reuse of `InjectionConstructor` instances across registrations
