namespace vm2.DevOps.Glob.Api.Tests;

[ExcludeFromCodeCoverage]
public sealed class GlobIntegrationTestsFixture : GlobUnitTestsFixture
{
    public const string TestStructureJson = "./FakeFSFiles/Integration.json";

    public override void Dispose() => base.Dispose();

    public static void CreateTestFileStructure(string testRootPath)
    {
        var fs = new FakeFS(TestStructureJson, DataType.Json);
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

    public static IEnumerable<string> VerifyTestFileStructure(string testRootPath)
    {
        var fs = new FakeFS(TestStructureJson, DataType.Json);
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

    public static string ExpandEnvironmentVariables(string pattern)
    {
        if (OperatingSystem.IsLinux() || OperatingSystem.IsMacOS() || OperatingSystem.IsFreeBSD())
        {
            pattern = pattern.Replace(UnixShellSpecificHome, UnixHomeEnvironmentVar);   // Support Unix shell home directory syntax: shell ~ -> Unix shell env.var. $HOME -> .NET env.var. %HOME%
            UnixEnvVarRegex().Replace(pattern, UnixEnvVarReplacement);                  // Support Unix shell env.var. syntax $ENV_VAR -> .NET env.var. %ENV_VAR%
        }

        return Environment.ExpandEnvironmentVariables(pattern);                                             // Ensure environment variables are supported
    }
}
