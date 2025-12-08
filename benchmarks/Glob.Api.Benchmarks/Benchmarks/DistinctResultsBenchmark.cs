// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Val Melamed

namespace vm2.DevOps.Glob.Api.Benchmarks;

/// <summary>
/// Measures the cost of deduplication with Distinct option.
/// Only relevant for patterns with multiple globstars that can produce duplicates.
/// </summary>
[Orderer(SummaryOrderPolicy.Declared, MethodOrderPolicy.Declared)]
[MemoryDiagnoser]
public class DistinctResultsBenchmark : BenchmarkBase
{
    [GlobalSetup]
    public void GlobalSetup() => SetupFakeStandardFileSystem();

    [Params("**/docs/**/*.md", "**/test/**/*.cs")]
    public string Pattern { get; set; } = "**/docs/**/*.md";

    [Benchmark(Description = "Non-distinct", Baseline = true)]
    public int NonDistinctResultsTest()
        => EnumerateAll(
                new GlobEnumeratorBuilder()
                    .WithGlob(Pattern)
                    .Configure(_glob)
            );

    [Benchmark(Description = "Distinct")]
    public int DistinctResultsTest()
        => EnumerateAll(
                new GlobEnumeratorBuilder()
                    .WithGlob(Pattern)
                    .Distinct()
                    .Configure(_glob)
            );
}