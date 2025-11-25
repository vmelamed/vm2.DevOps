using vm2.DevOps.Glob.Api.Benchmarks.BenchmarkConfigs;
using vm2.DevOps.Glob.Api.Benchmarks.Infrastructure;

namespace vm2.DevOps.Glob.Api.Benchmarks.Benchmarks.RealFileSystem;

/// <summary>
/// Benchmarks comparing case-sensitive vs case-insensitive matching on real file system.
/// </summary>
[Config(typeof(AntiVirusFriendlyConfig))]
public class CaseSensitivityBenchmarks : BenchmarkBase
{
    [Params("**/*.cs", "**/*test*.cs", "**/[A-Z]*.cs")]
    public string Pattern { get; set; } = string.Empty;

    [Params(MatchCasing.CaseSensitive, MatchCasing.CaseInsensitive, MatchCasing.PlatformDefault)]
    public MatchCasing CaseSensitivity { get; set; }

    [Benchmark]
    public int EnumerateWithCaseSensitivity()
    {
        var enumerator = CreateGlobEnumerator(
            Pattern,
            caseSensitivity: CaseSensitivity,
            depthFirst: false,
            distinct: false,
            enumerated: Objects.Files);

        return EnumerateAll(enumerator);
    }
}