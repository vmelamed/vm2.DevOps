// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Val Melamed

namespace vm2.TestUtilities;

/// <summary>
/// Provides methods to create and verify test file structures based on JSON specifications. Also includes utility method for
/// expanding environment variables in file paths.
/// </summary>
public static class TestFileStructure
{
    static void ValidateFiles(string jsonSpecFile, string testRootPath)
    {
        if (string.IsNullOrWhiteSpace(jsonSpecFile))
            throw new ArgumentException("The JSON specification file cannot be null, empty, or consist only of whitespaces.", nameof(jsonSpecFile));
        if (string.IsNullOrWhiteSpace(testRootPath))
            throw new ArgumentException("The test root path cannot be null, empty, or consist only of whitespaces.", nameof(testRootPath));
        if (!File.Exists(jsonSpecFile))
            throw new FileNotFoundException("The JSON specification file was not found.", jsonSpecFile);
    }

    /// <summary>
    /// Creates a  test file structures based on JSON specifications.
    /// </summary>
    /// <param name="jsonSpecFile">The JSON specification file.</param>
    /// <param name="testRootPath">The root path for the test files.</param>
    public static void CreateTestFileStructure(string jsonSpecFile, string testRootPath)
    {
        ValidateFiles(jsonSpecFile, testRootPath);

        var fs = new FakeFS(jsonSpecFile, DataType.Json);
        var folderStack = new Stack<Folder>([fs.RootFolder]);
        var rootLength = fs.RootFolder.Name.Length;

        while (folderStack.TryPop(out var folder))
        {
            var dirPath = Path.Combine(testRootPath, folder.Path[rootLength..]);
            if (!Directory.Exists(dirPath))
                Directory.CreateDirectory(dirPath);

            foreach (var subFolder in folder.Folders)
                folderStack.Push(subFolder);

            foreach (var file in folder.Files)
            {
                var filePath = Path.Combine(testRootPath, folder.Path[rootLength..], file);
                if (!File.Exists(filePath))
                    File.WriteAllText(filePath, file);
            }
        }
    }

    /// <summary>
    /// Verifies that the file structure at <paramref name="testRootPath"/> matches the JSON file structures specified in
    /// <paramref name="jsonSpecFile"/>.
    /// </summary>
    /// <param name="jsonSpecFile">The JSON specification file.</param>
    /// <param name="testRootPath">The root path for the test files.</param>
    /// <returns>A list of error messages, if any.</returns>
    public static IEnumerable<string> VerifyTestFileStructure(string jsonSpecFile, string testRootPath)
    {
        ValidateFiles(jsonSpecFile, testRootPath);

        var fs = new FakeFS(jsonSpecFile, DataType.Json);
        var folderStack = new Stack<Folder>([fs.RootFolder]);
        var rootLength = fs.RootFolder.Name.Length;

        while (folderStack.TryPop(out var folder))
        {
            var dirPath = Path.Combine(testRootPath, folder.Path[1..]);
            if (!Directory.Exists(dirPath))
                yield return $"The directory {dirPath} does not exist.";

            foreach (var subFolder in folder.Folders)
                folderStack.Push(subFolder);

            foreach (var file in folder.Files)
            {
                var filePath = Path.Combine(testRootPath, folder.Path[rootLength..], file);
                if (!File.Exists(filePath))
                    yield return $"The directory {dirPath} does not exist.";
            }
        }
    }

    /// <summary>
    /// Expands environment variables in the given path string.
    /// </summary>
    /// <param name="path">The path string to expand.</param>
    /// <returns>The expanded path string.</returns>
    public static string ExpandEnvironmentVariables(string path)
    {
        if (OperatingSystem.IsLinux() || OperatingSystem.IsMacOS() || OperatingSystem.IsFreeBSD())
        {
            path = path.Replace(UnixShellSpecificHome, UnixHomeEnvironmentVar);   // Support Unix shell home directory syntax: shell ~ -> Unix shell env.var. $HOME -> .NET env.var. %HOME%
            UnixEnvVarRegex().Replace(path, UnixEnvVarReplacement);                  // Support Unix shell env.var. syntax $ENV_VAR -> .NET env.var. %ENV_VAR%
        }

        return Environment.ExpandEnvironmentVariables(path);                                             // Ensure environment variables are supported
    }
}
