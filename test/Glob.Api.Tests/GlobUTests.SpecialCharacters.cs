// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Val Melamed

namespace vm2.DevOps.Glob.Api.Tests;

[ExcludeFromCodeCoverage]
public class GlobSpecialCharactersTests(GlobUnitTestsFixture fixture, ITestOutputHelper output) : GlobEnumeratorUnitTests(fixture, output)
{
    [Theory]
    [MemberData(nameof(Enumerate_SpecialCharacters))]
    public void Should_Enumerate_SpecialCharacters_GlobEnumerator(UnitTestElement data) => Enumerate_GlobEnumerator(data);
}
