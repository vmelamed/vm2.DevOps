namespace vm2.DevOps.Glob.Api.Benchmarks;

[MemoryDiagnoser]
[SimpleJob(BenchmarkDotNet.Engines.RunStrategy.Throughput)]
public class CaseSensitivityBenchmarks : IDisposable
{
    string _testPath = null!;
    GlobEnumerator _enumerator = null!;

    [GlobalSetup]
    public void GlobalSetup()
    {
        _testPath = Path.Combine(Path.GetTempPath(), "benchmark-case", Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(_testPath);

        // Create files with various case combinations
        for (int i = 0; i < 100; i++)
        {
            File.WriteAllText(Path.Combine(_testPath, $"file{i}.txt"), "content");

            if (!OperatingSystem.IsWindows())
            {
                // On Unix, we can create truly different case-variant files
                File.WriteAllText(Path.Combine(_testPath, $"FILE{i}.TXT"), "CONTENT");
                File.WriteAllText(Path.Combine(_testPath, $"File{i}.Txt"), "Content");
            }
        }

        _enumerator = new GlobEnumerator(new FileSystem(), new NullLogger<GlobEnumerator>());
    }

    [GlobalCleanup]
    public void GlobalCleanup()
    {
        Dispose();
    }

    public void Dispose()
    {
        if (_testPath != null && Directory.Exists(_testPath))
        {
            try
            {
                Directory.Delete(_testPath, recursive: true);
            }
            catch
            {
                // Best effort cleanup
            }
        }
    }

    [Benchmark(Baseline = true)]
    public int PlatformDefault_Matching()
    {
        _enumerator.FromDirectory = _testPath;
        _enumerator.Glob = "*.txt";
        _enumerator.Enumerated = Objects.Files;
        _enumerator.MatchCasing = MatchCasing.PlatformDefault;
        return _enumerator.Enumerate().Count();
    }

    [Benchmark]
    public int CaseSensitive_Matching()
    {
        _enumerator.FromDirectory = _testPath;
        _enumerator.Glob = "file*.txt";
        _enumerator.Enumerated = Objects.Files;
        _enumerator.MatchCasing = MatchCasing.CaseSensitive;
        return _enumerator.Enumerate().Count();
    }

    [Benchmark]
    public int CaseInsensitive_Matching()
    {
        _enumerator.FromDirectory = _testPath;
        _enumerator.Glob = "FILE*.TXT";
        _enumerator.Enumerated = Objects.Files;
        _enumerator.MatchCasing = MatchCasing.CaseInsensitive;
        return _enumerator.Enumerate().Count();
    }

    [Benchmark]
    public int BracketExpression_CaseSensitive()
    {
        _enumerator.FromDirectory = _testPath;
        _enumerator.Glob = "[Ff]ile[0-9]*.txt";
        _enumerator.Enumerated = Objects.Files;
        _enumerator.MatchCasing = MatchCasing.CaseSensitive;
        return _enumerator.Enumerate().Count();
    }

    [Benchmark]
    public int BracketExpression_CaseInsensitive()
    {
        _enumerator.FromDirectory = _testPath;
        _enumerator.Glob = "[Ff]ile[0-9]*.txt";
        _enumerator.Enumerated = Objects.Files;
        _enumerator.MatchCasing = MatchCasing.CaseInsensitive;
        return _enumerator.Enumerate().Count();
    }

    [Benchmark]
    public int CharacterClass_Lower()
    {
        _enumerator.FromDirectory = _testPath;
        _enumerator.Glob = "[[:lower:]]*.txt";
        _enumerator.Enumerated = Objects.Files;
        _enumerator.MatchCasing = MatchCasing.CaseSensitive;
        return _enumerator.Enumerate().Count();
    }

    [Benchmark]
    public int CharacterClass_Upper()
    {
        _enumerator.FromDirectory = _testPath;
        _enumerator.Glob = "[[:upper:]]*.TXT";
        _enumerator.Enumerated = Objects.Files;
        _enumerator.MatchCasing = MatchCasing.CaseSensitive;
        return _enumerator.Enumerate().Count();
    }
}