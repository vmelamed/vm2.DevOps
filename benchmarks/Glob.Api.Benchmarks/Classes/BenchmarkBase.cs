// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Val Melamed

namespace vm2.DevOps.Glob.Api.Benchmarks.Classes;

/// <summary>
/// Base class for all glob benchmarks providing common setup and teardown functionality.
/// </summary>
#if SHORT_RUN || DEBUG
[ShortRunJob]
#else
[SimpleJob(RuntimeMoniker.HostProcess)]
#endif
[MemoryDiagnoser]
[MarkdownExporter]
[JsonExporter]
[Orderer(SummaryOrderPolicy.FastestToSlowest, MethodOrderPolicy.Declared)]
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
            .AddJsonConsole()
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

        services.AddGlobEnumerator();
    }

    protected virtual void SetupFakeFileSystem(IServiceCollection services)
    {
        var jsonPath = Path.Combine("TestStructures", TestStructureFileName);
        var fakeFS = new FakeFS(jsonPath, DataType.Json);

        services.AddSingleton<IFileSystem>(fakeFS);
        services.AddTransient<GlobEnumerator>();

        TestRootPath = fakeFS.RootFolder.Path;
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
        GlobEnumeratorBuilder builder)
        => builder.Configure(Services.GetRequiredService<GlobEnumerator>());

    /// <summary>
    /// Executes the glob enumeration and consumes all results.
    /// </summary>
    protected int EnumerateAll(GlobEnumerator enumerator)
    {
        var count = 0;

        foreach (var _ in enumerator.Enumerate())
            count++;

        return count;
    }
}