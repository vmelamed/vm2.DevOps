namespace vm2.DevOps.Glob.Api.Benchmarks;

[MemoryDiagnoser]
[SimpleJob(BenchmarkDotNet.Engines.RunStrategy.Throughput)]
[RankColumn]
public class GlobEnumerationBenchmarks : IDisposable
{
    const string TestBaseDir = "benchmark-glob-structure";
    string _testRootPath = null!;
    GlobEnumerator _enumerator = null!;

    [GlobalSetup]
    public void GlobalSetup()
    {
        _testRootPath = Path.Combine(Path.GetTempPath(), TestBaseDir, Guid.NewGuid().ToString("N"));
        CreateBenchmarkStructure();
        _enumerator = new GlobEnumerator(new FileSystem(), new NullLogger<GlobEnumerator>());
    }

    [GlobalCleanup]
    public void GlobalCleanup()
    {
        Dispose();
    }

    public void Dispose()
    {
        if (_testRootPath != null && Directory.Exists(_testRootPath))
        {
            try
            {
                Directory.Delete(_testRootPath, recursive: true);
            }
            catch
            {
                // Best effort cleanup
            }
        }
    }

    void CreateBenchmarkStructure()
    {
        // Create a balanced tree: 5 levels, 5 dirs per level, 10 files per dir
        CreateTreeStructure(_testRootPath, depth: 0, maxDepth: 5, dirsPerLevel: 5, filesPerDir: 10);

        // Create a wide structure: 1 level, 500 files
        var wideDir = Path.Combine(_testRootPath, "wide");
        Directory.CreateDirectory(wideDir);
        for (int i = 0; i < 500; i++)
        {
            File.WriteAllText(Path.Combine(wideDir, $"file{i:D4}.txt"), "content");
        }

        // Create a deep structure: 20 levels, 1 file per level
        var deepPath = _testRootPath;
        for (int i = 0; i < 20; i++)
        {
            deepPath = Path.Combine(deepPath, $"level{i}");
            Directory.CreateDirectory(deepPath);
            File.WriteAllText(Path.Combine(deepPath, $"file{i}.txt"), "content");
        }
    }

    void CreateTreeStructure(string path, int depth, int maxDepth, int dirsPerLevel, int filesPerDir)
    {
        if (depth >= maxDepth)
            return;

        Directory.CreateDirectory(path);

        // Create files at this level
        for (int f = 0; f < filesPerDir; f++)
        {
            File.WriteAllText(Path.Combine(path, $"file{f:D3}.txt"), "content");
        }

        // Create subdirectories
        for (int d = 0; d < dirsPerLevel; d++)
        {
            var subDir = Path.Combine(path, $"dir{d}");
            CreateTreeStructure(subDir, depth + 1, maxDepth, dirsPerLevel, filesPerDir);
        }
    }

    [Benchmark(Baseline = true)]
    public int SimpleGlob_AllTxtFiles()
    {
        _enumerator.FromDirectory = _testRootPath;
        _enumerator.Glob = "*.txt";
        _enumerator.Enumerated = Objects.Files;
        return _enumerator.Enumerate().Count();
    }

    [Benchmark]
    public int RecursiveGlob_AllTxtFiles()
    {
        _enumerator.FromDirectory = _testRootPath;
        _enumerator.Glob = "**/*.txt";
        _enumerator.Enumerated = Objects.Files;
        return _enumerator.Enumerate().Count();
    }

    [Benchmark]
    public int RecursiveGlob_DepthFirst()
    {
        _enumerator.FromDirectory = _testRootPath;
        _enumerator.Glob = "**/*.txt";
        _enumerator.Enumerated = Objects.Files;
        _enumerator.DepthFirst = true;
        return _enumerator.Enumerate().Count();
    }

    [Benchmark]
    public int RecursiveGlob_BreadthFirst()
    {
        _enumerator.FromDirectory = _testRootPath;
        _enumerator.Glob = "**/*.txt";
        _enumerator.Enumerated = Objects.Files;
        _enumerator.DepthFirst = false;
        return _enumerator.Enumerate().Count();
    }

    [Benchmark]
    public int WideDirectory_Wildcard()
    {
        _enumerator.FromDirectory = Path.Combine(_testRootPath, "wide");
        _enumerator.Glob = "*.txt";
        _enumerator.Enumerated = Objects.Files;
        return _enumerator.Enumerate().Count();
    }

    [Benchmark]
    public int DeepDirectory_Recursive()
    {
        _enumerator.FromDirectory = _testRootPath;
        _enumerator.Glob = "**/level*/file*.txt";
        _enumerator.Enumerated = Objects.Files;
        return _enumerator.Enumerate().Count();
    }

    [Benchmark]
    public int BracketExpression_Matching()
    {
        _enumerator.FromDirectory = _testRootPath;
        _enumerator.Glob = "**/file[0-9][0-9][0-9].txt";
        _enumerator.Enumerated = Objects.Files;
        return _enumerator.Enumerate().Count();
    }

    [Benchmark]
    public int CharacterClass_Digit()
    {
        _enumerator.FromDirectory = _testRootPath;
        _enumerator.Glob = "**/file[[:digit:]]*.txt";
        _enumerator.Enumerated = Objects.Files;
        return _enumerator.Enumerate().Count();
    }

    [Benchmark]
    public int MultipleRecursive_WithDistinct()
    {
        _enumerator.FromDirectory = _testRootPath;
        _enumerator.Glob = "/**/**/dir*/**/*.txt";
        _enumerator.Enumerated = Objects.Files;
        _enumerator.Distinct = true;
        return _enumerator.Enumerate().Count();
    }

    [Benchmark]
    public int MultipleRecursive_WithoutDistinct()
    {
        _enumerator.FromDirectory = _testRootPath;
        _enumerator.Glob = "/**/**/dir*/**/*.txt";
        _enumerator.Enumerated = Objects.Files;
        _enumerator.Distinct = false;
        return _enumerator.Enumerate().Count();
    }

    [Benchmark]
    public int EnumerateDirectories_Only()
    {
        _enumerator.FromDirectory = _testRootPath;
        _enumerator.Glob = "**/dir*";
        _enumerator.Enumerated = Objects.Directories;
        return _enumerator.Enumerate().Count();
    }

    [Benchmark]
    public int EnumerateFilesAndDirectories()
    {
        _enumerator.FromDirectory = _testRootPath;
        _enumerator.Glob = "**/*";
        _enumerator.Enumerated = Objects.FilesAndDirectories;
        return _enumerator.Enumerate().Count();
    }
}
