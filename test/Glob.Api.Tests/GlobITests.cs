// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Val Melamed

namespace vm2.DevOps.Glob.Api.Tests;

[ExcludeFromCodeCoverage]
public partial class GlobEnumeratorIntegrationTests : IClassFixture<GlobIntegrationTestsFixture>, IDisposable
{
    public const string TestStructureJsonFile = "./FSFiles/Integration.json";

    IHost _host;
    bool _tempTestRootPath;

    public GlobEnumeratorIntegrationTests(
        GlobIntegrationTestsFixture fixture,
        ITestOutputHelper output)
    {
        Output  = output;
        Fixture = fixture;

        _host = Fixture.BuildHost(output);

        var configuration = _host.Services.GetRequiredService<IConfiguration>();
        TestRootPath = configuration["GlobIntegrationTests:TestRootPath"] ?? "";

        if (string.IsNullOrWhiteSpace(TestRootPath))
        {
            TestRootPath = Path.Combine(Path.GetTempPath(), "glob-integration-test", Guid.NewGuid().ToString("N"));
            _tempTestRootPath = true;
        }
        else
            TestRootPath = Path.GetFullPath(TestFileStructure.ExpandEnvironmentVariables(TestRootPath));

        Debug.Assert(!string.IsNullOrWhiteSpace(TestRootPath));
        if (!OperatingSystem.PathRegex().IsMatch(TestRootPath))
            throw new ConfigurationErrorsException($"The configured test root path '{TestRootPath}' is not valid a valid path for the current operating system.");

        if (Directory.Exists(TestRootPath))
        {
            var message = string.Join(",\n", TestFileStructure.VerifyTestFileStructure(TestStructureJsonFile, TestRootPath));

            if (!string.IsNullOrWhiteSpace(message))
                throw new InvalidOperationException($"The expected test file structure at '{TestRootPath}' does not match the JSON specification {TestStructureJsonFile}:\n{message}\n");
        }
        else
            TestFileStructure.CreateTestFileStructure(TestStructureJsonFile, TestRootPath);
    }

    public void Dispose()
    {
        _host.Dispose();
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

    GlobIntegrationTestsFixture Fixture { get; }

    ITestOutputHelper Output { get; }

    string TestRootPath { get; }

    protected GlobEnumerator GetGlobEnumerator()
        => _host.Services.GetRequiredService<GlobEnumerator>();

    protected GlobEnumerator GetGlobEnumerator(
        Func<GlobEnumeratorBuilder, GlobEnumeratorBuilder> configureBuilder)
        => _host.Services.GetGlobEnumerator(configureBuilder);

    [Theory]
    [MemberData(nameof(RecursiveEnumerationTests))]
    public void Enumerate_GlobEnumerator(IntegrationTestData data)
    {
        // Skip platform-incompatible tests
        if (OperatingSystem.IsWindows() ? data.Unix : data.Win)
        {
            Output.WriteLine($"Skipping OS-specific test: {data.D}");
            return;
        }

        // Arrange
        var ge = GetGlobEnumerator(builder => data
                                                .ConfigureBuilder(builder)
                                                .FromDirectory(Path.Combine(TestRootPath, data.Sd))
                                                .Build());
        var enumerate = ge.Enumerate;

        if (data.Tx)
        {
            // Act & Assert
            enumerate.Enumerating().Should().Throw<ArgumentException>();
            return;
        }

        // Act
        var result = enumerate
                        .Should()
                        .NotThrow()
                        .Which
                        .Select(p => p[(TestRootPath.Length + 1)..])
                        .ToList()
                        ;

        // Assert
        Output.WriteLine("Expected Results: \"{0}\"", string.Join("\", \"", data.R));
        Output.WriteLine("  Actual Results: \"{0}\"", string.Join("\", \"", result));

        result.Should().BeEquivalentTo(data.R, opt => opt.WithoutStrictOrdering());
    }
}
