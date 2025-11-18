namespace vm2.DevOps.Glob.Api.Tests;

[ExcludeFromCodeCoverage]
public class GlobWinLargeSetTests : GlobEnumeratorTests
{
    public GlobWinLargeSetTests(GlobTestsFixture fixture, ITestOutputHelper output)
        : base(fixture, output)
    {
    }

    [Theory]
    [MemberData(nameof(Enumerate_Win_LargeSet))]
    public void Should_Enumerate_WinLargeSet_GlobEnumerator(GlobEnumerateTheoryElement data) => Enumerate_GlobEnumerator(data);
}
