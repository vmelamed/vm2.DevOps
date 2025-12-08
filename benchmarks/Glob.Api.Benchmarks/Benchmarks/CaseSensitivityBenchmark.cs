// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Val Melamed

namespace vm2.DevOps.Glob.Api.Benchmarks;

/// <summary>
/// Compares case-sensitive vs case-insensitive matching performance.
/// </summary>
[Orderer(SummaryOrderPolicy.Declared, MethodOrderPolicy.Declared)]
[MemoryDiagnoser]
public class CaseSensitivityBenchmark : BenchmarkBase
{
    [GlobalSetup]
    public void GlobalSetup() => SetupFakeStandardFileSystem();

    [Params(
        "**/*.CS",
        "**/*.md")]
    public string Pattern { get; set; } = "**/*.CS";

    [Benchmark(Description = "Case Sensitive")]
    public int CaseSensitiveTest()
        => EnumerateAll(
                new GlobEnumeratorBuilder()
                        .WithGlob(Pattern)
                        .CaseSensitive()
                        .Configure(_glob)
            );

    [Benchmark(Description = "Case Insensitive", Baseline = true)]
    public int CaseInsensitiveTest()
        => EnumerateAll(
                new GlobEnumeratorBuilder()
                        .WithGlob(Pattern)
                        .CaseInsensitive()
                        .Configure(_glob)
            );
}