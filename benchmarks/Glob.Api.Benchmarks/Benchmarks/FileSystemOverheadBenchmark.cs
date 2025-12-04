// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Val Melamed

namespace vm2.DevOps.Glob.Api.Benchmarks;

/// <summary>
/// Benchmarks to measure the overhead of real filesystem vs in-memory FakeFS.
/// This provides baseline measurements to understand I/O impact.
/// </summary>
[Orderer(SummaryOrderPolicy.Declared, MethodOrderPolicy.Declared)]
[MemoryDiagnoser]
public class FileSystemBenchmark : BenchmarkBase
{
    GlobEnumerator _globRealFS = null!;

    [GlobalSetup]
    public void GlobalSetup()
    {
        SetupFakeStandardFileSystem();
        _globRealFS = SetupRealFileSystems(_fsStandardJsonModelPath);
    }

    [GlobalCleanup]
    public virtual void GlobalCleanup() => CleanupRealFileSystems();

    [Params("**/*.cs", "**/*.md", "**/test/**/*.cs")]
    public string Pattern { get; set; } = "**/*.cs";

    [Benchmark(Description = "Fake File System Base", Baseline = true)]
    public int FakeFileSystemTest()
        => EnumerateAll(
                new GlobEnumeratorBuilder()
                        .WithGlob(Pattern)
                        .Configure(_glob)
            );

    [Benchmark(Description = "Real File System Overhead")]
    public int RealFileSystemTest()
        => EnumerateAll(
                new GlobEnumeratorBuilder()
                        .WithGlob(Pattern)
                        .Configure(_globRealFS)
            );
}