namespace vm2.DevOps.Glob.Api.Benchmarks;

using System;
using System.IO;

using BenchmarkDotNet.Attributes;

using static vm2.DevOps.Glob.Api.Objects;

[MemoryDiagnoser]
[SimpleJob(BenchmarkDotNet.Engines.RunStrategy.Throughput)]
[RankColumn]
public class AllocationBenchmarks : IDisposable
{
    string _testPath = null!;
    GlobEnumerator _enumerator = null!;

    [Params(10, 100, 1000)]
    public int FileCount { get; set; }

    [GlobalSetup]
    public void GlobalSetup()
    {
        _testPath = Path.Combine(Path.GetTempPath(), "benchmark-alloc", Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(_testPath);

        for (int i = 0; i < FileCount; i++)
        {
            File.WriteAllText(Path.Combine(_testPath, $"file{i:D4}.txt"), "content");
        }

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

    [Benchmark(Baseline = true)]
    public int Enumerate_ToList()
    {
        _enumerator.FromDirectory = _testPath;
        _enumerator.Glob = "*.txt";
        _enumerator.Enumerated = Files;
        return _enumerator.Enumerate().ToList().Count;
    }

    [Benchmark]
    public int Enumerate_Count()
    {
        _enumerator.FromDirectory = _testPath;
        _enumerator.Glob = "*.txt";
        _enumerator.Enumerated = Files;
        return _enumerator.Enumerate().Count();
    }

    [Benchmark]
    public int Enumerate_Lazy()
    {
        _enumerator.FromDirectory = _testPath;
        _enumerator.Glob = "*.txt";
        _enumerator.Enumerated = Files;

        int count = 0;
        foreach (var _ in _enumerator.Enumerate())
        {
            count++;
        }
        return count;
    }

    [Benchmark]
    public int Enumerate_WithDistinct()
    {
        _enumerator.FromDirectory = _testPath;
        _enumerator.Glob = "**/*.txt";
        _enumerator.Enumerated = Files;
        _enumerator.Distinct = true;
        return _enumerator.Enumerate().Count();
    }

    [Benchmark]
    public int Enumerate_WithoutDistinct()
    {
        _enumerator.FromDirectory = _testPath;
        _enumerator.Glob = "**/*.txt";
        _enumerator.Enumerated = Files;
        _enumerator.Distinct = false;
        return _enumerator.Enumerate().Count();
    }
}
