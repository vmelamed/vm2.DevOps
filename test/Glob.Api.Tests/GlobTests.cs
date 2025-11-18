namespace vm2.DevOps.Glob.Api.Tests;

[ExcludeFromCodeCoverage]
public partial class GlobTests(GlobTestsFixture fixture, ITestOutputHelper output) : IClassFixture<GlobTestsFixture>
{
    [Fact]
    public void Invalid_Path_In_GlobEnumerator_ShouldThrow()
    {
        var ge = fixture.GetGlobEnumerator("FakeFSFiles/FakeFS2.Win.json");
        var assignInvalidPath = () => ge.FromDirectory = "C:/fldr1";

        assignInvalidPath.Should().Throw<ArgumentException>();
    }

    [Fact]
    public void Invalid_EnumerateFromFolder_ShouldThrow()
    {
        var ge = fixture.GetGlobEnumerator("FakeFSFiles/FakeFS2.Win.json");
        var assignInvalidPath = () => ge.FromDirectory = "C:/nonexistent";

        assignInvalidPath.Should().Throw<ArgumentException>();
    }

    [Fact]
    public void Invalid_MatchCasing_ShouldThrow()
    {
        var ge = fixture.GetGlobEnumerator("FakeFSFiles/FakeFS2.Win.json");
        var assignInvalidPath = () => ge.MatchCasing = (MatchCasing)3;

        assignInvalidPath.Should().Throw<ArgumentException>();
    }

    [Fact]
    public void MoreThan2Asterisks_Pattern_ShouldNotThrow()
    {
        var ge = fixture.GetGlobEnumerator("FakeFSFiles/FakeFS2.Win.json");

        ge.Glob = "***";
        var enumerate = () => ge.Enumerate();

        enumerate.Should().NotThrow();
    }

    [Fact]
    public void Invalid_FilePattern_ShouldThrow()
    {
        var ge = fixture.GetGlobEnumerator("FakeFSFiles/FakeFS2.Win.json");

        ge.Enumerated = Objects.Files;
        ge.Glob       = "*/";
        var enumerate = () => ge.Enumerate();

        enumerate.Should().Throw<ArgumentException>();
    }

    [Fact]
    public void RecursiveInTheEnd_FilePattern_ShouldThrow()
    {
        var ge = fixture.GetGlobEnumerator("FakeFSFiles/FakeFS2.Win.json");

        ge.Glob = "*/**";
        ge.Enumerated = Objects.Files;
        var enumerate = () => ge.Enumerate();

        enumerate.Should().Throw<ArgumentException>();
    }

    [Theory]
    [MemberData(nameof(Enumerate_TestDataSet))]
    public void Should_Enumerate_TestDataSet_GlobEnumerator(GlobEnumerateTheoryElement data) => Enumerate_GlobEnumerator(data);

    [Theory]
    [MemberData(nameof(Enumerate_Unix_TestDataLargeSet))]
    public void Should_Enumerate_UnixLargeSet_GlobEnumerator(GlobEnumerateTheoryElement data) => Enumerate_GlobEnumerator(data);

    [Theory]
    [MemberData(nameof(Enumerate_Win_TestDataLargeSet))]
    public void Should_Enumerate_WinLargeSet_GlobEnumerator(GlobEnumerateTheoryElement data) => Enumerate_GlobEnumerator(data);

    [Theory]
    [MemberData(nameof(Enumerate_CaseSensitivity_TestDataSet))]
    public void Should_Enumerate_CaseSensitivity_GlobEnumerator(GlobEnumerateTheoryElement data) => Enumerate_GlobEnumerator(data);

    [Theory]
    [MemberData(nameof(Enumerate_RelativePaths_TestDataSet))]
    public void Should_Enumerate_RelativePaths_GlobEnumerator(GlobEnumerateTheoryElement data) => Enumerate_GlobEnumerator(data);

    [Theory]
    [MemberData(nameof(Enumerate_SpecialCharacters_TestDataSet))]
    public void Should_Enumerate_SpecialCharacters_GlobEnumerator(GlobEnumerateTheoryElement data) => Enumerate_GlobEnumerator(data);

    GlobEnumeratorBuilder Configure(
        GlobEnumeratorBuilder builder,
        GlobEnumerateTheoryElement data)
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
            case Objects.FilesAndDirefctories:
                builder.SelectDirectoriesAndFiles();
                break;
            default:
                throw new ArgumentException("Invalid Objects value.");
        }
        return builder;
    }

    [Theory]
    [MemberData(nameof(Enumerate_RecursiveWildcards_TestDataSet))]
    public void Should_Enumerate_RecursiveWildcards_GlobEnumerator(GlobEnumerateTheoryElement data)
    {
        var ge = fixture.GetGlobEnumerator(
            data.File,
            b =>
            {
                b = data.Throws
                        ? b.Distinct()
                        : b;
                return Configure(b, data);
            });
        // For recursive wildcards tests, we change the meaning of data.Throws to indicate _distinctResults
        // Dirty hack for reusing the same test data, so ashamed... ;)

        var enumerate = ge.Enumerate;
        var result = enumerate.Should().NotThrow().Which.OrderBy(s => s, StringComparer.Ordinal).ToList();

        result.Should().BeEquivalentTo(data.Results);
    }

    void Enumerate_GlobEnumerator(GlobEnumerateTheoryElement data)
    {
        var ge = fixture.GetGlobEnumerator(data.File, b => Configure(b, data));
        var enumerate = ge.Enumerate;

        if (data.Throws)
        {
            enumerate.Enumerating().Should().Throw<ArgumentException>();
        }
        else
        {
            var result = enumerate.Should().NotThrow().Which.OrderBy(s => s, StringComparer.Ordinal).ToList();

            result.Should().BeEquivalentTo(data.Results);
        }
    }

    [Fact]
    public void WithBuilder_Should_Enumerate_DepthFirst_GlobEnumerator()
    {
        GlobEnumerator ge = fixture.GetGlobEnumerator(
                                        "FakeFSFiles/FakeFS7.Unix.json",
                                        builder => builder
                                                    .WithGlob("**/*.txt")
                                                    .FromDirectory("/")
                                                    .CaseSensitive()
                                                    .SelectFiles()
                                                    .DepthFirst()
                                                    .Distinct()
                                        );

        var enumerate = ge.Enumerate;

        var result = enumerate.Should().NotThrow().Which.ToList();

        Console.WriteLine("DepthFirst Results:");
        foreach (var item in result)
            output.WriteLine(item);

        result.Should().BeEquivalentTo(
        [
            "/aaa.txt",
            "/a/aa.txt",
            "/a/b/bb.txt",
            "/a/b/c/cc.txt",
            "/x/xx.txt",
            "/x/y/yy.txt",
            "/x/y/z/zz.txt",
        ]);
    }

    [Fact]
    public void WithBuilder_Should_Enumerate_BreadthFirst_GlobEnumerator()
    {
        GlobEnumerator ge = fixture.GetGlobEnumerator(
                                        "FakeFSFiles/FakeFS7.Unix.json",
                                        builder => builder
                                                    .WithGlob("**/*.txt")
                                                    .FromDirectory("/")
                                                    .CaseInsensitive()
                                                    .SelectFiles()
                                                    .BreadthFirst()
                                                    .Distinct()
                                        );

        var enumerate = ge.Enumerate;

        var result = enumerate.Should().NotThrow().Which.ToList();

        Console.WriteLine("BreadthFirst Results:");
        foreach (var item in result)
            output.WriteLine(item);

        result.Should().BeEquivalentTo(
        [
            "/aaa.txt",
            "/a/aa.txt",
            "/x/xx.txt",
            "/a/b/bb.txt",
            "/x/y/yy.txt",
            "/a/b/c/cc.txt",
            "/x/y/z/zz.txt",
        ]);
    }
}
