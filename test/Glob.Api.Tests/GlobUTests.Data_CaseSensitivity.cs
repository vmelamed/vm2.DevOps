namespace vm2.DevOps.Glob.Api.Tests;

public partial class GlobEnumeratorTests
{
    public static TheoryData<UnitTestElement> Enumerate_CaseSensitivity =
    [
        // ==========================================================================================================
        // CASE SENSITIVITY: Unix (default: case-sensitive)
        // ==========================================================================================================
        //                                         fsFile  glob                                  cwd    start       objects          _matchCasing                  throws  results...
        new UnitTestElement(TestFileLine("Unix: Match lowercase file only (default: case-sensitive)"),
                                                   "FakeFSFiles/FakeFS5.Unix.json",
                                                           "/mixed/*/file.txt",                  "/",   "/",        Objects.Files,   MatchCasing.PlatformDefault, false,  "/mixed/CaseSensitive/file.txt"),

        new UnitTestElement(TestFileLine("Unix: Match uppercase FILE.TXT only (default: case-sensitive)"),
                                                   "FakeFSFiles/FakeFS5.Unix.json",
                                                           "/mixed/*/FILE.TXT",                  "/",   "/",        Objects.Files,   MatchCasing.PlatformDefault, false,  "/mixed/CaseSensitive/FILE.TXT"),

        new UnitTestElement(TestFileLine("Unix: Match mixed case File.txt only"),
                                                   "FakeFSFiles/FakeFS5.Unix.json",
                                                           "/mixed/*/File.txt",                    "/",   "/",        Objects.Files,   MatchCasing.PlatformDefault, false,  "/mixed/CaseSensitive/File.txt"),

        new UnitTestElement(TestFileLine("Unix: All *.txt files (case matters)"),
                                                   "FakeFSFiles/FakeFS5.Unix.json",
                                                           "/mixed/*/*.txt",                     "/",   "/",        Objects.Files,   MatchCasing.PlatformDefault, false,  "/mixed/CaseSensitive/File.txt", "/mixed/CaseSensitive/file.txt"),

        new UnitTestElement(TestFileLine("Unix: All *.TXT files (case matters)"),
                                                   "FakeFSFiles/FakeFS5.Unix.json",
                                                           "/mixed/*/*.TXT",                     "/",   "/",        Objects.Files,   MatchCasing.PlatformDefault, false,  "/mixed/CaseSensitive/FILE.TXT"),

        new UnitTestElement(TestFileLine("Unix: Directory name case matters - CaseSensitive"),
                                                   "FakeFSFiles/FakeFS5.Unix.json",
                                                           "/mixed/CaseSensitive/*",             "/",   "/",        Objects.Files,   MatchCasing.PlatformDefault, false,  "/mixed/CaseSensitive/FILE.TXT", "/mixed/CaseSensitive/File.txt", "/mixed/CaseSensitive/TEST.DAT", "/mixed/CaseSensitive/Test.dat", "/mixed/CaseSensitive/file.txt", "/mixed/CaseSensitive/test.dat"),

        new UnitTestElement(TestFileLine("Unix: Directory name case matters - casesensitive"),
                                                   "FakeFSFiles/FakeFS5.Unix.json",
                                                           "/mixed/casesensitive/*",             "/",   "/",        Objects.Files,   MatchCasing.PlatformDefault, false,  "/mixed/casesensitive/README.md", "/mixed/casesensitive/ReadMe.md", "/mixed/casesensitive/readme.md"),

        new UnitTestElement(TestFileLine("Unix: Directory name case matters - CASESENSITIVE"),
                                                   "FakeFSFiles/FakeFS5.Unix.json",
                                                           "/mixed/CASESENSITIVE/*",             "/",   "/",        Objects.Files,   MatchCasing.PlatformDefault, false,  "/mixed/CASESENSITIVE/DATA.JSON", "/mixed/CASESENSITIVE/Data.json", "/mixed/CASESENSITIVE/data.json"),

        new UnitTestElement(TestFileLine("Unix: Wildcard pattern - all three directories separately"),
                                                   "FakeFSFiles/FakeFS5.Unix.json",
                                                           "/mixed/CaseSensitive",               "/",   "/",        Objects.Directories, MatchCasing.PlatformDefault, false,  "/mixed/CaseSensitive/"),

        new UnitTestElement(TestFileLine("Unix: Case-sensitive glob - exact file match"),
                                                   "FakeFSFiles/FakeFS5.Unix.json",
                                                           "/mixed/index.html",                  "/",   "/",        Objects.Files,   MatchCasing.PlatformDefault, false,  "/mixed/index.html"),

        new UnitTestElement(TestFileLine("Unix: Case-sensitive glob - different case no match"),
                                                   "FakeFSFiles/FakeFS5.Unix.json",
                                                           "/mixed/Index.html",                  "/",   "/",        Objects.Files,   MatchCasing.PlatformDefault, false,  "/mixed/Index.html"),

        // ==========================================================================================================
        // CASE SENSITIVITY: Unix with EXPLICIT _matchCasing.CaseInsensitive override
        // ==========================================================================================================
        //                                         fsFile  glob                                  cwd    start       objects          _matchCasing                  throws  results...
        new UnitTestElement(TestFileLine("Unix: OVERRIDE to case-insensitive - file.txt matches all"),
                                                   "FakeFSFiles/FakeFS5.Unix.json",
                                                           "/mixed/*/file.txt",                  "/",   "/",        Objects.Files,   MatchCasing.CaseInsensitive, false,  "/mixed/CaseSensitive/FILE.TXT", "/mixed/CaseSensitive/File.txt", "/mixed/CaseSensitive/file.txt"),

        new UnitTestElement(TestFileLine("Unix: OVERRIDE to case-insensitive - FILE.TXT matches all"),
                                                   "FakeFSFiles/FakeFS5.Unix.json",
                                                           "/mixed/*/FILE.TXT",                  "/",   "/",        Objects.Files,   MatchCasing.CaseInsensitive, false,  "/mixed/CaseSensitive/FILE.TXT", "/mixed/CaseSensitive/File.txt", "/mixed/CaseSensitive/file.txt"),

        new UnitTestElement(TestFileLine("Unix: OVERRIDE to case-insensitive - *.txt matches all variations"),
                                                   "FakeFSFiles/FakeFS5.Unix.json",
                                                           "/mixed/*/*.txt",                     "/",   "/",        Objects.Files,   MatchCasing.CaseInsensitive, false,  "/mixed/CaseSensitive/FILE.TXT", "/mixed/CaseSensitive/File.txt", "/mixed/CaseSensitive/file.txt"),

        new UnitTestElement(TestFileLine("Unix: OVERRIDE to case-insensitive - directory name casesensitive matches all"),
                                                   "FakeFSFiles/FakeFS5.Unix.json",
                                                           "/mixed/casesensitive/*",             "/",   "/",        Objects.Files,   MatchCasing.CaseInsensitive, false,  "/mixed/CASESENSITIVE/DATA.JSON", "/mixed/CASESENSITIVE/Data.json", "/mixed/CASESENSITIVE/data.json", "/mixed/CaseSensitive/FILE.TXT", "/mixed/CaseSensitive/File.txt", "/mixed/CaseSensitive/TEST.DAT", "/mixed/CaseSensitive/Test.dat", "/mixed/CaseSensitive/file.txt", "/mixed/CaseSensitive/test.dat", "/mixed/casesensitive/README.md", "/mixed/casesensitive/ReadMe.md", "/mixed/casesensitive/readme.md"),

        new UnitTestElement(TestFileLine("Unix: OVERRIDE to case-insensitive - index.html matches all variations"),
                                                   "FakeFSFiles/FakeFS5.Unix.json",
                                                           "/mixed/index.html",                  "/",   "/",        Objects.Files,   MatchCasing.CaseInsensitive, false,  "/mixed/INDEX.HTML", "/mixed/Index.html", "/mixed/index.html"),

        new UnitTestElement(TestFileLine("Unix: OVERRIDE to case-insensitive - INDEX.HTML matches all variations"),
                                                   "FakeFSFiles/FakeFS5.Unix.json",
                                                           "/mixed/INDEX.HTML",                  "/",   "/",        Objects.Files,   MatchCasing.CaseInsensitive, false,  "/mixed/INDEX.HTML", "/mixed/Index.html", "/mixed/index.html"),

        new UnitTestElement(TestFileLine("Unix: OVERRIDE to case-insensitive - *.dat matches all"),
                                                   "FakeFSFiles/FakeFS5.Unix.json",
                                                           "/mixed/*/*.dat",                     "/",   "/",        Objects.Files,   MatchCasing.CaseInsensitive, false,  "/mixed/CaseSensitive/TEST.DAT", "/mixed/CaseSensitive/Test.dat", "/mixed/CaseSensitive/test.dat"),

        new UnitTestElement(TestFileLine("Unix: OVERRIDE to case-insensitive - recursive *.md"),
                                                   "FakeFSFiles/FakeFS5.Unix.json",
                                                           "/mixed/**/*.md",                     "/",   "/",        Objects.Files,   MatchCasing.CaseInsensitive, false,  "/mixed/casesensitive/README.md", "/mixed/casesensitive/ReadMe.md", "/mixed/casesensitive/readme.md"),

        // ==========================================================================================================
        // CASE SENSITIVITY: Unix with EXPLICIT _matchCasing.CaseSensitive (redundant but explicit)
        // ==========================================================================================================
        //                                         fsFile  glob                                  cwd    start       objects          _matchCasing                  throws  results...
        new UnitTestElement(TestFileLine("Unix: EXPLICIT case-sensitive - file.txt only"),
                                                   "FakeFSFiles/FakeFS5.Unix.json",
                                                           "/mixed/*/file.txt",                  "/",   "/",        Objects.Files,   MatchCasing.CaseSensitive,   false,  "/mixed/CaseSensitive/file.txt"),

        new UnitTestElement(TestFileLine("Unix: EXPLICIT case-sensitive - Test.dat only"),
                                                   "FakeFSFiles/FakeFS5.Unix.json",
                                                           "/mixed/*/Test.dat",                  "/",   "/",        Objects.Files,   MatchCasing.CaseSensitive,   false,  "/mixed/CaseSensitive/Test.dat"),

        // ==========================================================================================================
        // CASE SENSITIVITY: Windows (default: case-insensitive)
        // ==========================================================================================================
        //                                         fsFile  glob                                  cwd    start       objects          _matchCasing                  throws  results...
        new UnitTestElement(TestFileLine("Win: Match index.html (default: case-insensitive)"),
                                                   "FakeFSFiles/FakeFS5.Win.json",
                                                           "C:/mixed/index.html",                "C:/", "C:/",      Objects.Files,   MatchCasing.PlatformDefault, false,  "C:/mixed/Index.html"),

        new UnitTestElement(TestFileLine("Win: Match INDEX.HTML (default: case-insensitive)"),
                                                   "FakeFSFiles/FakeFS5.Win.json",
                                                           "C:/mixed/INDEX.HTML",                "C:/", "C:/",      Objects.Files,   MatchCasing.PlatformDefault, false,  "C:/mixed/Index.html"),

        new UnitTestElement(TestFileLine("Win: Match Index.html (default: case-insensitive)"),
                                                   "FakeFSFiles/FakeFS5.Win.json",
                                                           "C:/mixed/Index.html",                "C:/", "C:/",      Objects.Files,   MatchCasing.PlatformDefault, false,  "C:/mixed/Index.html"),

        new UnitTestElement(TestFileLine("Win: Wildcard *.html (case-insensitive)"),
                                                   "FakeFSFiles/FakeFS5.Win.json",
                                                           "C:/mixed/*.html",                    "C:/", "C:/",      Objects.Files,   MatchCasing.PlatformDefault, false,  "C:/mixed/Index.html"),

        new UnitTestElement(TestFileLine("Win: Wildcard *.HTML (case-insensitive)"),
                                                   "FakeFSFiles/FakeFS5.Win.json",
                                                           "C:/mixed/*.HTML",                    "C:/", "C:/",      Objects.Files,   MatchCasing.PlatformDefault, false,  "C:/mixed/Index.html"),

        new UnitTestElement(TestFileLine("Win: Match test.dat (case-insensitive)"),
                                                   "FakeFSFiles/FakeFS5.Win.json",
                                                           "C:/mixed/test.dat",                  "C:/", "C:/",      Objects.Files,   MatchCasing.PlatformDefault, false,  "C:/mixed/Test.dat"),

        new UnitTestElement(TestFileLine("Win: Match TEST.DAT (case-insensitive)"),
                                                   "FakeFSFiles/FakeFS5.Win.json",
                                                           "C:/mixed/TEST.DAT",                  "C:/", "C:/",      Objects.Files,   MatchCasing.PlatformDefault, false,  "C:/mixed/Test.dat"),

        new UnitTestElement(TestFileLine("Win: Match readme.md (case-insensitive)"),
                                                   "FakeFSFiles/FakeFS5.Win.json",
                                                           "C:/mixed/readme.md",                 "C:/", "C:/",      Objects.Files,   MatchCasing.PlatformDefault, false,  "C:/mixed/readme.md"),

        new UnitTestElement(TestFileLine("Win: Match README.MD (case-insensitive)"),
                                                   "FakeFSFiles/FakeFS5.Win.json",
                                                           "C:/mixed/README.MD",                 "C:/", "C:/",      Objects.Files,   MatchCasing.PlatformDefault, false,  "C:/mixed/readme.md"),

        // ==========================================================================================================
        // CASE SENSITIVITY: Windows with EXPLICIT _matchCasing.CaseSensitive override
        // ==========================================================================================================
        //                                         fsFile  glob                                  cwd    start       objects          _matchCasing                  throws  results...
        new UnitTestElement(TestFileLine("Win: OVERRIDE to case-sensitive - Index.html only"),
                                                   "FakeFSFiles/FakeFS5.Win.json",
                                                           "C:/mixed/Index.html",                "C:/", "C:/",      Objects.Files,   MatchCasing.CaseSensitive,   false,  "C:/mixed/Index.html"),

        new UnitTestElement(TestFileLine("Win: OVERRIDE to case-sensitive - index.html no match"),
                                                   "FakeFSFiles/FakeFS5.Win.json",
                                                           "C:/mixed/index.html",                "C:/", "C:/",      Objects.Files,   MatchCasing.CaseSensitive,   false),

        new UnitTestElement(TestFileLine("Win: OVERRIDE to case-sensitive - INDEX.HTML no match"),
                                                   "FakeFSFiles/FakeFS5.Win.json",
                                                           "C:/mixed/INDEX.HTML",                "C:/", "C:/",      Objects.Files,   MatchCasing.CaseSensitive,   false),

        new UnitTestElement(TestFileLine("Win: OVERRIDE to case-sensitive - Test.dat only"),
                                                   "FakeFSFiles/FakeFS5.Win.json",
                                                           "C:/mixed/Test.dat",                  "C:/", "C:/",      Objects.Files,   MatchCasing.CaseSensitive,   false,  "C:/mixed/Test.dat"),

        new UnitTestElement(TestFileLine("Win: OVERRIDE to case-sensitive - test.dat no match"),
                                                   "FakeFSFiles/FakeFS5.Win.json",
                                                           "C:/mixed/test.dat",                  "C:/", "C:/",      Objects.Files,   MatchCasing.CaseSensitive,   false),

        new UnitTestElement(TestFileLine("Win: OVERRIDE to case-sensitive - readme.md only"),
                                                   "FakeFSFiles/FakeFS5.Win.json",
                                                           "C:/mixed/readme.md",                 "C:/", "C:/",      Objects.Files,   MatchCasing.CaseSensitive,   false,  "C:/mixed/readme.md"),

        new UnitTestElement(TestFileLine("Win: OVERRIDE to case-sensitive - README.md no match"),
                                                   "FakeFSFiles/FakeFS5.Win.json",
                                                           "C:/mixed/README.md",                 "C:/", "C:/",      Objects.Files,   MatchCasing.CaseSensitive,   false),

        // ==========================================================================================================
        // CASE SENSITIVITY: Windows with EXPLICIT _matchCasing.CaseInsensitive (redundant but explicit)
        // ==========================================================================================================
        //                                         fsFile  glob                                  cwd    start       objects          _matchCasing                  throws  results...
        new UnitTestElement(TestFileLine("Win: EXPLICIT case-insensitive - index.html"),
                                                   "FakeFSFiles/FakeFS5.Win.json",
                                                           "C:/mixed/index.html",                "C:/", "C:/",      Objects.Files,   MatchCasing.CaseInsensitive, false,  "C:/mixed/Index.html"),

        new UnitTestElement(TestFileLine("Win: EXPLICIT case-insensitive - INDEX.HTML"),
                                                   "FakeFSFiles/FakeFS5.Win.json",
                                                           "C:/mixed/INDEX.HTML",                "C:/", "C:/",      Objects.Files,   MatchCasing.CaseInsensitive, false,  "C:/mixed/Index.html"),

        // ==========================================================================================================
        // CASE SENSITIVITY: Complex patterns with case variations
        // ==========================================================================================================
        //                                         fsFile  glob                                  cwd    start       objects          _matchCasing                  throws  results...
        new UnitTestElement(TestFileLine("Unix: Bracket expression case-sensitive [Tt]est.dat"),
                                                   "FakeFSFiles/FakeFS5.Unix.json",
                                                           "/mixed/*/[Tt]est.dat",               "/",   "/",        Objects.Files,   MatchCasing.PlatformDefault, false,  "/mixed/CaseSensitive/Test.dat",  "/mixed/CaseSensitive/test.dat"),

        new UnitTestElement(TestFileLine("Unix: Bracket expression case-sensitive [Tt][Ee][Ss][Tt].dat"),
                                                   "FakeFSFiles/FakeFS5.Unix.json",
                                                           "/mixed/*/[Tt][Ee][Ss][Tt].dat",      "/",   "/",        Objects.Files,   MatchCasing.PlatformDefault, false,  "/mixed/CaseSensitive/Test.dat", "/mixed/CaseSensitive/test.dat"),

        new UnitTestElement(TestFileLine("Unix: Character class case-sensitive [[:upper:]]*.dat"),
                                                   "FakeFSFiles/FakeFS5.Unix.json",
                                                           "/mixed/*/[[:upper:]]*.dat",          "/",   "/",        Objects.Files,   MatchCasing.PlatformDefault, false,  "/mixed/CaseSensitive/Test.dat"),

        new UnitTestElement(TestFileLine("Unix: Character class case-sensitive [[:lower:]]*.dat"),
                                                   "FakeFSFiles/FakeFS5.Unix.json",
                                                           "/mixed/*/[[:lower:]]*.dat",          "/",   "/",        Objects.Files,   MatchCasing.PlatformDefault, false,  "/mixed/CaseSensitive/test.dat"),

        new UnitTestElement(TestFileLine("Win: Bracket expression case-insensitive [Tt]est.dat"),
                                                   "FakeFSFiles/FakeFS5.Win.json",
                                                           "C:/mixed/[Tt]est.dat",               "C:/", "C:/",      Objects.Files,   MatchCasing.PlatformDefault, false,  "C:/mixed/Test.dat"),

        new UnitTestElement(TestFileLine("Win: Character class case-insensitive [[:upper:]]*.dat"),
                                                   "FakeFSFiles/FakeFS5.Win.json",
                                                           "C:/mixed/[[:upper:]]*.dat",          "C:/", "C:/",      Objects.Files,   MatchCasing.PlatformDefault, false,  "C:/mixed/Test.dat"),

        new UnitTestElement(TestFileLine("Win: Character class case-insensitive [[:lower:]]*.dat"),
                                                   "FakeFSFiles/FakeFS5.Win.json",
                                                           "C:/mixed/[[:lower:]]*.dat",          "C:/", "C:/",      Objects.Files,   MatchCasing.PlatformDefault, false,  "C:/mixed/Test.dat"),
    ];
}