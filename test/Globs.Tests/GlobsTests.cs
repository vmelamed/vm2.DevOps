namespace vm2.DevOps.Glob.Api.Tests;

[ExcludeFromCodeCoverage]
public partial class GlobsTests
{
    [Fact]
    public void Invalid_Path_In_GlobEnumerator_ShouldThrow()
    {
        var ge = new GlobEnumerator(new FakeFS("FakeFSFiles/FakeFS2.Win.json", DataFileType.Json));
        var assignInvalidPath = () => ge.EnumerateFromFolder = "C:/fldr1";

        assignInvalidPath.Should().Throw<ArgumentException>();
    }

    [Theory]
    [MemberData(nameof(Enumerate_TestDataSet))]
    [MemberData(nameof(GlobEnumerate_Unix_Exhaustive_TestDataSet))]
    public void Should_Enumerate_GlobEnumerator(GlobEnumerate_TestData data)
    {
        var ge = new GlobEnumerator(new FakeFS(data.JsonFile, DataFileType.Json)) {
            Enumerated          = data.Enumerated,
            EnumerateFromFolder = data.Path,
            DebugOutput         = true,
        };

        var enumerate = () => ge.Enumerate(data.Pattern);

        if (data.Throws)
        {
            enumerate.Should().Throw<ArgumentException>();
        }
        else
        {
            var result = enumerate.Should().NotThrow().Which.OrderBy(s => s, StringComparer.Ordinal).ToList();

            result.Should().BeEquivalentTo(data.Results);
        }
    }
}
