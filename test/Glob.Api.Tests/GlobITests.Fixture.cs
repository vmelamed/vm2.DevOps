namespace vm2.DevOps.Glob.Api.Tests;

public sealed class GlobIntegrationTestsFixture : GlobUnitTestsFixture
{
    public string TestRootPath { get; set; } = @"C:\Users\valme\AppData\Local\Temp\test-glob-integration\1471d983f7e34de6a05a4a3446c9fe52";
    bool ownTestRootPath;

    public GlobIntegrationTestsFixture() : base()
    {
        if (TestRootPath is "" || !Directory.Exists(TestRootPath))
        {
            TestRootPath = Path.Combine(Path.GetTempPath(), "test-glob-integration", Guid.NewGuid().ToString("N"));
            CreateTestStructure();
            ownTestRootPath = true;
        }
    }

    public override void Dispose()
    {
        base.Dispose();
        if (ownTestRootPath && Directory.Exists(TestRootPath))
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

    void CreateTestStructure()
    {
        // Case sensitivity structure
        var caseTestDir = Path.Combine(TestRootPath, "case-test");
        Directory.CreateDirectory(caseTestDir);
        File.WriteAllText(Path.Combine(caseTestDir, "file.txt"), "content");
        File.WriteAllText(Path.Combine(caseTestDir, "readme.md"), "content");
        File.WriteAllText(Path.Combine(caseTestDir, "_FILE.TXT"), "CONTENT");
        File.WriteAllText(Path.Combine(caseTestDir, "_README.MD"), "CONTENT");

        // Recursive structure
        var recursiveDir = Path.Combine(TestRootPath, "recursive");
        var level3 = Path.Combine(recursiveDir, "level1", "level2", "level3");
        Directory.CreateDirectory(level3);
        File.WriteAllText(Path.Combine(recursiveDir, "root.txt"), "root");
        File.WriteAllText(Path.Combine(recursiveDir, "level1", "one.txt"), "one");
        File.WriteAllText(Path.Combine(recursiveDir, "level1", "level2", "two.txt"), "two");
        File.WriteAllText(Path.Combine(level3, "three.txt"), "three");

        // Branch structure
        var branch1Sub1 = Path.Combine(recursiveDir, "branch1", "subbranch1");
        var branch1Sub2 = Path.Combine(recursiveDir, "branch1", "subbranch2");
        var branch2Sub3 = Path.Combine(recursiveDir, "branch2", "subbranch3");
        Directory.CreateDirectory(branch1Sub1);
        Directory.CreateDirectory(branch1Sub2);
        Directory.CreateDirectory(branch2Sub3);
        File.WriteAllText(Path.Combine(recursiveDir, "branch1", "branch.log"), "log");
        File.WriteAllText(Path.Combine(branch1Sub1, "leaf1.txt"), "leaf1");
        File.WriteAllText(Path.Combine(branch1Sub2, "leaf2.txt"), "leaf2");
        File.WriteAllText(Path.Combine(recursiveDir, "branch2", "branch2.log"), "log");
        File.WriteAllText(Path.Combine(branch2Sub3, "leaf3.txt"), "leaf3");

        // Special characters
        var specialDir = Path.Combine(TestRootPath, "spec-chars");
        var spacesDir = Path.Combine(specialDir, "spaces in names");
        Directory.CreateDirectory(spacesDir);
        File.WriteAllText(Path.Combine(spacesDir, "file with spaces.txt"), "content");
        File.WriteAllText(Path.Combine(spacesDir, "another file.dat"), "content");

        var symbolsDir = Path.Combine(specialDir, "symbols");
        Directory.CreateDirectory(symbolsDir);
        File.WriteAllText(Path.Combine(symbolsDir, "file@home.txt"), "content");
        File.WriteAllText(Path.Combine(symbolsDir, "report_2024.pdf"), "content");

        var parenDir = Path.Combine(specialDir, "parentheses");
        Directory.CreateDirectory(parenDir);
        File.WriteAllText(Path.Combine(parenDir, "file(1).txt"), "content");
        File.WriteAllText(Path.Combine(parenDir, "data(copy).dat"), "content");

        var unicodeDir = Path.Combine(specialDir, "unicode");
        Directory.CreateDirectory(unicodeDir);
        File.WriteAllText(Path.Combine(unicodeDir, "café.md"), "content");
        File.WriteAllText(Path.Combine(unicodeDir, "naïve.txt"), "content");
        File.WriteAllText(Path.Combine(unicodeDir, "файл.txt"), "content");

        // Hidden files
        var hiddenDir = Path.Combine(TestRootPath, "hidden");
        Directory.CreateDirectory(hiddenDir);
        File.WriteAllText(Path.Combine(hiddenDir, ".bashrc"), "content");
        File.WriteAllText(Path.Combine(hiddenDir, ".profile"), "content");
        File.WriteAllText(Path.Combine(hiddenDir, ".hidden"), "content");
        File.WriteAllText(Path.Combine(hiddenDir, "visible.txt"), "content");
    }
}
