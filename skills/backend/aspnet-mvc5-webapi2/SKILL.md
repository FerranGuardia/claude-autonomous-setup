---
name: aspnet-mvc5-webapi2
description: ASP.NET MVC 5 + Web API 2 patterns for .NET Framework 4.7. Routing, controllers, filters, model binding, DI, error handling, CORS, configuration. NOT ASP.NET Core.
---

# ASP.NET MVC 5 + Web API 2

**CRITICAL**: This skill covers ASP.NET MVC 5 and Web API 2 on .NET Framework 4.7. These are COMPLETELY DIFFERENT from ASP.NET Core. Never use ASP.NET Core patterns (`builder.Services`, `app.MapControllers()`, `[ApiController]`, `IServiceCollection`, middleware pipeline) in this codebase.

## Architecture Overview

```
Global.asax                          ← Application lifecycle (Start, Error, End)
  └─ Application_Start()
       ├─ GlobalConfiguration.Configure(WebApiConfig.Register)   ← Web API config FIRST
       ├─ FilterConfig.RegisterGlobalFilters(GlobalFilters.Filters)
       ├─ RouteConfig.RegisterRoutes(RouteTable.Routes)          ← MVC routes AFTER Web API
       └─ BundleConfig.RegisterBundles(BundleTable.Bundles)

Two separate pipelines:
  Web API:  ApiController  → System.Web.Http.Filters   → HttpConfiguration
  MVC:      Controller     → System.Web.Mvc             → RouteTable.Routes
```

**Web API config MUST come before MVC routes** — otherwise `api/` routes get swallowed by the MVC catch-all `{controller}/{action}/{id}`.

## Project Structure

```
App_Start/
    WebApiConfig.cs        ← Web API routing, formatters, filters, CORS
    RouteConfig.cs         ← MVC routing
    FilterConfig.cs        ← MVC global filters
    BundleConfig.cs        ← CSS/JS bundling
    UnityConfig.cs         ← DI container registration
Controllers/
    Api/                   ← Web API controllers (: ApiController)
    HomeController.cs      ← MVC controllers (: Controller)
Models/                    ← Domain/DTO models
Filters/                   ← Custom filter attributes
Views/                     ← Razor views (MVC only)
Global.asax                ← Application lifecycle
Web.config                 ← Main configuration
Web.Debug.config           ← Debug transform
Web.Release.config         ← Release transform
packages.config            ← NuGet packages (legacy format)
```

## 1. Routing

### Web API Convention Routing (WebApiConfig.cs)

```csharp
public static class WebApiConfig
{
    public static void Register(HttpConfiguration config)
    {
        // Attribute routing MUST come first
        config.MapHttpAttributeRoutes();

        // Convention route — verb-based action selection
        config.Routes.MapHttpRoute(
            name: "DefaultApi",
            routeTemplate: "api/{controller}/{id}",
            defaults: new { id = RouteParameter.Optional }
        );
    }
}
```

Web API selects actions by **HTTP verb**, not URI path. `GetAllProducts` matches GET, `DeleteProduct` matches DELETE.

### Web API Attribute Routing

```csharp
[RoutePrefix("api/books")]
public class BooksController : ApiController
{
    [Route("")]                     // GET api/books
    public IEnumerable<Book> Get() { ... }

    [Route("{id:int}")]             // GET api/books/5
    public Book Get(int id) { ... }

    [Route("~/api/authors/{authorId:int}/books")]  // Override prefix with ~
    public IEnumerable<Book> GetByAuthor(int authorId) { ... }
}
```

### Route Constraints

```
{id:int}              {name:alpha}           {active:bool}
{date:datetime}       {price:decimal}        {id:guid}
{age:min(18)}         {age:max(120)}         {age:range(18,120)}
{name:minlength(2)}   {name:maxlength(50)}   {code:length(6)}
{ssn:regex(^\d{3}-\d{3}-\d{4}$)}
```

Multiple: `{id:int:min(1)}`. Optional: `{lcid:int?}`.

### MVC Routing (RouteConfig.cs)

```csharp
public static void RegisterRoutes(RouteCollection routes)
{
    routes.IgnoreRoute("{resource}.axd/{*pathInfo}");
    routes.MapRoute(
        "Default",
        "{controller}/{action}/{id}",
        new { controller = "Home", action = "Index", id = "" }
    );
}
```

**Key difference**: MVC uses `{action}` in URL. Web API uses HTTP verb to select action.

## 2. Controllers

### ApiController (Web API) — Returns data

```csharp
public class ProductsController : ApiController
{
    private readonly IProductRepository _repo;

    public ProductsController(IProductRepository repo)  // DI via Unity
    {
        _repo = repo;
    }

    // IHttpActionResult — preferred return type
    public IHttpActionResult Get(int id)
    {
        var product = _repo.Get(id);
        if (product == null) return NotFound();     // 404
        return Ok(product);                          // 200 + serialized body
    }
}
```

### IHttpActionResult Helper Methods

| Method | Status Code |
|--------|-------------|
| `Ok()` | 200 |
| `Ok(content)` | 200 + body |
| `NotFound()` | 404 |
| `BadRequest()` | 400 |
| `BadRequest(message)` | 400 + message |
| `BadRequest(ModelState)` | 400 + validation errors |
| `Content(HttpStatusCode, T)` | Any status + body |
| `Created(uri, T)` | 201 + Location header |
| `CreatedAtRoute(name, values, T)` | 201 + route-based Location |
| `InternalServerError()` | 500 |
| `InternalServerError(exception)` | 500 + exception |
| `StatusCode(HttpStatusCode)` | Any status, no body |
| `Unauthorized(params AuthenticationHeaderValue[])` | 401 |

### HttpResponseMessage — Full control

```csharp
public HttpResponseMessage Get()
{
    var response = Request.CreateResponse(HttpStatusCode.OK, myObject);
    response.Headers.CacheControl = new CacheControlHeaderValue
    {
        MaxAge = TimeSpan.FromMinutes(20)
    };
    return response;
}
```

### Controller (MVC) — Returns views

```csharp
public class HomeController : Controller
{
    public ActionResult Index()
    {
        return View();           // Returns Razor view
    }

    public ActionResult Details(int id)
    {
        var model = _service.Get(id);
        return View(model);      // Returns view with model
    }
}
```

**NEVER mix**: `ApiController` returns data. `Controller` returns views. Different namespaces, different pipelines, different filter systems.

## 3. Filters

### Web API Filters (System.Web.Http.Filters)

Execution order: Authentication → Authorization → Action → Exception

```csharp
// Action filter
public class LogActionFilter : System.Web.Http.Filters.ActionFilterAttribute
{
    public override void OnActionExecuting(HttpActionContext actionContext) { ... }
    public override void OnActionExecuted(HttpActionExecutedContext actionExecutedContext) { ... }
}

// Exception filter
public class GlobalExceptionFilter : ExceptionFilterAttribute
{
    public override void OnException(HttpActionExecutedContext context)
    {
        // Log the exception
        _logger.Error(context.Exception);

        context.Response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
        {
            Content = new StringContent("An error occurred"),
            ReasonPhrase = "Internal Server Error"
        };
    }
}

// Authentication filter (Web API 2.1+)
public class HmacAuthFilter : IAuthenticationFilter
{
    public bool AllowMultiple => false;

    public Task AuthenticateAsync(HttpAuthenticationContext context, CancellationToken ct)
    {
        // Validate HMAC signature, set principal
        return Task.CompletedTask;
    }

    public Task ChallengeAsync(HttpAuthenticationChallengeContext context, CancellationToken ct)
    {
        // Add WWW-Authenticate header on 401
        return Task.CompletedTask;
    }
}
```

### Registering Filters

```csharp
// Globally (WebApiConfig.cs)
config.Filters.Add(new GlobalExceptionFilter());

// Per controller
[LogActionFilter]
public class ProductsController : ApiController { ... }

// Per action
[LogActionFilter]
public IHttpActionResult Get(int id) { ... }
```

**CRITICAL**: `HttpResponseException` is NOT caught by exception filters. It returns an HTTP response directly.

### MVC Filters (System.Web.Mvc) — SEPARATE SYSTEM

MVC filters are in `System.Web.Mvc`. They do NOT apply to Web API controllers, and vice versa. If you need the same filter on both, you must register in both systems.

## 4. Model Binding

### Default Rules

- **Simple types** (int, string, bool, DateTime, Guid, decimal): from URI (route + query string)
- **Complex types**: from request body (JSON deserialized by media formatter)

```csharp
public IHttpActionResult Put(int id, Product item)
// id = from URI, item = from body (JSON)
```

### [FromUri] — Complex type from query string

```csharp
public IHttpActionResult Get([FromUri] GeoPoint location)
// Call: /api/values?Latitude=47.67&Longitude=-122.13
```

### [FromBody] — Simple type from body

```csharp
public IHttpActionResult Post([FromBody] string name)
```

**CRITICAL**: Only ONE parameter can use `[FromBody]`. The body stream is read once and cannot be rewound.

## 5. Error Handling

### HttpResponseException — Direct HTTP response

```csharp
if (item == null)
    throw new HttpResponseException(HttpStatusCode.NotFound);
```

### HttpError — Consistent error body

```csharp
if (!ModelState.IsValid)
    return Request.CreateErrorResponse(HttpStatusCode.BadRequest, ModelState);
```

Returns:
```json
{
  "Message": "The request is invalid.",
  "ModelState": {
    "item.Name": ["The Name field is required."]
  }
}
```

### Global Error Handling (Web API 2.1+)

Exception filters DON'T catch exceptions from: controller constructors, message handlers, routing, response serialization.

```csharp
// IExceptionLogger — logs ALL unhandled exceptions (multiple allowed)
public class TraceExceptionLogger : ExceptionLogger
{
    public override void LogCore(ExceptionLoggerContext context)
    {
        Trace.TraceError(context.ExceptionContext.Exception.ToString());
    }
}

// IExceptionHandler — customizes response (only one)
public class GlobalExceptionHandler : ExceptionHandler
{
    public override void HandleCore(ExceptionHandlerContext context)
    {
        context.Result = new InternalServerErrorResult(context.ExceptionContext.Request);
    }
}

// Register in WebApiConfig
config.Services.Add(typeof(IExceptionLogger), new TraceExceptionLogger());
config.Services.Replace(typeof(IExceptionHandler), new GlobalExceptionHandler());
```

### Global.asax — Last resort

```csharp
protected void Application_Error(object sender, EventArgs e)
{
    Exception exception = Server.GetLastError();
    // Log, then clear
    Server.ClearError();
}
```

## 6. CORS

Install: `Microsoft.AspNet.WebApi.Cors`

```csharp
// WebApiConfig.cs — enable the CORS pipeline
config.EnableCors();

// Per controller/action
[EnableCors(origins: "http://myclient.com", headers: "*", methods: "*")]
public class ApiController : ApiController { ... }

// Disable for specific action
[DisableCors]
public IHttpActionResult SecretAction() { ... }

// Globally
var cors = new EnableCorsAttribute("http://www.example.com", "*", "*");
config.EnableCors(cors);
```

Precedence: Action > Controller > Global.

**IMPORTANT**: Remove `OPTIONSVerbHandler` in Web.config so OPTIONS requests reach Web API:

```xml
<system.webServer>
  <handlers>
    <remove name="OPTIONSVerbHandler" />
  </handlers>
</system.webServer>
```

**NEVER** add CORS headers manually in Web.config `<customHeaders>` — it conflicts with `EnableCorsAttribute` and causes double headers.

## 7. JSON Serialization

Configure in WebApiConfig.cs:

```csharp
var json = config.Formatters.JsonFormatter;

// camelCase output
json.SerializerSettings.ContractResolver = new CamelCasePropertyNamesContractResolver();

// Indented
json.SerializerSettings.Formatting = Formatting.Indented;

// UTC dates
json.SerializerSettings.DateTimeZoneHandling = DateTimeZoneHandling.Utc;

// Handle circular references
json.SerializerSettings.ReferenceLoopHandling = ReferenceLoopHandling.Ignore;

// Remove XML formatter for JSON-only API
config.Formatters.Remove(config.Formatters.XmlFormatter);
```

Control serialization per class:

```csharp
public class Product
{
    public string Name { get; set; }

    [JsonIgnore]
    public int InternalCode { get; set; }

    [JsonProperty("display_name")]
    public string DisplayName { get; set; }
}
```

## 8. Web.config

### Key Sections

```xml
<configuration>
  <appSettings>
    <add key="Environment" value="Dev" />
  </appSettings>

  <connectionStrings>
    <add name="DefaultConnection"
         connectionString="Data Source=.\SQLEXPRESS;Initial Catalog=MyDb;User ID=app;Password=***;MARS=True;Max Pool Size=5000"
         providerName="System.Data.SqlClient" />
  </connectionStrings>

  <system.web>
    <compilation debug="true" targetFramework="4.7" />
    <httpRuntime targetFramework="4.7" maxRequestLength="10240" />
  </system.web>

  <system.webServer>
    <modules>
      <remove name="FormsAuthentication" />
    </modules>
    <handlers>
      <remove name="ExtensionlessUrlHandler-Integrated-4.0" />
      <remove name="OPTIONSVerbHandler" />
      <add name="ExtensionlessUrlHandler-Integrated-4.0" path="*." verb="*"
           type="System.Web.Handlers.TransferRequestHandler"
           preCondition="integratedMode,runtimeVersionv4.0" />
    </handlers>
  </system.webServer>
</configuration>
```

### Web.config Transforms

```xml
<!-- Web.Release.config -->
<configuration xmlns:xdt="http://schemas.microsoft.com/XML-Document-Transform">
  <system.web>
    <compilation xdt:Transform="RemoveAttributes(debug)" />
  </system.web>
  <connectionStrings>
    <add name="DefaultConnection"
         connectionString="Data Source=ProdServer;Initial Catalog=MyDb;..."
         xdt:Transform="SetAttributes" xdt:Locator="Match(name)" />
  </connectionStrings>
</configuration>
```

Transform operations: `SetAttributes`, `RemoveAttributes(attr)`, `Replace`, `Insert`, `Remove`.
Locators: `Match(attr)`, `Condition(xpath)`.

## Anti-Patterns

### NEVER do these in MVC 5 / Web API 2

| Anti-Pattern | Why it's wrong |
|---|---|
| Use `services.AddControllers()` or `builder.Services` | ASP.NET Core pattern — does not exist here |
| Mix `System.Web.Http.Filters` with `System.Web.Mvc` filters | Separate pipelines, not interchangeable |
| Return `HttpResponseMessage` from MVC `Controller` | MVC returns `ActionResult`, not HTTP messages |
| Multiple `[FromBody]` parameters | Body stream reads once only |
| `WebApiConfig.Register(GlobalConfiguration.Configuration)` | Breaks attribute routing — use `GlobalConfiguration.Configure(WebApiConfig.Register)` |
| Throw from `IDependencyResolver.GetService` | Must return `null` for unresolvable types or app crashes |
| Use `HttpContext.Current.Session` in Web API | Breaks statelessness, IIS coupling |
| Add CORS headers in Web.config `<customHeaders>` | Conflicts with `EnableCorsAttribute`, double headers |
| Suppress exceptions in filters without logging | Loses diagnostic info |
| Ignore route registration order | Specific routes MUST come before general ones |

## Checklist

- [ ] `GlobalConfiguration.Configure()` called before `RouteConfig.RegisterRoutes()` in Application_Start
- [ ] Attribute routing enabled with `config.MapHttpAttributeRoutes()`
- [ ] `OPTIONSVerbHandler` removed in Web.config if using CORS
- [ ] XML formatter removed if API is JSON-only
- [ ] camelCase JSON serialization configured
- [ ] `IDependencyResolver.GetService` returns null (not throws) for unresolvable types
- [ ] Exception filters registered globally + `IExceptionLogger` for pipeline exceptions
- [ ] Model validation uses `ModelState.IsValid` with proper error responses
- [ ] No ASP.NET Core patterns anywhere in the codebase
- [ ] Web API filters in `System.Web.Http.Filters`, MVC filters in `System.Web.Mvc`
