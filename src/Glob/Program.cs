var services = new ServiceCollection()
    .AddSingleton<IFileSystem, FileSystem>()
    .AddTransient<GlobEnumerator>()
    .AddLogging(
        builder =>
        {
            builder.AddConsole();
            builder.SetMinimumLevel(LogLevel.Warning);
        })
    .BuildServiceProvider()
    ;

Argument<string> globExpression = new("glob-pattern")
{
    HelpName = "glob-pattern",
    Description = """
    The glob pattern to use for searching file system objects. E.g.
    'results/**/*.y?ml' to find recursively all YAML files in the 'results'
    sub-directory of the current or start-from directory and in the
    sub-directories of 'results'.
    Note that the glob pattern can contain environment variables, e.g.
    '%USERPROFILE%/documents/**/*.json' on Windows or
    '$HOME/documents/**/*.json', or even '~/documents/**/*.y?ml' on Unix
    operating systems.
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

            var regex = OperatingSystem.IsWindows() ? WindowsGlobRegex() : UnixGlobRgex();

            if (!regex.IsMatch(pattern))
                result.AddError($"The specified glob pattern is not valid: `{pattern}`.");
        }
    }
};

Option<string> startDirectory = new(name: "--start-from", "-d")
{
    HelpName = "start-from",
    Description = """
    The directory from which to start the glob pattern search. If not specified,
    the search will start from the current working directory, i.e. equivalent to
    the pattern '.'.
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

            var regex = OperatingSystem.IsWindows() ? WindowsPathRegex() : UnixPathRgex();

            if (!regex.IsMatch(directoryPath))
                result.AddError($"The specified start directory is not a valid path: `{directoryPath}`.");
            else
            if (!Directory.Exists(directoryPath))
                result.AddError($"The specified directory does not exist: `{directoryPath}`.");
        }
    }
};
startDirectory.AcceptLegalFilePathsOnly();

Option<Objects> searchFor = new(name: "--search-for", "-s")
{
    HelpName = "search-for",
    Description = """
    Specifies the type of file system objects to find. The value should be one
    or more of the starting letters of one of the values: 'files',
    'directories', or 'both'.
    E.g. 'f', 'fi', 'fil', etc. for files; 'd', 'di', etc. for directories, or
    'b', 'bo', etc. for both.
    Default is 'both'.
    """,
    Required = false,
    Arity = ArgumentArity.ExactlyOne,
    DefaultValueFactory = _ => Objects.FilesAndDirefctories,
    Validators =
    {
        result =>
        {
            var value = result.Tokens[0].Value;

            if (!Objects.Files.ToString().StartsWith(value, StringComparison.OrdinalIgnoreCase) &&
                !Objects.Directories.ToString().StartsWith(value, StringComparison.OrdinalIgnoreCase) &&
                !Objects.FilesAndDirefctories.ToString().StartsWith(value, StringComparison.OrdinalIgnoreCase))
                result.AddError($"None of the expected values `{Objects.Files}`, `{Objects.Directories}`, or `{Objects.FilesAndDirefctories}` starts with `{value}`.");
        }
    },
    CustomParser = result =>
    {
        var value = result.Tokens[0].Value;

        return Objects.Files.ToString().StartsWith(value, StringComparison.OrdinalIgnoreCase) ? Objects.Files :
               Objects.Directories.ToString().StartsWith(value, StringComparison.OrdinalIgnoreCase) ? Objects.Directories :
               Objects.FilesAndDirefctories;
    }
};

Option<bool> distinct = new(name: "--distinct", "-x")
{
    HelpName = "distinct",
    Description = """
    Some globs may produce repeating matches, when they contain more than one
    recursive pattern, like '/**/docs/**/*.txt'. This may not be desireable.
    This option specifies whether to remove the duplicated results.
    """,
    Required = false,
    Arity = ArgumentArity.ExactlyOne,
    DefaultValueFactory = _ => false,
};

Option<bool> debug = new(name: "--debug")
{
    Description = "If specified, enables debug output.",
    Hidden = true,
    Required = false,
    Arity = ArgumentArity.Zero,
    DefaultValueFactory = _ => false,
    CustomParser = _ => true,
};

RootCommand rootCommand = new RootCommand("A tool to search for file system objects using glob patterns.")
{
    debug,
    startDirectory,
    searchFor,
    globExpression,
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
        var pattern = ExpandEnvironmentVariables(
                        parseResult
                            .GetRequiredValue(globExpression)
                            .Replace('\\', '/'));

        var enumerator = services.GetRequiredService<GlobEnumerator>();

        enumerator.FromDirectory   = parseResult.GetRequiredValue(startDirectory);
        enumerator.Enumerated      = parseResult.GetRequiredValue(searchFor);
        enumerator.Glob            =  pattern;
        enumerator.DistinctResults = parseResult.GetRequiredValue(distinct);

        foreach (var entry in enumerator.Enumerate())
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
