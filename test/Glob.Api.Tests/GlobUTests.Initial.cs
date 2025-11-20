namespace vm2.DevOps.Glob.Api.Tests;

[ExcludeFromCodeCoverage]
public class GlobInitialTests : GlobEnumeratorTests
{
    public GlobInitialTests(GlobUnitTestsFixture fixture, ITestOutputHelper output)
        : base(fixture, output)
    {
    }

    [Theory]
    [MemberData(nameof(Enumerate_InitialSet))]
    public void Should_Enumerate_TestDataSet_GlobEnumerator(UnitTestElement data) => Enumerate_GlobEnumerator(data);
}
