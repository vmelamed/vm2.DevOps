namespace vm2.DevOps.Glob.Api.Tests;

[ExcludeFromCodeCoverage]
public abstract partial class GlobEnumeratorUnitTests : IClassFixture<GlobUnitTestsFixture>
{
    protected IHost _host;

    public GlobEnumeratorUnitTests(
        GlobUnitTestsFixture fixture,
        ITestOutputHelper output)
    {
        Output  = output;
        Fixture = fixture;

        _host = Fixture.BuildHost(output);
    }

    protected GlobUnitTestsFixture Fixture { get; }

    protected ITestOutputHelper Output { get; }

    protected GlobEnumerator GetGlobEnumerator(
        string fileSystemDescriptionFile)
        => _host.Services.GetGlobEnumerator(fileSystemDescriptionFile);

    protected GlobEnumerator GetGlobEnumerator(
        string fileSystemDescriptionFile,
        Func<GlobEnumeratorBuilder, GlobEnumeratorBuilder> configureBuilder)
        => _host.Services.GetGlobEnumerator(configureBuilder, fileSystemDescriptionFile);

    protected virtual void Enumerate_GlobEnumerator(UnitTestElement data)
    {
        // Arrange
        var ge = GetGlobEnumerator(data.Fs, data.ConfigureBuilder);
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
                        .ToList()
                        ;

        Output.WriteLine("Expected Results: \"{0}\"", string.Join("\", \"", data.R));
        Output.WriteLine("  Actual Results: \"{0}\"", string.Join("\", \"", result));

        // Assert
        result.Should().BeEquivalentTo(data.R);
    }

    protected static GlobEnumeratorBuilder CreateBuilder(
        UnitTestElement data,
        bool distinct = false) => ((GlobEnumeratorBuilder)data).WithDistinct(distinct);
}
