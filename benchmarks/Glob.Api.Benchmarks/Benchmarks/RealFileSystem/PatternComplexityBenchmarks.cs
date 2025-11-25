using vm2.DevOps.Glob.Api.Benchmarks.BenchmarkConfigs;
using vm2.DevOps.Glob.Api.Benchmarks.Infrastructure;

namespace vm2.DevOps.Glob.Api.Benchmarks.Benchmarks.RealFileSystem;

/// <summary>
/// Benchmarks comparing different glob pattern complexities on real file system.
/// </summary>
[Config(typeof(AntiVirusFriendlyConfig))]
public class PatternComplexityBenchmarks : BenchmarkBase
{
    [Params(
        "*.cs",                      // Simple wildcard
        "**/*.cs",                   // Single globstar
        "**/test/**/*.cs",           // Multiple path components with globstar
        "**/**/**/*.cs",             // Multiple globstars
        "**/[a-z]*.cs",              // Character class
        "**/*[Tt]est*.cs",           // Mixed wildcards
        "src/**/[A-Z]*Service.cs"    // Complex realistic pattern
    )]
    public string Pattern { get; set; } = string.Empty;

    [Benchmark]
    public int EnumeratePattern()
    {
        var enumerator = CreateGlobEnumerator(
            Pattern,
            caseSensitivity: MatchCasing.PlatformDefault,
            depthFirst: false,
            distinct: false,
            enumerated: Objects.Files);

        return EnumerateAll(enumerator);
    }
}