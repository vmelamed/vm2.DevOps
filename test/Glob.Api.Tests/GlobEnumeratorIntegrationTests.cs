namespace vm2.DevOps.Glob.Api.Tests;

[ExcludeFromCodeCoverage]
public partial class GlobEnumeratorIntegrationTests : IClassFixture<IntegrationTestsFixture>
{
    readonly IntegrationTestsFixture _fixture;
    readonly ITestOutputHelper _output;

    public GlobEnumeratorIntegrationTests(IntegrationTestsFixture fixture, ITestOutputHelper output)
    {
        _fixture = fixture;
        _output = output;
    }

    [Theory]
    [MemberData(nameof(RecursiveEnumerationTests))]
    public void Integration_Recursive_Enumeration(IntegrationTestData data)
    {
        // Arrange
        var enumerator = new GlobEnumerator(new FileSystem(), null);
        enumerator.FromDirectory = Path.Combine(_fixture.TestRootPath, data.StartDirectory);
        enumerator.Glob = data.Glob;
        enumerator.Enumerated = data.Objects;
        if (data.MatchCasing.HasValue)
            enumerator.MatchCasing = data.MatchCasing.Value;

        // Act
        var results = enumerator.Enumerate().ToList();

        // Assert
        _output.WriteLine($"Test: {data.Description}");
        _output.WriteLine($"Pattern: {data.Glob} in {data.StartDirectory}");
        _output.WriteLine($"Found {results.Count} items:");
        foreach (var item in results.OrderBy(r => r))
        {
            _output.WriteLine($"  {item}");
        }

        foreach (var expected in data.ExpectedContains)
        {
            results.Should().Contain(r => r.Contains(expected),
                $"results should contain path with '{expected}'");
        }

        if (data.ExpectedCount.HasValue)
        {
            results.Should().HaveCount(data.ExpectedCount.Value);
        }
    }

    [Theory]
    [MemberData(nameof(SpecialCharactersTests))]
    public void Integration_Special_Characters(IntegrationTestData data)
    {
        // Arrange
        var enumerator = new GlobEnumerator(new FileSystem(), null);
        enumerator.FromDirectory = Path.Combine(_fixture.TestRootPath, data.StartDirectory);
        enumerator.Glob = data.Glob;
        enumerator.Enumerated = data.Objects;

        // Act
        var results = enumerator.Enumerate().ToList();

        // Assert
        _output.WriteLine($"Test: {data.Description}");
        _output.WriteLine($"Found {results.Count} items with special characters");

        foreach (var expected in data.ExpectedContains)
        {
            results.Should().Contain(r => r.Contains(expected),
                $"results should contain '{expected}'");
        }
    }

    [Theory]
    [MemberData(nameof(CaseSensitivityTests))]
    public void Integration_Case_Sensitivity(IntegrationTestData data)
    {
        // Skip platform-incompatible tests
        if (data.RequireUnix && OperatingSystem.IsWindows())
        {
            _output.WriteLine($"Skipping Unix-specific test on Windows: {data.Description}");
            return;
        }
        if (data.RequireWindows && !OperatingSystem.IsWindows())
        {
            _output.WriteLine($"Skipping Windows-specific test on Unix: {data.Description}");
            return;
        }

        // Arrange
        var enumerator = new GlobEnumerator(new FileSystem(), null);
        enumerator.FromDirectory = Path.Combine(_fixture.TestRootPath, data.StartDirectory);
        enumerator.Glob = data.Glob;
        enumerator.Enumerated = data.Objects;
        if (data.MatchCasing.HasValue)
            enumerator.MatchCasing = data.MatchCasing.Value;

        // Act
        var results = enumerator.Enumerate().ToList();

        // Assert
        _output.WriteLine($"Test: {data.Description}");
        _output.WriteLine($"Platform: {(OperatingSystem.IsWindows() ? "Windows" : "Unix")}");
        _output.WriteLine($"Case mode: {enumerator.MatchCasing}");
        _output.WriteLine($"Found {results.Count} files");

        if (data.ExpectedCount.HasValue)
        {
            results.Should().HaveCount(data.ExpectedCount.Value, data.Description);
        }

        foreach (var expected in data.ExpectedContains)
        {
            results.Should().Contain(r => r.EndsWith(expected),
                $"results should end with '{expected}'");
        }

        foreach (var notExpected in data.ExpectedNotContains)
        {
            results.Should().NotContain(r => r.EndsWith(notExpected),
                $"results should NOT end with '{notExpected}'");
        }
    }

    [Theory]
    [MemberData(nameof(TraversalOrderTests))]
    public void Integration_Traversal_Order(IntegrationTestData data)
    {
        // Arrange
        var enumerator = new GlobEnumerator(new FileSystem(), null);
        enumerator.FromDirectory = Path.Combine(_fixture.TestRootPath, data.StartDirectory);
        enumerator.Glob = data.Glob;
        enumerator.Enumerated = data.Objects;
        enumerator.DepthFirst = data.DepthFirst;

        // Act
        var results = enumerator.Enumerate().ToList();

        // Assert
        _output.WriteLine($"Test: {data.Description}");
        _output.WriteLine($"Order: {(data.DepthFirst ? "Depth-First" : "Breadth-First")}");
        _output.WriteLine($"Results ({results.Count} items):");
        for (int i = 0; i < results.Count; i++)
        {
            _output.WriteLine($"  [{i}] {results[i]}");
        }

        // Verify ordering expectations
        if (data.OrderVerifications != null)
        {
            foreach (var (before, after) in data.OrderVerifications)
            {
                var beforeIdx = results.FindIndex(r => r.EndsWith(before));
                var afterIdx = results.FindIndex(r => r.EndsWith(after));

                beforeIdx.Should().BeGreaterThanOrEqualTo(0, $"'{before}' should be found");
                afterIdx.Should().BeGreaterThanOrEqualTo(0, $"'{after}' should be found");
                beforeIdx.Should().BeLessThan(afterIdx,
                    $"'{before}' should appear before '{after}'");
            }
        }
    }

    // TheoryData definitions
    public static TheoryData<IntegrationTestData> RecursiveEnumerationTests =>
    [
        new IntegrationTestData
        {
            Description = "Find all .txt files recursively",
            StartDirectory = "",
            Glob = "**/*.txt",
            Objects = Objects.Files,
            ExpectedContains = ["root.txt", "one.txt", "two.txt", "three.txt",
                                "leaf1.txt", "leaf2.txt", "leaf3.txt"]
        },
        new IntegrationTestData
        {
            Description = "Find all directories matching branch*",
            StartDirectory = "",
            Glob = "**/branch*",
            Objects = Objects.Directories,
            ExpectedContains = ["branch1", "branch2"]
        },
        new IntegrationTestData
        {
            Description = "Find hidden dot files",
            StartDirectory = "hidden",
            Glob = ".*",
            Objects = Objects.Files,
            ExpectedContains = [".bashrc", ".profile", ".hidden"]
        }
    ];

    public static TheoryData<IntegrationTestData> SpecialCharactersTests =>
    [
        new IntegrationTestData
        {
            Description = "Files with spaces in names",
            StartDirectory = "special-chars",
            Glob = "**/file with spaces.txt",
            Objects = Objects.Files,
            ExpectedCount = 1,
            ExpectedContains = ["file with spaces.txt"]
        },
        new IntegrationTestData
        {
            Description = "Files with Unicode names",
            StartDirectory = Path.Combine("special-chars", "unicode"),
            Glob = "*.txt",
            Objects = Objects.Files,
            ExpectedContains = ["naïve.txt", "файл.txt"]
        },
        new IntegrationTestData
        {
            Description = "Files with parentheses",
            StartDirectory = Path.Combine("special-chars", "parentheses"),
            Glob = "*(*)*",
            Objects = Objects.Files,
            ExpectedContains = ["file(1).txt", "data(copy).dat"]
        }
    ];

    public static TheoryData<IntegrationTestData> CaseSensitivityTests =>
    [
        new IntegrationTestData
        {
            Description = "Unix: Case-sensitive exact match - lowercase",
            RequireUnix = true,
            StartDirectory = "case-test",
            Glob = "file.txt",
            Objects = Objects.Files,
            MatchCasing = MatchCasing.CaseSensitive,
            ExpectedCount = 1,
            ExpectedContains = ["file.txt"],
            ExpectedNotContains = ["FILE.TXT"]
        },
        new IntegrationTestData
        {
            Description = "Windows: Case-insensitive default",
            RequireWindows = true,
            StartDirectory = "case-test",
            Glob = "FILE.TXT",
            Objects = Objects.Files,
            MatchCasing = MatchCasing.PlatformDefault,
            ExpectedCount = 1,
            ExpectedContains = ["file.txt"]
        }
    ];

    public static TheoryData<IntegrationTestData> TraversalOrderTests =>
    [
        new IntegrationTestData
        {
            Description = "Depth-first traversal order",
            StartDirectory = "recursive",
            Glob = "**/*.txt",
            Objects = Objects.Files,
            DepthFirst = true,
            OrderVerifications = [("leaf1.txt", "leaf2.txt")]
        },
        new IntegrationTestData
        {
            Description = "Breadth-first traversal order",
            StartDirectory = "recursive",
            Glob = "**/*.txt",
            Objects = Objects.Files,
            DepthFirst = false,
            OrderVerifications = [("root.txt", "one.txt"), ("one.txt", "two.txt")]
        }
    ];
}

/// <summary>
/// Data structure for integration test parameters.
/// </summary>
public record IntegrationTestData
{
    public required string Description { get; init; }
    public required string StartDirectory { get; init; }
    public required string Glob { get; init; }
    public required Objects Objects { get; init; }
    public MatchCasing? MatchCasing { get; init; }
    public bool DepthFirst { get; init; }
    public string[] ExpectedContains { get; init; } = [];
    public string[] ExpectedNotContains { get; init; } = [];
    public int? ExpectedCount { get; init; }
    public bool RequireUnix { get; init; }
    public bool RequireWindows { get; init; }
    public List<(string before, string after)>? OrderVerifications { get; init; }
}

/// <summary>
/// Fixture for integration tests - creates test directory structure once.
/// </summary>
public class IntegrationTestsFixture : IDisposable
{
    public string TestRootPath { get; }

    public IntegrationTestsFixture()
    {
        TestRootPath = Path.Combine(Path.GetTempPath(), "test-glob-integration", Guid.NewGuid().ToString("N"));
        CreateTestStructure();
    }

    void CreateTestStructure()
    {
        // Case sensitivity structure
        var caseTestDir = Path.Combine(TestRootPath, "case-test");
        Directory.CreateDirectory(caseTestDir);
        File.WriteAllText(Path.Combine(caseTestDir, "file.txt"), "content");
        File.WriteAllText(Path.Combine(caseTestDir, "readme.md"), "content");

        if (!OperatingSystem.IsWindows())
        {
            File.WriteAllText(Path.Combine(caseTestDir, "FILE.TXT"), "CONTENT");
            File.WriteAllText(Path.Combine(caseTestDir, "README.MD"), "CONTENT");
        }

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
        var specialDir = Path.Combine(TestRootPath, "special-chars");
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

    public void Dispose()
    {
        if (Directory.Exists(TestRootPath))
        {
            try
            {
                Directory.Delete(TestRootPath, recursive: true);
            }
            catch
            {
                // Best effort cleanup
            }
        }
    }
}