namespace vm2.DevOps.Glob.Api.Tests;

[ExcludeFromCodeCoverage]
public class GlobEnumerationDistinctTests(GlobUnitTestsFixture fixture, ITestOutputHelper output) : GlobEnumeratorUnitTests(fixture, output)
{
    [Fact]
    public void Should_Enumerate_WithDuplicates_GlobEnumerator()
    {
        var ge = GetGlobEnumerator(
                            "FakeFSFiles/FakeFS6.Unix.json",
                            builder => builder
                                        .WithGlob("/**/[lb]*/**/[lb]*/*.txt")
                                        .FromDirectory("/")
                                        .CaseSensitive()
                                        .SelectFiles()
                                        .Build());
        var enumerate = ge.Enumerate;
        var result = enumerate.Should().NotThrow().Which.ToList();
        string[] expected = [
            "/deep-recursive/level1/level2/level3/deep1.txt",
            "/deep-recursive/level1/level2/level3/deep1.txt",
            "/deep-recursive/level1/level2/mid1.txt",
        ];

        Output.WriteLine("Expected Results: \"{0}\"", string.Join("\", \"", expected));
        Output.WriteLine("  Actual Results: \"{0}\"", string.Join("\", \"", result));

        result.Should().BeEquivalentTo(expected);
    }

    [Fact]
    public void Should_Enumerate_Distinct_GlobEnumerator()
    {
        var ge = GetGlobEnumerator(
                            "FakeFSFiles/FakeFS6.Unix.json",
                            builder => builder
                                        .WithGlob("/**/[lb]*/**/[lb]*/*.txt")
                                        .FromDirectory("/")
                                        .CaseInsensitive()
                                        .SelectFiles()
                                        .Distinct()
                                        .Build()
                            );
        var enumerate = ge.Enumerate;
        var result = enumerate.Should().NotThrow().Which.ToList();
        string[] expected = [
            "/deep-recursive/level1/level2/level3/deep1.txt",
            "/deep-recursive/level1/level2/mid1.txt",
        ];

        Output.WriteLine("Expected Results: \"{0}\"", string.Join("\", \"", expected));
        Output.WriteLine("  Actual Results: \"{0}\"", string.Join("\", \"", result));

        result.Should().BeEquivalentTo(expected);
    }
}
