namespace vm2.DevOps.Glob.Api;

/// <summary>
/// Validation regular expressions for pathnames.
/// </summary>
[ExcludeFromCodeCoverage]
public static partial class GlobConstants
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
    /// Represents a regular expression pattern that matches valid characters for a Windows file or directory name.
    /// </summary>
    public const string WinNameChars = @"[^\x00-\x1F""/<>\\|]";

    /// <summary>
    /// Represents a regular expression pattern that matches valid characters for the last character in a Windows file or directory name.
    /// </summary>
    public const string WinNameLastChars = @"[^\x00-\x1F""./<>\\|]";

    /// <summary>
    /// Represents a regular expression pattern that matches valid characters for a Unix file or directory name.
    /// </summary>
    public const string UnixNameChars = @"[^\x00/]";

    /// <summary>
    /// The regular expression pattern for validating Windows pathnames.
    /// </summary>
    internal const string WindowsPathname = """
        ^
        (?=^.{0,260}$)
        ((?<drive>[A-Z]):)?
        (?<path>
            ( [/\\]?
              (
                ( \. | \.\.|
                    (
                      [^\x00-\x1F"*/:<>?\\|]*[^\x00-\x1F "*./:<>?\\|]
                      (?<! (CON|PRN|AUX|NUL|COM\d?|LPT\d?)(\.[^\x00-\x1F"*./:<>?\\|]*[^\x00-\x1F "*./:<>?\\|])? ) ) )
                ([/\\]
                  ( \. | \.\.|
                    (
                      [^\x00-\x1F"*/:<>?\\|]*[^\x00-\x1F "*./:<>?\\|]
                      (?<! (CON|PRN|AUX|NUL|COM\d?|LPT\d?)(\.[^\x00-\x1F"*./:<>?\\|]*[^\x00-\x1F "*./:<>?\\|])? ) ) ) )*
              ) [/\\] )
          | ( [/\\] )
          | ( \. | \.\. )
        )?
        (?<file>
          ( ( (?<name> [^\x00-\x1F"*/:<>?\\|]+ )\.(?<suffix> [^\x00-\x1F"*./:<>?\\|]*[^\x00-\x1F "*./:<>?\\|] ) )
                | (?<name> [^\x00-\x1F"*/:<>?\\|]*[^\x00-\x1F "*./:<>?\\|] ) )
          (?<! (CON|PRN|AUX|NUL|COM\d?|LPT\d?)(\.[^\x00-\x1F"*./:<>?\\|]*[^\x00-\x1F "*./:<>?\\|])? ) )?
        $
        """;

    /// <summary>
    /// The regular expression pattern for validating Windows glob-patterns.
    /// </summary>
    internal const string WindowsGlobPattern = """
        ^
        (( [A-Z]):)?
        (
          (
            ( [/\\]?
              (
                        ( \. | \.\. | \*\* | ( (?! [^\x00-\x1F"/<>\\|]*\*\* )( [^\x00-\x1F"/<>\\|]*[^\x00-\x1F "./<>\\|] ) ) )
                ( [/\\] ( \. | \.\. | \*\* | ( (?! [^\x00-\x1F"/<>\\|]*\*\* )( [^\x00-\x1F"/<>\\|]*[^\x00-\x1F "./<>\\|] ) ) ) )*
              )
            ) | ( \. | \.\. | \*\* )
          )
          ( [/\\] | $ )
        )?
        ( (?! [^\x00-\x1F"/<>\\|]*\*\* )( [^\x00-\x1F"/<>\\|]*[^\x00-\x1F "./<>\\|] ) )?
        $
        """;

    /// <summary>
    /// The regular expression pattern for validating Unix pathnames.
    /// </summary>
    internal const string UnixPathname = """
        ^
        ( ( (?<path> /? ( [^\x00/]{1,255} ( / [^\x00/]{1,255} )* ) ) / )
              | (?<path> /? ) )?
        (?<file> [^\x00/]{1,255} )?
        $
        """;

    /// <summary>
    /// The regular expression pattern for validating Unix pathnames.
    /// </summary>
    internal const string UnixGlobPattern = """
        ^
        ( /? |
            ( /?      ( (\*\*) | ( (?![^\x00/]*\*\*) [^\x00/]{1,255} ) )
                  ( / ( (\*\*) | ( (?![^\x00/]*\*\*) [^\x00/]{1,255} ) ) )* / ) )?
                      ( (\*\*) | ( (?![^\x00/]*\*\*) [^\x00/]{1,255} ) )?
        $
        """;

    const RegexOptions unixOptions = RegexOptions.IgnorePatternWhitespace | RegexOptions.ExplicitCapture;
    const RegexOptions winOptions  = unixOptions | RegexOptions.IgnoreCase;

    /// <summary>
    /// Gets a <see cref="Regex"/> object for validating Windows pathnames.
    /// </summary>
    /// <returns></returns>
    [GeneratedRegex(WindowsPathname, winOptions)]
    public static partial Regex WindowsPath();

    /// <summary>
    /// Gets a <see cref="Regex"/> object for validating Windows pathnames.
    /// </summary>
    /// <returns></returns>
    [GeneratedRegex(WindowsGlobPattern, winOptions)]
    public static partial Regex WindowsGlob();

    /// <summary>
    /// Gets a <see cref="Regex"/> object for validating Unix pathnames.
    /// </summary>
    /// <returns></returns>
    [GeneratedRegex(UnixPathname, unixOptions)]
    public static partial Regex UnixPath();

    /// <summary>
    /// Gets a <see cref="Regex"/> object for validating Unix pathnames.
    /// </summary>
    /// <returns></returns>
    [GeneratedRegex(UnixGlobPattern, unixOptions)]
    public static partial Regex UnixGlob();

    /// <summary>
    /// The name of a capturing group that represents a Unix environment variable
    /// </summary>
    internal const string EnvVarNameGr = "envVar";

    const string envVarName = "[A-Za-z_][0-9A-Za-z_]*";

    /// <summary>
    /// Gets a regular expression object that matches Unix-style environment variable patterns.
    /// </summary>
    /// <remarks>
    /// The pattern matches strings that start with a dollar sign ('$') followed by an optional opening brace ('{'), a valid
    /// environment variable name consisting of letters, digits, or underscores, and an optional closing brace ('}').
    /// </remarks>
    /// <returns>A <see cref="Regex"/> object configured to identify Unix-style environment variable patterns.</returns>
    [GeneratedRegex($@"\$ ( (?<brace>\{{) {envVarName} (?<{EnvVarNameGr}-brace>\}}) | (?<{EnvVarNameGr}> {envVarName} ) )", unixOptions)]
    public static partial Regex UnixEnvVar();

    /// <summary>
    /// Represents the replacement string for Unix environment variables captured by the <see cref="UnixEnvVar"/> regex. After
    /// replacement, the environment variable will be in the format "%{variable_name}%" - suitable for
    /// <see cref="Environment.ExpandEnvironmentVariables(string)"/>.
    /// </summary>
    /// <remarks>This constant defines the pattern for environment variable replacement in Unix systems, using
    /// the format "%${variable_name}%". It is intended for use in scenarios where environment variables need to be
    /// identified and replaced within strings and then expanded with <see cref="Environment.ExpandEnvironmentVariables(string)"/>.
    /// </remarks>
    public const string UnixEnvVarReplacement = $"%${{{EnvVarNameGr}}}%";

    /// <summary>
    /// Represents the environment variable used to retrieve the home directory path on Unix-based systems.
    /// </summary>
    public const string UnixHomeEnvironmentVar = "%HOME%";

    /// <summary>
    /// Represents the Unix shell-specific shorthand for the user's home directory.
    /// </summary>
    public const string UnixShellSpecificHome = "~";

    /// <summary>
    /// Represents the environment variable placeholder for the user's home directory on Windows systems.
    /// </summary>
    internal const string WinHomeEnvironmentVar = "%USERPROFILE%";

    /// <summary>
    /// Creates a regular expression to match Windows environment variable patterns.
    /// </summary>
    /// <remarks>
    /// The pattern matches strings that represent Windows environment variables, which are enclosed in percent signs and
    /// consist of alphanumeric characters and underscores, starting with a letter or underscore.
    /// </remarks>
    /// <returns>A <see cref="Regex"/> object configured to identify Windows environment variable patterns.</returns>
    [GeneratedRegex($@"(?<percent> % ) {envVarName} (?<{EnvVarNameGr}-percent> % )", winOptions)]
    internal static partial Regex WindowsEnvVar();

    /// <summary>
    /// Gets a <see cref="Regex"/> object for validating recursive wildcard patterns.
    /// </summary>
    /// <remarks>
    /// Recursive wildcard '**' cannot be preceded by anything other than a '/' or be at the beginning of the pattern string;
    /// and also cannot be followed by anything other than a '/' or be at the end of the pattern.
    /// Examples of invalid patterns: "a**", "**a", "a/**b", "a**/b", "a/**b".
    /// Examples of valid patterns: "**", "**/", "/**", "/**/", "a/**", "**/a", "a/**/", "/**/a", "a/**/b", "/**/a/b", "a/**/b/**/c".
    /// </remarks>
    /// <returns>
    /// A <see cref="Regex"/> object configured to identify invalid recursive wildcard patterns.
    /// </returns>
    [GeneratedRegex(@"(?<! ^ | /) \*\* | \*\* (?! $ | /)", unixOptions)]
    internal static partial Regex InvalidRecursive();

    /// <summary>
    /// Gets a <see cref="Regex"/> object for matching recursive wildcards '**' at the end of a pattern.
    /// </summary>
    /// <returns>
    /// A <see cref="Regex"/> object configured to identify matching recursive wildcards '**' at the end of a pattern.
    /// </returns>
    [GeneratedRegex(@"\*\*$")]
    internal static partial Regex RecursiveAtEnd();

    /// <summary>
    /// Gets a regular expression that matches Windows-style root paths.
    /// </summary>
    /// <remarks>
    /// The generated regular expression matches strings that represent root paths in Windows, such as "/", "\", or drive
    /// letters followed by a colon and a slash or backslash (e.g., "C:/", "D:\").
    /// </remarks>
    /// <returns>A <see cref="Regex"/> instance configured to match Windows-style root paths.</returns>
    [GeneratedRegex(@"^(/ | \\ | [A-Z]:[/\\]? )", winOptions)]
    internal static partial Regex WindowsFileSystemRoot();

    /// <summary>
    /// Gets a regular expression that matches strings starting with a forward slash ('/'), typically used to identify
    /// Unix-style root paths.
    /// </summary>
    /// <returns>A <see cref="Regex"/> instance configured to match strings beginning with a forward slash ('/').</returns>
    [GeneratedRegex(@"^/")]
    internal static partial Regex UnixFileSystemRoot();

    internal const string SeqWildcardGr = "seqwc";
    internal const string CharWildcardGr = "charwc";
    internal const string NamedClassGr = "namedClass";
    internal const string ClassNameGr = "classNm";
    internal const string ClassGr = "class";

    const string NmClassRegex = $"""
        (?<brcol> \[: ) (alnum | alpha | blank | cntrl | digit | graph | lower | print | punct | space | upper | xdigit) (?<-brcol> :\] )
        """;

    const string GlobExpressionRegex = $"""
          (?<{SeqWildcardGr}> \* )
        | (?<{CharWildcardGr}> \? )
        | (?<br> \[ ) !?\]? ( [^\[\]] | \[(?!:) | {NmClassRegex} )* (?<{ClassGr}-br> \] )
        """;

    /// <summary>
    /// Represents a regular expression pattern used to match named character classes and capture the name of the class in
    /// <see cref="ClassNameGr"/>.
    /// </summary>
    const string NamedClassRegex = $"""
        (?<brcol> \[: ) (alnum | alpha | blank | cntrl | digit | graph | lower | print | punct | space | upper | xdigit) (?<{ClassNameGr}-brcol> :\] )
        """;

    /// <summary>
    /// Creates a regular expression that matches replaceable wildcard patterns.
    /// </summary>
    [GeneratedRegex(GlobExpressionRegex, unixOptions)]
    internal static partial Regex GlobExpression();

    /// <summary>
    /// Creates a <see cref="Regex"/> instance using the specified named class pattern.
    /// </summary>
    [GeneratedRegex(NamedClassRegex, unixOptions)]
    internal static partial Regex NamedClass();

    /// <summary>
    /// A string containing characters that should be escaped in a regular expression.
    /// </summary>
    public const string RegexEscapable = "\t\v #$()*+.?[\\^{|";

    /// <summary>
    /// Represents the character used to separate the drive letter fromIndex the dirPath in f system paths.
    /// </summary>
    /// <remarks>Typically used in Windows.</remarks>
    public const char DriveSep = ':';

    /// <summary>
    /// Represents the more popular character used to separate the folders or directories in a dirPath for Windows.
    /// </summary>
    public const char WinSepChar = '\\';    // always converted to '/' - Windows takes both '/' and '\'

    /// <summary>
    /// Represents the character used to separate the folders or directories in a dirPath for both Unix and Windows.
    /// </summary>
    public const char SepChar = '/';

    /// <summary>
    /// Represents the dirPath of the current working directory as a dirPath segment.
    /// </summary>
    public const string CurrentDir = ".";

    /// <summary>
    /// Represents the dirPath of the parent directory of the current working directory as a dirPath segment.
    /// </summary>
    public const string ParentDir = "..";

    /// <summary>
    /// Represents a recursive wildcard pattern that matches all levels of a directory hierarchy fromIndex "here" - down.
    /// </summary>
    public const string RecursiveWildcard = "**";

    /// <summary>
    /// Represents a string used to denote an arbitrary sequence in a glob.
    /// </summary>
    public const string SequenceWildcard  = "*";

    /// <summary>
    /// Represents a wildcard for any single character in a dirPath.
    /// </summary>
    public const string CharacterWildcard = "?";
}
