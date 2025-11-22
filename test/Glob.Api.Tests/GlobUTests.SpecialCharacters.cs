namespace vm2.DevOps.Glob.Api.Tests;

[ExcludeFromCodeCoverage]
public class GlobSpecialCharactersTests : GlobEnumeratorUnitTests
{
    public GlobSpecialCharactersTests(GlobUnitTestsFixture fixture, ITestOutputHelper output)
        : base(fixture, output)
    {
    }

    [Theory]
    [MemberData(nameof(Enumerate_SpecialCharacters))]
    public void Should_Enumerate_SpecialCharacters_GlobEnumerator(UnitTestElement data) => Enumerate_GlobEnumerator(data);
}
