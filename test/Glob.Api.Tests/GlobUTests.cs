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
        string fileSystemFile,
        Func<GlobEnumeratorBuilder>? configureBuilder = null)
    {
        // Get the file system for this test
        var fileSystem = _host
                            .Services
                            .GetRequiredService<IFakeFileSystemCache>()
                            .GetFileSystem(fileSystemFile);
        var enumerator = _host
                            .Services
                            .GetRequiredService<GlobEnumeratorFactory>()
                            .Create(fileSystem)
                            ;

        if (configureBuilder is not null)
            configureBuilder().Configure(enumerator);

        return enumerator;
    }

    protected virtual void Enumerate_GlobEnumerator(UnitTestElement data)
    {
        // Arrange
        var ge = GetGlobEnumerator(data.Fs, () => CreateBuilder(data));
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
