namespace vm2.DevOps.Glob.Api.Tests;

[ExcludeFromCodeCoverage]
public class UnitTestElement(
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
    public UnitTestElement()
        : this("", "", "", "", "", Objects.FilesAndDirectories, MatchCasing.PlatformDefault, false, [])
    {
    }

    #region Properties
    // Note: the property names are kept short to reduce the size of the displayed output.

    /// <summary>
    /// D of the test case incl. the file and line number where it is defined.
    /// </summary>
    public string D { get; private set; } = testFileLine;
    /// <summary>
    /// Fake file system definition file.
    /// </summary>
    public string Fs { get; private set; } = fsFile;
    /// <summary>
    /// The glob pattern to evaluate.
    /// </summary>
    public string G { get; private set; } = glob;
    /// <summary>
    /// Current working directory for the enumeration.
    /// </summary>
    public string Cwd { get; private set; } = workingDir;
    /// <summary>
    /// Gets the starting directory path used by the instance.
    /// </summary>
    public string Sd { get; private set; } = startDir;
    /// <summary>
    /// Gets the type of objects to enumerate.
    /// </summary>
    public Objects O { get; private set; } = objects;
    /// <summary>
    /// Defines the casing behavior for matching.
    /// </summary>
    public MatchCasing M { get; private set; } = matchCasing;
    /// <summary>
    /// If the enumeration is expected to throw an exception.
    /// </summary>
    public bool Throws { get; private set; } = throws;
    /// <summary>
    /// Expected results from the enumeration.
    /// </summary>
    public string[] R { get; private set; } = [.. results.AsEnumerable().OrderBy(s => s, StringComparer.Ordinal)];
    #endregion

    public void Deserialize(IXunitSerializationInfo info)
    {
        D      = info.GetValue<string>(nameof(D)) ?? "";
        Fs     = info.GetValue<string>(nameof(Fs)) ?? "";
        G      = info.GetValue<string>(nameof(G)) ?? "";
        Cwd    = info.GetValue<string>(nameof(Cwd)) ?? "";
        Sd     = info.GetValue<string>(nameof(Sd)) ?? "";
        O      = info.GetValue<Objects>(nameof(O));
        M      = info.GetValue<MatchCasing>(nameof(M));
        Throws = info.GetValue<bool>(nameof(Throws));
        R      = info.GetValue<string[]>(nameof(R)) ?? [];
    }

    public void Serialize(IXunitSerializationInfo info)
    {
        info.AddValue(nameof(D), D);
        info.AddValue(nameof(Fs), Fs);
        info.AddValue(nameof(G), G);
        info.AddValue(nameof(Cwd), Cwd);
        info.AddValue(nameof(Sd), Sd);
        info.AddValue(nameof(O), O);
        info.AddValue(nameof(M), M);
        info.AddValue(nameof(Throws), Throws);
        info.AddValue(nameof(R), R);
    }
    #endregion

    public static implicit operator GlobEnumeratorBuilder(UnitTestElement data)
        => new GlobEnumeratorBuilder()
                            .WithGlob(data.G)
                            .FromDirectory(data.Sd)
                            .WithCaseSensitivity(data.M)
                            .Select(data.O)
                            ;

    public GlobEnumeratorBuilder ConfigureBuilder(GlobEnumeratorBuilder builder)
        => builder
            .WithGlob(G)
            .FromDirectory(Sd)
            .WithCaseSensitivity(M)
            .Select(O)
            .Build()
            ;
}
