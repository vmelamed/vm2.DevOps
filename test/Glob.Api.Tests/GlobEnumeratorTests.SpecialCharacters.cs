namespace vm2.DevOps.Glob.Api.Tests;

[ExcludeFromCodeCoverage]
public class GlobSpecialCharactersTests : GlobEnumeratorTests
{
    public GlobSpecialCharactersTests(GlobTestsFixture fixture, ITestOutputHelper output)
        : base(fixture, output)
    {
    }

    [Theory]
    [MemberData(nameof(Enumerate_SpecialCharacters))]
    public void Should_Enumerate_SpecialCharacters_GlobEnumerator(GlobEnumerateTheoryElement data) => Enumerate_GlobEnumerator(data);
}
