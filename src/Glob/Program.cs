Argument<string> globExpression = new("glob")
{
    HelpName = "glob",
    Description = """
    Glob pattern for matching file system objects (e.g., '**/*.txt',
    'src/**/[a-z]*.cs'). Supports wildcards (*, ?), character classes ([abc],
    [a-z]), globstars (**), and environment variables (%VAR% on Windows, $VAR or
    ~ on Unix-like systems). Path separators can be either '/' or '\' regardless
    of the operating system.
    """,
    Arity = ArgumentArity.ExactlyOne,
    Validators =
    {
        result =>
        {
            var pattern = result.GetValueOrDefault<string>();

            if (string.IsNullOrWhiteSpace(pattern))
            {
                result.AddError("The glob pattern cannot be empty.");
                return;
            }

            if (!OperatingSystem.GlobRegex().IsMatch(pattern))
                result.AddError($"The specified glob pattern is not valid: `{pattern}`.");
        }
    },
    DefaultValueFactory = _ => "*",
};

Option<string> startDirectory = new(name: "--start-from", "-d")
{
    HelpName = "start-from",
    Description = """
    The directory from which to start the search.
    If not specified, the search starts from the
    current working directory.

    """,
    Required = false,
    Arity = ArgumentArity.ExactlyOne,
    DefaultValueFactory = _ => ".",
    Validators =
    {
        result =>
        {
            var directoryPath = result.GetValueOrDefault<string>();

            if (string.IsNullOrWhiteSpace(directoryPath))
                return;

            if (!OperatingSystem.PathRegex().IsMatch(directoryPath))
                result.AddError($"The specified start directory is not a valid path: `{directoryPath}`.");
            else
            if (!Directory.Exists(directoryPath))
                result.AddError($"The specified directory does not exist: `{directoryPath}`.");
        }
    }
};
startDirectory.AcceptLegalFilePathsOnly();

Option<Objects> searchFor = new(name: "--search-objects", "-o")
{
    HelpName = "search-objects",
    Description = """
    Specifies the type of file system objects to
    find: 'files' (f), 'directories' (d), or
    'both' (b).

    """,
    Required = false,
    Arity = ArgumentArity.ExactlyOne,
    DefaultValueFactory = _ => Objects.FilesAndDirectories,
    CustomParser = result => result.Tokens[0].Value switch
    {
        "files" or "f" => Objects.Files,
        "directories" or "d" => Objects.Directories,
        "both" or "b" => Objects.FilesAndDirectories,
        _ => Objects.FilesAndDirectories
    }
};
searchFor.AcceptOnlyFromAmong("files", "f", "directories", "d", "both", "b");

Option<MatchCasing> caseSensitive = new(name: "--case", "-c")
{
    HelpName = "case",
    Description = """
    Case-sensitivity for pattern matching:
    'sensitive' (s), 'insensitive' (i), or
    'platform' (p). Platform uses case-insensitive
    matching on Windows and case-sensitive on
    Unix-like systems (Linux, macOS, BSD).

    """,
    Required = false,
    Arity = ArgumentArity.ZeroOrOne,
    DefaultValueFactory = _ => MatchCasing.PlatformDefault,
    CustomParser = result => result.Tokens[0].Value switch
    {
        "sensitive" or "s" => MatchCasing.CaseSensitive,
        "insensitive" or "i" => MatchCasing.CaseInsensitive,
        "platform" or "p" => MatchCasing.PlatformDefault,
        _ => MatchCasing.PlatformDefault
    }
};
caseSensitive.AcceptOnlyFromAmong("sensitive", "s", "insensitive", "i", "platform", "p");

Option<bool> distinct = new(name: "--distinct", "-x")
{
    HelpName = "distinct",
    Description = """
    Removes duplicate results from patterns with
    multiple globstars (**). Patterns like
    '/**/docs/**/*.txt' may match the same file
    through different paths. Enabling this option
    ensures each result appears only once.

    """,
    Required = false,
    Arity = ArgumentArity.ExactlyOne,
    DefaultValueFactory = _ => false,
};

RootCommand rootCommand = new RootCommand("""
A cross-platform glob pattern matching tool for finding files and directories.

DESCRIPTION:
    This tool implements glob pattern matching based on the POSIX.2
    specification with cross-platform extensions for Windows and Unix-like
    systems.

GLOB PATTERN SYNTAX:
    *           Matches any sequence of characters (excluding path separators)
    ?           Matches any single character (excluding path separators)
    [abc]       Matches any character in the set (a, b, or c)
    [a-z]       Matches any character in the range (a through z)
    [!abc]      Matches any character NOT in the set
    **          Matches zero or more directory levels (globstar)
    [:class:]   Named character classes (alpha, digit, lower, upper, etc.)

PATH HANDLING:
    - Path separators: Use '/' or '\' regardless of the operating system
    - Absolute paths: Supports drive letters on Windows (e.g.,
      'C:/docs/**/*.txt')
    - Relative paths: Start from current or [start-from] directory
    - Environment variables: Expanded before pattern matching
        Windows: %USERPROFILE%\documents\**\*.pdf
        Unix:    $HOME/documents/**/*.pdf or ~/documents/**/*.pdf

OUTPUT FORMAT:
    - All matched objects are displayed with their full absolute paths
    - Directory paths are always terminated with a trailing '/' separator
    - Each result is printed on a separate line

EXAMPLES:
    glob "**/*.txt"                          # Find all .txt files recursively
    glob "src/**/[a-z]*.cs" -d ~/projects    # C# files starting with lowercase
    glob "[!.]*.json" -c sensitive           # JSON files not starting with dot
    glob "**" -o directories -x              # All directories, no duplicates

For detailed glob specification, see:
https://www.man7.org/linux/man-pages/man7/glob.7.html
""")
{
    globExpression,
    startDirectory,
    searchFor,
    caseSensitive,
    distinct,
};

var parseResult = rootCommand.Parse(args);

if (parseResult.Errors.Count > 0)
{
    Console.WriteLine("Error parsing command line arguments:");
    foreach (var error in parseResult.Errors)
        Console.WriteLine($"  {error.Message}");
    return 1;
}

var builder = Host.CreateApplicationBuilder();

builder
    .Configuration
    .Sources
    .Clear()
    ;
builder
    .Configuration
    .AddJsonFile("appsettings.json", optional: true)
    .AddJsonFile("appsettings.Development.json", optional: true)
    .AddJsonFile($"appsettings.{Environment.GetEnvironmentVariable("USERPROFILE")}.json", optional: true)
    .AddEnvironmentVariables()
    ;
builder
    .Logging
    .ClearProviders()
    .AddConsole()
    .SetMinimumLevel(LogLevel.Warning)
    ;
builder
    .Services
    .AddGlobEnumerator(
        builder => builder
                    .WithGlob(
                        ExpandEnvironmentVariables(
                            parseResult.GetRequiredValue(globExpression)))
                    .WithCaseSensitivity(
                        parseResult.GetRequiredValue(caseSensitive))
                    .FromDirectory(
                        parseResult.GetRequiredValue(startDirectory))
                    .SelectObjects(
                        parseResult.GetRequiredValue(searchFor))
                    .WithDistinct(
                        parseResult.GetRequiredValue(distinct)));
var host = builder.Build();

// Do
rootCommand.SetAction(Enumerate);
return parseResult.Invoke();

#pragma warning disable CA1031 // Do not catch general exception types but here there is no other way to report errors from the action
void Enumerate(ParseResult parseResult)
{
    try
    {
        var glob = host.Services.GetRequiredService<GlobEnumerator>();

        foreach (var entry in glob.Enumerate())
            Console.WriteLine(entry);
    }
    catch (Exception ex)
    {
        parseResult.CommandResult.AddError($"An error occurred during glob enumeration:\n{ex.Message}");
    }
}
#pragma warning restore CA1031 // Do not catch general exception types

string ExpandEnvironmentVariables(string pattern)
{
    if (OperatingSystem.IsLinux() || OperatingSystem.IsMacOS() || OperatingSystem.IsFreeBSD())
    {
        pattern = pattern.Replace(UnixShellSpecificHome, UnixHomeEnvironmentVar);   // Support Unix shell home directory syntax like ~ -> $HOME -> %HOME%
        UnixEnvVarRegex().Replace(pattern, UnixEnvVarReplacement);                  // Support Unix shell environment variable syntax $ENV_VAR -> %ENV_VAR%
    }

    return Environment.ExpandEnvironmentVariables(pattern);                                             // Ensure environment variables are supported
}
