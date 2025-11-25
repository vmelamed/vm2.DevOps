namespace vm2.DevOps.Glob.Api.Benchmarks.Infrastructure;

/// <summary>
/// Base class for all glob benchmarks providing common setup and teardown functionality.
/// </summary>
[MemoryDiagnoser]
[MarkdownExporter]
[JsonExporter]
public abstract class BenchmarkBase
{
    protected IHost? BmHost;
    protected IServiceProvider Services => BmHost?.Services ?? throw new InvalidOperationException("BmHost not initialized");
    protected string TestRootPath = string.Empty;

    /// <summary>
    /// Override to specify which test structure JSON file to use.
    /// </summary>
    protected virtual string TestStructureFileName => "standard-test-tree.json";

    /// <summary>
    /// Override to use fake file system instead of real one.
    /// </summary>
    protected virtual bool UseFakeFileSystem => false;

    [GlobalSetup]
    public virtual void GlobalSetup()
    {
        var builder = Host.CreateApplicationBuilder();

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
            .SetMinimumLevel(LogLevel.Warning)
            ;

        if (UseFakeFileSystem)
            SetupFakeFileSystem(builder.Services);
        else
            SetupRealFileSystem(builder.Services);

        BmHost = builder.Build();
    }

    protected virtual void SetupRealFileSystem(IServiceCollection services)
    {
        TestRootPath = Path.Combine(Path.GetTempPath(), $"GlobBenchmarks_{Guid.NewGuid():N}");

        TestFileStructure.CreateTestFileStructure(
            Path.Combine("TestStructures", TestStructureFileName),
            TestRootPath);

        services.AddSingleton<IFileSystem, FileSystem>();
        services.AddTransient<GlobEnumerator>();
    }

    protected virtual void SetupFakeFileSystem(IServiceCollection services)
    {
        // TODO: Implement FakeFS setup when we integrate with Glob.Api.Tests
        // For now, use real filesystem
        SetupRealFileSystem(services);
    }

    [GlobalCleanup]
    public virtual void GlobalCleanup()
    {
        if (!UseFakeFileSystem && Directory.Exists(TestRootPath))
            try
            {
                Directory.Delete(TestRootPath, recursive: true);
            }
            catch
            {
                // Best effort cleanup
            }

        BmHost?.Dispose();
    }

    /// <summary>
    /// Helper method to create and configure a GlobEnumerator instance.
    /// </summary>
    protected GlobEnumerator CreateGlobEnumerator(
        string pattern,
        MatchCasing caseSensitivity = MatchCasing.PlatformDefault,
        bool depthFirst = false,
        bool distinct = false,
        Objects enumerated = Objects.Files)
    {
        var enumerator = Services.GetRequiredService<GlobEnumerator>();

        enumerator.Glob = pattern;
        enumerator.FromDirectory = TestRootPath;
        enumerator.MatchCasing = caseSensitivity;
        enumerator.DepthFirst = depthFirst;
        enumerator.Distinct = distinct;
        enumerator.Enumerated = enumerated;

        return enumerator;
    }

    /// <summary>
    /// Executes the glob enumeration and consumes all results.
    /// </summary>
    protected int EnumerateAll(GlobEnumerator enumerator)
    {
        var count = 0;

        foreach (var _ in enumerator.Enumerate())
        {
            count++;
        }

        return count;
    }
}