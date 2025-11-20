namespace vm2.DevOps.Glob.Api.Tests;

[ExcludeFromCodeCoverage]
public class GlobEnumerationOrderTests : GlobEnumeratorTests
{
    public GlobEnumerationOrderTests(GlobUnitTestsFixture fixture, ITestOutputHelper output)
        : base(fixture, output)
    {
    }

    [Fact]
    public void WithBuilder_Should_Enumerate_DepthFirst_GlobEnumerator()
    {
        var ge = Fixture.GetGlobEnumerator(
                            "FakeFSFiles/FakeFS7.Unix.json",
                            () => new GlobEnumeratorBuilder()
                                        .WithGlob("**/*.txt")
                                        .FromDirectory("/")
                                        .CaseSensitive()
                                        .SelectFiles()
                                        .DepthFirst()
                                        .Distinct()
                                        .Build()
                            );
        var enumerate = ge.Enumerate;
        var result = enumerate.Should().NotThrow().Which.ToList();

        Console.WriteLine("Tdf R:");
        foreach (var item in result)
            Output.WriteLine(item);

        result.Should().BeEquivalentTo(
        [
            "/aaa.txt",
            "/a/aa.txt",
            "/a/b/bb.txt",
            "/a/b/c/cc.txt",
            "/x/xx.txt",
            "/x/y/yy.txt",
            "/x/y/z/zz.txt",
        ]);
    }

    [Fact]
    public void WithBuilder_Should_Enumerate_BreadthFirst_GlobEnumerator()
    {
        var ge = Fixture.GetGlobEnumerator(
                            "FakeFSFiles/FakeFS7.Unix.json",
                            () => new GlobEnumeratorBuilder()
                                        .WithGlob("**/*.txt")
                                        .FromDirectory("/")
                                        .CaseInsensitive()
                                        .SelectFiles()
                                        .BreadthFirst()
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
            "/aaa.txt",
            "/a/aa.txt",
            "/x/xx.txt",
            "/a/b/bb.txt",
            "/x/y/yy.txt",
            "/a/b/c/cc.txt",
            "/x/y/z/zz.txt",
        ]);
    }
}
