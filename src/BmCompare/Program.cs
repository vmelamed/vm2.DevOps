Option<Matcher> baseline = new(name: "--baseline-reports", "-b")
{
    Description =
    """
    Path to baseline JSON report(s) to compare the current reports against. You
    can specify a single file or use a wildcard pattern (glob) as a value for
    this parameter, e.g. `downloads/baseline/**/*-report.json`.
    """,
    Required = true,
    Arity = ArgumentArity.ExactlyOne,
    CustomParser = MatcherParser,
};

Option<Matcher> current = new(name: "--current-reports", "-c")
{
    Description =
    """
    Path to the current JSON report(s) to compare against the baseline reports.
    You can specify a single file or use a wildcard pattern for this parameter,
    e.g. `myApp/*Artifacts/*-report.json`
    """,
    Required = true,
    Arity = ArgumentArity.ExactlyOne,
    CustomParser = MatcherParser,
};

Option<string> jsonResult = new(name: "--json-result", "-j")
{
    Description = "Path to the comparison result JSON file. If not specified, the comparison file will be created in the directory " +
                  "of the first current report with the name 'comparison-result.json'.",
    Required = false,
    Arity = ArgumentArity.ZeroOrOne,
    DefaultValueFactory = _ => string.Empty
};

Option<int> maxSlowdown = new(name: "--max-slowdown", "-s")
{
    Description = "Maximum allowed performance slowdown of the mean execution time (in percentage) before the comparison fails.",
    Required = false,
    Arity = ArgumentArity.ExactlyOne,
    DefaultValueFactory = _ => 10
};

Option<int> maxMemoryIncrease = new(name: "--max-memory-increase", "-m")
{
    Description = "Maximum memory increase of the mean allocated memory (in percentage) before the comparison fails.",
    Required = false,
    Arity = ArgumentArity.ExactlyOne,
    DefaultValueFactory = _ => 10
};

#pragma warning disable IDE0028 // Simplify collection initialization
RootCommand rootCommand = new("A tool to compare the current BenchmarkDotNet JSON reports to some baseline reports. The "+
                              "comparison result will be written to a JSON file and displayed on the console in a markdown format.")
{
    baseline,
    current,
    maxSlowdown,
    maxMemoryIncrease
};
#pragma warning restore IDE0028 // Simplify collection initialization

rootCommand.SetAction(Handler);

var parseResult = rootCommand.Parse(args);

if (parseResult.Errors.Count > 0)
{
    Console.WriteLine("Error parsing command line arguments:");
    foreach (var error in parseResult.Errors)
        Console.WriteLine($"  {error.Message}");
    return 1;
}

return parseResult.Invoke();

Matcher? MatcherParser(ArgumentResult result)
{
    var matcher = new Matcher(OperatingSystem.Comparison);

    var pattern = result.Tokens[0].Value.Replace('\\', '/');
    matcher.AddInclude(pattern);

    var files = matcher.Execute(new DirectoryInfoWrapper(new DirectoryInfo("C:\\")));

    if (files.HasMatches is false)
    {
        result.AddError($"The specified path '{result.Tokens[0].Value}' does not match any files.");
        return null;
    }

    return matcher;
}

int Handler(ParseResult parseResult)
{
    var baselineReport           = parseResult.GetRequiredValue<Matcher>(baseline);
    var currentReport            = parseResult.GetRequiredValue<Matcher>(current);
    var jsonResultValue          = parseResult.GetValue<string>(jsonResult);
    var maxSlowdownValue         = parseResult.GetValue<int>(maxSlowdown);
    var maxMemoryIncreaseValue   = parseResult.GetValue<int>(maxMemoryIncrease);

    return 0;
}
