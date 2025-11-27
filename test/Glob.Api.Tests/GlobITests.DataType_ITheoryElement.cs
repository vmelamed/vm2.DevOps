namespace vm2.DevOps.Glob.Api.Tests;

[ExcludeFromCodeCoverage]
public class IntegrationTestData(
    string testFileLine,
    string glob,
    string startDir,
    Objects objects,
    MatchCasing matchCasing,
    bool depthFirst,
    bool distinct,
    bool win,
    bool unix,
    bool throws,
    params string[] results) : IXunitSerializable
{
    #region boilerplate
    public IntegrationTestData()
        : this("", "", "", Objects.FilesAndDirectories, MatchCasing.PlatformDefault, false, false, false, false, false, [])
    {
    }

    #region Properties
    // Note: the property names are kept short to reduce the size of the displayed output.

    /// <summary>
    /// [D]escription of the test case incl. the file and line number where it is defined.
    /// </summary>
    public string D { get; private set; } = testFileLine;
    /// <summary>
    /// The [G]lob pattern to evaluate.
    /// </summary>
    public string G { get; private set; } = glob;
    /// <summary>
    /// Gets the [S]tarting [D]irectory path used by the instance.
    /// </summary>
    public string Sd { get; private set; } = startDir;
    /// <summary>
    /// Gets the type of [O]bjects to enumerate.
    /// </summary>
    public Objects O { get; private set; } = objects;
    /// <summary>
    /// Defines the casing behavior for [M]atching.
    /// </summary>
    public MatchCasing M { get; private set; } = matchCasing;
    /// <summary>
    /// Gets or sets a value indicating whether [T]raversal is performed in [D]epth-[F]irst order (vs breadth-first).
    /// </summary>
    public bool Tdf { get; set; } = depthFirst;
    /// <summary>
    /// Gets or sets a value indicating whether the results will be distinct (e[X]clusive) or may contain duplicates.
    /// </summary>
    public bool X { get; set; } = distinct;
    /// <summary>
    /// Gets or sets a value indicating whether the data is Windows specific.
    /// </summary>
    public bool Win { get; private set; } = win;
    /// <summary>
    /// Gets or sets a value indicating whether the data is Unix specific.
    /// </summary>
    public bool Unix { get; private set; } = unix;
    /// <summary>
    /// If the enumeration is expected to [T]hrow an e[X]ception.
    /// </summary>
    public bool Tx { get; private set; } = throws;
    /// <summary>
    /// Expected [R]esults from the enumeration.
    /// </summary>
    public string[] R { get; private set; } = results;
    #endregion

    public void Deserialize(IXunitSerializationInfo info)
    {
        D      = info.GetValue<string>(nameof(D)) ?? "";
        G      = info.GetValue<string>(nameof(G)) ?? "";
        Sd     = info.GetValue<string>(nameof(Sd)) ?? "";
        O      = info.GetValue<Objects>(nameof(O));
        M      = info.GetValue<MatchCasing>(nameof(M));
        Tdf    = info.GetValue<bool>(nameof(Tdf));
        X      = info.GetValue<bool>(nameof(X));
        Win    = info.GetValue<bool>(nameof(Win));
        Unix   = info.GetValue<bool>(nameof(Unix));
        Tx     = info.GetValue<bool>(nameof(Tx));
        R      = info.GetValue<string[]>(nameof(R)) ?? [];
    }

    public void Serialize(IXunitSerializationInfo info)
    {
        info.AddValue(nameof(D), D);
        info.AddValue(nameof(G), G);
        info.AddValue(nameof(Sd), Sd);
        info.AddValue(nameof(O), O);
        info.AddValue(nameof(M), M);
        info.AddValue(nameof(Tdf), Tdf);
        info.AddValue(nameof(X), X);
        info.AddValue(nameof(Win), Win);
        info.AddValue(nameof(Unix), Unix);
        info.AddValue(nameof(Tx), Tx);
        info.AddValue(nameof(R), R);
    }
    #endregion

    public static implicit operator GlobEnumeratorBuilder(IntegrationTestData data)
        => data.ConfigureBuilder(new GlobEnumeratorBuilder());

    public GlobEnumeratorBuilder ConfigureBuilder(GlobEnumeratorBuilder builder)
        => builder
            .WithGlob(G)
            .FromDirectory(Sd)
            .WithCaseSensitivity(M)
            .TraverseDepthFirst(Tdf)
            .Select(O)
            .WithDistinct(X)
            .Build()
            ;
}
