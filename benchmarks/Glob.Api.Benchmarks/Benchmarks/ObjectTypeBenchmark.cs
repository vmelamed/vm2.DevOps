// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Val Melamed

namespace vm2.DevOps.Glob.Api.Benchmarks;

/// <summary>
/// Compares performance of enumerating files vs directories vs both.
/// </summary>
[Orderer(SummaryOrderPolicy.Declared, MethodOrderPolicy.Declared)]
[MemoryDiagnoser]
public class ObjectTypeBenchmark : BenchmarkBase
{
    [GlobalSetup]
    public void GlobalSetup() => SetupFakeStandardFileSystem();

    [Params("**/*", "**/test/**/*")]
    public string Pattern { get; set; } = "**/*";

    [Benchmark(Description = "Get Files", Baseline = true)]
    public int FilesTest()
        => EnumerateAll(
                new GlobEnumeratorBuilder()
                    .WithGlob(Pattern)
                    .SelectFiles()
                    .Configure(_glob)
            );

    [Benchmark(Description = "Get Directories")]
    public int DirectoriesTest()
        => EnumerateAll(
                new GlobEnumeratorBuilder()
                    .WithGlob(Pattern)
                    .SelectDirectories()
                    .Configure(_glob)
            );

    [Benchmark(Description = "Get Files and Directories")]
    public int DirectoriesAndFilesTest()
        => EnumerateAll(
                new GlobEnumeratorBuilder()
                    .WithGlob(Pattern)
                    .SelectDirectoriesAndFiles()
                    .Configure(_glob)
            );
}