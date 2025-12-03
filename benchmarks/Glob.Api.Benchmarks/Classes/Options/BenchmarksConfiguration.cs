namespace vm2.DevOps.Glob.Api.Benchmarks.Classes.Options;

public static class BenchmarksConfiguration
{
    public static BenchmarkOptions Options { get; private set; } = new();

    public static void Bind()
    {
        var builder = new ConfigurationBuilder();

        builder
            .Sources
            .Clear();

        builder
            .SetBasePath(Directory.GetCurrentDirectory())
            .AddJsonFile("appsettings.json", optional: true)
            .AddJsonFile("appsettings.Development.json", optional: true)
            .AddJsonFile($"appsettings.{Environment.GetEnvironmentVariable("USERPROFILE")}.json", optional: true)
            .AddEnvironmentVariables()
            .AddCommandLine(Environment.GetCommandLineArgs())
            .Build()
            .GetSection(nameof(BenchmarkOptions))
            .Bind(Options)
            ;
    }
}
