namespace vm2.DevOps.Globs;

/// <summary>
/// Validation regular expressions for pathnames.
/// </summary>
public static partial class PathRegex
{
    /// <summary>
    /// The the name of a matching group representing the drive letter in a path name.
    /// </summary>
    public const string DriveGr = "drive";

    /// <summary>
    /// The the name of a matching group representing the path path name.
    /// </summary>
    public const string PathGr = "path";

    /// <summary>
    /// The the name of a matching group representing the file name.
    /// </summary>
    public const string FileGr = "file";

    /// <summary>
    /// The the name of a matching group representing the file name's suffix.
    /// </summary>
    public const string SuffixGr = "suffix";

    /// <summary>
    /// The regular expression pattern for validating Windows pathnames.
    /// </summary>
    public const string WindowsPathname = """
        ^
        (?=^.{1,260}$)
        (?:(?<drive>[A-Za-z]):)?
        (?:
            (?:
              (?<path> [/\\]? (?: (?: \.|\.\.|(?: (?! (?:CON|PRN|AUX|NUL|COM\d?|LPT\d?)(?:\.[^\x00-\x1F"*./:<>?\\|]*[^\x00-\x1F "*./:<>?\\|])? )
                                                  (?: [^\x00-\x1F"*/:<>?\\|]*[^\x00-\x1F "*./:<>?\\|] ) ) )
                    (?:[/\\]      (?: \.|\.\.|(?: (?! (?:CON|PRN|AUX|NUL|COM\d?|LPT\d?)(?:\.[^\x00-\x1F"*./:<>?\\|]*[^\x00-\x1F "*./:<>?\\|])? )
                                                  (?: [^\x00-\x1F"*/:<>?\\|]*[^\x00-\x1F "*./:<>?\\|] ) ) ))*
              )) [/\\]
            )
          | (?<path> [/\\]? )
        )?
        (?<file> (?! (?:CON|PRN|AUX|NUL|COM\d?|LPT\d?)(?:\.[^\x00-\x1F"*./:<>?\\|]*[^\x00-\x1F "*./:<>?\\|])? )
                 (?: (?: (?<name> [^\x00-\x1F"*/:<>?\\|]+ )\.
                         (?<suffix> [^\x00-\x1F"*./:<>?\\|]*[^\x00-\x1F "*./:<>?\\|] ) )
                    |    (?<name> (?: [^\x00-\x1F"*/:<>?\\|]*[^\x00-\x1F "*./:<>?\\|] ) ) ) )?
        $
        """;

    /// <summary>
    /// The regular expression pattern for validating Unix pathnames.
    /// </summary>
    public const string UnixPathname = """
        ^
        (?: (?: (?<path> /? (?: [^\x00/]{1,255} (?: / [^\x00/]{1,255} )* ) ) / ) | (?<path> /? ) )?
        (?<file> [^\x00/]{1,255} )?
        $
        """;

    const RegexOptions winOptions  = RegexOptions.Singleline | RegexOptions.IgnorePatternWhitespace | RegexOptions.IgnoreCase;

    /// <summary>
    /// Gets a <see cref="Regex"/> object for validating Windows pathnames.
    /// </summary>
    /// <returns></returns>
    [GeneratedRegex(WindowsPathname, winOptions)]
    public static partial Regex WindowsPath();

    const RegexOptions unixOptions = RegexOptions.Singleline | RegexOptions.IgnorePatternWhitespace;

    /// <summary>
    /// Gets a <see cref="Regex"/> object for validating Unix pathnames.
    /// </summary>
    /// <returns></returns>
    [GeneratedRegex(UnixPathname, unixOptions)]
    public static partial Regex UnixPath();
}
