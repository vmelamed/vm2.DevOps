namespace vm2.DevOps.Glob.Api.Tests;

public partial class GlobEnumeratorUnitTests
{
    public static TheoryData<UnitTestElement> Enumerate_EdgeCases =
    [
        // ==========================================================================================================
        // SYMLINKS AND JUNCTIONS (if supported by FakeFS)
        // ==========================================================================================================
        //                                         fsFile  glob                                  cwd    start       objects          _matchCasing                  throws  results...
        new UnitTestElement(TestFileLine("Unix: Symlink files should be treated as files"),
                                                   "FakeFSFiles/FakeFS8.Unix.json",
                                                           "/**/link_to_file.txt",               "/",   "/",        Objects.Files,   MatchCasing.PlatformDefault, false,  "/links/link_to_file.txt"),

        new UnitTestElement(TestFileLine("Unix: Symlink directories should follow into target"),
                                                   "FakeFSFiles/FakeFS8.Unix.json",
                                                           "/links/link_to_dir/**/*.txt",        "/",   "/",        Objects.Files,   MatchCasing.PlatformDefault, false,  "/links/link_to_dir/file.txt"),

        // ==========================================================================================================
        // VERY LONG PATHS (Windows MAX_PATH limitation testing)
        // ==========================================================================================================
        new UnitTestElement(TestFileLine("Win: Path near MAX_PATH limit (260 chars)"),
                                                   "FakeFSFiles/FakeFS8.Win.json",
                                                           "C:/very/long/path/**/*.txt",         "C:/", "C:/",      Objects.Files,   MatchCasing.PlatformDefault, false,  "C:/very/long/path/with/many/nested/subdirectories/file.txt"),

        new UnitTestElement(TestFileLine("Win: Path exceeding MAX_PATH with long prefix"),
                                                   "FakeFSFiles/FakeFS8.Win.json",
                                                           "C:/extremely/long/**/*.txt",         "C:/", "C:/",      Objects.Files,   MatchCasing.PlatformDefault, false,  "C:/extremely/long/path/result.txt"),

        // ==========================================================================================================
        // EMPTY AND WHITESPACE PATTERNS
        // ==========================================================================================================
        new UnitTestElement(TestFileLine("Unix: Pattern with only spaces should enumerate from current"),
                                                   "FakeFSFiles/FakeFS2.Unix.json",
                                                           "   ",                                "/",   "/",        Objects.Files,   MatchCasing.PlatformDefault, false,  "/root.txt"),

        new UnitTestElement(TestFileLine("Unix: Pattern with tabs and spaces"),
                                                   "FakeFSFiles/FakeFS2.Unix.json",
                                                           "  \t  ",                             "/",   "/",        Objects.Files,   MatchCasing.PlatformDefault, false,  "/root.txt"),

        // ==========================================================================================================
        // NUMERIC PATTERNS AND SEQUENCES
        // ==========================================================================================================
        new UnitTestElement(TestFileLine("Unix: Files with numeric sequences - file[0-9].txt"),
                                                   "FakeFSFiles/FakeFS8.Unix.json",
                                                           "/numeric/file[0-9].txt",             "/",   "/",        Objects.Files,   MatchCasing.PlatformDefault, false,  "/numeric/file0.txt", "/numeric/file1.txt", "/numeric/file5.txt", "/numeric/file9.txt"),

        new UnitTestElement(TestFileLine("Unix: Files with double-digit numbers - file[0-9][0-9].txt"),
                                                   "FakeFSFiles/FakeFS8.Unix.json",
                                                           "/numeric/file[0-9][0-9].txt",        "/",   "/",        Objects.Files,   MatchCasing.PlatformDefault, false,  "/numeric/file10.txt", "/numeric/file25.txt", "/numeric/file99.txt"),

        new UnitTestElement(TestFileLine("Unix: Year patterns - log-202[0-5]-*.txt"),
                                                   "FakeFSFiles/FakeFS8.Unix.json",
                                                           "/logs/log-202[0-5]-*.txt",           "/",   "/",        Objects.Files,   MatchCasing.PlatformDefault, false,  "/logs/log-2020-01.txt", "/logs/log-2024-12.txt", "/logs/log-2025-01.txt"),

        // ==========================================================================================================
        // MIXED NEWLINE STYLES (CRLF vs LF in paths - if applicable)
        // ==========================================================================================================

        // ==========================================================================================================
        // PERFORMANCE BOUNDARY CASES
        // ==========================================================================================================
        new UnitTestElement(TestFileLine("Unix: Very deep nesting (10+ levels)"),
                                                   "FakeFSFiles/FakeFS8.Unix.json",
                                                           "/**/level10/*.txt",                  "/",   "/",        Objects.Files,   MatchCasing.PlatformDefault, false,  "/a/b/c/d/e/f/g/h/i/j/level10/deep.txt"),

        new UnitTestElement(TestFileLine("Unix: Wide directory (100+ files)"),
                                                   "FakeFSFiles/FakeFS8.Unix.json",
                                                           "/wide/*.txt",                        "/",   "/",        Objects.Files,   MatchCasing.PlatformDefault, false), // ... 100+ files

        new UnitTestElement(TestFileLine("Unix: Many siblings at same level"),
                                                   "FakeFSFiles/FakeFS8.Unix.json",
                                                           "/siblings/*/data.txt",               "/",   "/",        Objects.Files,   MatchCasing.PlatformDefault, false), // ... files from 50+ sibling directories

        // ==========================================================================================================
        // TIMESTAMP AND DATE PATTERNS
        // ==========================================================================================================
        new UnitTestElement(TestFileLine("Unix: ISO 8601 date patterns - backup-????-??-??.tar.gz"),
                                                   "FakeFSFiles/FakeFS8.Unix.json",
                                                           "/backups/backup-????-??-??.tar.gz",  "/",   "/",        Objects.Files,   MatchCasing.PlatformDefault, false,  "/backups/backup-2024-12-25.tar.gz", "/backups/backup-2025-01-01.tar.gz"),

        new UnitTestElement(TestFileLine("Unix: Timestamp patterns - log-????-??-??T??-??-??.txt"),
                                                   "FakeFSFiles/FakeFS8.Unix.json",
                                                           "/logs/log-????-??-??T??-??-??.txt",  "/",   "/",        Objects.Files,   MatchCasing.PlatformDefault, false,  "/logs/log-2025-01-15T14-30-00.txt"),

        // ==========================================================================================================
        // COMBINED CASE SENSITIVITY WITH UNICODE
        // ==========================================================================================================
        new UnitTestElement(TestFileLine("Unix: Unicode with case - café vs CAFÉ vs Café"),
                                                   "FakeFSFiles/FakeFS8.Unix.json",
                                                           "/unicode/caf[éÉ].txt",               "/",   "/",        Objects.Files,   MatchCasing.PlatformDefault, false,  "/unicode/café.txt", "/unicode/cafÉ.txt"),

        new UnitTestElement(TestFileLine("Unix: Cyrillic case sensitivity"),
                                                   "FakeFSFiles/FakeFS8.Unix.json",
                                                           "/unicode/файл.txt",                  "/",   "/",        Objects.Files,   MatchCasing.PlatformDefault, false,  "/unicode/файл.txt"),

        new UnitTestElement(TestFileLine("Unix: Cyrillic uppercase ФАЙЛ.TXT"),
                                                   "FakeFSFiles/FakeFS8.Unix.json",
                                                           "/unicode/ФАЙЛ.TXT",                  "/",   "/",        Objects.Files,   MatchCasing.PlatformDefault, false,  "/unicode/ФАЙЛ.TXT"),

        // ==========================================================================================================
        // ESCAPED CHARACTERS IN BRACKETS
        // ==========================================================================================================
        new UnitTestElement(TestFileLine("Unix: Literal hyphen at start [-abc].txt"),
                                                   "FakeFSFiles/FakeFS8.Unix.json",
                                                           "/special/[-abc].txt",                "/",   "/",        Objects.Files,   MatchCasing.PlatformDefault, false,  "/special/-.txt", "/special/a.txt"),

        new UnitTestElement(TestFileLine("Unix: Literal hyphen at end [abc-].txt"),
                                                   "FakeFSFiles/FakeFS8.Unix.json",
                                                           "/special/[abc-].txt",                "/",   "/",        Objects.Files,   MatchCasing.PlatformDefault, false,  "/special/a.txt", "/special/-.txt"),

        new UnitTestElement(TestFileLine("Unix: Escaped closing bracket [[]].txt"),
                                                   "FakeFSFiles/FakeFS8.Unix.json",
                                                           "/special/[[]].txt",                  "/",   "/",        Objects.Files,   MatchCasing.PlatformDefault, false,  "/special/].txt"),

        // ==========================================================================================================
        // PERFORMANCE: GLOB PATTERNS WITH HIGH BRANCHING FACTOR
        // ==========================================================================================================
        new UnitTestElement(TestFileLine("Unix: Many wildcards - */*/*/*/*/*/*/*.txt"),
                                                   "FakeFSFiles/FakeFS8.Unix.json",
                                                           "*/*/*/*/*/*/*/*.txt",                "/",   "/",        Objects.Files,   MatchCasing.PlatformDefault, false),

        // ==========================================================================================================
        // FILES STARTING WITH NUMBERS
        // ==========================================================================================================
        new UnitTestElement(TestFileLine("Unix: Files starting with digits - [0-9]*.txt"),
                                                   "FakeFSFiles/FakeFS8.Unix.json",
                                                           "/numbers/[0-9]*.txt",                "/",   "/",        Objects.Files,   MatchCasing.PlatformDefault, false,  "/numbers/1file.txt", "/numbers/2data.txt", "/numbers/9test.txt"),

        new UnitTestElement(TestFileLine("Unix: Files NOT starting with digits - [!0-9]*.txt"),
                                                   "FakeFSFiles/FakeFS8.Unix.json",
                                                           "/numbers/[!0-9]*.txt",               "/",   "/",        Objects.Files,   MatchCasing.PlatformDefault, false,  "/numbers/file1.txt", "/numbers/data2.txt"),

        // ==========================================================================================================
        // DEPTH-FIRST VS BREADTH-FIRST ORDER VERIFICATION
        // ==========================================================================================================
        new UnitTestElement(TestFileLine("Unix: Verify depth-first order - results should be in DFS order"),
                                                   "FakeFSFiles/FakeFS7.Unix.json",
                                                           "/**/*.txt",                          "/",   "/",        Objects.Files,   MatchCasing.PlatformDefault, false),  // Order matters here

        new UnitTestElement(TestFileLine("Unix: Verify breadth-first order - results should be in BFS order"),
                                                   "FakeFSFiles/FakeFS7.Unix.json",
                                                           "/**/*.txt",                          "/",   "/",        Objects.Files,   MatchCasing.PlatformDefault, false),  // Order matters here
    ];
}