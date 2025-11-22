namespace vm2.DevOps.Glob.Api.Tests;

[ExcludeFromCodeCoverage]
public partial class GlobEnumeratorIntegrationTests(
    GlobIntegrationTestsFixture fixture,
    ITestOutputHelper output) : IClassFixture<GlobIntegrationTestsFixture>
{
    protected GlobIntegrationTestsFixture Fixture => fixture;
    protected ITestOutputHelper Output => output;

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
        var builder   = (GlobEnumeratorBuilder)data;
        var ge        = Fixture.GetGlobEnumerator(() => builder.FromDirectory(Path.Combine(fixture.TestRootPath, data.Sd)));
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
                        .Select(p => p[(fixture.TestRootPath.Length + 1)..])
                        .ToList()
                        ;

        // Assert
        Output.WriteLine("Expected Results: \"{0}\"", string.Join("\", \"", data.R));
        Output.WriteLine("  Actual Results: \"{0}\"", string.Join("\", \"", result));

        result.Should().BeEquivalentTo(data.R, opt => opt.WithStrictOrdering());
    }
}
