namespace vm2.DevOps.Glob.Api.Tests;

[ExcludeFromCodeCoverage]
public partial class GlobsTests : IClassFixture<GlobTestsFixture>
{
    GlobTestsFixture _fixture;

    public GlobsTests(GlobTestsFixture fixture)
    {
        _fixture = fixture;
    }

    [Fact]
    public void Invalid_Path_In_GlobEnumerator_ShouldThrow()
    {
        var ge = _fixture.GetGlobEnumerator("FakeFSFiles/FakeFS2.Win.json");
        var assignInvalidPath = () => ge.EnumerateFromFolder = "C:/fldr1";

        assignInvalidPath.Should().Throw<ArgumentException>();
    }

    [Fact]
    public void Invalid_EnumerateFromFolder_ShouldThrow()
    {
        var ge = _fixture.GetGlobEnumerator("FakeFSFiles/FakeFS2.Win.json");
        var assignInvalidPath = () => ge.EnumerateFromFolder = "C:/nonexistent";

        assignInvalidPath.Should().Throw<ArgumentException>();
    }

    [Fact]
    public void Invalid_MatchCasing_ShouldThrow()
    {
        var ge = _fixture.GetGlobEnumerator("FakeFSFiles/FakeFS2.Win.json");
        var assignInvalidPath = () => ge.MatchCasing = (MatchCasing)3;

        assignInvalidPath.Should().Throw<ArgumentException>();
    }

    [Fact]
    public void Invalid_Pattern_ShouldThrow()
    {
        var ge = _fixture.GetGlobEnumerator("FakeFSFiles/FakeFS2.Win.json");
        var enumerate = () => ge.Enumerate("***");

        enumerate.Should().Throw<ArgumentException>();
    }

    [Fact]
    public void Invalid_FilePattern_ShouldThrow()
    {
        var ge = _fixture.GetGlobEnumerator("FakeFSFiles/FakeFS2.Win.json");
        ge.Enumerated = Objects.Files;
        var enumerate = () => ge.Enumerate("*/");

        enumerate.Should().Throw<ArgumentException>();
    }

    [Fact]
    public void RecursiveInTheEnd_FilePattern_ShouldThrow()
    {
        var ge = _fixture.GetGlobEnumerator("FakeFSFiles/FakeFS2.Win.json");
        ge.Enumerated = Objects.Files;
        var enumerate = () => ge.Enumerate("*/**");

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

    [Theory]
    [MemberData(nameof(Enumerate_RecursiveWildcards_TestDataSet))]
    public void Should_Enumerate_RecursiveWildcards_GlobEnumerator(GlobEnumerateTheoryElement data)
    {
        var ge = _fixture.GetGlobEnumerator(data.File);
        ge.Enumerated          = data.Objects;
        ge.EnumerateFromFolder = data.StartDir;
        ge.MatchCasing         = data.MatchCasing;
        // For recursive wildcards tests, we change the meaning of data.Throws to indicate DistinctResults
        // Dirty hack for reusing the same test data, so ashamed... ;)
        ge.DistinctResults     = data.Throws;

        var enumerate = () => ge.Enumerate(data.Glob);

        var result = enumerate.Should().NotThrow().Which.OrderBy(s => s, StringComparer.Ordinal).ToList();

        result.Should().BeEquivalentTo(data.Results);
    }

    void Enumerate_GlobEnumerator(GlobEnumerateTheoryElement data)
    {
        var ge = _fixture.GetGlobEnumerator(data.File);

        ge.Enumerated          = data.Objects;
        ge.EnumerateFromFolder = data.StartDir;
        ge.MatchCasing         = data.MatchCasing;

        var enumerate = () => ge.Enumerate(data.Glob);

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
}
