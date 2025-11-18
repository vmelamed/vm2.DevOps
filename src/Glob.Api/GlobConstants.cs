namespace vm2.DevOps.Glob.Api;

/// <summary>
/// Validation regular expressions for pathnames.
/// </summary>
[ExcludeFromCodeCoverage]
public static partial class GlobConstants
{
    #region Common glob and pattern constants
    /// <summary>
    /// Represents the character used to separate the directories or directories in a dirPath for both Unix and Windows.
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
    /// Represents the asterisk character used in <see cref="SequenceWildcard"/> and <see cref="RecursiveWildcard"/>
    /// </summary>
    public const char Asterisk = '*';

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

    /// <summary>
    /// Represents the regular expression pattern for a valid environment variable name.
    /// </summary>
    const string envVarName = "[A-Za-z_][0-9A-Za-z_]*";
    #endregion

    #region Names of regex matching groups
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
    /// The name of a capturing group that represents a Unix environment variable
    /// </summary>
    public const string EnvVarNameGr = "envVar";
    #endregion

    #region Unix related regex-es and constants
    /// <summary>
    /// Represents a regular expression pattern that matches valid characters for a Unix file or directory name.
    /// </summary>
    public const string UnixNameChars = @"[^\x00/]";

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

    /// <summary>
    /// Gets a <see cref="Regex"/> object for validating Unix pathnames.
    /// </summary>
    /// <returns></returns>
    [GeneratedRegex(UnixPathname, unixOptions)]
    public static partial Regex UnixPathRgex();

    /// <summary>
    /// Gets a <see cref="Regex"/> object for validating Unix pathnames.
    /// </summary>
    /// <returns></returns>
    [GeneratedRegex(UnixGlobPattern, unixOptions)]
    public static partial Regex UnixGlobRgex();

    /// <summary>
    /// Gets a regular expression object that matches Unix-style environment variable patterns.
    /// </summary>
    /// <remarks>
    /// The pattern matches strings that start with a dollar sign ('$') followed by an optional opening brace ('{'), a valid
    /// environment variable name consisting of letters, digits, or underscores, and an optional closing brace ('}').
    /// </remarks>
    /// <returns>A <see cref="Regex"/> object configured to identify Unix-style environment variable patterns.</returns>
    [GeneratedRegex($@"\$ ( (?<brace>\{{) {envVarName} (?<{EnvVarNameGr}-brace>\}}) | (?<{EnvVarNameGr}> {envVarName} ) )", unixOptions)]
    public static partial Regex UnixEnvVarRegex();

    /// <summary>
    /// Represents the replacement string for Unix environment variables captured by the <see cref="UnixEnvVarRegex"/> regex. After
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
    /// Gets a regular expression that matches strings starting with a forward slash ('/'), typically used to identify
    /// Unix-style root paths.
    /// </summary>
    /// <returns>A <see cref="Regex"/> instance configured to match strings beginning with a forward slash ('/').</returns>
    [GeneratedRegex(@"^/")]
    internal static partial Regex UnixFileSystemRootRegex();
    #endregion

    #region Windows related regex-es and constants
    /// <summary>
    /// Represents a regular expression pattern that matches valid characters for a Windows file or directory name.
    /// </summary>
    public const string WinNameChars = @"[^\x00-\x1F""/<>\\|]";

    /// <summary>
    /// Represents a regular expression pattern that matches valid characters for the last character in a Windows file or directory name.
    /// </summary>
    public const string WinNameLastChars = @"[^\x00-\x1F""./<>\\|]";

    /// <summary>
    /// Represents the character used to separate the drive letter fromIndex the dirPath in f system paths.
    /// </summary>
    /// <remarks>Typically used in Windows.</remarks>
    public const char DriveSep = ':';

    /// <summary>
    /// Represents the more popular character used to separate the directories or directories in a dirPath for Windows.
    /// </summary>
    public const char WinSepChar = '\\';    // here it is always converted to '/' - Windows takes both '/' and '\'

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

    const RegexOptions winOptions  = unixOptions | RegexOptions.IgnoreCase;

    /// <summary>
    /// Gets a <see cref="Regex"/> object for validating Windows pathnames.
    /// </summary>
    /// <returns></returns>
    [GeneratedRegex(WindowsPathname, winOptions)]
    public static partial Regex WindowsPathRegex();

    /// <summary>
    /// Gets a <see cref="Regex"/> object for validating Windows pathnames.
    /// </summary>
    /// <returns></returns>
    [GeneratedRegex(WindowsGlobPattern, winOptions)]
    public static partial Regex WindowsGlobRegex();

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
    internal static partial Regex WindowsEnvVarRegex();

    /// <summary>
    /// Gets a regular expression that matches Windows-style root paths.
    /// </summary>
    /// <remarks>
    /// The generated regular expression matches strings that represent root paths in Windows, such as "/", "\", or drive
    /// letters followed by a colon and a slash or backslash (e.g., "C:/", "D:\").
    /// </remarks>
    /// <returns>A <see cref="Regex"/> instance configured to match Windows-style root paths.</returns>
    [GeneratedRegex(@"^(/ | \\ | [A-Z]:[/\\]? )", winOptions)]
    internal static partial Regex WindowsFileSystemRootRegex();
    #endregion

    #region Glob regex parsing, names of capturing groups, and other related constants
    /// <summary>
    /// Gets a <see cref="Regex"/> object for detecting invalid recursive wildcard patterns.
    /// </summary>
    /// <remarks>
    /// RecursiveRegex wildcard '**' cannot be preceded by anything other than a '/' or be at the beginning of the pattern string;
    /// and also cannot be followed by anything other than a '/' or be at the end of the pattern.
    /// Examples of invalid patterns: "a**", "**a", "a/**b", "a**/b", "a/**b".
    /// Examples of valid patterns: "**", "**/", "/**", "/**/", "a/**", "**/a", "a/**/", "/**/a", "a/**/b", "/**/a/b", "a/**/b/**/c".
    /// </remarks>
    /// <returns>
    /// A <see cref="Regex"/> object configured to identify invalid recursive wildcard patterns.
    /// </returns>
    [GeneratedRegex(@"(?<! ^ | /) \*\*+ | \*\*+ (?! $ | /)", unixOptions)]
    internal static partial Regex InvalidRecursiveRegex();

    /// <summary>
    /// Gets a <see cref="Regex"/> object for matching recursive wildcards '**'.
    /// </summary>
    /// <returns>
    /// A <see cref="Regex"/> object configured to identify matching recursive wildcards '**'.
    /// </returns>
    [GeneratedRegex(@"\*\*")]
    internal static partial Regex RecursiveRegex();

    /// <summary>
    /// Gets a <see cref="Regex"/> object for matching recursive wildcards '**' at the end of a pattern.
    /// </summary>
    /// <returns>
    /// A <see cref="Regex"/> object configured to identify matching recursive wildcards '**' at the end of a pattern.
    /// </returns>
    [GeneratedRegex(@"\*\*$")]
    internal static partial Regex RecursiveAtEndRegex();

    internal const string SeqWildcardGr = "seqwc";
    internal const string CharWildcardGr = "charwc";
    internal const string NamedClassGr = "namedClass";
    internal const string ClassNameGr = "classNm";
    internal const string ClassGr = "class";

    const string NmClassRegex = $"""
        (?<brcol> \[: ) (alnum | alpha | blank | cntrl | digit | graph | lower | print | punct | space | upper | xdigit) (?<-brcol> :\] )
        """;

    // Idea: "\*(?<! (([^\\]\\)|(^\\))\*)" might implement the escaping rules for the special characters *, ?, and [:
    // - <non-backslash>*              - is a wildcard
    // - <non-backslash><backslash>*   - is a literal *
    // - <start of string><backslash>* - is a literal *
    // - <backslash><backslash>*       - is a literal <backslash> followed by a wildcard

    const string GlobExpression = $"""
          (?<{SeqWildcardGr}> \* )
        | (?<{CharWildcardGr}> \? )
        | (?<br> \[ ) !?\]? ( [^\[\]] | \[(?!:) | {NmClassRegex} )* (?<{ClassGr}-br> \] )
        """;

    /// <summary>
    /// Represents a regular expression pattern used to match named character classes and capture the name of the class in
    /// <see cref="ClassNameGr"/>.
    /// </summary>
    const string NamedClass = $"""
        (?<brcol> \[: ) (alnum | alpha | blank | cntrl | digit | graph | lower | print | punct | space | upper | xdigit) (?<{ClassNameGr}-brcol> :\] )
        """;

    /// <summary>
    /// Creates a regular expression that matches replaceable wildcard patterns.
    /// </summary>
    [GeneratedRegex(GlobExpression, unixOptions)]
    internal static partial Regex GlobExpressionRegex();

    /// <summary>
    /// Creates a <see cref="Regex"/> instance using the specified named class pattern.
    /// </summary>
    [GeneratedRegex(NamedClass, unixOptions)]
    internal static partial Regex NamedClassRegex();

    /// <summary>
    /// A string containing characters that should be escaped in a regular expression.
    /// </summary>
    public const string RegexEscapable = "\t\v #$()*+.?[\\^{|";
    #endregion
}
