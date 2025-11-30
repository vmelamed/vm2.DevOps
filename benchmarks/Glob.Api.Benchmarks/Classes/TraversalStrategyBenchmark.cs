// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Val Melamed

namespace vm2.DevOps.Glob.Api.Benchmarks.Classes;

/// <summary>
/// Compares depth-first vs breadth-first traversal strategies.
/// </summary>
public class TraversalStrategyBenchmark : BenchmarkBase
{
    [Params(true, false)]
    public bool IsDepthFirst { get; set; }

    [Params("**/*.cs", "**/docs/**/*.md")]
    public string Pattern { get; set; } = "**/*.cs";

    [Benchmark(Description = "Enumerate with traversal strategy")]
    public int EnumerateWithStrategy()
        => EnumerateAll(
            CreateGlobEnumerator(
                new GlobEnumeratorBuilder()
                    .WithGlob(Pattern)
                    .TraverseDepthFirst(IsDepthFirst ? TraverseOrder.DepthFirst : TraverseOrder.BreadthFirst)
                    .FromDirectory(TestRootPath)));
}