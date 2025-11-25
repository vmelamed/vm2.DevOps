using vm2.DevOps.Glob.Api.Benchmarks.BenchmarkConfigs;
using vm2.DevOps.Glob.Api.Benchmarks.Infrastructure;

namespace vm2.DevOps.Glob.Api.Benchmarks.Benchmarks.RealFileSystem;

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
    {
        var enumerator = CreateGlobEnumerator(
            Pattern,
            caseSensitivity: MatchCasing.PlatformDefault,
            depthFirst: DepthFirst,
            distinct: Distinct,
            enumerated: Objects.Files);

        return EnumerateAll(enumerator);
    }
}