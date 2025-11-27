namespace vm2.DevOps.Glob.Api.Benchmarks.RealFileSystem;

/// <summary>
/// Benchmarks comparing depth-first vs breadth-first traversal on real file system.
/// </summary>
[Config(typeof(AntiVirusFriendlyConfig))]
public class TraversalBenchmarks : BenchmarkBase
{
    [Params("**/*.cs", "**/test/**/*.cs", "**/**/**/*.json")]
    public string Pattern { get; set; } = string.Empty;

    [Params(true, false)]
    public bool DepthFirst { get; set; }

    [Params(true, false)]
    public bool Distinct { get; set; }

    [Benchmark]
    public int EnumerateWithTraversalOrder()
        => EnumerateAll(
                CreateGlobEnumerator(
                    new GlobEnumeratorBuilder()
                            .WithGlob(Pattern)
                            .FromDirectory(TestRootPath)
                            .WithDistinct(Distinct)
                            .TraverseDepthFirst(DepthFirst)
                            .SelectObjects(Objects.Files)
                            .Build()));
}