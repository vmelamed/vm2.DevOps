namespace vm2.DevOps.Globs.Tests;

public partial class GlobsTests
{
    [Theory]
    [MemberData(nameof(Enumerate_TestDataSet))]
    public void Should_Enumerate_GlobEnumerator(GlobEnumerate_TestData data)
    {
        var ge = new GlobEnumerator(new FakeFS(data.JsonFile, DataFileType.Json)) {
            Enumerated          = data.Enumerated,
            Comparison          = data.Comparison,
            EnumerateFromFolder = data.Path
        };

        var enumerate = () => ge.Enumerate(data.Pattern);

        if (data.Throws)
        {
            enumerate.Should().Throw<ArgumentException>();
        }
        else
        {
            var result = enumerate.Should().NotThrow().Which;

            result.Should().BeEquivalentTo(data.ResultsSet);
        }
    }
}
