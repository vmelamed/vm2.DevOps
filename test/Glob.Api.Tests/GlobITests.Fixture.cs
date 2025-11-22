namespace vm2.DevOps.Glob.Api.Tests;

[ExcludeFromCodeCoverage]
public sealed class GlobIntegrationTestsFixture : GlobUnitTestsFixture
{
    public const string TestStructureJson = "./FakeFSFiles/Integration.json";

    public string TestRootPath { get; private set; }
    bool _tempTestRootPath;

    public GlobIntegrationTestsFixture() : base()
    {
        var configuration = TestHost.Services.GetRequiredService<IConfiguration>();
        TestRootPath = configuration["GlobIntegrationTests:TestRootPath"] ?? "";

        if (string.IsNullOrWhiteSpace(TestRootPath))
        {
            TestRootPath = Path.Combine(Path.GetTempPath(), "glob-integration-test", Guid.NewGuid().ToString("N"));
            _tempTestRootPath = true;
        }
        else
            TestRootPath = Path.GetFullPath(ExpandEnvironmentVariables(TestRootPath));

        Debug.Assert(!string.IsNullOrWhiteSpace(TestRootPath));
        if (!OperatingSystem.PathRegex().IsMatch(TestRootPath))
            throw new ConfigurationErrorsException($"The configured test root path '{TestRootPath}' is not valid a valid path for the current operating system.");

        if (Directory.Exists(TestRootPath))
        {
            var message = string.Join(",\n", VerifyTestStructure(TestRootPath));

            if (!string.IsNullOrWhiteSpace(message))
                throw new InvalidOperationException($"The expected test file structure at '{TestRootPath}' does not match the JSON specification {TestStructureJson}:\n{message}\n");
        }
        else
            CreateTestStructure(TestRootPath);
    }

    public override void Dispose()
    {
        base.Dispose();
        if (_tempTestRootPath && Directory.Exists(TestRootPath))
        {
            try
            {
                Directory.Delete(TestRootPath, recursive: true);
            }
            catch
            {
                // quietly swallow it - not much we can do about it
            }
        }
    }

    static void CreateTestStructure(string testRootPath)
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

    static IEnumerable<string> VerifyTestStructure(string testRootPath)
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

    static string ExpandEnvironmentVariables(string pattern)
    {
        if (OperatingSystem.IsLinux() || OperatingSystem.IsMacOS() || OperatingSystem.IsFreeBSD())
        {
            pattern = pattern.Replace(UnixShellSpecificHome, UnixHomeEnvironmentVar);   // Support Unix shell home directory syntax: shell ~ -> Unix shell env.var. $HOME -> .NET env.var. %HOME%
            UnixEnvVarRegex().Replace(pattern, UnixEnvVarReplacement);                  // Support Unix shell env.var. syntax $ENV_VAR -> .NET env.var. %ENV_VAR%
        }

        return Environment.ExpandEnvironmentVariables(pattern);                                             // Ensure environment variables are supported
    }
}
