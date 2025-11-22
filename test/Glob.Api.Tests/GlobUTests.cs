namespace vm2.DevOps.Glob.Api.Tests;

[ExcludeFromCodeCoverage]
public abstract partial class GlobEnumeratorUnitTests(
    GlobUnitTestsFixture fixture,
    ITestOutputHelper output) : IClassFixture<GlobUnitTestsFixture>
{
    protected GlobUnitTestsFixture Fixture => fixture;
    protected ITestOutputHelper Output => output;

    protected virtual void Enumerate_GlobEnumerator(UnitTestElement data)
    {
        // Arrange
        var ge = fixture.GetGlobEnumerator(data.Fs, () => CreateBuilder(data));
        var enumerate = ge.Enumerate;

        if (data.Throws)
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
                        .ToList();

        Output.WriteLine("Expected Results: \"{0}\"", string.Join("\", \"", data.R));
        Output.WriteLine("  Actual Results: \"{0}\"", string.Join("\", \"", result));

        // Assert
        result.Should().BeEquivalentTo(data.R);
    }

    protected static GlobEnumeratorBuilder CreateBuilder(
        UnitTestElement data,
        bool distinct = false) => ((GlobEnumeratorBuilder)data).WithDistinct(distinct);
}
