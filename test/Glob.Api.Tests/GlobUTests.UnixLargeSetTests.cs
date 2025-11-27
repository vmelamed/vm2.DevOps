// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Val Melamed

namespace vm2.DevOps.Glob.Api.Tests;

[ExcludeFromCodeCoverage]
public class GlobUnixLargeSetTests(GlobUnitTestsFixture fixture, ITestOutputHelper output) : GlobEnumeratorUnitTests(fixture, output)
{
    [Theory]
    [MemberData(nameof(Enumerate_Unix_LargeSet))]
    public void Should_Enumerate_UnixLargeSet_GlobEnumerator(UnitTestElement data) => Enumerate_GlobEnumerator(data);
}
