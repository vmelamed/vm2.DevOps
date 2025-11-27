// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Val Melamed

namespace vm2.DevOps.Glob.Api.Benchmarks.Classes;

/// <summary>
/// Compares case-sensitive vs case-insensitive matching performance.
/// </summary>
public class CaseSensitivityBenchmark : BenchmarkBase
{
    [Params(MatchCasing.PlatformDefault, MatchCasing.CaseSensitive, MatchCasing.CaseInsensitive)]
    public MatchCasing CaseSensitivity { get; set; }

    [Params("**/*.CS", "**/*.md")]
    public string Pattern { get; set; } = "**/*.CS";

    [Benchmark(Description = "Enumerate with case sensitivity")]
    public int EnumerateWithCaseSensitivity()
        => EnumerateAll(
            CreateGlobEnumerator(
                new GlobEnumeratorBuilder()
                    .WithGlob(Pattern)
                    .WithCaseSensitivity(CaseSensitivity)
                    .FromDirectory(TestRootPath)));
}