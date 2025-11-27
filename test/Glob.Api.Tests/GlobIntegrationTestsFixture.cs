namespace vm2.DevOps.Glob.Api.Tests;

using vm2.DevOps.Glob.Api.DI;

[ExcludeFromCodeCoverage]
public sealed class GlobIntegrationTestsFixture : GlobUnitTestsFixture
{
    public override IHost BuildHost(ITestOutputHelper testOutputHelper)
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
            .AddGlobEnumerator()                      // for the unit tests
            ;

        return builder.Build();
    }
}
