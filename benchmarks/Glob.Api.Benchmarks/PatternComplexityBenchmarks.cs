namespace vm2.DevOps.Glob.Api.Benchmarks;

[MemoryDiagnoser]
[SimpleJob(BenchmarkDotNet.Engines.RunStrategy.Throughput)]
[RankColumn]
public class PatternComplexityBenchmarks : IDisposable
{
    string _testPath = null!;
    GlobEnumerator _enumerator = null!;

    [GlobalSetup]
    public void GlobalSetup()
    {
        _testPath = Path.Combine(Path.GetTempPath(), "benchmark-complexity", Guid.NewGuid().ToString("N"));
        CreateComplexStructure();
        _enumerator = new GlobEnumerator(new FileSystem(), null);
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
                // Best effort
            }
        }
    }

    void CreateComplexStructure()
    {
        Directory.CreateDirectory(_testPath);

        // Create various file patterns
        var patterns = new[]
        {
            "simple.txt", "file123.txt", "test_file.txt", "data-2024.csv",
            "backup~old.bak", "config#main.ini", "file@home.txt",
            "array[0].txt", "data(1).dat", "file with spaces.txt",
            "café.md", "файл.txt", "document.PDF", "IMAGE.JPG"
        };

        foreach (var pattern in patterns)
        {
            try
            {
                File.WriteAllText(Path.Combine(_testPath, pattern), "content");
            }
            catch
            {
                // Some patterns may not be valid on all filesystems
            }
        }

        // Create subdirectories with more files
        for (int i = 0; i < 10; i++)
        {
            var subDir = Path.Combine(_testPath, $"dir{i}");
            Directory.CreateDirectory(subDir);

            foreach (var pattern in patterns)
            {
                try
                {
                    File.WriteAllText(Path.Combine(subDir, pattern), "content");
                }
                catch
                {
                    // Ignore
                }
            }
        }
    }

    [Benchmark(Baseline = true)]
    public int Simple_Asterisk()
    {
        _enumerator.FromDirectory = _testPath;
        _enumerator.Glob = "*.txt";
        _enumerator.Enumerated = Objects.Files;
        return _enumerator.Enumerate().Count();
    }

    [Benchmark]
    public int Simple_QuestionMark()
    {
        _enumerator.FromDirectory = _testPath;
        _enumerator.Glob = "file???.txt";
        _enumerator.Enumerated = Objects.Files;
        return _enumerator.Enumerate().Count();
    }

    [Benchmark]
    public int BracketExpression_Range()
    {
        _enumerator.FromDirectory = _testPath;
        _enumerator.Glob = "file[0-9]*.txt";
        _enumerator.Enumerated = Objects.Files;
        return _enumerator.Enumerate().Count();
    }

    [Benchmark]
    public int BracketExpression_Set()
    {
        _enumerator.FromDirectory = _testPath;
        _enumerator.Glob = "[sfd]*.txt";
        _enumerator.Enumerated = Objects.Files;
        return _enumerator.Enumerate().Count();
    }

    [Benchmark]
    public int BracketExpression_Negation()
    {
        _enumerator.FromDirectory = _testPath;
        _enumerator.Glob = "[!0-9]*.txt";
        _enumerator.Enumerated = Objects.Files;
        return _enumerator.Enumerate().Count();
    }

    [Benchmark]
    public int CharacterClass_Alnum()
    {
        _enumerator.FromDirectory = _testPath;
        _enumerator.Glob = "[[:alnum:]]*.txt";
        _enumerator.Enumerated = Objects.Files;
        return _enumerator.Enumerate().Count();
    }

    [Benchmark]
    public int CharacterClass_Alpha()
    {
        _enumerator.FromDirectory = _testPath;
        _enumerator.Glob = "[[:alpha:]]*.txt";
        _enumerator.Enumerated = Objects.Files;
        return _enumerator.Enumerate().Count();
    }

    [Benchmark]
    public int CharacterClass_Digit()
    {
        _enumerator.FromDirectory = _testPath;
        _enumerator.Glob = "[[:digit:]]*.txt";
        _enumerator.Enumerated = Objects.Files;
        return _enumerator.Enumerate().Count();
    }

    [Benchmark]
    public int Complex_MultipleWildcards()
    {
        _enumerator.FromDirectory = _testPath;
        _enumerator.Glob = "**/file*[0-9]*.*";
        _enumerator.Enumerated = Objects.Files;
        return _enumerator.Enumerate().Count();
    }

    [Benchmark]
    public int Complex_MixedPatterns()
    {
        _enumerator.FromDirectory = _testPath;
        _enumerator.Glob = "**/?[aeiou]*[0-9]*.???";
        _enumerator.Enumerated = Objects.Files;
        return _enumerator.Enumerate().Count();
    }

    [Benchmark]
    public int SpecialChars_Spaces()
    {
        _enumerator.FromDirectory = _testPath;
        _enumerator.Glob = "*file with*";
        _enumerator.Enumerated = Objects.Files;
        return _enumerator.Enumerate().Count();
    }

    [Benchmark]
    public int SpecialChars_Symbols()
    {
        _enumerator.FromDirectory = _testPath;
        _enumerator.Glob = "*@*.txt";
        _enumerator.Enumerated = Objects.Files;
        return _enumerator.Enumerate().Count();
    }

    [Benchmark]
    public int Unicode_Patterns()
    {
        _enumerator.FromDirectory = _testPath;
        _enumerator.Glob = "**/*[éа]*.txt";
        _enumerator.Enumerated = Objects.Files;
        return _enumerator.Enumerate().Count();
    }
}