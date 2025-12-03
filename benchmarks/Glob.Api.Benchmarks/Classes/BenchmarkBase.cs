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
    // these must be initialized in GlobalSetup(), so we use the old dirty hack - the null-forgiving operator:
    protected IFileSystem _fileSystem = null!;
    protected GlobEnumerator _glob = null!;
    protected string _testFSJsonPath = null!;

    protected string TestFSJsonName = "standard-test-tree.json";

    [GlobalSetup]
    public virtual void GlobalSetup()
    {
        var bmo = BenchmarksConfiguration.Options;

        // get the standard file structure JSON:
        _testFSJsonPath = Path.Combine(bmo.TestFSFilesDirectory, TestFSJsonName);

        if (!File.Exists(_testFSJsonPath))
            throw new FileNotFoundException("Test file system structure file not found", _testFSJsonPath);

        // figure out where to create a real file system root:
        if (string.IsNullOrWhiteSpace(bmo.TestsRootPath))
        {
            // create a temp directory:
            var info = Directory.CreateTempSubdirectory($"GlobBm_");
            TestFileStructure.CreateTestFileStructure(_testFSJsonPath, info.FullName);
            bmo.TestsRootPath = info.FullName;
        }
        else
        {
            // use the specified directory, but verify it first:
            bmo.TestsRootPath = Path.GetFullPath(TestFileStructure.ExpandEnvironmentVariables(bmo.TestsRootPath));
            if (Directory.Exists(bmo.TestsRootPath))
            {
                var messages = string.Join("\n    ", TestFileStructure.VerifyTestFileStructure(_testFSJsonPath, bmo.TestsRootPath));
                if (!string.IsNullOrWhiteSpace(messages))
                    throw new InvalidOperationException($"Test file structure verification failed:\n    {messages}");
            }
            else
            {
                // create the directory if it doesn't exist
                Directory.CreateDirectory(bmo.TestsRootPath);
                TestFileStructure.CreateTestFileStructure(_testFSJsonPath, bmo.TestsRootPath);
            }
        }
    }

    protected virtual void SetupFileSystems(IServiceCollection services)
    {
    }

    [GlobalCleanup]
    public virtual void GlobalCleanup()
    {
    }

    /// <summary>
    /// Helper method to create and configure a GlobEnumerator instance.
    /// </summary>
    protected GlobEnumerator CreateGlobEnumerator(
        GlobEnumeratorBuilder builder)
        => builder.Configure(new GlobEnumerator());

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