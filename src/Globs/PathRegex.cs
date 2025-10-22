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
        ^(?=^.{0,260}$)
        (?:(?<drive>[A-Za-z]):)?
        (?<path>
            (?: [/\\]?
              (?:
                (?: \. | \.\.|
                    (?:
                      (?! (?:CON|PRN|AUX|NUL|COM\d?|LPT\d?)(?:\.[^\x00-\x1F"*./:<>?\\|]*[^\x00-\x1F "*./:<>?\\|])? )
                      (?: [^\x00-\x1F"*/:<>?\\|]*[^\x00-\x1F "*./:<>?\\|] ) ) )
                (?:[/\\]
                  (?: \. | \.\.|
                    (?:
                      (?! (?:CON|PRN|AUX|NUL|COM\d?|LPT\d?)(?:\.[^\x00-\x1F"*./:<>?\\|]*[^\x00-\x1F "*./:<>?\\|])? )
                      (?: [^\x00-\x1F"*/:<>?\\|]*[^\x00-\x1F "*./:<>?\\|] ) ) ) )*
              ) [/\\] )
          | (?: [/\\] )
          | (?: \.|\.\. )
        )?
        (?<file>
          (?! (?:CON|PRN|AUX|NUL|COM\d?|LPT\d?)(?:\.[^\x00-\x1F"*./:<>?\\|]*[^\x00-\x1F "*./:<>?\\|])? )
          (?: (?: (?<name> [^\x00-\x1F"*/:<>?\\|]+ )\.(?<suffix> [^\x00-\x1F"*./:<>?\\|]*[^\x00-\x1F "*./:<>?\\|] ) )
                | (?<name> [^\x00-\x1F"*/:<>?\\|]*[^\x00-\x1F "*./:<>?\\|] ) ) )?$
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

    /// <summary>
    /// The name of a capturing group that represents a Unix environment variable
    /// </summary>
    public const string EnvVarGr = "envVar";

    const string envVarName = $@"(?<{EnvVarGr}> [A-Za-z_][0-9A-Za-z_]* )";

    /// <summary>
    /// Gets a regular expression object that matches Unix-style environment variable patterns.
    /// </summary>
    /// <remarks>
    /// The pattern matches strings that start with a dollar sign ('$') followed by an optional opening brace ('{'), a valid
    /// environment variable name consisting of letters, digits, or underscores, and an optional closing brace ('}').
    /// </remarks>
    /// <returns>A <see cref="Regex"/> object configured to identify Unix-style environment variable patterns.</returns>
    [GeneratedRegex($@"\$(?<brace> \{{? ) {envVarName} (?<close-brace> \}}? )", RegexOptions.IgnorePatternWhitespace)]
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
    public const string UnixEnvVarReplacement = $"%${{{PathRegex.EnvVarGr}}}%";

    /// <summary>
    /// Creates a regular expression to match Windows environment variable patterns.
    /// </summary>
    /// <remarks>
    /// The pattern matches strings that represent Windows environment variables, which are enclosed in percent signs and
    /// consist of alphanumeric characters and underscores, starting with a letter or underscore.
    /// </remarks>
    /// <returns>A <see cref="Regex"/> object configured to identify Windows environment variable patterns.</returns>
    [GeneratedRegex($@"(?<percent> % ) {envVarName} (?<close-percent> % )", RegexOptions.IgnorePatternWhitespace)]
    public static partial Regex WinEnvVar();
}
