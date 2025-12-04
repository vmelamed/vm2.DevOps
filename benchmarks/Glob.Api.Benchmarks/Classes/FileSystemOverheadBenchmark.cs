// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Val Melamed

namespace vm2.DevOps.Glob.Api.Benchmarks.Classes;

/// <summary>
/// Benchmarks to measure the overhead of real filesystem vs in-memory FakeFS.
/// This provides baseline measurements to understand I/O impact.
/// </summary>
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

    [Params(UseFileSystem.Real, UseFileSystem.Fake)]
    public UseFileSystem UseFakeFS { get; set; }

    [Params("**/*.cs", "**/*.md", "**/test/**/*.cs")]
    public string Pattern { get; set; } = "**/*.cs";

    [Benchmark(Description = "Real File System Overhead")]
    public int FileSystemTest()
        => EnumerateAll(
                new GlobEnumeratorBuilder()
                        .WithGlob(Pattern)
                        .Configure(UseFakeFS switch {
                            UseFileSystem.Fake => _glob,
                            UseFileSystem.Real => _globRealFS,
                            _ => throw new InvalidOperationException($"Unsupported UseFileSystem value: {UseFakeFS}")
                        })
            );
}