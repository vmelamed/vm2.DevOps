// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Val Melamed

namespace vm2.DevOps.Glob.Api.Tests;

[ExcludeFromCodeCoverage]
public class GlobCaseSensitivityTests(GlobUnitTestsFixture fixture, ITestOutputHelper output) : GlobEnumeratorUnitTests(fixture, output)
{
    [Theory]
    [MemberData(nameof(Enumerate_CaseSensitivity))]
    public void Should_Enumerate_CaseSensitivity_GlobEnumerator(UnitTestElement data) => Enumerate_GlobEnumerator(data);
}
