// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Val Melamed

namespace vm2.DevOps.Glob.Api.Tests;

public partial class GlobEnumeratorUnitTests
{
    public static TheoryData<UnitTestElement> Enumerate_Globstars =
    [
        // For globstar tests, we change the meaning of data.Tx to indicate _distinctResults
        // Dirty hack for reusing the same test data field

        // ==========================================================================================================
        // SINGLE ** AT DIFFERENT POSITIONS - Unix
        // ==========================================================================================================
        //                                         fsFile  glob                                           cwd    start                         objects          _matchCasing                  dist    results...
        new UnitTestElement(TestFileLine("Unix: ** at start - **/*.txt"),
                                                   "FSFiles/FS6.Unix.json",
                                                           "**/*.txt",                                    "/",   "/deep-recursive",            Objects.Files,   MatchCasing.PlatformDefault, false,  "/deep-recursive/branch1/branch.txt",
                                                                                                                                                                                                     "/deep-recursive/branch1/subbranch1/leaf1.txt",
                                                                                                                                                                                                     "/deep-recursive/branch1/subbranch2/leaf2.txt",
                                                                                                                                                                                                     "/deep-recursive/branch2/branch2.txt",
                                                                                                                                                                                                     "/deep-recursive/branch2/subbranch3/leaf3.txt",
                                                                                                                                                                                                     "/deep-recursive/level1/level2/level3/deep1.txt",
                                                                                                                                                                                                     "/deep-recursive/level1/level2/mid1.txt",
                                                                                                                                                                                                     "/deep-recursive/level1/top1.txt",
                                                                                                                                                                                                     "/deep-recursive/root.txt"),

        new UnitTestElement(TestFileLine("Unix: ** at middle - /level1/**/deep*.txt"),
                                                   "FSFiles/FS6.Unix.json",
                                                           "/deep-recursive/level1/**/deep*.txt",         "/",   "/",                          Objects.Files,   MatchCasing.PlatformDefault, false,  "/deep-recursive/level1/level2/level3/deep1.txt"),

        new UnitTestElement(TestFileLine("Unix: ** at end - /deep-recursive/**"),
                                                   "FSFiles/FS6.Unix.json",
                                                           "/deep-recursive/**",                          "/",   "/",                          Objects.Directories, MatchCasing.PlatformDefault, false,"/deep-recursive/branch1/",
                                                                                                                                                                                                       "/deep-recursive/branch1/subbranch1/",
                                                                                                                                                                                                       "/deep-recursive/branch1/subbranch2/",
                                                                                                                                                                                                       "/deep-recursive/branch2/",
                                                                                                                                                                                                       "/deep-recursive/branch2/subbranch3/",
                                                                                                                                                                                                       "/deep-recursive/level1/",
                                                                                                                                                                                                       "/deep-recursive/level1/level2/",
                                                                                                                                                                                                       "/deep-recursive/level1/level2/level3/"),

        new UnitTestElement(TestFileLine("Unix: ** in middle with pattern - /**/level3/*.txt"),
                                                   "FSFiles/FS6.Unix.json",
                                                           "/**/level3/*.txt",                            "/",   "/",                          Objects.Files,   MatchCasing.PlatformDefault, false,  "/deep-recursive/level1/level2/level3/deep1.txt"),

        new UnitTestElement(TestFileLine("Unix: ** with exact directory name - /**/subbranch1/*"),
                                                   "FSFiles/FS6.Unix.json",
                                                           "/**/subbranch1/*",                            "/",   "/",                          Objects.Files,   MatchCasing.PlatformDefault, false,  "/deep-recursive/branch1/subbranch1/leaf1.txt"),

        // ==========================================================================================================
        // MULTIPLE ** IN SINGLE PATTERN - Unix
        // ==========================================================================================================
        //                                         fsFile  glob                                           cwd    start                         objects          _matchCasing                  dist    results...
        new UnitTestElement(TestFileLine("Unix: Two ** - /**/branch1/**/*.txt"),
                                                   "FSFiles/FS6.Unix.json",
                                                           "/**/branch1/**/*.txt",                        "/",   "/",                          Objects.Files,   MatchCasing.PlatformDefault, false,  "/deep-recursive/branch1/branch.txt",
                                                                                                                                                                                                     "/deep-recursive/branch1/subbranch1/leaf1.txt",
                                                                                                                                                                                                     "/deep-recursive/branch1/subbranch2/leaf2.txt"),

        new UnitTestElement(TestFileLine("Unix: Two ** - /**/level2/**/*.txt"),
                                                   "FSFiles/FS6.Unix.json",
                                                           "/**/level2/**/*.txt",                         "/",   "/",                          Objects.Files,   MatchCasing.PlatformDefault, false,  "/deep-recursive/level1/level2/level3/deep1.txt",
                                                                                                                                                                                                     "/deep-recursive/level1/level2/mid1.txt"),

        new UnitTestElement(TestFileLine("Unix: Three ** - /**/**/level2/**/*.dat"),
                                                   "FSFiles/FS6.Unix.json",
                                                           "/**/**/level2/**/*.dat",                      "/",   "/",                          Objects.Files,   MatchCasing.PlatformDefault, false,  "/deep-recursive/level1/level2/level3/deep2.dat",
                                                                                                                                                                                                     "/deep-recursive/level1/level2/mid2.dat"),

        new UnitTestElement(TestFileLine("Unix: Multiple ** with wildcards - /**/**/sub*/**/*.txt"),
                                                   "FSFiles/FS6.Unix.json",
                                                           "/**/**/sub*/**/*.txt",                        "/",   "/",                          Objects.Files,   MatchCasing.PlatformDefault, false,  "/deep-recursive/branch1/subbranch1/leaf1.txt",
                                                                                                                                                                                                     "/deep-recursive/branch1/subbranch2/leaf2.txt",
                                                                                                                                                                                                     "/deep-recursive/branch2/subbranch3/leaf3.txt"),

        new UnitTestElement(TestFileLine("Unix: Four ** in pattern"),
                                                   "FSFiles/FS6.Unix.json",
                                                           "/**/**/branch*/**/**/leaf*.txt",              "/",   "/",                          Objects.Files,   MatchCasing.PlatformDefault, false,  "/deep-recursive/branch1/subbranch1/leaf1.txt",
                                                                                                                                                                                                     "/deep-recursive/branch1/subbranch2/leaf2.txt",
                                                                                                                                                                                                     "/deep-recursive/branch2/subbranch3/leaf3.txt"),

        // ==========================================================================================================
        // ** WITH SPECIFIC PATTERNS - Unix
        // ==========================================================================================================
        //                                         fsFile  glob                                           cwd    start                         objects          _matchCasing                  dist    results...
        new UnitTestElement(TestFileLine("Unix: ** with bracket expression - /**/[lb]*/*.txt"),
                                                   "FSFiles/FS6.Unix.json",
                                                           "/**/[lb]*/*.txt",                             "/",   "/",                          Objects.Files,   MatchCasing.PlatformDefault, false,  "/deep-recursive/branch1/branch.txt",
                                                                                                                                                                                                     "/deep-recursive/branch2/branch2.txt",
                                                                                                                                                                                                     "/deep-recursive/level1/level2/level3/deep1.txt",
                                                                                                                                                                                                     "/deep-recursive/level1/level2/mid1.txt",
                                                                                                                                                                                                     "/deep-recursive/level1/top1.txt",
                                                                                                                                                                                                     "/special-chars/brackets/[prefix]file.txt",
                                                                                                                                                                                                     "/special-chars/brackets/array[0].txt"),
        new UnitTestElement(TestFileLine("Unix: ** with question mark - /**/?ranch?/*.txt"),
                                                   "FSFiles/FS6.Unix.json",
                                                           "/**/?ranch?/*.txt",                           "/",   "/",                          Objects.Files,   MatchCasing.PlatformDefault, false,  "/deep-recursive/branch1/branch.txt",
                                                                                                                                                                                                     "/deep-recursive/branch2/branch2.txt"),

        new UnitTestElement(TestFileLine("Unix: ** with negation - /**/[!l]*/*.txt"),
                                                   "FSFiles/FS6.Unix.json",
                                                           "/**/[!l]*/*.txt",                             "/",   "/",                          Objects.Files,   MatchCasing.PlatformDefault, false,  "/deep-recursive/level1/level2/level3/deep1.txt",
                                                                                                                                                                                                     "/deep-recursive/level1/level2/mid1.txt",
                                                                                                                                                                                                     "/deep-recursive/level1/top1.txt"),

        new UnitTestElement(TestFileLine("Unix: ** with character class - /**/[[:lower:]]*1/*.txt"),
                                                   "FSFiles/FS6.Unix.json",
                                                           "/**/[[:lower:]]*1/*.txt",                     "/",   "/",                          Objects.Files,   MatchCasing.PlatformDefault, false,  "/deep-recursive/branch1/branch.txt",
                                                                                                                                                                                                     "/deep-recursive/branch1/subbranch1/leaf1.txt",
                                                                                                                                                                                                     "/deep-recursive/level1/top1.txt"),


        new UnitTestElement(TestFileLine("Unix: ** matching zero directories - /deep-recursive/**/root.txt"),
                                                   "FSFiles/FS6.Unix.json",
                                                           "/deep-recursive/**/root.txt",                 "/",   "/",                          Objects.Files,   MatchCasing.PlatformDefault, false,  "/deep-recursive/root.txt"),

        // ==========================================================================================================
        // ** AT DIFFERENT DEPTHS - Unix
        // ==========================================================================================================
        //                                         fsFile  glob                                           cwd    start                         objects          _matchCasing                  dist    results...
        new UnitTestElement(TestFileLine("Unix: Deep ** - /deep-recursive/level1/level2/**/*.txt"),
                                                   "FSFiles/FS6.Unix.json",
                                                           "/deep-recursive/level1/level2/**/*.txt",      "/",   "/",                          Objects.Files,   MatchCasing.PlatformDefault, false,  "/deep-recursive/level1/level2/level3/deep1.txt",
                                                                                                                                                                                                     "/deep-recursive/level1/level2/mid1.txt"),

        new UnitTestElement(TestFileLine("Unix: Deep ** with wildcards - /deep-recursive/*/level2/**/*.dat"),
                                                   "FSFiles/FS6.Unix.json",
                                                           "/deep-recursive/*/level2/**/*.dat",           "/",   "/",                          Objects.Files,   MatchCasing.PlatformDefault, false,  "/deep-recursive/level1/level2/level3/deep2.dat",
                                                                                                                                                                                                     "/deep-recursive/level1/level2/mid2.dat"),

        new UnitTestElement(TestFileLine("Unix: ** from deep start point"),
                                                   "FSFiles/FS6.Unix.json",
                                                           "**/*.txt",                                    "/",   "/deep-recursive/level1/level2", Objects.Files, MatchCasing.PlatformDefault, false, "/deep-recursive/level1/level2/level3/deep1.txt",
                                                                                                                                                                                                     "/deep-recursive/level1/level2/mid1.txt"),

        new UnitTestElement(TestFileLine("Unix: Shallow vs deep matches - /**/branch*.txt"),
                                                   "FSFiles/FS6.Unix.json",
                                                           "/**/branch*.txt",                             "/",   "/",                          Objects.Files,   MatchCasing.PlatformDefault, false,  "/deep-recursive/branch1/branch.txt",
                                                                                                                                                                                                     "/deep-recursive/branch2/branch2.txt"),

        // ==========================================================================================================
        // ** WITH BOTH FILES AND DIRECTORIES - Unix
        // ==========================================================================================================
        //                                         fsFile  glob                                           cwd    start                         objects          _matchCasing                  dist    results...
        new UnitTestElement(TestFileLine("Unix: ** all objects under branch1"),
                                                   "FSFiles/FS6.Unix.json",
                                                           "/deep-recursive/branch1/**/*",                "/",   "/",                          Objects.FilesAndDirectories,    MatchCasing.PlatformDefault, false,  "/deep-recursive/branch1/branch.txt",
                                                                                                                                                                                                     "/deep-recursive/branch1/subbranch1/",
                                                                                                                                                                                                     "/deep-recursive/branch1/subbranch1/leaf1.txt",
                                                                                                                                                                                                     "/deep-recursive/branch1/subbranch2/",
                                                                                                                                                                                                     "/deep-recursive/branch1/subbranch2/leaf2.txt"),

        new UnitTestElement(TestFileLine("Unix: ** only directories under deep-recursive"),
                                                   "FSFiles/FS6.Unix.json",
                                                           "/deep-recursive/**",                          "/",   "/",                          Objects.Directories, MatchCasing.PlatformDefault, false,"/deep-recursive/branch1/",
                                                                                                                                                                                                       "/deep-recursive/branch1/subbranch1/",
                                                                                                                                                                                                       "/deep-recursive/branch1/subbranch2/",
                                                                                                                                                                                                       "/deep-recursive/branch2/",
                                                                                                                                                                                                       "/deep-recursive/branch2/subbranch3/",
                                                                                                                                                                                                       "/deep-recursive/level1/",
                                                                                                                                                                                                       "/deep-recursive/level1/level2/",
                                                                                                                                                                                                       "/deep-recursive/level1/level2/level3/"),

        new UnitTestElement(TestFileLine("Unix: ** only files under deep-recursive"),
                                                   "FSFiles/FS6.Unix.json",
                                                           "/deep-recursive/**/*",                        "/",   "/",                          Objects.Files,   MatchCasing.PlatformDefault, false,  "/deep-recursive/branch1/branch.txt",
                                                                                                                                                                                                     "/deep-recursive/branch1/subbranch1/leaf1.txt",
                                                                                                                                                                                                     "/deep-recursive/branch1/subbranch2/leaf2.txt",
                                                                                                                                                                                                     "/deep-recursive/branch2/branch2.txt",
                                                                                                                                                                                                     "/deep-recursive/branch2/subbranch3/leaf3.txt",
                                                                                                                                                                                                     "/deep-recursive/level1/level2/level3/deep1.txt",
                                                                                                                                                                                                     "/deep-recursive/level1/level2/level3/deep2.dat",
                                                                                                                                                                                                     "/deep-recursive/level1/level2/mid1.txt",
                                                                                                                                                                                                     "/deep-recursive/level1/level2/mid2.dat",
                                                                                                                                                                                                     "/deep-recursive/level1/top1.txt",
                                                                                                                                                                                                     "/deep-recursive/level1/top2.dat",
                                                                                                                                                                                                     "/deep-recursive/root.txt"),

        // ==========================================================================================================
        // WINDOWS TESTS - GlobstarRegex wildcards
        // ==========================================================================================================
        //                                         fsFile  glob                                           cwd    start                         objects          _matchCasing                  dist    results...
        new UnitTestElement(TestFileLine("Win: ** at start - **/*.txt"),
                                                   "FSFiles/FS6.Win.json",
                                                           "**/*.txt",                                    "C:/", "C:/deep-recursive",          Objects.Files,   MatchCasing.PlatformDefault, false,  "C:/deep-recursive/branch1/branch.txt",
                                                                                                                                                                                                     "C:/deep-recursive/branch1/subbranch1/leaf1.txt",
                                                                                                                                                                                                     "C:/deep-recursive/branch1/subbranch2/leaf2.txt",
                                                                                                                                                                                                     "C:/deep-recursive/branch2/branch2.txt",
                                                                                                                                                                                                     "C:/deep-recursive/branch2/subbranch3/leaf3.txt",
                                                                                                                                                                                                     "C:/deep-recursive/level1/level2/level3/deep1.txt",
                                                                                                                                                                                                     "C:/deep-recursive/level1/level2/mid1.txt",
                                                                                                                                                                                                     "C:/deep-recursive/level1/top1.txt",
                                                                                                                                                                                                     "C:/deep-recursive/root.txt"),

        new UnitTestElement(TestFileLine("Win: Two ** - C:/**/branch1/**/*.txt"),
                                                   "FSFiles/FS6.Win.json",
                                                           "C:/**/branch1/**/*.txt",                      "C:/", "C:/",                        Objects.Files,   MatchCasing.PlatformDefault, false,  "C:/deep-recursive/branch1/branch.txt",
                                                                                                                                                                                                     "C:/deep-recursive/branch1/subbranch1/leaf1.txt",
                                                                                                                                                                                                     "C:/deep-recursive/branch1/subbranch2/leaf2.txt"),
       new UnitTestElement(TestFileLine("Win: ** with pattern - C:/**/level3/*.txt"),
                                                   "FSFiles/FS6.Win.json",
                                                           "C:/**/level3/*.txt",                          "C:/", "C:/",                        Objects.Files,   MatchCasing.PlatformDefault, false,  "C:/deep-recursive/level1/level2/level3/deep1.txt"),

        new UnitTestElement(TestFileLine("Win: ** with bracket - C:/**/[lb]*/*.txt"),
                                                   "FSFiles/FS6.Win.json",
                                                           "C:/**/[lb]*/*.txt",                           "C:/", "C:/",                        Objects.Files,   MatchCasing.PlatformDefault, false,  "C:/deep-recursive/branch1/branch.txt",
                                                                                                                                                                                                     "C:/deep-recursive/branch2/branch2.txt",
                                                                                                                                                                                                     "C:/deep-recursive/level1/level2/level3/deep1.txt",
                                                                                                                                                                                                     "C:/deep-recursive/level1/level2/mid1.txt",
                                                                                                                                                                                                     "C:/deep-recursive/level1/top1.txt",
                                                                                                                                                                                                     "C:/special-chars/brackets/[prefix]file.txt",
                                                                                                                                                                                                     "C:/special-chars/brackets/array[0].txt"),
        new UnitTestElement(TestFileLine("Win: Multiple ** - C:/**/**/sub*/**/*.txt"),
                                                   "FSFiles/FS6.Win.json",
                                                           "C:/**/**/sub*/**/*.txt",                      "C:/", "C:/",                        Objects.Files,   MatchCasing.PlatformDefault, false,  "C:/deep-recursive/branch1/subbranch1/leaf1.txt",
                                                                                                                                                                                                     "C:/deep-recursive/branch1/subbranch2/leaf2.txt",
                                                                                                                                                                                                     "C:/deep-recursive/branch2/subbranch3/leaf3.txt"),

        new UnitTestElement(TestFileLine("Win: ** all objects under branch1"),
                                                   "FSFiles/FS6.Win.json",
                                                           "C:/deep-recursive/branch1/**/*",              "C:/", "C:/",                        Objects.FilesAndDirectories,    MatchCasing.PlatformDefault, false,  "C:/deep-recursive/branch1/branch.txt",
                                                                                                                                                                                                     "C:/deep-recursive/branch1/subbranch1/",
                                                                                                                                                                                                     "C:/deep-recursive/branch1/subbranch1/leaf1.txt",
                                                                                                                                                                                                     "C:/deep-recursive/branch1/subbranch2/",
                                                                                                                                                                                                     "C:/deep-recursive/branch1/subbranch2/leaf2.txt"),

        new UnitTestElement(TestFileLine("Win: ** only directories"),
                                                   "FSFiles/FS6.Win.json",
                                                           "C:/deep-recursive/**",                        "C:/", "C:/",                        Objects.Directories, MatchCasing.PlatformDefault, false,"C:/deep-recursive/branch1/",
                                                                                                                                                                                                       "C:/deep-recursive/branch1/subbranch1/",
                                                                                                                                                                                                       "C:/deep-recursive/branch1/subbranch2/",
                                                                                                                                                                                                       "C:/deep-recursive/branch2/",
                                                                                                                                                                                                       "C:/deep-recursive/branch2/subbranch3/",
                                                                                                                                                                                                       "C:/deep-recursive/level1/",
                                                                                                                                                                                                       "C:/deep-recursive/level1/level2/",
                                                                                                                                                                                                       "C:/deep-recursive/level1/level2/level3/"),

        // ==========================================================================================================
        // EDGE CASES - ** BEHAVIOR
        // ==========================================================================================================
        //                                         fsFile  glob                                           cwd    start                         objects          _matchCasing                  dist    results...
        new UnitTestElement(TestFileLine("Unix: ** matches zero directories exactly"),
                                                   "FSFiles/FS6.Unix.json",
                                                           "/deep-recursive/**/root.txt",                 "/",   "/",                          Objects.Files,   MatchCasing.PlatformDefault, false,  "/deep-recursive/root.txt"),

        new UnitTestElement(TestFileLine("Unix: ** matches one directory"),
                                                   "FSFiles/FS6.Unix.json",
                                                           "/deep-recursive/**/top1.txt",                 "/",   "/",                          Objects.Files,   MatchCasing.PlatformDefault, false,  "/deep-recursive/level1/top1.txt"),

        new UnitTestElement(TestFileLine("Unix: ** matches two directories"),
                                                   "FSFiles/FS6.Unix.json",
                                                           "/deep-recursive/**/mid1.txt",                 "/",   "/",                          Objects.Files,   MatchCasing.PlatformDefault, false,  "/deep-recursive/level1/level2/mid1.txt"),

        new UnitTestElement(TestFileLine("Unix: ** matches three directories"),
                                                   "FSFiles/FS6.Unix.json",
                                                           "/deep-recursive/**/deep1.txt",                "/",   "/",                          Objects.Files,   MatchCasing.PlatformDefault, false,  "/deep-recursive/level1/level2/level3/deep1.txt"),

        new UnitTestElement(TestFileLine("Unix: ** with specific depth requirement"),
                                                   "FSFiles/FS6.Unix.json",
                                                           "/deep-recursive/*/*/*/*",                     "/",   "/",                          Objects.Files,   MatchCasing.PlatformDefault, false,  "/deep-recursive/level1/level2/level3/deep1.txt",
                                                                                                                                                                                                     "/deep-recursive/level1/level2/level3/deep2.dat"),

        new UnitTestElement(TestFileLine("Unix: ** vs * difference - only immediate children"),
                                                   "FSFiles/FS6.Unix.json",
                                                           "/deep-recursive/*/*.txt",                     "/",   "/",                          Objects.Files,   MatchCasing.PlatformDefault, false,  "/deep-recursive/branch1/branch.txt",
                                                                                                                                                                                                     "/deep-recursive/branch2/branch2.txt",
                                                                                                                                                                                                     "/deep-recursive/level1/top1.txt"),

        new UnitTestElement(TestFileLine("Unix: ** vs * difference - all descendants"),
                                                   "FSFiles/FS6.Unix.json",
                                                           "/deep-recursive/**/*.txt",                    "/",   "/",                          Objects.Files,   MatchCasing.PlatformDefault, false,  "/deep-recursive/branch1/branch.txt",
                                                                                                                                                                                                     "/deep-recursive/branch1/subbranch1/leaf1.txt",
                                                                                                                                                                                                     "/deep-recursive/branch1/subbranch2/leaf2.txt",
                                                                                                                                                                                                     "/deep-recursive/branch2/branch2.txt",
                                                                                                                                                                                                     "/deep-recursive/branch2/subbranch3/leaf3.txt",
                                                                                                                                                                                                     "/deep-recursive/level1/level2/level3/deep1.txt",
                                                                                                                                                                                                     "/deep-recursive/level1/level2/mid1.txt",
                                                                                                                                                                                                     "/deep-recursive/level1/top1.txt",
                                                                                                                                                                                                     "/deep-recursive/root.txt"),

        new UnitTestElement(TestFileLine("Win: ** matches zero directories"),
                                                   "FSFiles/FS6.Win.json",
                                                           "C:/deep-recursive/**/root.txt",               "C:/", "C:/",                        Objects.Files,   MatchCasing.PlatformDefault, false,  "C:/deep-recursive/root.txt"),

        new UnitTestElement(TestFileLine("Win: ** vs * difference - only immediate"),
                                                   "FSFiles/FS6.Win.json",
                                                           "C:/deep-recursive/*/*.txt",                   "C:/", "C:/",                        Objects.Files,   MatchCasing.PlatformDefault, false,  "C:/deep-recursive/branch1/branch.txt",
                                                                                                                                                                                                     "C:/deep-recursive/branch2/branch2.txt",
                                                                                                                                                                                                     "C:/deep-recursive/level1/top1.txt"),

        new UnitTestElement(TestFileLine("Win: ** vs * difference - all descendants"),
                                                   "FSFiles/FS6.Win.json",
                                                           "C:/deep-recursive/**/*.txt",                  "C:/", "C:/",                        Objects.Files,   MatchCasing.PlatformDefault, false,  "C:/deep-recursive/branch1/branch.txt",
                                                                                                                                                                                                     "C:/deep-recursive/branch1/subbranch1/leaf1.txt",
                                                                                                                                                                                                     "C:/deep-recursive/branch1/subbranch2/leaf2.txt",
                                                                                                                                                                                                     "C:/deep-recursive/branch2/branch2.txt",
                                                                                                                                                                                                     "C:/deep-recursive/branch2/subbranch3/leaf3.txt",
                                                                                                                                                                                                     "C:/deep-recursive/level1/level2/level3/deep1.txt",
                                                                                                                                                                                                     "C:/deep-recursive/level1/level2/mid1.txt",
                                                                                                                                                                                                     "C:/deep-recursive/level1/top1.txt",
                                                                                                                                                                                                     "C:/deep-recursive/root.txt"),

        // ==========================================================================================================
        // COMPLEX PATTERNS COMBINING ** WITH OTHER FEATURES
        // ==========================================================================================================
        //                                         fsFile  glob                                           cwd    start                         objects          _matchCasing                  dist    results...
        new UnitTestElement(TestFileLine("Unix: ** with relative path from current dir"),
                                                   "FSFiles/FS6.Unix.json",
                                                           "./**/*.txt",                                  "/",   "/deep-recursive/branch1",    Objects.Files,   MatchCasing.PlatformDefault, false,  "/deep-recursive/branch1/branch.txt",
                                                                                                                                                                                                     "/deep-recursive/branch1/subbranch1/leaf1.txt",
                                                                                                                                                                                                     "/deep-recursive/branch1/subbranch2/leaf2.txt"),

        new UnitTestElement(TestFileLine("Unix: ** with parent directory navigation"),
                                                   "FSFiles/FS6.Unix.json",
                                                           "../**/*.txt",                                 "/",   "/deep-recursive/branch1",    Objects.Files,   MatchCasing.PlatformDefault, false,  "/deep-recursive/branch1/branch.txt",
                                                                                                                                                                                                     "/deep-recursive/branch1/subbranch1/leaf1.txt",
                                                                                                                                                                                                     "/deep-recursive/branch1/subbranch2/leaf2.txt",
                                                                                                                                                                                                     "/deep-recursive/branch2/branch2.txt",
                                                                                                                                                                                                     "/deep-recursive/branch2/subbranch3/leaf3.txt",
                                                                                                                                                                                                     "/deep-recursive/level1/level2/level3/deep1.txt",
                                                                                                                                                                                                     "/deep-recursive/level1/level2/mid1.txt",
                                                                                                                                                                                                     "/deep-recursive/level1/top1.txt",
                                                                                                                                                                                                     "/deep-recursive/root.txt"),

        new UnitTestElement(TestFileLine("Unix: ** with complex bracket expression and results with repeating elements"),
                                                   "FSFiles/FS6.Unix.json",
                                                           "/**/[lb][er][va][en][lc]?/**/*.txt",          "/",   "/",                          Objects.Files,   MatchCasing.PlatformDefault, false,  "/deep-recursive/level1/level2/level3/deep1.txt",
                                                                                                                                                                                                     "/deep-recursive/level1/level2/level3/deep1.txt",
                                                                                                                                                                                                     "/deep-recursive/level1/level2/level3/deep1.txt",
                                                                                                                                                                                                     "/deep-recursive/level1/level2/mid1.txt",
                                                                                                                                                                                                     "/deep-recursive/level1/level2/mid1.txt",
                                                                                                                                                                                                     "/deep-recursive/level1/top1.txt"),

        new UnitTestElement(TestFileLine("Unix: ** with complex bracket expression and results with distinct elements"),
                                                   "FSFiles/FS6.Unix.json",
                                                           "/**/[lb][er][va][en][lc]?/**/*.txt",          "/",   "/",                          Objects.Files,   MatchCasing.PlatformDefault, false,   "/deep-recursive/level1/top1.txt",
                                                                                                                                                                                                      "/deep-recursive/level1/level2/mid1.txt",
                                                                                                                                                                                                      "/deep-recursive/level1/level2/mid1.txt",
                                                                                                                                                                                                      "/deep-recursive/level1/level2/level3/deep1.txt",
                                                                                                                                                                                                      "/deep-recursive/level1/level2/level3/deep1.txt",
                                                                                                                                                                                                      "/deep-recursive/level1/level2/level3/deep1.txt"),

        new UnitTestElement(TestFileLine("Win: ** with relative current dir"),
                                                   "FSFiles/FS6.Win.json",
                                                           "./**/*.txt",                                  "C:/", "C:/deep-recursive/branch1",  Objects.Files,   MatchCasing.PlatformDefault, false,  "C:/deep-recursive/branch1/branch.txt",
                                                                                                                                                                                                     "C:/deep-recursive/branch1/subbranch1/leaf1.txt",
                                                                                                                                                                                                     "C:/deep-recursive/branch1/subbranch2/leaf2.txt"),

        new UnitTestElement(TestFileLine("Win: ** with parent directory"),
                                                   "FSFiles/FS6.Win.json",
                                                           "../**/*.txt",                                 "C:/", "C:/deep-recursive/branch1",  Objects.Files,   MatchCasing.PlatformDefault, false,  "C:/deep-recursive/branch1/branch.txt",
                                                                                                                                                                                                     "C:/deep-recursive/branch1/subbranch1/leaf1.txt",
                                                                                                                                                                                                     "C:/deep-recursive/branch1/subbranch2/leaf2.txt",
                                                                                                                                                                                                     "C:/deep-recursive/branch2/branch2.txt",
                                                                                                                                                                                                     "C:/deep-recursive/branch2/subbranch3/leaf3.txt",
                                                                                                                                                                                                     "C:/deep-recursive/level1/level2/level3/deep1.txt",
                                                                                                                                                                                                     "C:/deep-recursive/level1/level2/mid1.txt",
                                                                                                                                                                                                     "C:/deep-recursive/level1/top1.txt",
                                                                                                                                                                                                     "C:/deep-recursive/root.txt"),
    ];
}
