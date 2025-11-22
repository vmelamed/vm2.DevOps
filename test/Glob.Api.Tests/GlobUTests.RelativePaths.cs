namespace vm2.DevOps.Glob.Api.Tests;

[ExcludeFromCodeCoverage]
public class GlobRelativePathsTests : GlobEnumeratorUnitTests
{
    public GlobRelativePathsTests(GlobUnitTestsFixture fixture, ITestOutputHelper output)
        : base(fixture, output)
    {
    }

    [Theory]
    [MemberData(nameof(Enumerate_RelativePaths))]
    public void Should_Enumerate_RelativePaths_GlobEnumerator(UnitTestElement data) => Enumerate_GlobEnumerator(data);
}
