namespace vm2.DevOps.Glob.Api.Tests;

[ExcludeFromCodeCoverage]
public class GlobUnitTestsFixture : IDisposable
{
    public IHost BuildHost(ITestOutputHelper testOutputHelper)
    {
        var builder = Host.CreateApplicationBuilder();

        builder
            .Configuration
            .Sources
            .Clear()
            ;
        builder
            .Configuration
            .AddJsonFile("appsettings.json", optional: true)
            .AddJsonFile("appsettings.Development.json", optional: true)
            .AddJsonFile($"appsettings.{Environment.GetEnvironmentVariable("USERPROFILE")}.json", optional: true)
            .AddEnvironmentVariables()
            ;
        builder
            .Logging
            .ClearProviders()
            .AddConsole()
            .AddJsonConsole()
            .SetMinimumLevel(LogLevel.Trace)
        ;
        builder
            .Services
            .AddScoped(sp => testOutputHelper)
            .AddScoped<ILoggerProvider, XUnitLoggerProvider>()
            .AddSingleton<IFakeFileSystemCache, FakeFileSystemCache>()  // for the unit tests
            .AddTransient<GlobEnumeratorFactory>()                      // for the unit tests
            .AddGlobEnumerator()                                        // for the integration tests
            ;

        return builder.Build();
    }

    public virtual void Dispose()
    {
        GC.SuppressFinalize(this);
    }
}
