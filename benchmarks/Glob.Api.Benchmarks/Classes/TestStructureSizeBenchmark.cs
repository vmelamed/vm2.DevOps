// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Val Melamed

namespace vm2.DevOps.Glob.Api.Benchmarks.Classes;

/// <summary>
/// Benchmarks performance across different test structure sizes.
/// </summary>
public class TestStructureSizeBenchmark : BenchmarkBase
{
    const string FsLargeJsonModelFileName = "large-test-tree.json";

    protected string _fsLargeJsonModelPath = null!;
    GlobEnumerator _globLarge = null!;

    [GlobalSetup]
    public override void GlobalSetup()
    {
        // create the standard glob enumerator:
        base.GlobalSetup();

        // create the large glob enumerator:
        _fsLargeJsonModelPath = Path.Combine(
                                        BmConfiguration.Options.FsJsonModelsDirectory,
                                        FsLargeJsonModelFileName);
        _globLarge = SetupFakeFileSystem(_fsLargeJsonModelPath);
    }

    [Params(FsStandardJsonModelFileName, FsLargeJsonModelFileName)]
    public string TestStructure { get; set; } = FsStandardJsonModelFileName;

    [Params("**/*.cs", "**/*.md")]
    public string Pattern { get; set; } = "**/*.cs";

    [Benchmark(Description = "Enumerate across structure sizes")]
    public int EnumerateAcrossStructures()
        => EnumerateAll(
                new GlobEnumeratorBuilder()
                        .WithGlob(Pattern)
                        .Configure(
                            TestStructure switch {
                                FsStandardJsonModelFileName => _glob,
                                FsLargeJsonModelFileName => _globLarge,
                                _ => throw new ArgumentOutOfRangeException()
                            })
            );
}