// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Val Melamed

namespace vm2.DevOps.Glob.Api.Benchmarks.Classes;

/// <summary>
/// Compares performance of enumerating files vs directories vs both.
/// </summary>
public class ObjectTypeBenchmark : BenchmarkBase
{
    [GlobalSetup]
    public void GlobalSetup() => SetupFakeStandardFileSystem();

    [Params(Objects.Files, Objects.Directories, Objects.FilesAndDirectories)]
    public Objects EnumerationType { get; set; }

    [Params("**/*", "**/test/**/*")]
    public string Pattern { get; set; } = "**/*";

    [Benchmark(Description = "Object Types")]
    public int ObjectTypeTest()
        => EnumerateAll(
                new GlobEnumeratorBuilder()
                    .WithGlob(Pattern)
                    .Select(EnumerationType)
                    .Configure(_glob)
            );
}