---
name: quartz-scheduling
description: Quartz.NET 3.x job scheduling for .NET Framework 4.7. Scheduler setup, job/trigger patterns, cron expressions, persistent job store, ASP.NET integration, CrystalQuartz dashboard.
---

# Quartz.NET 3.x Scheduling

## Scheduler Setup

```csharp
using Quartz;
using Quartz.Impl;

StdSchedulerFactory factory = new StdSchedulerFactory();
IScheduler scheduler = await factory.GetScheduler();
await scheduler.Start();

// Triggers do NOT fire until Start() is called
// Once shut down, cannot restart without re-instantiation
await scheduler.Shutdown(waitForJobsToComplete: true);
```

### With Configuration Properties

```csharp
var properties = new NameValueCollection
{
    ["quartz.scheduler.instanceName"] = "MyScheduler",
    ["quartz.threadPool.maxConcurrency"] = "10",
    ["quartz.jobStore.type"] = "Quartz.Impl.AdoJobStore.JobStoreTX, Quartz",
    ["quartz.jobStore.driverDelegateType"] = "Quartz.Impl.AdoJobStore.SqlServerDelegate, Quartz",
    ["quartz.jobStore.tablePrefix"] = "QRTZ_",
    ["quartz.jobStore.dataSource"] = "myDS",
    ["quartz.dataSource.myDS.connectionString"] = "Server=.;Database=QuartzDB;...",
    ["quartz.dataSource.myDS.provider"] = "SqlServer",
    ["quartz.serializer.type"] = "json"
};

ISchedulerFactory factory = new StdSchedulerFactory(properties);
IScheduler scheduler = await factory.GetScheduler();
```

## Job Definition

```csharp
[DisallowConcurrentExecution]       // CRITICAL: prevent overlapping executions
[PersistJobDataAfterExecution]      // Save updated JobDataMap after execution
public class SendEmailJob : IJob
{
    // Auto-property injection: Quartz sets these from JobDataMap
    public string Recipient { get; set; }

    public async Task Execute(IJobExecutionContext context)
    {
        JobDataMap dataMap = context.MergedJobDataMap;
        string subject = dataMap.GetString("subject");

        try
        {
            await SendEmailAsync(Recipient, subject);
        }
        catch (Exception ex)
        {
            // ONLY throw JobExecutionException from Execute()
            throw new JobExecutionException("Failed", ex, refireImmediately: false);
        }
    }
}
```

**Key facts**: New instance per execution (instance fields don't persist). Must have parameterless constructor. Public setters auto-populated from `JobDataMap`.

## Triggers

### SimpleTrigger (interval-based)

```csharp
// Fire every 30 seconds, forever
ITrigger trigger = TriggerBuilder.Create()
    .WithIdentity("repeating", "group1")
    .StartNow()
    .WithSimpleSchedule(x => x
        .WithIntervalInSeconds(30)
        .RepeatForever())
    .Build();

// Fire every 2 hours, 10 times
ITrigger trigger = TriggerBuilder.Create()
    .WithSimpleSchedule(x => x
        .WithIntervalInHours(2)
        .WithRepeatCount(10))
    .Build();
```

### CronTrigger

Format: `Seconds Minutes Hours DayOfMonth Month DayOfWeek [Year]`

```csharp
ITrigger trigger = TriggerBuilder.Create()
    .WithCronSchedule("0 0/2 8-17 * * ?")  // every 2 min, business hours
    .Build();
```

### Common Cron Expressions

| Expression | Meaning |
|------------|---------|
| `0 0 12 * * ?` | Every day at noon |
| `0 15 10 ? * MON-FRI` | 10:15 AM weekdays |
| `0 0/5 * * * ?` | Every 5 minutes |
| `0 0 8-17 * * ?` | Every hour 8 AM-5 PM |
| `0 15 10 L * ?` | 10:15 AM last day of month |
| `0 15 10 ? * 6L` | 10:15 AM last Friday of month |
| `0 15 10 ? * 6#3` | 10:15 AM third Friday of month |
| `0 0 2 * * ?` | Every day at 2 AM |

Special characters:
- `?` — required when other day field is set (can't specify both day-of-month AND day-of-week)
- `L` — last (last day of month, or `6L` = last Friday)
- `W` — nearest weekday (`15W` = nearest weekday to 15th)
- `#` — nth occurrence (`6#3` = third Friday)
- `/` — increments (`0/15` = every 15 starting at 0)

## Job Scheduling

```csharp
IJobDetail job = JobBuilder.Create<SendEmailJob>()
    .WithIdentity("emailJob", "emailGroup")
    .UsingJobData("recipient", "admin@example.com")
    .UsingJobData("subject", "Daily Report")
    .StoreDurably()           // keep even without triggers
    .RequestRecovery()        // re-execute if scheduler crashes
    .Build();

ITrigger trigger = TriggerBuilder.Create()
    .WithIdentity("emailTrigger", "emailGroup")
    .StartNow()
    .WithCronSchedule("0 0 9 ? * MON-FRI")
    .Build();

await scheduler.ScheduleJob(job, trigger);

// Add another trigger to existing job
ITrigger secondTrigger = TriggerBuilder.Create()
    .ForJob("emailJob", "emailGroup")
    .WithCronSchedule("0 0 17 ? * MON-FRI")
    .Build();
await scheduler.ScheduleJob(secondTrigger);
```

## Persistent Job Store (AdoJobStore)

Uses `QRTZ_` prefixed tables in SQL Server. Survives restarts. Supports clustering.

```csharp
["quartz.jobStore.type"] = "Quartz.Impl.AdoJobStore.JobStoreTX, Quartz",
["quartz.jobStore.driverDelegateType"] = "Quartz.Impl.AdoJobStore.SqlServerDelegate, Quartz",
["quartz.jobStore.tablePrefix"] = "QRTZ_",
["quartz.jobStore.useProperties"] = "true",        // store as strings (recommended)
["quartz.jobStore.clustered"] = "true",             // for multi-instance
["quartz.serializer.type"] = "json"
```

RAMJobStore (default): in-memory, fast, but all jobs lost on restart.

## Misfire Policies

| Trigger Type | Policy | Behavior |
|--------------|--------|----------|
| SimpleTrigger | `FireNow` | Fire immediately |
| SimpleTrigger | `RescheduleNowWithRemainingRepeatCount` | Fire now, remaining repeats only |
| SimpleTrigger | `RescheduleNextWithRemainingCount` | Wait for next scheduled time |
| CronTrigger | `DoNothing` | Skip misfired firings, wait for next |
| CronTrigger | `FireOnceNow` | Fire once now, resume normal |
| Both | `SmartPolicy` (default) | Auto-selects appropriate behavior |

Misfire threshold: default 60 seconds.

## ASP.NET Integration (Global.asax)

```csharp
public class MvcApplication : System.Web.HttpApplication
{
    private IScheduler _scheduler;

    protected async void Application_Start()
    {
        AreaRegistration.RegisterAllAreas();
        RouteConfig.RegisterRoutes(RouteTable.Routes);

        ISchedulerFactory factory = new StdSchedulerFactory();
        _scheduler = await factory.GetScheduler();
        await _scheduler.Start();

        // Schedule jobs here
        await ScheduleJobs(_scheduler);
    }

    protected async void Application_End()
    {
        if (_scheduler != null && !_scheduler.IsShutdown)
            await _scheduler.Shutdown(waitForJobsToComplete: true);
    }
}
```

## CrystalQuartz Dashboard

Package: `CrystalQuartz.Owin`

```csharp
// Startup.cs (OWIN)
using CrystalQuartz.Owin;

public class Startup
{
    public void Configuration(IAppBuilder app)
    {
        app.UseCrystalQuartz(() => scheduler, new CrystalQuartzOptions
        {
            Path = "/quartz-dashboard"
        });
    }
}
// Dashboard at: http://localhost:PORT/quartz-dashboard
```

## Common Pitfalls

| Pitfall | Solution |
|---------|----------|
| Missing `[DisallowConcurrentExecution]` | Jobs overlap if they take longer than trigger interval — always use it |
| Forgetting `scheduler.Start()` | Nothing fires — triggers only fire after `Start()` |
| Not calling `Shutdown()` in `Application_End` | Threads keep running after app pool recycle |
| Unhandled exceptions in `Execute()` | Only throw `JobExecutionException` — wrap everything in try-catch |
| Long-running jobs blocking thread pool | Increase `maxConcurrency` or use async I/O |
| `JobDataMap` serialization in AdoJobStore | Set `useProperties = true` to store as strings |
| Not using `[PersistJobDataAfterExecution]` with `[DisallowConcurrentExecution]` | Updated JobDataMap values are lost between executions |

## Checklist

- [ ] `[DisallowConcurrentExecution]` on all jobs that shouldn't overlap
- [ ] `[PersistJobDataAfterExecution]` when using `DisallowConcurrentExecution`
- [ ] `Execute()` wrapped in try-catch, only throws `JobExecutionException`
- [ ] `scheduler.Start()` called in `Application_Start`
- [ ] `scheduler.Shutdown(true)` called in `Application_End`
- [ ] AdoJobStore with `useProperties = true` for persistent storage
- [ ] Misfire policy explicitly set for critical jobs
- [ ] Thread pool `maxConcurrency` sized for workload
