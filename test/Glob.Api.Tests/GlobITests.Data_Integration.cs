// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Val Melamed

namespace vm2.DevOps.Glob.Api.Tests;

public partial class GlobEnumeratorIntegrationTests
{
    // TheoryData definitions
    public static TheoryData<IntegrationTestData> RecursiveEnumerationTests =>
    [
        new IntegrationTestData(TestFileLine("Find all .txt files recursively"),
                                    "**/*.txt",   "",       Objects.Files,
                                        MatchCasing.PlatformDefault, false, false, false, false, false,
                                        "case-test/file.txt", "hidden/visible.txt", "recursive/root.txt", "recursive/level1/one.txt", "spec-chars/parentheses/file(1).txt", "spec-chars/spaces in names/file with spaces.txt", "spec-chars/symbols/file@home.txt", "spec-chars/unicode/naïve.txt", "spec-chars/unicode/файл.txt", "recursive/level1/level2/two.txt", "recursive/level1/branch1/subbranch1/leaf1.txt", "recursive/level1/branch1/subbranch2/leaf2.txt", "recursive/level1/branch2/subbranch3/leaf3.txt", "recursive/level1/level2/level3/three.txt"),

        new IntegrationTestData(TestFileLine("Find all directories matching 'branch*'"),
                                    "**/branch*", "",       Objects.Directories,
                                        MatchCasing.PlatformDefault, false, false, false, false, false,
                                        "recursive/level1/branch1/", "recursive/level1/branch2/"),

        new IntegrationTestData(TestFileLine("Find hidden dot files"),
                                    ".*",         "hidden", Objects.Files,
                                        MatchCasing.PlatformDefault, false, false, false, false, false,
                                        "hidden/.bashrc", "hidden/.hidden", "hidden/.profile"),

        new IntegrationTestData(TestFileLine("Files with spaces in names"),
                                    "*.txt",      "spec-chars/spaces in names", Objects.Files,
                                        MatchCasing.PlatformDefault, false, false, false, false, false,
                                        "spec-chars/spaces in names/file with spaces.txt"),

        new IntegrationTestData(TestFileLine("Files with Unicode names"),
                                    "*.txt",      "spec-chars/unicode", Objects.Files,
                                    MatchCasing.PlatformDefault, false, false, false, false, false,
                                    "spec-chars/unicode/naïve.txt", "spec-chars/unicode/файл.txt"),

        new IntegrationTestData(TestFileLine("Files with parentheses"),
                                    "*(*)*",      "spec-chars/parentheses", Objects.Files,
                                    MatchCasing.PlatformDefault, false, false, false, false, false,
                                    "spec-chars/parentheses/data(copy).dat", "spec-chars/parentheses/file(1).txt"),

        new IntegrationTestData(TestFileLine("Unix: Case-sensitive exact match - lowercase"),
                                    "*.txt",   "case-test", Objects.Files,
                                    MatchCasing.CaseSensitive, false, false, false, true,  false,
                                    ["case-test/file.txt"]),

        new IntegrationTestData(TestFileLine("Unix: Case-sensitive exact match - uppercase"),
                                    "*.TXT",   "case-test", Objects.Files,
                                    MatchCasing.CaseSensitive, false, false, false, true,  false,
                                    ["case-test/_FILE.TXT"]),

        new IntegrationTestData(TestFileLine("Unix: Case-insensitive match"),
                                    "*.txt",   "case-test", Objects.Files,
                                    MatchCasing.CaseInsensitive, false, false, false, true,  false,
                                    ["case-test/file.txt", "case-test/_FILE.TXT"]),

        new IntegrationTestData(TestFileLine("Win: Case-sensitive exact match - lowercase"),
                                    "*.txt",   "case-test", Objects.Files,
                                    MatchCasing.CaseSensitive, false, false, true,  false, false,
                                    "case-test/file.txt"),

        new IntegrationTestData(TestFileLine("Win: Case-sensitive exact match - uppercase"),
                                    "*.TXT",   "case-test", Objects.Files,
                                    MatchCasing.CaseSensitive, false, false, true,  false, false,
                                    "case-test/_FILE.TXT"),

        new IntegrationTestData(TestFileLine("Win: Case-insensitive match"),
                                    "*.txt",   "case-test", Objects.Files,
                                    MatchCasing.CaseInsensitive, false, false, true,  false, false,
                                    "case-test/file.txt", "case-test/_FILE.TXT"),

        new IntegrationTestData(TestFileLine("Depth-first traversal order"),
                                    "**/*.txt",   "recursive", Objects.Files,
                                    MatchCasing.CaseInsensitive, true,  false, false, false, false,
                                    "recursive/root.txt", "recursive/level1/one.txt", "recursive/level1/level2/two.txt", "recursive/level1/level2/level3/three.txt", "recursive/level1/branch2/subbranch3/leaf3.txt", "recursive/level1/branch1/subbranch2/leaf2.txt", "recursive/level1/branch1/subbranch1/leaf1.txt"),

        new IntegrationTestData(TestFileLine("Breadth-first traversal order"),
                                    "**/*.txt",   "recursive", Objects.Files,
                                    MatchCasing.CaseInsensitive, false, false, false, false, false,
                                    "recursive/root.txt", "recursive/level1/one.txt", "recursive/level1/level2/two.txt", "recursive/level1/branch1/subbranch1/leaf1.txt", "recursive/level1/branch1/subbranch2/leaf2.txt", "recursive/level1/branch2/subbranch3/leaf3.txt", "recursive/level1/level2/level3/three.txt"),

    ];
}
