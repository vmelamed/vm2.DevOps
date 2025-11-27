// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Val Melamed

namespace vm2.DevOps.Glob.Api.Tests;

[ExcludeFromCodeCoverage]
public partial class GlobPropertiesTests : GlobEnumeratorUnitTests
{
    public GlobPropertiesTests(GlobUnitTestsFixture fixture, ITestOutputHelper output)
        : base(fixture, output)
    {
    }

    [Fact]
    public void Invalid_Path_In_GlobEnumerator_ShouldThrow()
    {
        var ge = GetGlobEnumerator("FakeFSFiles/FakeFS2.Win.json");
        var assignInvalidPath = () => ge.FromDirectory = "C:/fldr1";

        assignInvalidPath.Should().Throw<ArgumentException>();
    }

    [Fact]
    public void Invalid_EnumerateFromFolder_ShouldThrow()
    {
        var ge = GetGlobEnumerator("FakeFSFiles/FakeFS2.Win.json");
        var assignInvalidPath = () => ge.FromDirectory = "C:/nonexistent";

        assignInvalidPath.Should().Throw<ArgumentException>();
    }

    [Fact]
    public void Invalid_MatchCasing_ShouldThrow()
    {
        var ge = GetGlobEnumerator("FakeFSFiles/FakeFS2.Win.json");
        var assignInvalidPath = () => ge.MatchCasing = ((MatchCasing)3);

        assignInvalidPath.Should().Throw<ArgumentException>();
    }

    [Fact]
    public void MoreThan2Asterisks_Pattern_ShouldNotThrow()
    {
        var ge = GetGlobEnumerator("FakeFSFiles/FakeFS2.Win.json");

        ge.Glob = "***";
        ge.Enumerated = Objects.Directories;
        var enumerate = ge.Enumerate;

        enumerate.Should().NotThrow();
    }

    [Fact]
    public void Invalid_FilePattern_ShouldThrow()
    {
        var ge = GetGlobEnumerator("FakeFSFiles/FakeFS2.Win.json");

        ge.Enumerated = Objects.Files;
        ge.Glob       = "*/";
        var enumerate = ge.Enumerate;

        enumerate.Should().Throw<ArgumentException>();
    }

    [Fact]
    public void RecursiveInTheEnd_FilePattern_ShouldThrow()
    {
        var ge = GetGlobEnumerator("FakeFSFiles/FakeFS2.Win.json");

        ge.Glob = "*/**";
        ge.Enumerated = Objects.Files;
        var enumerate = ge.Enumerate;

        enumerate.Should().Throw<ArgumentException>();
    }
}
