namespace vm2.DevOps.Glob.Api.Tests;

[ExcludeFromCodeCoverage]
public class GlobEnumerateTheoryElement(
    string testFileLine,
    string fsFile,
    string glob,
    string workingDir,
    string startDir,
    Objects objects,
    MatchCasing matchCasing,
    bool throws,
    params string[] results) : IXunitSerializable
{
    #region boilerplate
    public GlobEnumerateTheoryElement()
        : this("", "", "", "", "", Objects.FilesAndDirectories, MatchCasing.PlatformDefault, false, [])
    {
    }

    #region Properties
    public string A { get; private set; } = testFileLine;
    public string File { get; private set; } = fsFile;
    public string Glob { get; private set; } = glob;
    public string WorkDir { get; private set; } = workingDir;
    public string StartDir { get; private set; } = startDir;
    public Objects Objects { get; private set; } = objects;
    public MatchCasing MatchCasing { get; private set; } = matchCasing;
    public bool Throws { get; private set; } = throws;
    public string[] Results { get; private set; } = [.. results.AsEnumerable().OrderBy(s => s, StringComparer.Ordinal)];
    #endregion

    public void Deserialize(IXunitSerializationInfo info)
    {
        A           = info.GetValue<string>(nameof(A)) ?? "";
        File        = info.GetValue<string>(nameof(File)) ?? "";
        Glob        = info.GetValue<string>(nameof(Glob)) ?? "";
        WorkDir     = info.GetValue<string>(nameof(WorkDir)) ?? "";
        StartDir    = info.GetValue<string>(nameof(StartDir)) ?? "";
        Objects     = info.GetValue<Objects>(nameof(Objects));
        MatchCasing = info.GetValue<MatchCasing>(nameof(MatchCasing));
        Throws      = info.GetValue<bool>(nameof(Throws));
        Results     = info.GetValue<string[]>(nameof(Results)) ?? [];
    }

    public void Serialize(IXunitSerializationInfo info)
    {
        info.AddValue(nameof(A), A);
        info.AddValue(nameof(File), File);
        info.AddValue(nameof(Glob), Glob);
        info.AddValue(nameof(WorkDir), WorkDir);
        info.AddValue(nameof(StartDir), StartDir);
        info.AddValue(nameof(Objects), Objects);
        info.AddValue(nameof(MatchCasing), MatchCasing);
        info.AddValue(nameof(Throws), Throws);
        info.AddValue(nameof(Results), Results);
    }
    #endregion
}
