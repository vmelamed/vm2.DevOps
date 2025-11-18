namespace vm2.DevOps.Glob.Api.Tests;

[ExcludeFromCodeCoverage]
public class GlobCaseSensitivityTests : GlobEnumeratorTests
{
    public GlobCaseSensitivityTests(GlobTestsFixture fixture, ITestOutputHelper output)
        : base(fixture, output)
    {
    }

    [Theory]
    [MemberData(nameof(Enumerate_CaseSensitivity))]
    public void Should_Enumerate_CaseSensitivity_GlobEnumerator(GlobEnumerateTheoryElement data) => Enumerate_GlobEnumerator(data);
}
