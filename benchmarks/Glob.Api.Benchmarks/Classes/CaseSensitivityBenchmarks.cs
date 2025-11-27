namespace vm2.DevOps.Glob.Api.Benchmarks.Classes;

/// <summary>
/// Benchmarks comparing case-sensitive vs case-insensitive matching on real file system.
/// </summary>
[Config(typeof(AntiVirusFriendlyConfig))]
public class CaseSensitivity : BenchmarkBase
{
    [Params("**/*.cs", "**/*test*.cs", "**/[A-Z]*.cs")]
    public string Pattern { get; set; } = string.Empty;

    [Params(MatchCasing.CaseSensitive, MatchCasing.CaseInsensitive, MatchCasing.PlatformDefault)]
    public MatchCasing CaseSensitive { get; set; }

    [Benchmark]
    public int EnumerateWithCaseSensitivity()
        => EnumerateAll(
                CreateGlobEnumerator(
                    new GlobEnumeratorBuilder()
                            .WithGlob(Pattern)
                            .FromDirectory(TestRootPath)
                            .WithCaseSensitivity(CaseSensitive)
                            .SelectObjects(Objects.Files)
                            .Build()));
}