namespace vm2.DevOps.Glob.Api.Tests;

[ExcludeFromCodeCoverage]
public class GlobWinLargeSetTests : GlobEnumeratorUnitTests
{
    public GlobWinLargeSetTests(GlobUnitTestsFixture fixture, ITestOutputHelper output)
        : base(fixture, output)
    {
    }

    [Theory]
    [MemberData(nameof(Enumerate_Win_LargeSet))]
    public void Should_Enumerate_WinLargeSet_GlobEnumerator(UnitTestElement data) => Enumerate_GlobEnumerator(data);
}
