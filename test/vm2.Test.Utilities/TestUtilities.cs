namespace vm2.Test.Utilities;

[ExcludeFromCodeCoverage]
public static partial class TestUtilities
{
    /// <summary>
    /// Returns a string describing where this method was called from and an optional description.
    /// Convenient utility to use in the second parameter of the methods <see cref="RegexTest(Regex, string, bool, string, Dictionary{string, string}?, bool)"/> or
    /// <see cref="RegexStringTest(string, string, bool, string, RegexOptions, string[])"/>.
    /// </summary>
    /// <param name="testDescription">The test description.</param>
    /// <param name="pathTestFile">Name of the file.</param>
    /// <param name="lineNumber">The line.</param>
    /// <returns>System.String.</returns>
    public static string PathLine(
        string testDescription = "",
        [CallerFilePath] string pathTestFile = "",
        [CallerLineNumber] int lineNumber = 0)
        => $"{pathTestFile}:{lineNumber:d4} : {(testDescription.Length > 0 ? $" : {testDescription}" : "")}";

    [GeneratedRegex(@"[/\\]tests?[/\\]", RegexOptions.Compiled | RegexOptions.IgnoreCase, 500)]
    private static partial Regex TestDir();

    /// <summary>
    /// Returns a string describing where this method was called from and an optional description.
    /// Convenient utility to use in the second parameter of the methods <see cref="RegexTest(Regex, string, bool, string, Dictionary{string, string}?, bool)"/> or
    /// <see cref="RegexStringTest(string, string, bool, string, RegexOptions, string[])"/>.
    /// </summary>
    /// <param name="testDescription">The test description.</param>
    /// <param name="pathTestFile">Name of the file.</param>
    /// <param name="lineNumber">The line.</param>
    /// <returns>System.String.</returns>
    public static string RelativePathLine(
        string testDescription = "",
        [CallerFilePath] string pathTestFile = "",
        [CallerLineNumber] int lineNumber = 0)
    {
        var match = TestDir().Match(pathTestFile);
        var testDirIndex = match.Success ? match!.Index+6 : 0;

        return $"{pathTestFile[testDirIndex..]}:{lineNumber:d4} : {(testDescription.Length > 0 ? $" : {testDescription}" : "")}";
    }

    /// <summary>
    /// Returns a string describing where this method was called from and an optional description.
    /// Convenient utility to use in the second parameter of the methods <see cref="RegexTest(Regex, string, bool, string, Dictionary{string, string}?, bool)"/> or
    /// <see cref="RegexStringTest(string, string, bool, string, RegexOptions, string[])"/>.
    /// </summary>
    /// <param name="testDescription">The test description.</param>
    /// <param name="pathTestFile">Name of the file.</param>
    /// <param name="lineNumber">The line.</param>
    /// <returns>System.String.</returns>
    public static string TestFileLine(
        string testDescription = "",
        [CallerFilePath] string pathTestFile = "",
        [CallerLineNumber] int lineNumber = 0)
        => $"{Path.GetFileName(pathTestFile)}:{lineNumber:d4} : {(testDescription.Length > 0 ? $" : {testDescription}" : "")}";

    /// <summary>
    /// Returns a string describing where this method was called from and an optional description.
    /// Convenient utility to use in the second parameter of the methods <see cref="RegexTest(Regex, string, bool, string, Dictionary{string, string}?, bool)"/> or
    /// <see cref="RegexStringTest(string, string, bool, string, RegexOptions, string[])"/>.
    /// </summary>
    /// <param name="testDescription">The test description.</param>
    /// <param name="pathTestFile">Name of the file.</param>
    /// <param name="lineNumber">The line.</param>
    /// <returns>System.String.</returns>
    public static string TestLine(
        string testDescription = "",
        [CallerLineNumber] int lineNumber = 0)
        => $"{lineNumber:d4} : {(testDescription.Length > 0 ? $" : {testDescription}" : "")}";
}
