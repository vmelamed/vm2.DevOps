namespace vm2.DevOps.Glob.Api.Tests;

[ExcludeFromCodeCoverage]
public class GlobEnumerationDistinctTests : GlobEnumeratorUnitTests
{
    public GlobEnumerationDistinctTests(GlobUnitTestsFixture fixture, ITestOutputHelper output)
        : base(fixture, output)
    {
    }

    [Fact]
    public void Should_Enumerate_WithDuplicates_GlobEnumerator()
    {
        var ge = Fixture.GetGlobEnumerator(
                            "FakeFSFiles/FakeFS6.Unix.json",
                            () => new GlobEnumeratorBuilder()
                                        .WithGlob("/**/[lb]*/**/[lb]*/*.txt")
                                        .FromDirectory("/")
                                        .CaseSensitive()
                                        .SelectFiles()
                                        .Build()
                            );
        var enumerate = ge.Enumerate;
        var result = enumerate.Should().NotThrow().Which.ToList();

        Console.WriteLine("Tdf R:");
        foreach (var item in result)
            Output.WriteLine(item);

        result.Should().BeEquivalentTo(
        [
            "/deep-recursive/level1/level2/level3/deep1.txt",
            "/deep-recursive/level1/level2/level3/deep1.txt",
            "/deep-recursive/level1/level2/mid1.txt",
        ]);
    }

    [Fact]
    public void Should_Enumerate_Distinct_GlobEnumerator()
    {
        var ge = Fixture.GetGlobEnumerator(
                            "FakeFSFiles/FakeFS6.Unix.json",
                            () => new GlobEnumeratorBuilder()
                                        .WithGlob("/**/[lb]*/**/[lb]*/*.txt")
                                        .FromDirectory("/")
                                        .CaseInsensitive()
                                        .SelectFiles()
                                        .Distinct()
                                        .Build()
                            );
        var enumerate = ge.Enumerate;
        var result = enumerate.Should().NotThrow().Which.ToList();

        Console.WriteLine("BreadthFirst R:");
        foreach (var item in result)
            Output.WriteLine(item);

        result.Should().BeEquivalentTo(
        [
            "/deep-recursive/level1/level2/level3/deep1.txt",
            "/deep-recursive/level1/level2/mid1.txt",
        ]);
    }
}
