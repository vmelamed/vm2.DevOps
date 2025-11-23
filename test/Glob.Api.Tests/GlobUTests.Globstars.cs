namespace vm2.DevOps.Glob.Api.Tests;

[ExcludeFromCodeCoverage]
public class GlobstarsTests(GlobUnitTestsFixture fixture, ITestOutputHelper output) : GlobEnumeratorUnitTests(fixture, output)
{
    [Theory]
    [MemberData(nameof(Enumerate_Globstars))]
    public void Should_Enumerate_Globstars_GlobEnumerator(UnitTestElement data)
    {
        var ge = Fixture.GetGlobEnumerator(data.Fs, () => CreateBuilder(data, data.Throws));
        // For globstar tests, we change the meaning of data.Tx to indicate _distinctResults
        // Dirty hack for reusing the same test data, so ashamed... ;)

        var enumerate = ge.Enumerate;
        var result = enumerate.Should().NotThrow().Which.OrderBy(s => s, StringComparer.Ordinal);

        result.Should().BeEquivalentTo(data.R);
    }
}
