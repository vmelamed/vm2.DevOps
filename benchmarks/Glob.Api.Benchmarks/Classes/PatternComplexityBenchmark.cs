// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Val Melamed

namespace vm2.DevOps.Glob.Api.Benchmarks.Classes;

/// <summary>
/// Benchmarks different glob pattern complexities to identify performance characteristics.
/// </summary>
public class PatternComplexityBenchmark : BenchmarkBase
{
    [GlobalSetup]
    public void GlobalSetup() => SetupFakeStandardFileSystem();

    [Params(
        "*.md",                      // Simple: root only
        "src/*.cs",                  // Single level
        "**/*.cs",                   // Single globstar
        "**/*.md",                   // Single globstar (different extension)
        "**/test/**/*.cs",           // Multiple globstars
        "**/docs/**/*.md",           // Multiple globstars (different path)
        "**/?????Service.cs",        // Character wildcard
        "**/test/**/???Tests.cs"     // Mixed wildcards
    )]
    public string Pattern { get; set; } = "*.md";

    [Benchmark(Description = "Pattern Complexity")]
    public int PatternComplexityTest()
        => EnumerateAll(
                new GlobEnumeratorBuilder()
                    .WithGlob(Pattern)
                    .Configure(_glob)
            );
}