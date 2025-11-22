namespace vm2.DevOps.Glob.Api.Tests;

public sealed class GlobIntegrationTestsFixture : GlobUnitTestsFixture
{
    public const string TestStructureJson = "./FakeFSFiles/Integration.json";

    string _testRootPath;
    bool _tempTestRootPath;

    public GlobIntegrationTestsFixture() : base()
    {
        var configuration = TestHost.Services.GetRequiredService<IConfiguration>();
        _testRootPath = configuration["GlobIntegrationTests:_testRootPath"] ?? "";

        if (string.IsNullOrWhiteSpace(_testRootPath))
        {
            _testRootPath = Path.Combine(Path.GetTempPath(), "glob-integration-test", Guid.NewGuid().ToString("N"));
            _tempTestRootPath = true;
        }
        else
        {
            _testRootPath = ExpandEnvironmentVariables(_testRootPath);
            _testRootPath = Path.GetFullPath(_testRootPath);
        }

        Debug.Assert(!string.IsNullOrWhiteSpace(_testRootPath));
        if (!OperatingSystem.PathRegex().IsMatch(_testRootPath))
            throw new ConfigurationErrorsException($"The configured test root path '{_testRootPath}' is not valid a valid path for the current operating system.");

        if (Directory.Exists(_testRootPath))
        {
            var message = string.Join(",\n", VerifyTestStructure(_testRootPath));

            if (!string.IsNullOrWhiteSpace(message))
                throw new InvalidOperationException($"The expected test file structure at '{_testRootPath}' does not match the JSON specification {TestStructureJson}:\n{message}\n");
        }
        else
            CreateTestStructure(_testRootPath);
    }

    public override void Dispose()
    {
        base.Dispose();
        if (_tempTestRootPath && Directory.Exists(_testRootPath))
        {
            try
            {
                Directory.Delete(_testRootPath, recursive: true);
            }
            catch
            {
                // quietly swallow it - not much we can do about it
            }
        }
    }

    void CreateTestStructure(string testRootPath)
    {
        var fs = new FakeFS(TestStructureJson, DataType.Json);
        var folderStack = new Stack<Folder>([fs.RootFolder]);

        while (folderStack.TryPop(out var folder))
        {
            var dirPath = Path.Combine(testRootPath, folder.Name);
            if (!Directory.Exists(dirPath))
                Directory.CreateDirectory(dirPath);

            foreach (var subFolder in folder.Folders)
                folderStack.Push(subFolder);

            foreach (var file in folder.Files)
            {
                var filePath = Path.Combine(dirPath, file);
                if (!File.Exists(filePath))
                    File.WriteAllText(filePath, file);
            }
        }
    }

    IEnumerable<string> VerifyTestStructure(string testRootPath)
    {
        var fs = new FakeFS(TestStructureJson, DataType.Json);
        var folderStack = new Stack<Folder>([fs.RootFolder]);

        while (folderStack.TryPop(out var folder))
        {
            var dirPath = Path.Combine(testRootPath, folder.Name);
            if (!Directory.Exists(dirPath))
                yield return $"The directory {dirPath} does not exist.";

            foreach (var subFolder in folder.Folders)
                folderStack.Push(subFolder);

            foreach (var file in folder.Files)
            {
                var filePath = Path.Combine(dirPath, file);
                if (!File.Exists(filePath))
                    yield return $"The directory {dirPath} does not exist.";
            }
        }
    }

    string ExpandEnvironmentVariables(string pattern)
    {
        if (OperatingSystem.IsLinux() || OperatingSystem.IsMacOS() || OperatingSystem.IsFreeBSD())
        {
            pattern = pattern.Replace(UnixShellSpecificHome, UnixHomeEnvironmentVar);   // Support Unix shell home directory syntax: shell ~ -> Unix shell env.var. $HOME -> .NET env.var. %HOME%
            UnixEnvVarRegex().Replace(pattern, UnixEnvVarReplacement);                  // Support Unix shell env.var. syntax $ENV_VAR -> .NET env.var. %ENV_VAR%
        }

        return Environment.ExpandEnvironmentVariables(pattern);                                             // Ensure environment variables are supported
    }
}
