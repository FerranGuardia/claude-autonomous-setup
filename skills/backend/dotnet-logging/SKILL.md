---
name: dotnet-logging
description: log4net + ELMAH logging and error tracking for .NET Framework 4.7. Configuration, appenders, Web API integration, error filtering, dashboard security.
---

# Logging & Error Tracking (.NET Framework)

## log4net

### Initialization

```csharp
// Option A: Assembly attribute (preferred)
[assembly: log4net.Config.XmlConfigurator(Watch = true)]

// Option B: In Global.asax
protected void Application_Start()
{
    log4net.Config.XmlConfigurator.Configure();
}

// Option C: External file
[assembly: log4net.Config.XmlConfigurator(ConfigFile = "log4net.config", Watch = true)]
```

**Note**: `Watch = true` does NOT work when config is in Web.config (System.Configuration doesn't support reload). Use a separate file if you need watch.

### Usage

```csharp
private static readonly ILog log = LogManager.GetLogger(typeof(MyClass));

log.Debug("Debug message");
log.Info("Info message");
log.Warn("Warning message");
log.Error("Error message", ex);    // With exception
log.Fatal("Fatal message");

// Format (avoid string concatenation for performance)
log.DebugFormat("Processing {0} items", count);

// Guard expensive operations
if (log.IsDebugEnabled)
    log.DebugFormat("Expensive: {0}", ComputeExpensiveString());
```

Levels (ascending): `ALL` < `DEBUG` < `INFO` < `WARN` < `ERROR` < `FATAL` < `OFF`

Calling `GetLogger` with same name returns same instance — no need to pass references.

### Web.config Configuration

```xml
<configSections>
  <section name="log4net"
           type="log4net.Config.Log4NetConfigurationSectionHandler, log4net"
           requirePermission="false" />
</configSections>

<log4net>
  <!-- RollingFileAppender: date + size rolling -->
  <appender name="RollingFile" type="log4net.Appender.RollingFileAppender">
    <file value="Logs\app.log" />
    <appendToFile value="true" />
    <rollingStyle value="Composite" />
    <datePattern value="yyyyMMdd" />
    <maxSizeRollBackups value="10" />
    <maximumFileSize value="10MB" />
    <staticLogFileName value="true" />
    <layout type="log4net.Layout.PatternLayout">
      <conversionPattern value="%date [%thread] %-5level %logger - %message%newline" />
    </layout>
  </appender>

  <!-- AdoNetAppender: SQL Server -->
  <appender name="SqlAppender" type="log4net.Appender.AdoNetAppender">
    <bufferSize value="100" />
    <connectionType value="System.Data.SqlClient.SqlConnection, System.Data, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089" />
    <connectionString value="data source=.\SQLEXPRESS;initial catalog=Logging;integrated security=true;" />
    <commandText value="INSERT INTO Log ([Date],[Thread],[Level],[Logger],[Message],[Exception]) VALUES (@log_date, @thread, @log_level, @logger, @message, @exception)" />
    <parameter>
      <parameterName value="@log_date" />
      <dbType value="DateTime" />
      <layout type="log4net.Layout.RawTimeStampLayout" />
    </parameter>
    <parameter>
      <parameterName value="@thread" />
      <dbType value="String" /><size value="255" />
      <layout type="log4net.Layout.PatternLayout">
        <conversionPattern value="%thread" />
      </layout>
    </parameter>
    <parameter>
      <parameterName value="@log_level" />
      <dbType value="String" /><size value="50" />
      <layout type="log4net.Layout.PatternLayout">
        <conversionPattern value="%level" />
      </layout>
    </parameter>
    <parameter>
      <parameterName value="@logger" />
      <dbType value="String" /><size value="255" />
      <layout type="log4net.Layout.PatternLayout">
        <conversionPattern value="%logger" />
      </layout>
    </parameter>
    <parameter>
      <parameterName value="@message" />
      <dbType value="String" /><size value="4000" />
      <layout type="log4net.Layout.PatternLayout">
        <conversionPattern value="%message" />
      </layout>
    </parameter>
    <parameter>
      <parameterName value="@exception" />
      <dbType value="String" /><size value="2000" />
      <layout type="log4net.Layout.ExceptionLayout" />
    </parameter>
  </appender>

  <!-- Named logger for specific namespace -->
  <logger name="MyApp.DataAccess" additivity="false">
    <level value="DEBUG" />
    <appender-ref ref="SqlAppender" />
  </logger>

  <!-- Root logger -->
  <root>
    <level value="INFO" />
    <appender-ref ref="RollingFile" />
  </root>
</log4net>
```

### PatternLayout Tokens

| Token | Meaning |
|-------|---------|
| `%date` | Timestamp |
| `%level` | Log level |
| `%-5level` | Left-aligned, 5-char padded level |
| `%logger` | Logger name |
| `%message` | Log message |
| `%exception` | Exception info |
| `%newline` | Line break |
| `%thread` | Thread name/ID |
| `%property{key}` | Context property |
| `%file` | Source file (slow — uses stack trace) |
| `%line` | Source line (slow — uses stack trace) |

### Context Properties

```csharp
// Per-thread (per-request)
log4net.ThreadContext.Properties["user"] = username;
log4net.ThreadContext.Properties["sessionId"] = sessionId;

// Global (app-wide)
log4net.GlobalContext.Properties["appVersion"] = "1.0.0";

// Access in pattern: %property{user}
```

### Logger Hierarchy

`additivity="false"` prevents messages from propagating to parent/root appenders:

```xml
<logger name="MyApp.DataAccess" additivity="false">
  <level value="DEBUG" />
  <appender-ref ref="DataAccessAppender" />
</logger>
```

---

## ELMAH

### Setup

Packages: `Elmah` + `Elmah.Mvc`

```xml
<configSections>
  <sectionGroup name="elmah">
    <section name="security" requirePermission="false"
             type="Elmah.SecuritySectionHandler, Elmah" />
    <section name="errorLog" requirePermission="false"
             type="Elmah.ErrorLogSectionHandler, Elmah" />
    <section name="errorFilter" requirePermission="false"
             type="Elmah.ErrorFilterSectionHandler, Elmah" />
  </sectionGroup>
</configSections>

<elmah>
  <errorLog type="Elmah.SqlErrorLog, Elmah"
            connectionStringName="ElmahConnectionString" />
  <security allowRemoteAccess="0" />
</elmah>

<system.webServer>
  <modules>
    <add name="ErrorLog" type="Elmah.ErrorLogModule, Elmah" preCondition="managedHandler" />
    <add name="ErrorFilter" type="Elmah.ErrorFilterModule, Elmah" preCondition="managedHandler" />
  </modules>
</system.webServer>
```

### Error Log Backends

| Backend | Type | Use For |
|---------|------|---------|
| `SqlErrorLog` | SQL Server | Production |
| `XmlFileErrorLog` | XML files (set `logPath`) | No-DB environments |
| `MemoryErrorLog` | In-memory (max 500) | Development/testing |

### Web API Integration (CRITICAL — ELMAH doesn't catch Web API exceptions by default)

```csharp
public class ElmahExceptionLogger : ExceptionLogger
{
    public override void LogCore(ExceptionLoggerContext context)
    {
        var signal = ErrorSignal.FromCurrentContext();
        signal.Raise(context.ExceptionContext.Exception);
    }
}

// Register in WebApiConfig.cs
config.Services.Add(typeof(IExceptionLogger), new ElmahExceptionLogger());
```

### Dashboard Security

```xml
<!-- Restrict elmah.axd access -->
<location path="elmah.axd">
  <system.web>
    <authorization>
      <allow roles="admin" />
      <deny users="*" />
    </authorization>
  </system.web>
</location>
```

Must add `routes.IgnoreRoute("elmah.axd")` in `RouteConfig.cs`.

### Error Filtering

```xml
<elmah>
  <errorFilter>
    <test>
      <!-- Filter 404s -->
      <equal binding="HttpStatusCode" value="404" type="Int32" />
    </test>
  </errorFilter>
</elmah>
```

Filter 400-499 range:
```xml
<errorFilter>
  <test>
    <and>
      <greater binding="HttpStatusCode" value="399" type="Int32" />
      <lesser binding="HttpStatusCode" value="500" type="Int32" />
    </and>
  </test>
</errorFilter>
```

Programmatic filtering in Global.asax:
```csharp
void ErrorLog_Filtering(object sender, ExceptionFilterEventArgs e)
{
    if (e.Exception.GetBaseException() is HttpRequestValidationException)
        e.Dismiss();
}
```

## Checklist

- [ ] log4net initialized via assembly attribute or Global.asax
- [ ] Rolling file appender configured with size/date limits
- [ ] Logger hierarchy uses `additivity="false"` for namespace-specific loggers
- [ ] ELMAH modules registered in `system.webServer` (integrated mode)
- [ ] ELMAH `ElmahExceptionLogger` registered for Web API pipeline
- [ ] `elmah.axd` secured with authorization rules
- [ ] `routes.IgnoreRoute("elmah.axd")` in RouteConfig
- [ ] Error filtering configured to suppress noise (404s, validation errors)
- [ ] Remote access disabled (`allowRemoteAccess="0"`) unless explicitly needed
