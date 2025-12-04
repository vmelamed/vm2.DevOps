// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Val Melamed

namespace vm2.DevOps.Glob.Api.Benchmarks;

/// <summary>
/// Compares depth-first vs breadth-first traversal strategies.
/// </summary>
[Orderer(SummaryOrderPolicy.Declared, MethodOrderPolicy.Declared)]
[MemoryDiagnoser]
public class TraversalStrategyBenchmark : BenchmarkBase
{
    [GlobalSetup]
    public void GlobalSetup() => SetupFakeStandardFileSystem();

    [Params("**/*.cs", "**/docs/**/*.md")]
    public string Pattern { get; set; } = "**/*.cs";

    [Benchmark(Description = "Traverse Depth First", Baseline = true)]
    public int TdfStrategyTest()
        => EnumerateAll(
                new GlobEnumeratorBuilder()
                    .WithGlob(Pattern)
                    .DepthFirst()
                    .Configure(_glob)
            );

    [Benchmark(Description = "Traverse Breadth First")]
    public int TbfStrategyTest()
        => EnumerateAll(
                new GlobEnumeratorBuilder()
                    .WithGlob(Pattern)
                    .BreadthFirst()
                    .Configure(_glob)
            );
}