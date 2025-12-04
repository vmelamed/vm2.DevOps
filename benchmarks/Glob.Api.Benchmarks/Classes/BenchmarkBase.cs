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
    protected GlobEnumerator _glob = null!;
    protected string _realFSRootsPath = "";
    protected const string FsStandardJsonModelFileName = "standard-test-tree.json";
    protected string _fsStandardJsonModelPath = null!;
    protected bool _createdTempDirectory = false;

    public void SetupFakeStandardFileSystem()
    {
        BmConfiguration.BindOptions();
        _fsStandardJsonModelPath = Path.Combine(
                                            BmConfiguration.Options.FsJsonModelsDirectory,
                                            FsStandardJsonModelFileName);
        _glob = SetupFakeFileSystem(_fsStandardJsonModelPath);
    }

    protected virtual string FSJsonModelExist(string fsJsonModelPath)
        => File.Exists(fsJsonModelPath)
                    ? fsJsonModelPath
                    : throw new FileNotFoundException($"Did not find the test file system structure file {fsJsonModelPath} (CWD: {Directory.GetCurrentDirectory()}).", fsJsonModelPath);

    protected virtual GlobEnumerator SetupFakeFileSystem(string fsJsonModelPath)
        => new(
            new FakeFS(
                    FSJsonModelExist(fsJsonModelPath),
                    DataType.Json));

    protected virtual GlobEnumerator SetupRealFileSystems(string fsJsonModelPath)
    {
        FSJsonModelExist(fsJsonModelPath);

        // all real FS will be tested under the root specified in the configuration or in a temp directory.
        // Each glob enumerator will have its own subdirectory with a name - the name of the JSON model file (without the extension).

        _realFSRootsPath = BmConfiguration.Options.TestsRootPath;

        // figure out where is the root of all the file systems in the current environment:
        if (string.IsNullOrWhiteSpace(_realFSRootsPath))
        {
            // not specified - create the file system root in a temp directory:
            var info = Directory.CreateTempSubdirectory($"GlobBm_");
            _realFSRootsPath = info.FullName;
            _createdTempDirectory = true;
        }

        // the directory for this specific file system:
        var realDirectoryPath = Path.Combine(_realFSRootsPath, Path.GetFileNameWithoutExtension(fsJsonModelPath));

        // use the specified directory
        if (Directory.Exists(realDirectoryPath))
        {
            // it exists - verify it first:
            var errors = string.Join("\n  ", TestFileStructure.VerifyTestFileStructure(fsJsonModelPath, realDirectoryPath));

            if (errors.Length > 0)
                throw new InvalidOperationException($"Test file structure verification failed:\n{errors}");
        }
        else
        {
            // it does not exist - create it:
            Directory.CreateDirectory(realDirectoryPath);
            TestFileStructure.CreateTestFileStructure(fsJsonModelPath, realDirectoryPath);
        }

        return new GlobEnumerator(new FileSystem()) { FromDirectory = realDirectoryPath };
    }

    protected virtual void CleanupRealFileSystems()
    {
        if (!_createdTempDirectory || !Directory.Exists(_realFSRootsPath))
            return;

        try
        {
            Directory.Delete(_realFSRootsPath, true);
            _createdTempDirectory = false;
        }
        catch
        {
            // ignore any errors during cleanup of the temp directory.
        }
    }

    /// <summary>
    /// Executes the glob enumeration and consumes all results.
    /// </summary>
    protected static int EnumerateAll(GlobEnumerator enumerator)
    {
        var count = 0;

        foreach (var _ in enumerator.Enumerate())
            count++;

        return count;
    }
}