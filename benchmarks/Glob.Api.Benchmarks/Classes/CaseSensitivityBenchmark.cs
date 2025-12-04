// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Val Melamed

namespace vm2.DevOps.Glob.Api.Benchmarks.Classes;

/// <summary>
/// Compares case-sensitive vs case-insensitive matching performance.
/// </summary>
public class CaseSensitivityBenchmark : BenchmarkBase
{
    [GlobalSetup]
    public void GlobalSetup() => SetupFakeStandardFileSystem();

    [Params(
        MatchCasing.PlatformDefault,
        MatchCasing.CaseSensitive,
        MatchCasing.CaseInsensitive)]
    public MatchCasing CaseSensitivity { get; set; }

    [Params(
        "**/*.CS",
        "**/*.md")]
    public string Pattern { get; set; } = "**/*.CS";

    [Benchmark(Description = "Case sensitivity")]
    public int CaseSensitivityTest()
        => EnumerateAll(
                new GlobEnumeratorBuilder()
                        .WithGlob(Pattern)
                        .WithCaseSensitivity(CaseSensitivity)
                        .Configure(_glob)
            );
}