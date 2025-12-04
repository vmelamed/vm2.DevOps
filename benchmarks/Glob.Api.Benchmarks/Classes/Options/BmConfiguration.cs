namespace vm2.DevOps.Glob.Api.Benchmarks.Classes.Options;

public static class BmConfiguration
{
    public static BmOptions Options { get; private set; } = new();

    public static void BindOptions()
    {
        var builder = new ConfigurationBuilder();

        builder
            .Sources
            .Clear();

        builder
            .SetBasePath(Directory.GetCurrentDirectory())
            .AddJsonFile("appsettings.json", optional: true)
            .AddJsonFile("appsettings.Development.json", optional: true)
            .AddJsonFile($"appsettings.{Environment.GetEnvironmentVariable("USERNAME")}.json", optional: true)
            .AddEnvironmentVariables()
            .AddCommandLine(Environment.GetCommandLineArgs())
            .Build()
            .GetSection(nameof(BmOptions))
            .Bind(Options)
            ;

        Options = new BmOptions(
            TestFileStructure.ExpandEnvironmentVariables(Options.ResultsPath),
            TestFileStructure.ExpandEnvironmentVariables(Options.FsJsonModelsDirectory),
            TestFileStructure.ExpandEnvironmentVariables(Options.TestsRootPath)
        );
    }
}
