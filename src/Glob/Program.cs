Argument<string> globExpression = new("glob")
{
    HelpName = "glob",
    Description = """
    The path-like glob pattern to use for searching file system objects. E.g.
    'results/**/*.y?ml' to find recursively all YAML files in the 'results'
    sub-directory of the current or start-from directory and in the
    sub-directories of 'results'.
    Note that the glob pattern can contain environment variables, e.g.
    '%USERPROFILE%/documents/**/*.json' on Windows or
    '$HOME/documents/**/*.json', or even '~/documents/**/*.y?ml' on Unix-like
    operating systems (Linux, MacOS, etc.).
    The segments of the path can be separated by either forward slashes ('/') or
    backslashes ('\') regardless of the operating system.
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
    }
};

Option<string> startDirectory = new(name: "--start-from", "-d")
{
    HelpName = "start-from",
    Description = """
    The directory from which to start the search. If not specified, the search
    will start from the current working directory, i.e. defaults to the pattern
    '.'.
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
    HelpName = "search-object",
    Description = """
    Specifies the type of file system objects to find. The value should be one
    of the words 'files', 'directories', 'both', or one of their first letters
    'f', 'd', 'b'.
    Default is 'both'.
    """,
    Required = false,
    Arity = ArgumentArity.ExactlyOne,
    DefaultValueFactory = _ => Objects.FilesAndDirectories,
    CustomParser = result =>
    {
        var value = result.Tokens[0].Value;

        return value switch
        {
            "files" or "f" => Objects.Files,
            "directories" or "d" => Objects.Directories,
            "both" or "b" => Objects.FilesAndDirectories,
            _ => Objects.FilesAndDirectories
        };
    }
};
searchFor.AcceptOnlyFromAmong("files", "f", "directories", "d", "both", "b");

Option<MatchCasing> caseSensitive = new(name: "--case", "-c")
{
    HelpName = "case",
    Description = """
    Specifies the case-sensitivity of the glob pattern matching. The value
    should be one of the words 'sensitive', 'insensitive', 'platform', or one
    of their first letters 's', 'i', 'p'.
    The default is platform-specific: case insensitive on Windows, and case
    sensitive on Linux, macOS, and other Unix-like systems.
    """,
    Required = false,
    Arity = ArgumentArity.ZeroOrOne,
    DefaultValueFactory = _ => MatchCasing.PlatformDefault,
    CustomParser = result =>
    {
        var value = result.Tokens[0].Value;

        return value switch
        {
            "sensitive" or "s" => MatchCasing.CaseSensitive,
            "insensitive" or "i" => MatchCasing.CaseInsensitive,
            "platform" or "p" => MatchCasing.PlatformDefault,
            _ => MatchCasing.PlatformDefault
        };
    }
};
caseSensitive.AcceptOnlyFromAmong("sensitive", "s", "insensitive", "i", "platform", "p");

Option<bool> distinct = new(name: "--distinct", "-x")
{
    HelpName = "distinct",
    Description = """
    Some globs may produce repeating matches, when they contain more than one
    recursive pattern (globstars), like '/**/docs/**/*.txt'. This may not be
    desirable. This option specifies whether to remove the duplicated results.
    """,
    Required = false,
    Arity = ArgumentArity.ExactlyOne,
    DefaultValueFactory = _ => false,
};

RootCommand rootCommand = new RootCommand("A tool to search for file system objects using glob patterns.")
{
    globExpression,
    startDirectory,
    searchFor,
    caseSensitive,
    distinct,
};

rootCommand.SetAction(Enumerate);

ParseResult parseResult = rootCommand.Parse(args);

if (parseResult.Errors.Count > 0)
{
    Console.WriteLine("Error parsing command line arguments:");
    foreach (var error in parseResult.Errors)
        Console.WriteLine($"  {error.Message}");
    return 1;
}

// Do
return parseResult.Invoke();

#pragma warning disable CA1031 // Do not catch general exception types but here there is no other way to report errors from the action
void Enumerate(ParseResult parseResult)
{
    try
    {
        var glob = new GlobEnumeratorBuilder()
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
                                parseResult.GetRequiredValue(distinct))
                            .Configure(new GlobEnumerator(new FileSystem()))
                            ;

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
