namespace vm2.DevOps.Glob.Api.Tests;

[ExcludeFromCodeCoverage]
public class GlobCaseSensitivityTests : GlobEnumeratorUnitTests
{
    public GlobCaseSensitivityTests(GlobUnitTestsFixture fixture, ITestOutputHelper output)
        : base(fixture, output)
    {
    }

    [Theory]
    [MemberData(nameof(Enumerate_CaseSensitivity))]
    public void Should_Enumerate_CaseSensitivity_GlobEnumerator(UnitTestElement data) => Enumerate_GlobEnumerator(data);
}
