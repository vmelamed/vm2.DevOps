namespace vm2.DevOps.Glob.Api.Tests;

[ExcludeFromCodeCoverage]
public abstract partial class GlobEnumeratorTests(GlobTestsFixture fixture, ITestOutputHelper output) : IClassFixture<GlobTestsFixture>
{
    protected GlobTestsFixture Fixture => fixture;
    protected ITestOutputHelper Output => output;

    protected virtual void Enumerate_GlobEnumerator(GlobEnumerateTheoryElement data)
    {
        var ge = fixture.GetGlobEnumerator(data.File, builder => Configure(builder, data));
        var enumerate = ge.Enumerate;

        if (data.Throws)
        {
            enumerate.Enumerating().Should().Throw<ArgumentException>();
        }
        else
        {
            var result = enumerate
                            .Should()
                            .NotThrow()
                            .Which
                            .ToList();

            Output.WriteLine("Results: \"{0}\"", string.Join(", ", result));

            result.Should().BeEquivalentTo(data.Results);
        }
    }

    protected static GlobEnumeratorBuilder Configure(
        GlobEnumeratorBuilder builder,
        GlobEnumerateTheoryElement data,
        bool distinct = false)
    {
        builder
            .WithGlob(data.Glob)
            .FromDirectory(data.StartDir)
            ;

        switch (data.MatchCasing)
        {
            case MatchCasing.CaseSensitive:
                builder.CaseSensitive();
                break;
            case MatchCasing.CaseInsensitive:
                builder.CaseInsensitive();
                break;
            case MatchCasing.PlatformDefault:
                builder.PlatformSensitive();
                break;
            default:
                throw new ArgumentException("Invalid MatchCasing value.");
        }

        switch (data.Objects)
        {
            case Objects.Directories:
                builder.SelectDirectories();
                break;
            case Objects.Files:
                builder.SelectFiles();
                break;
            case Objects.FilesAndDirectories:
                builder.SelectDirectoriesAndFiles();
                break;
            default:
                throw new ArgumentException("Invalid Objects value.");
        }

        if (distinct)
            builder.Distinct();

        return builder;
    }
}
