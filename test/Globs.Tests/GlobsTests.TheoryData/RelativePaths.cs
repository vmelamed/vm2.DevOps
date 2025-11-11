namespace vm2.DevOps.Glob.Api.Tests;

public partial class GlobsTests
{
    public static TheoryData<GlobEnumerateTheoryElement> Enumerate_RelativePaths_TestDataSet =
    [
        // ==========================================================================================================
        // CURRENT DIRECTORY (.) PATTERNS - Unix
        // ==========================================================================================================
        //                                         fsFile  glob                                  cwd    start                    objects          MatchCasing                  throws  results...
        new GlobEnumerateTheoryElement(TestFileLine("Unix: Current dir ./*.md from /projects/app1"),
                                                   "FakeFSFiles/FakeFS4.Unix.json",
                                                           "./*.md",                             "/",   "/projects/app1",        Objects.Files,   MatchCasing.PlatformDefault, false,  "/projects/app1/README.md"),

        new GlobEnumerateTheoryElement(TestFileLine("Unix: Current dir ./src/*.c"),
                                                   "FakeFSFiles/FakeFS4.Unix.json",
                                                           "./src/*.c",                          "/",   "/projects/app1",        Objects.Files,   MatchCasing.PlatformDefault, false,  "/projects/app1/src/main.c", "/projects/app1/src/util.c"),

        new GlobEnumerateTheoryElement(TestFileLine("Unix: Current dir ./src/*.h"),
                                                   "FakeFSFiles/FakeFS4.Unix.json",
                                                           "./src/*.h",                          "/",   "/projects/app1",        Objects.Files,   MatchCasing.PlatformDefault, false,  "/projects/app1/src/app.h"),

        new GlobEnumerateTheoryElement(TestFileLine("Unix: Current dir ./tests/*.c"),
                                                   "FakeFSFiles/FakeFS4.Unix.json",
                                                           "./tests/*.c",                        "/",   "/projects/app1",        Objects.Files,   MatchCasing.PlatformDefault, false,  "/projects/app1/tests/test_main.c", "/projects/app1/tests/test_util.c"),

        new GlobEnumerateTheoryElement(TestFileLine("Unix: Current dir with recursive ./**/*.c"),
                                                   "FakeFSFiles/FakeFS4.Unix.json",
                                                           "./**/*.c",                           "/",   "/projects/app1",        Objects.Files,   MatchCasing.PlatformDefault, false,  "/projects/app1/src/main.c", "/projects/app1/src/util.c", "/projects/app1/tests/test_main.c", "/projects/app1/tests/test_util.c"),

        new GlobEnumerateTheoryElement(TestFileLine("Unix: Current dir ./*/* from /projects"),
                                                   "FakeFSFiles/FakeFS4.Unix.json",
                                                           "./*/*",                              "/",   "/projects",             Objects.Files,   MatchCasing.PlatformDefault, false,  "/projects/app1/Makefile", "/projects/app1/README.md", "/projects/app2/README.txt", "/projects/app2/requirements.txt", "/projects/shared/LICENSE"),

        new GlobEnumerateTheoryElement(TestFileLine("Unix: Current dir ./ matches current directory"),
                                                   "FakeFSFiles/FakeFS4.Unix.json",
                                                           "./",                                 "/",   "/projects/app1",        Objects.Directories, MatchCasing.PlatformDefault, false,  "/projects/app1/build/", "/projects/app1/src/", "/projects/app1/tests/"),

        new GlobEnumerateTheoryElement(TestFileLine("Unix: Current dir ./*/"),
                                                   "FakeFSFiles/FakeFS4.Unix.json",
                                                           "./*/",                               "/",   "/projects/app1",        Objects.Directories, MatchCasing.PlatformDefault, false,  "/projects/app1/build/", "/projects/app1/src/", "/projects/app1/tests/"),

        new GlobEnumerateTheoryElement(TestFileLine("Unix: Multiple ./ in path ./.././app1/*.md"),
                                                   "FakeFSFiles/FakeFS4.Unix.json",
                                                           "./.././app1/*.md",                   "/",   "/projects/app2",        Objects.Files,   MatchCasing.PlatformDefault, false,  "/projects/app1/README.md"),

        // ==========================================================================================================
        // PARENT DIRECTORY (..) PATTERNS - Unix
        // ==========================================================================================================
        //                                         fsFile  glob                                  cwd    start                    objects          MatchCasing                  throws  results...
        new GlobEnumerateTheoryElement(TestFileLine("Unix: Parent dir ../*.md from /projects/app1"),
                                                   "FakeFSFiles/FakeFS4.Unix.json",
                                                           "../*.md",                            "/",   "/projects/app1",        Objects.Files,   MatchCasing.PlatformDefault, false,  "/projects/OVERVIEW.md"),

        new GlobEnumerateTheoryElement(TestFileLine("Unix: Parent dir ../app2/*.txt from /projects/app1"),
                                                   "FakeFSFiles/FakeFS4.Unix.json",
                                                           "../app2/*.txt",                      "/",   "/projects/app1",        Objects.Files,   MatchCasing.PlatformDefault, false,  "/projects/app2/README.txt", "/projects/app2/requirements.txt"),

        new GlobEnumerateTheoryElement(TestFileLine("Unix: Parent dir ../shared/lib/*.c"),
                                                   "FakeFSFiles/FakeFS4.Unix.json",
                                                           "../shared/lib/*.c",                  "/",   "/projects/app1",        Objects.Files,   MatchCasing.PlatformDefault, false,  "/projects/shared/lib/common.c"),

        new GlobEnumerateTheoryElement(TestFileLine("Unix: Parent dir ../shared/include/*.h"),
                                                   "FakeFSFiles/FakeFS4.Unix.json",
                                                           "../shared/include/*.h",              "/",   "/projects/app1",        Objects.Files,   MatchCasing.PlatformDefault, false,  "/projects/shared/include/constants.h", "/projects/shared/include/types.h"),

        new GlobEnumerateTheoryElement(TestFileLine("Unix: Double parent ../../docs/*.md from /projects/app1/src"),
                                                   "FakeFSFiles/FakeFS4.Unix.json",
                                                           "../../../docs/*.md",                 "/",   "/projects/app1/src",    Objects.Files,   MatchCasing.PlatformDefault, false,  "/docs/index.md"),

        new GlobEnumerateTheoryElement(TestFileLine("Unix: Double parent ../../docs/**/*.md from /projects/app1/src"),
                                                   "FakeFSFiles/FakeFS4.Unix.json",
                                                           "../../../docs/**/*.md",              "/",   "/projects/app1/src",    Objects.Files,   MatchCasing.PlatformDefault, false,  "/docs/api/guide.md", "/docs/api/reference.md", "/docs/index.md", "/docs/tutorials/advanced.md", "/docs/tutorials/getting-started.md"),

        new GlobEnumerateTheoryElement(TestFileLine("Unix: Triple parent ../../../LICENSE from /projects/app1/src"),
                                                   "FakeFSFiles/FakeFS4.Unix.json",
                                                           "../../../LICENSE",                   "/",   "/projects/app1/src",    Objects.Files,   MatchCasing.PlatformDefault, false,  "/LICENSE"),

        new GlobEnumerateTheoryElement(TestFileLine("Unix: Parent with wildcard ../*/*.md from /projects/app1"),
                                                   "FakeFSFiles/FakeFS4.Unix.json",
                                                           "../*/*.md",                          "/",   "/projects/app1",        Objects.Files,   MatchCasing.PlatformDefault, false,  "/projects/app1/README.md"),

        new GlobEnumerateTheoryElement(TestFileLine("Unix: Parent recursive ../**/*.py from /projects/app1"),
                                                   "FakeFSFiles/FakeFS4.Unix.json",
                                                           "../**/*.py",                         "/",   "/projects/app1",        Objects.Files,   MatchCasing.PlatformDefault, false,  "/projects/app2/src/app.py", "/projects/app2/src/config.py", "/projects/app2/tests/test_app.py"),

        new GlobEnumerateTheoryElement(TestFileLine("Unix: Parent dir ../ lists parent directories"),
                                                   "FakeFSFiles/FakeFS4.Unix.json",
                                                           "../",                                "/",   "/projects/app1",        Objects.Directories, MatchCasing.PlatformDefault, false,  "/projects/app1/", "/projects/app2/", "/projects/shared/"),

        new GlobEnumerateTheoryElement(TestFileLine("Unix: Parent dir ../*/"),
                                                   "FakeFSFiles/FakeFS4.Unix.json",
                                                           "../*/",                              "/",   "/projects/app1",        Objects.Directories, MatchCasing.PlatformDefault, false,  "/projects/app1/", "/projects/app2/", "/projects/shared/"),

        new GlobEnumerateTheoryElement(TestFileLine("Unix: Complex ../app2/src/*.py from /projects/app1/tests"),
                                                   "FakeFSFiles/FakeFS4.Unix.json",
                                                           "../../app2/src/*.py",                "/",   "/projects/app1/tests",  Objects.Files,   MatchCasing.PlatformDefault, false,  "/projects/app2/src/app.py", "/projects/app2/src/config.py"),

        // ==========================================================================================================
        // MIXED . AND .. PATTERNS - Unix
        // ==========================================================================================================
        //                                         fsFile  glob                                  cwd    start                    objects          MatchCasing                  throws  results...
        new GlobEnumerateTheoryElement(TestFileLine("Unix: Mixed ./../app2/*.txt from /projects/app1"),
                                                   "FakeFSFiles/FakeFS4.Unix.json",
                                                           "./../app2/*.txt",                    "/",   "/projects/app1",        Objects.Files,   MatchCasing.PlatformDefault, false,  "/projects/app2/README.txt", "/projects/app2/requirements.txt"),

        new GlobEnumerateTheoryElement(TestFileLine("Unix: Mixed .././app2/*.txt (redundant ./)"),
                                                   "FakeFSFiles/FakeFS4.Unix.json",
                                                           "./.././app2/*.txt",                  "/",   "/projects/app1",        Objects.Files,   MatchCasing.PlatformDefault, false,  "/projects/app2/README.txt", "/projects/app2/requirements.txt"),

        new GlobEnumerateTheoryElement(TestFileLine("Unix: Complex ././../app2/./src/*.py"),
                                                   "FakeFSFiles/FakeFS4.Unix.json",
                                                           "././../app2/./src/*.py",             "/",   "/projects/app1",        Objects.Files,   MatchCasing.PlatformDefault, false,  "/projects/app2/src/app.py", "/projects/app2/src/config.py"),

        new GlobEnumerateTheoryElement(TestFileLine("Unix: Navigate up and down ../../projects/app1/*.md from /projects/app1/src"),
                                                   "FakeFSFiles/FakeFS4.Unix.json",
                                                           "../../../projects/app1/*.md",        "/",   "/projects/app1/src",    Objects.Files,   MatchCasing.PlatformDefault, false,  "/projects/app1/README.md"),

        new GlobEnumerateTheoryElement(TestFileLine("Unix: Sibling directory ../app1/src/*.c from /projects/app2"),
                                                   "FakeFSFiles/FakeFS4.Unix.json",
                                                           "../app1/src/*.c",                    "/",   "/projects/app2",        Objects.Files,   MatchCasing.PlatformDefault, false,  "/projects/app1/src/main.c", "/projects/app1/src/util.c"),

        new GlobEnumerateTheoryElement(TestFileLine("Unix: Recursive from parent ../app1/**/*.c from /projects/app2"),
                                                   "FakeFSFiles/FakeFS4.Unix.json",
                                                           "../app1/**/*.c",                     "/",   "/projects/app2",        Objects.Files,   MatchCasing.PlatformDefault, false,  "/projects/app1/src/main.c", "/projects/app1/src/util.c", "/projects/app1/tests/test_main.c", "/projects/app1/tests/test_util.c"),

        // ==========================================================================================================
        // CURRENT DIRECTORY (.) PATTERNS - Windows
        // ==========================================================================================================
        //                                         fsFile  glob                                  cwd    start                    objects          MatchCasing                  throws  results...
        new GlobEnumerateTheoryElement(TestFileLine("Win: Current dir ./*.md from C:/projects/app1"),
                                                   "FakeFSFiles/FakeFS4.Win.json",
                                                           "./*.md",                             "C:/", "C:/projects/app1",      Objects.Files,   MatchCasing.PlatformDefault, false,  "C:/projects/app1/README.md"),

        new GlobEnumerateTheoryElement(TestFileLine("Win: Current dir ./src/*.c"),
                                                   "FakeFSFiles/FakeFS4.Win.json",
                                                           "./src/*.c",                          "C:/", "C:/projects/app1",      Objects.Files,   MatchCasing.PlatformDefault, false,  "C:/projects/app1/src/main.c", "C:/projects/app1/src/util.c"),

        new GlobEnumerateTheoryElement(TestFileLine("Win: Current dir ./src/*.h"),
                                                   "FakeFSFiles/FakeFS4.Win.json",
                                                           "./src/*.h",                          "C:/", "C:/projects/app1",      Objects.Files,   MatchCasing.PlatformDefault, false,  "C:/projects/app1/src/app.h"),

        new GlobEnumerateTheoryElement(TestFileLine("Win: Current dir ./tests/*.c"),
                                                   "FakeFSFiles/FakeFS4.Win.json",
                                                           "./tests/*.c",                        "C:/", "C:/projects/app1",      Objects.Files,   MatchCasing.PlatformDefault, false,  "C:/projects/app1/tests/test_main.c", "C:/projects/app1/tests/test_util.c"),

        new GlobEnumerateTheoryElement(TestFileLine("Win: Current dir with recursive ./**/*.c"),
                                                   "FakeFSFiles/FakeFS4.Win.json",
                                                           "./**/*.c",                           "C:/", "C:/projects/app1",      Objects.Files,   MatchCasing.PlatformDefault, false,  "C:/projects/app1/src/main.c", "C:/projects/app1/src/util.c", "C:/projects/app1/tests/test_main.c", "C:/projects/app1/tests/test_util.c"),

        new GlobEnumerateTheoryElement(TestFileLine("Win: Current dir ./*/* from C:/projects"),
                                                   "FakeFSFiles/FakeFS4.Win.json",
                                                           "./*/*",                              "C:/", "C:/projects",           Objects.Files,   MatchCasing.PlatformDefault, false,  "C:/projects/app1/Makefile", "C:/projects/app1/README.md", "C:/projects/app2/README.txt", "C:/projects/app2/requirements.txt", "C:/projects/shared/LICENSE"),

        new GlobEnumerateTheoryElement(TestFileLine("Win: Current dir with backslash .\\src\\*.c"),
                                                   "FakeFSFiles/FakeFS4.Win.json",
                                                           ".\\src\\*.c",                        "C:/", "C:/projects/app1",      Objects.Files,   MatchCasing.PlatformDefault, false,  "C:/projects/app1/src/main.c", "C:/projects/app1/src/util.c"),

        // ==========================================================================================================
        // PARENT DIRECTORY (..) PATTERNS - Windows
        // ==========================================================================================================
        //                                         fsFile  glob                                  cwd    start                    objects          MatchCasing                  throws  results...
        new GlobEnumerateTheoryElement(TestFileLine("Win: Parent dir ../*.md from C:/projects/app1"),
                                                   "FakeFSFiles/FakeFS4.Win.json",
                                                           "../*.md",                            "C:/", "C:/projects/app1",      Objects.Files,   MatchCasing.PlatformDefault, false,  "C:/projects/OVERVIEW.md"),

        new GlobEnumerateTheoryElement(TestFileLine("Win: Parent dir ../app2/*.txt from C:/projects/app1"),
                                                   "FakeFSFiles/FakeFS4.Win.json",
                                                           "../app2/*.txt",                      "C:/", "C:/projects/app1",      Objects.Files,   MatchCasing.PlatformDefault, false,  "C:/projects/app2/README.txt", "C:/projects/app2/requirements.txt"),

        new GlobEnumerateTheoryElement(TestFileLine("Win: Parent dir ../shared/lib/*.c"),
                                                   "FakeFSFiles/FakeFS4.Win.json",
                                                           "../shared/lib/*.c",                  "C:/", "C:/projects/app1",      Objects.Files,   MatchCasing.PlatformDefault, false,  "C:/projects/shared/lib/common.c"),

        new GlobEnumerateTheoryElement(TestFileLine("Win: Parent dir ../shared/include/*.h"),
                                                   "FakeFSFiles/FakeFS4.Win.json",
                                                           "../shared/include/*.h",              "C:/", "C:/projects/app1",      Objects.Files,   MatchCasing.PlatformDefault, false,  "C:/projects/shared/include/constants.h", "C:/projects/shared/include/types.h"),

        new GlobEnumerateTheoryElement(TestFileLine("Win: Double parent ../../docs/*.md from C:/projects/app1/src"),
                                                   "FakeFSFiles/FakeFS4.Win.json",
                                                           "../../../docs/*.md",                  "C:/", "C:/projects/app1/src",  Objects.Files,   MatchCasing.PlatformDefault, false,  "C:/docs/index.md"),

        new GlobEnumerateTheoryElement(TestFileLine("Win: Double parent ../../docs/**/*.md from C:/projects/app1/src"),
                                                   "FakeFSFiles/FakeFS4.Win.json",
                                                           "../../../docs/**/*.md",               "C:/", "C:/projects/app1/src",  Objects.Files,   MatchCasing.PlatformDefault, false,  "C:/docs/api/guide.md", "C:/docs/api/reference.md", "C:/docs/index.md", "C:/docs/tutorials/advanced.md", "C:/docs/tutorials/getting-started.md"),

        new GlobEnumerateTheoryElement(TestFileLine("Win: Triple parent ../../../LICENSE from C:/projects/app1/src"),
                                                   "FakeFSFiles/FakeFS4.Win.json",
                                                           "../../../LICENSE",                   "C:/", "C:/projects/app1/src",  Objects.Files,   MatchCasing.PlatformDefault, false,  "C:/LICENSE"),

        new GlobEnumerateTheoryElement(TestFileLine("Win: Parent with wildcard ../*/*.md from C:/projects/app1"),
                                                   "FakeFSFiles/FakeFS4.Win.json",
                                                           "../*/*.md",                          "C:/", "C:/projects/app1",      Objects.Files,   MatchCasing.PlatformDefault, false,  "C:/projects/app1/README.md"),

        new GlobEnumerateTheoryElement(TestFileLine("Win: Parent recursive ../**/*.py from C:/projects/app1"),
                                                   "FakeFSFiles/FakeFS4.Win.json",
                                                           "../**/*.py",                         "C:/", "C:/projects/app1",      Objects.Files,   MatchCasing.PlatformDefault, false,  "C:/projects/app2/src/app.py", "C:/projects/app2/src/config.py", "C:/projects/app2/tests/test_app.py"),

        new GlobEnumerateTheoryElement(TestFileLine("Win: Parent dir with backslash ..\\app2\\*.txt"),
                                                   "FakeFSFiles/FakeFS4.Win.json",
                                                           "..\\app2\\*.txt",                    "C:/", "C:/projects/app1",      Objects.Files,   MatchCasing.PlatformDefault, false,  "C:/projects/app2/README.txt", "C:/projects/app2/requirements.txt"),

        new GlobEnumerateTheoryElement(TestFileLine("Win: Complex ../app2/src/*.py from C:/projects/app1/tests"),
                                                   "FakeFSFiles/FakeFS4.Win.json",
                                                           "../../app2/src/*.py",                "C:/", "C:/projects/app1/tests",Objects.Files,   MatchCasing.PlatformDefault, false,  "C:/projects/app2/src/app.py", "C:/projects/app2/src/config.py"),

        // ==========================================================================================================
        // MIXED . AND .. PATTERNS - Windows
        // ==========================================================================================================
        //                                         fsFile  glob                                  cwd    start                    objects          MatchCasing                  throws  results...
        new GlobEnumerateTheoryElement(TestFileLine("Win: Mixed ./../app2/*.txt from C:/projects/app1"),
                                                   "FakeFSFiles/FakeFS4.Win.json",
                                                           "./../app2/*.txt",                    "C:/", "C:/projects/app1",      Objects.Files,   MatchCasing.PlatformDefault, false,  "C:/projects/app2/README.txt", "C:/projects/app2/requirements.txt"),

        new GlobEnumerateTheoryElement(TestFileLine("Win: Mixed .././app2/*.txt (redundant ./)"),
                                                   "FakeFSFiles/FakeFS4.Win.json",
                                                           "./.././app2/*.txt",                  "C:/", "C:/projects/app1",      Objects.Files,   MatchCasing.PlatformDefault, false,  "C:/projects/app2/README.txt", "C:/projects/app2/requirements.txt"),

        new GlobEnumerateTheoryElement(TestFileLine("Win: Complex ././../app2/./src/*.py"),
                                                   "FakeFSFiles/FakeFS4.Win.json",
                                                           "././../app2/./src/*.py",             "C:/", "C:/projects/app1",      Objects.Files,   MatchCasing.PlatformDefault, false,  "C:/projects/app2/src/app.py", "C:/projects/app2/src/config.py"),

        new GlobEnumerateTheoryElement(TestFileLine("Win: Navigate up and down ../../projects/app1/*.md from C:/projects/app1/src"),
                                                   "FakeFSFiles/FakeFS4.Win.json",
                                                           "../../../projects/app1/*.md",        "C:/", "C:/projects/app1/src",  Objects.Files,   MatchCasing.PlatformDefault, false,  "C:/projects/app1/README.md"),

        new GlobEnumerateTheoryElement(TestFileLine("Win: Sibling directory ../app1/src/*.c from C:/projects/app2"),
                                                   "FakeFSFiles/FakeFS4.Win.json",
                                                           "../app1/src/*.c",                    "C:/", "C:/projects/app2",      Objects.Files,   MatchCasing.PlatformDefault, false,  "C:/projects/app1/src/main.c", "C:/projects/app1/src/util.c"),

        new GlobEnumerateTheoryElement(TestFileLine("Win: Recursive from parent ../app1/**/*.c from C:/projects/app2"),
                                                   "FakeFSFiles/FakeFS4.Win.json",
                                                           "../app1/**/*.c",                     "C:/", "C:/projects/app2",      Objects.Files,   MatchCasing.PlatformDefault, false,  "C:/projects/app1/src/main.c", "C:/projects/app1/src/util.c", "C:/projects/app1/tests/test_main.c", "C:/projects/app1/tests/test_util.c"),

        // ==========================================================================================================
        // EDGE CASES WITH . AND .. - Both Unix and Windows
        // ==========================================================================================================
        //                                         fsFile  glob                                  cwd    start                    objects          MatchCasing                  throws  results...
        new GlobEnumerateTheoryElement(TestFileLine("Unix: Many consecutive dots ././././*.md"),
                                                   "FakeFSFiles/FakeFS4.Unix.json",
                                                           "././././*.md",                       "/",   "/projects/app1",        Objects.Files,   MatchCasing.PlatformDefault, false,  "/projects/app1/README.md"),

        new GlobEnumerateTheoryElement(TestFileLine("Unix: Many parent traversals ../../../../LICENSE from deep path"),
                                                   "FakeFSFiles/FakeFS4.Unix.json",
                                                           "../../../../LICENSE",                "/",   "/projects/app1/src",    Objects.Files,   MatchCasing.PlatformDefault, false,   "/LICENSE"),

        new GlobEnumerateTheoryElement(TestFileLine("Win: Many consecutive dots ././././*.md"),
                                                   "FakeFSFiles/FakeFS4.Win.json",
                                                           "././././*.md",                       "C:/", "C:/projects/app1",      Objects.Files,   MatchCasing.PlatformDefault, false,  "C:/projects/app1/README.md"),

        new GlobEnumerateTheoryElement(TestFileLine("Win: Many parent traversals ../../../../LICENSE from deep path"),
                                                   "FakeFSFiles/FakeFS4.Win.json",
                                                           "../../../../LICENSE",                "C:/", "C:/projects/app1/src",  Objects.Files,   MatchCasing.PlatformDefault, false,  "C:/LICENSE"),

        new GlobEnumerateTheoryElement(TestFileLine("Unix: Parent beyond root ../../../../../../../* from /projects"),
                                                   "FakeFSFiles/FakeFS4.Unix.json",
                                                           "../../../../../../../*",             "/",   "/projects",             Objects.Files,   MatchCasing.PlatformDefault, false,  "/LICENSE", "/README.md"),

        new GlobEnumerateTheoryElement(TestFileLine("Win: Parent beyond root ../../../../../../../* from C:/projects"),
                                                   "FakeFSFiles/FakeFS4.Win.json",
                                                           "../../../../../../../*",             "C:/", "C:/projects",           Objects.Files,   MatchCasing.PlatformDefault, false,  "C:/LICENSE", "C:/README.md"),
    ];
}