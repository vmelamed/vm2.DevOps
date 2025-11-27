// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Val Melamed

namespace vm2.DevOps.Glob.Api.Benchmarks.Classes;

/// <summary>
/// Benchmarks to measure the overhead of real filesystem vs in-memory FakeFS.
/// This provides baseline measurements to understand I/O impact.
/// </summary>
public class FileSystemOverheadBenchmark : BenchmarkBase
{
    [Params(false, true)]
    public bool UseFakeFS { get; set; }

    protected override bool UseFakeFileSystem => UseFakeFS;

    [Params("**/*.cs", "**/*.md", "**/test/**/*.cs")]
    public string Pattern { get; set; } = "**/*.cs";

    [Benchmark(Description = "Enumerate with pattern")]
    public int EnumeratePattern()
        => EnumerateAll(
            CreateGlobEnumerator(
                new GlobEnumeratorBuilder()
                    .WithGlob(Pattern)
                    .FromDirectory(TestRootPath)));
}