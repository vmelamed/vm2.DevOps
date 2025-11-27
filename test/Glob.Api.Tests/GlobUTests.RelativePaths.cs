// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Val Melamed

namespace vm2.DevOps.Glob.Api.Tests;

[ExcludeFromCodeCoverage]
public class GlobRelativePathsTests(GlobUnitTestsFixture fixture, ITestOutputHelper output) : GlobEnumeratorUnitTests(fixture, output)
{
    [Theory]
    [MemberData(nameof(Enumerate_RelativePaths))]
    public void Should_Enumerate_RelativePaths_GlobEnumerator(UnitTestElement data) => Enumerate_GlobEnumerator(data);
}
