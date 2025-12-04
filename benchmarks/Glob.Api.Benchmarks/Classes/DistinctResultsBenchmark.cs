// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Val Melamed

namespace vm2.DevOps.Glob.Api.Benchmarks.Classes;

/// <summary>
/// Measures the cost of deduplication with Distinct option.
/// Only relevant for patterns with multiple globstars that can produce duplicates.
/// </summary>
public class DistinctResultsBenchmark : BenchmarkBase
{
    [GlobalSetup]
    public void GlobalSetup() => SetupFakeStandardFileSystem();

    [Params(false, true)]
    public bool UseDistinct { get; set; }

    [Params("**/docs/**/*.md", "**/test/**/*.cs")]
    public string Pattern { get; set; } = "**/docs/**/*.md";

    [Benchmark(Description = "Distinct")]
    public int DistinctResultsTest()
        => EnumerateAll(
                new GlobEnumeratorBuilder()
                    .WithGlob(Pattern)
                    .WithDistinct(UseDistinct)
                    .Configure(_glob)
            );
}