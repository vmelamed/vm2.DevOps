namespace vm2.DevOps.Glob.Api.Tests;

[ExcludeFromCodeCoverage]
public class GlobUnixLargeSetTests : GlobEnumeratorTests
{
    public GlobUnixLargeSetTests(GlobTestsFixture fixture, ITestOutputHelper output)
        : base(fixture, output)
    {
    }

    [Theory]
    [MemberData(nameof(Enumerate_Unix_LargeSet))]
    public void Should_Enumerate_UnixLargeSet_GlobEnumerator(GlobEnumerateTheoryElement data) => Enumerate_GlobEnumerator(data);
}
