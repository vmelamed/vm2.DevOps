// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Val Melamed

namespace vm2.DevOps.Glob.Api.Benchmarks.Classes;

/// <summary>
/// Benchmarks performance across different test structure sizes.
/// </summary>
public class TestStructureSizeBenchmark : BenchmarkBase
{
    [Params("standard-test-tree.json", "large-test-tree.json")]
    public string TestStructure { get; set; } = "standard-test-tree.json";

    protected override string TestStructureFileName => TestStructure;

    [Params("**/*.cs", "**/*.md")]
    public string Pattern { get; set; } = "**/*.cs";

    [Benchmark(Description = "Enumerate across structure sizes")]
    public int EnumerateAcrossStructures()
        => EnumerateAll(
            CreateGlobEnumerator(
                new GlobEnumeratorBuilder()
                    .WithGlob(Pattern)
                    .FromDirectory(TestRootPath)));
}