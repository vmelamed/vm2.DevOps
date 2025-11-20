namespace vm2.DevOps.Glob.Api.Tests;

public partial class GlobEnumeratorTests
{
    public static TheoryData<UnitTestElement> Enumerate_SpecialCharacters =
    [
        // ==========================================================================================================
        // SPACES IN FILENAMES AND DIRECTORY NAMES - Unix
        // ==========================================================================================================
        //                                         fsFile  glob                                           cwd    start                         objects          _matchCasing                  throws  results...
        new UnitTestElement(TestFileLine("Unix: Files with spaces - exact match"),
                                                   "FakeFSFiles/FakeFS6.Unix.json",
                                                           "/special-chars/spaces in names/file with spaces.txt", "/", "/",              Objects.Files,   MatchCasing.PlatformDefault, false,  "/special-chars/spaces in names/file with spaces.txt"),

        new UnitTestElement(TestFileLine("Unix: Files with spaces - wildcard *.txt"),
                                                   "FakeFSFiles/FakeFS6.Unix.json",
                                                           "/special-chars/spaces in names/*.txt",        "/",   "/",                          Objects.Files,   MatchCasing.PlatformDefault, false,  "/special-chars/spaces in names/file with spaces.txt"),

        new UnitTestElement(TestFileLine("Unix: Files with spaces - file*"),
                                                   "FakeFSFiles/FakeFS6.Unix.json",
                                                           "/special-chars/spaces in names/file*",        "/",   "/",                          Objects.Files,   MatchCasing.PlatformDefault, false,  "/special-chars/spaces in names/file with spaces.txt"),

        new UnitTestElement(TestFileLine("Unix: Files with spaces - *file*"),
                                                   "FakeFSFiles/FakeFS6.Unix.json",
                                                           "/special-chars/spaces in names/*file*",       "/",   "/",                          Objects.Files,   MatchCasing.PlatformDefault, false,  "/special-chars/spaces in names/another file.dat", "/special-chars/spaces in names/file with spaces.txt", "/special-chars/spaces in names/test file 123.log"),

        new UnitTestElement(TestFileLine("Unix: Files with spaces - all files"),
                                                   "FakeFSFiles/FakeFS6.Unix.json",
                                                           "/special-chars/spaces in names/*",            "/",   "/",                          Objects.Files,   MatchCasing.PlatformDefault, false,  "/special-chars/spaces in names/another file.dat", "/special-chars/spaces in names/file with spaces.txt", "/special-chars/spaces in names/test file 123.log"),

        new UnitTestElement(TestFileLine("Unix: Directory with spaces in name"),
                                                   "FakeFSFiles/FakeFS6.Unix.json",
                                                           "/special-chars/spaces in names",              "/",   "/",                          Objects.Directories, MatchCasing.PlatformDefault, false,  "/special-chars/spaces in names/"),

        // ==========================================================================================================
        // SYMBOL CHARACTERS (@, $, #, ~, _, -) - Unix
        // ==========================================================================================================
        //                                         fsFile  glob                                           cwd    start                         objects          _matchCasing                  throws  results...
        new UnitTestElement(TestFileLine("Unix: Files with @ symbol"),
                                                   "FakeFSFiles/FakeFS6.Unix.json",
                                                           "/special-chars/symbols/*@*.txt",              "/",   "/",                          Objects.Files,   MatchCasing.PlatformDefault, false,  "/special-chars/symbols/file@home.txt"),

        new UnitTestElement(TestFileLine("Unix: Files with $ symbol"),
                                                   "FakeFSFiles/FakeFS6.Unix.json",
                                                           "/special-chars/symbols/*$*.csv",              "/",   "/",                          Objects.Files,   MatchCasing.PlatformDefault, false,  "/special-chars/symbols/data$1.csv"),

        new UnitTestElement(TestFileLine("Unix: Files with # symbol"),
                                                   "FakeFSFiles/FakeFS6.Unix.json",
                                                           "/special-chars/symbols/*#*.ini",              "/",   "/",                          Objects.Files,   MatchCasing.PlatformDefault, false,  "/special-chars/symbols/config#main.ini"),

        new UnitTestElement(TestFileLine("Unix: Files with ~ symbol"),
                                                   "FakeFSFiles/FakeFS6.Unix.json",
                                                           "/special-chars/symbols/*~*.bak",              "/",   "/",                          Objects.Files,   MatchCasing.PlatformDefault, false,  "/special-chars/symbols/backup~old.bak"),

        new UnitTestElement(TestFileLine("Unix: Files with _ underscore"),
                                                   "FakeFSFiles/FakeFS6.Unix.json",
                                                           "/special-chars/symbols/*_*.pdf",              "/",   "/",                          Objects.Files,   MatchCasing.PlatformDefault, false,  "/special-chars/symbols/report_2024.pdf"),

        new UnitTestElement(TestFileLine("Unix: Files with - hyphen"),
                                                   "FakeFSFiles/FakeFS6.Unix.json",
                                                           "/special-chars/symbols/*-*.sh",               "/",   "/",                          Objects.Files,   MatchCasing.PlatformDefault, false,  "/special-chars/symbols/script-v1.sh"),

        new UnitTestElement(TestFileLine("Unix: All symbol files"),
                                                   "FakeFSFiles/FakeFS6.Unix.json",
                                                           "/special-chars/symbols/*",                    "/",   "/",                          Objects.Files,   MatchCasing.PlatformDefault, false,  "/special-chars/symbols/backup~old.bak", "/special-chars/symbols/config#main.ini", "/special-chars/symbols/data$1.csv", "/special-chars/symbols/file@home.txt", "/special-chars/symbols/report_2024.pdf", "/special-chars/symbols/script-v1.sh"),

        new UnitTestElement(TestFileLine("Unix: Root level special @ file"),
                                                   "FakeFSFiles/FakeFS6.Unix.json",
                                                           "/special-chars/*@*.txt",                      "/",   "/",                          Objects.Files,   MatchCasing.PlatformDefault, false,  "/special-chars/root-special@file.txt"),

        new UnitTestElement(TestFileLine("Unix: Root level special ~ file"),
                                                   "FakeFSFiles/FakeFS6.Unix.json",
                                                           "/special-chars/*~*.dat",                      "/",   "/",                          Objects.Files,   MatchCasing.PlatformDefault, false,  "/special-chars/another~file.dat"),

        // ==========================================================================================================
        // UNICODE CHARACTERS - Unix
        // ==========================================================================================================
        //                                         fsFile  glob                                           cwd    start                         objects          _matchCasing                  throws  results...
        new UnitTestElement(TestFileLine("Unix: Cyrillic filename exact match"),
                                                   "FakeFSFiles/FakeFS6.Unix.json",
                                                           "/special-chars/unicode/файл.txt",             "/",   "/",                          Objects.Files,   MatchCasing.PlatformDefault, false,  "/special-chars/unicode/файл.txt"),

        new UnitTestElement(TestFileLine("Unix: Chinese filename exact match"),
                                                   "FakeFSFiles/FakeFS6.Unix.json",
                                                           "/special-chars/unicode/文档.doc",             "/",   "/",                          Objects.Files,   MatchCasing.PlatformDefault, false,  "/special-chars/unicode/文档.doc"),

        new UnitTestElement(TestFileLine("Unix: French accents - café"),
                                                   "FakeFSFiles/FakeFS6.Unix.json",
                                                           "/special-chars/unicode/café.md",              "/",   "/",                          Objects.Files,   MatchCasing.PlatformDefault, false,  "/special-chars/unicode/café.md"),

        new UnitTestElement(TestFileLine("Unix: French accents - naïve"),
                                                   "FakeFSFiles/FakeFS6.Unix.json",
                                                           "/special-chars/unicode/naïve.txt",            "/",   "/",                          Objects.Files,   MatchCasing.PlatformDefault, false,  "/special-chars/unicode/naïve.txt"),

        new UnitTestElement(TestFileLine("Unix: French accents - résumé"),
                                                   "FakeFSFiles/FakeFS6.Unix.json",
                                                           "/special-chars/unicode/résumé.pdf",           "/",   "/",                          Objects.Files,   MatchCasing.PlatformDefault, false,  "/special-chars/unicode/résumé.pdf"),

        new UnitTestElement(TestFileLine("Unix: Greek characters"),
                                                   "FakeFSFiles/FakeFS6.Unix.json",
                                                           "/special-chars/unicode/Ὀδυσσεύς.txt",         "/",   "/",                          Objects.Files,   MatchCasing.PlatformDefault, false,  "/special-chars/unicode/Ὀδυσσεύς.txt"),

        new UnitTestElement(TestFileLine("Unix: All unicode files wildcard"),
                                                   "FakeFSFiles/FakeFS6.Unix.json",
                                                           "/special-chars/unicode/*",                    "/",   "/",                          Objects.Files,   MatchCasing.PlatformDefault, false,  "/special-chars/unicode/café.md", "/special-chars/unicode/naïve.txt", "/special-chars/unicode/résumé.pdf", "/special-chars/unicode/Ὀδυσσεύς.txt", "/special-chars/unicode/файл.txt", "/special-chars/unicode/文档.doc"),

        new UnitTestElement(TestFileLine("Unix: Unicode with wildcard *.txt"),
                                                   "FakeFSFiles/FakeFS6.Unix.json",
                                                           "/special-chars/unicode/*.txt",                "/",   "/",                          Objects.Files,   MatchCasing.PlatformDefault, false,  "/special-chars/unicode/naïve.txt", "/special-chars/unicode/Ὀδυσσεύς.txt", "/special-chars/unicode/файл.txt"),

        new UnitTestElement(TestFileLine("Unix: Unicode with wildcard *.md"),
                                                   "FakeFSFiles/FakeFS6.Unix.json",
                                                           "/special-chars/unicode/*.md",                 "/",   "/",                          Objects.Files,   MatchCasing.PlatformDefault, false,  "/special-chars/unicode/café.md"),

        new UnitTestElement(TestFileLine("Unix: Unicode with wildcard *.doc"),
                                                   "FakeFSFiles/FakeFS6.Unix.json",
                                                           "/special-chars/unicode/*.doc",                "/",   "/",                          Objects.Files,   MatchCasing.PlatformDefault, false,  "/special-chars/unicode/文档.doc"),

        new UnitTestElement(TestFileLine("Unix: Unicode with wildcard *.pdf"),
                                                   "FakeFSFiles/FakeFS6.Unix.json",
                                                           "/special-chars/unicode/*.pdf",                "/",   "/",                          Objects.Files,   MatchCasing.PlatformDefault, false,  "/special-chars/unicode/résumé.pdf"),

        // ==========================================================================================================
        // MIXED SPECIAL CHARACTERS - Unix
        // ==========================================================================================================
        //                                         fsFile  glob                                           cwd    start                         objects          _matchCasing                  throws  results...
        new UnitTestElement(TestFileLine("Unix: Mixed special - space and @"),
                                                   "FakeFSFiles/FakeFS6.Unix.json",
                                                           "/special-chars/mixed/*@*.txt",                "/",   "/",                          Objects.Files,   MatchCasing.PlatformDefault, false,  "/special-chars/mixed/my file@2024.txt"),

        new UnitTestElement(TestFileLine("Unix: Mixed special - space and #"),
                                                   "FakeFSFiles/FakeFS6.Unix.json",
                                                           "/special-chars/mixed/*#*.dat",                "/",   "/",                          Objects.Files,   MatchCasing.PlatformDefault, false,  "/special-chars/mixed/test_file #1.dat"),

        new UnitTestElement(TestFileLine("Unix: Mixed special - ~ and ()"),
                                                   "FakeFSFiles/FakeFS6.Unix.json",
                                                           "/special-chars/mixed/*~*.bak",                "/",   "/",                          Objects.Files,   MatchCasing.PlatformDefault, false,  "/special-chars/mixed/backup~file (copy).bak"),

        new UnitTestElement(TestFileLine("Unix: Mixed special - hyphen and underscore"),
                                                   "FakeFSFiles/FakeFS6.Unix.json",
                                                           "/special-chars/mixed/*-*_*.csv",              "/",   "/",                          Objects.Files,   MatchCasing.PlatformDefault, false,  "/special-chars/mixed/data-2024_v1.csv"),

        new UnitTestElement(TestFileLine("Unix: All mixed special files"),
                                                   "FakeFSFiles/FakeFS6.Unix.json",
                                                           "/special-chars/mixed/*",                      "/",   "/",                          Objects.Files,   MatchCasing.PlatformDefault, false,  "/special-chars/mixed/backup~file (copy).bak", "/special-chars/mixed/data-2024_v1.csv", "/special-chars/mixed/my file@2024.txt", "/special-chars/mixed/test_file #1.dat"),

        // ==========================================================================================================
        // DOTS AND DASHES - Unix
        // ==========================================================================================================
        //                                         fsFile  glob                                           cwd    start                         objects          _matchCasing                  throws  results...
        new UnitTestElement(TestFileLine("Unix: Single dot hidden file"),
                                                   "FakeFSFiles/FakeFS6.Unix.json",
                                                           "/special-chars/dots-and-dashes/.hidden",      "/",   "/",                          Objects.Files,   MatchCasing.PlatformDefault, false,  "/special-chars/dots-and-dashes/.hidden"),

        new UnitTestElement(TestFileLine("Unix: Double dot file"),
                                                   "FakeFSFiles/FakeFS6.Unix.json",
                                                           "/special-chars/dots-and-dashes/..double",     "/",   "/",                          Objects.Files,   MatchCasing.PlatformDefault, false,  "/special-chars/dots-and-dashes/..double"),

        new UnitTestElement(TestFileLine("Unix: Triple dot file"),
                                                   "FakeFSFiles/FakeFS6.Unix.json",
                                                           "/special-chars/dots-and-dashes/...triple",    "/",   "/",                          Objects.Files,   MatchCasing.PlatformDefault, false,  "/special-chars/dots-and-dashes/...triple"),

        new UnitTestElement(TestFileLine("Unix: File with multiple dots in name"),
                                                   "FakeFSFiles/FakeFS6.Unix.json",
                                                           "/special-chars/dots-and-dashes/*.dots.txt",   "/",   "/",                          Objects.Files,   MatchCasing.PlatformDefault, false,  "/special-chars/dots-and-dashes/file.name.with.dots.txt"),

        new UnitTestElement(TestFileLine("Unix: Hyphenated filename"),
                                                   "FakeFSFiles/FakeFS6.Unix.json",
                                                           "/special-chars/dots-and-dashes/*-*-*.dat",    "/",   "/",                          Objects.Files,   MatchCasing.PlatformDefault, false,  "/special-chars/dots-and-dashes/hyphen-file-name.dat"),

        new UnitTestElement(TestFileLine("Unix: Underscored filename"),
                                                   "FakeFSFiles/FakeFS6.Unix.json",
                                                           "/special-chars/dots-and-dashes/*_*_*.log",    "/",   "/",                          Objects.Files,   MatchCasing.PlatformDefault, false,  "/special-chars/dots-and-dashes/under_score_file.log"),

        new UnitTestElement(TestFileLine("Unix: Dot files with wildcard .*"),
                                                   "FakeFSFiles/FakeFS6.Unix.json",
                                                           "/special-chars/dots-and-dashes/.*",           "/",   "/",                          Objects.Files,   MatchCasing.PlatformDefault, false,  "/special-chars/dots-and-dashes/..double", "/special-chars/dots-and-dashes/...triple", "/special-chars/dots-and-dashes/.hidden"),

        new UnitTestElement(TestFileLine("Unix: All files in dots-and-dashes"),
                                                   "FakeFSFiles/FakeFS6.Unix.json",
                                                           "/special-chars/dots-and-dashes/*",            "/",   "/",                          Objects.Files,   MatchCasing.PlatformDefault, false,  "/special-chars/dots-and-dashes/..double", "/special-chars/dots-and-dashes/...triple", "/special-chars/dots-and-dashes/.hidden", "/special-chars/dots-and-dashes/file.name.with.dots.txt", "/special-chars/dots-and-dashes/hyphen-file-name.dat", "/special-chars/dots-and-dashes/under_score_file.log"),

        // ==========================================================================================================
        // PARENTHESES IN FILENAMES - Unix
        // ==========================================================================================================
        //                                         fsFile  glob                                           cwd    start                         objects          _matchCasing                  throws  results...
        new UnitTestElement(TestFileLine("Unix: File with (1) suffix"),
                                                   "FakeFSFiles/FakeFS6.Unix.json",
                                                           "/special-chars/parentheses/file(1).txt",      "/",   "/",                          Objects.Files,   MatchCasing.PlatformDefault, false,  "/special-chars/parentheses/file(1).txt"),

        new UnitTestElement(TestFileLine("Unix: File with (copy) suffix"),
                                                   "FakeFSFiles/FakeFS6.Unix.json",
                                                           "/special-chars/parentheses/data(copy).dat",   "/",   "/",                          Objects.Files,   MatchCasing.PlatformDefault, false,  "/special-chars/parentheses/data(copy).dat"),

        new UnitTestElement(TestFileLine("Unix: File with multiple parentheses"),
                                                   "FakeFSFiles/FakeFS6.Unix.json",
                                                           "/special-chars/parentheses/test(final)(2).log","/",  "/",                          Objects.Files,   MatchCasing.PlatformDefault, false,  "/special-chars/parentheses/test(final)(2).log"),

        new UnitTestElement(TestFileLine("Unix: File starting with parenthesis"),
                                                   "FakeFSFiles/FakeFS6.Unix.json",
                                                           "/special-chars/parentheses/(start)file.txt",  "/",   "/",                          Objects.Files,   MatchCasing.PlatformDefault, false,  "/special-chars/parentheses/(start)file.txt"),

        new UnitTestElement(TestFileLine("Unix: File ending with parenthesis (no extension)"),
                                                   "FakeFSFiles/FakeFS6.Unix.json",
                                                           "/special-chars/parentheses/file(end)",        "/",   "/",                          Objects.Files,   MatchCasing.PlatformDefault, false,  "/special-chars/parentheses/file(end)"),

        new UnitTestElement(TestFileLine("Unix: Wildcard files with parentheses *(*)*"),
                                                   "FakeFSFiles/FakeFS6.Unix.json",
                                                           "/special-chars/parentheses/*(*)*",            "/",   "/",                          Objects.Files,   MatchCasing.PlatformDefault, false,  "/special-chars/parentheses/(start)file.txt", "/special-chars/parentheses/data(copy).dat", "/special-chars/parentheses/file(1).txt", "/special-chars/parentheses/file(end)", "/special-chars/parentheses/test(final)(2).log"),

        new UnitTestElement(TestFileLine("Unix: All parentheses files"),
                                                   "FakeFSFiles/FakeFS6.Unix.json",
                                                           "/special-chars/parentheses/*",                "/",   "/",                          Objects.Files,   MatchCasing.PlatformDefault, false,  "/special-chars/parentheses/(start)file.txt", "/special-chars/parentheses/data(copy).dat", "/special-chars/parentheses/file(1).txt", "/special-chars/parentheses/file(end)", "/special-chars/parentheses/test(final)(2).log"),

        // ==========================================================================================================
        // BRACKETS IN FILENAMES (literal brackets, not glob patterns) - Unix
        // ==========================================================================================================
        //                                         fsFile  glob                                           cwd    start                         objects          _matchCasing                  throws  results...
        new UnitTestElement(TestFileLine("Unix: Literal bracket in filename - array[0].txt"),
                                                   "FakeFSFiles/FakeFS6.Unix.json",
                                                           "/special-chars/brackets/array[[]0[]].txt",    "/",   "/",                          Objects.Files,   MatchCasing.PlatformDefault, false,  "/special-chars/brackets/array[0].txt"),

        new UnitTestElement(TestFileLine("Unix: Literal brackets - data[index].dat"),
                                                   "FakeFSFiles/FakeFS6.Unix.json",
                                                           "/special-chars/brackets/data[[]index[]].dat", "/",   "/",                          Objects.Files,   MatchCasing.PlatformDefault, false,  "/special-chars/brackets/data[index].dat"),

        new UnitTestElement(TestFileLine("Unix: Multiple literal brackets"),
                                                   "FakeFSFiles/FakeFS6.Unix.json",
                                                           "/special-chars/brackets/test[[]1[]][[]2[]].log","/", "/",                          Objects.Files,   MatchCasing.PlatformDefault, false,  "/special-chars/brackets/test[1][2].log"),

        new UnitTestElement(TestFileLine("Unix: Bracket at start of filename"),
                                                   "FakeFSFiles/FakeFS6.Unix.json",
                                                           "/special-chars/brackets/[[]prefix[]]file.txt","/",   "/",                          Objects.Files,   MatchCasing.PlatformDefault, false,  "/special-chars/brackets/[prefix]file.txt"),

        new UnitTestElement(TestFileLine("Unix: Wildcard with literal brackets *[*]*"),
                                                   "FakeFSFiles/FakeFS6.Unix.json",
                                                           "/special-chars/brackets/*[[]*[]]*",           "/",   "/",                          Objects.Files,   MatchCasing.PlatformDefault, false,  "/special-chars/brackets/[prefix]file.txt", "/special-chars/brackets/array[0].txt", "/special-chars/brackets/data[index].dat", "/special-chars/brackets/test[1][2].log"),

        new UnitTestElement(TestFileLine("Unix: All bracket files"),
                                                   "FakeFSFiles/FakeFS6.Unix.json",
                                                           "/special-chars/brackets/*",                   "/",   "/",                          Objects.Files,   MatchCasing.PlatformDefault, false,  "/special-chars/brackets/[prefix]file.txt", "/special-chars/brackets/array[0].txt", "/special-chars/brackets/data[index].dat", "/special-chars/brackets/test[1][2].log"),

        // ==========================================================================================================
        // RECURSIVE SEARCH WITH SPECIAL CHARACTERS - Unix
        // ==========================================================================================================
        //                                         fsFile  glob                                           cwd    start                         objects          _matchCasing                  throws  results...
        new UnitTestElement(TestFileLine("Unix: RecursiveRegex search for files with @"),
                                                   "FakeFSFiles/FakeFS6.Unix.json",
                                                           "/special-chars/**/*@*",                       "/",   "/",                          Objects.Files,   MatchCasing.PlatformDefault, false,  "/special-chars/mixed/my file@2024.txt", "/special-chars/root-special@file.txt", "/special-chars/symbols/file@home.txt"),

        new UnitTestElement(TestFileLine("Unix: RecursiveRegex search for files with spaces"),
                                                   "FakeFSFiles/FakeFS6.Unix.json",
                                                           "/special-chars/**/* *",                       "/",   "/",                          Objects.Files,   MatchCasing.PlatformDefault, false,  "/special-chars/mixed/backup~file (copy).bak", "/special-chars/mixed/my file@2024.txt", "/special-chars/mixed/test_file #1.dat", "/special-chars/spaces in names/another file.dat", "/special-chars/spaces in names/file with spaces.txt", "/special-chars/spaces in names/test file 123.log"),

        new UnitTestElement(TestFileLine("Unix: RecursiveRegex search for .txt files"),
                                                   "FakeFSFiles/FakeFS6.Unix.json",
                                                           "/special-chars/**/*.txt",                     "/",   "/",                          Objects.Files,   MatchCasing.PlatformDefault, false,  "/special-chars/brackets/[prefix]file.txt", "/special-chars/brackets/array[0].txt", "/special-chars/dots-and-dashes/file.name.with.dots.txt", "/special-chars/mixed/my file@2024.txt", "/special-chars/parentheses/(start)file.txt", "/special-chars/parentheses/file(1).txt", "/special-chars/root-special@file.txt", "/special-chars/spaces in names/file with spaces.txt", "/special-chars/symbols/file@home.txt", "/special-chars/unicode/naïve.txt", "/special-chars/unicode/файл.txt", "/special-chars/unicode/Ὀδυσσεύς.txt"),

        new UnitTestElement(TestFileLine("Unix: RecursiveRegex search all special-chars"),
                                                   "FakeFSFiles/FakeFS6.Unix.json",
                                                           "/special-chars/**/*",                         "/",   "/",                          Objects.Files,   MatchCasing.PlatformDefault, false,  "/special-chars/another~file.dat", "/special-chars/brackets/[prefix]file.txt", "/special-chars/brackets/array[0].txt", "/special-chars/brackets/data[index].dat", "/special-chars/brackets/test[1][2].log", "/special-chars/dots-and-dashes/..double", "/special-chars/dots-and-dashes/...triple", "/special-chars/dots-and-dashes/.hidden", "/special-chars/dots-and-dashes/file.name.with.dots.txt", "/special-chars/dots-and-dashes/hyphen-file-name.dat", "/special-chars/dots-and-dashes/under_score_file.log", "/special-chars/mixed/backup~file (copy).bak", "/special-chars/mixed/data-2024_v1.csv", "/special-chars/mixed/my file@2024.txt", "/special-chars/mixed/test_file #1.dat", "/special-chars/parentheses/(start)file.txt", "/special-chars/parentheses/data(copy).dat", "/special-chars/parentheses/file(1).txt", "/special-chars/parentheses/file(end)", "/special-chars/parentheses/test(final)(2).log", "/special-chars/root-special@file.txt", "/special-chars/spaces in names/another file.dat", "/special-chars/spaces in names/file with spaces.txt", "/special-chars/spaces in names/test file 123.log", "/special-chars/symbols/backup~old.bak", "/special-chars/symbols/config#main.ini", "/special-chars/symbols/data$1.csv", "/special-chars/symbols/file@home.txt", "/special-chars/symbols/report_2024.pdf", "/special-chars/symbols/script-v1.sh", "/special-chars/unicode/café.md", "/special-chars/unicode/naïve.txt", "/special-chars/unicode/résumé.pdf", "/special-chars/unicode/Ὀδυσσεύς.txt", "/special-chars/unicode/файл.txt", "/special-chars/unicode/文档.doc"),

        // ==========================================================================================================
        // WINDOWS TESTS - Same patterns but with Windows paths
        // ==========================================================================================================
        //                                         fsFile  glob                                           cwd    start                         objects          _matchCasing                  throws  results...
        new UnitTestElement(TestFileLine("Win: Files with spaces - *.txt"),
                                                   "FakeFSFiles/FakeFS6.Win.json",
                                                           "C:/special-chars/spaces in names/*.txt",      "C:/", "C:/",                        Objects.Files,   MatchCasing.PlatformDefault, false,  "C:/special-chars/spaces in names/file with spaces.txt"),

        new UnitTestElement(TestFileLine("Win: Files with @ symbol"),
                                                   "FakeFSFiles/FakeFS6.Win.json",
                                                           "C:/special-chars/symbols/*@*.txt",            "C:/", "C:/",                        Objects.Files,   MatchCasing.PlatformDefault, false,  "C:/special-chars/symbols/file@home.txt"),

        new UnitTestElement(TestFileLine("Win: Unicode filename - café"),
                                                   "FakeFSFiles/FakeFS6.Win.json",
                                                           "C:/special-chars/unicode/café.md",            "C:/", "C:/",                        Objects.Files,   MatchCasing.PlatformDefault, false,  "C:/special-chars/unicode/café.md"),

        new UnitTestElement(TestFileLine("Win: Fs with parentheses"),
                                                   "FakeFSFiles/FakeFS6.Win.json",
                                                           "C:/special-chars/parentheses/file(1).txt",    "C:/", "C:/",                        Objects.Files,   MatchCasing.PlatformDefault, false,  "C:/special-chars/parentheses/file(1).txt"),

        new UnitTestElement(TestFileLine("Win: Literal bracket in filename"),
                                                   "FakeFSFiles/FakeFS6.Win.json",
                                                           "C:/special-chars/brackets/array[[]0[]].txt",  "C:/", "C:/",                        Objects.Files,   MatchCasing.PlatformDefault, false,  "C:/special-chars/brackets/array[0].txt"),

        new UnitTestElement(TestFileLine("Win: RecursiveRegex search for files with @"),
                                                   "FakeFSFiles/FakeFS6.Win.json",
                                                           "C:/special-chars/**/*@*",                     "C:/", "C:/",                        Objects.Files,   MatchCasing.PlatformDefault, false,  "C:/special-chars/mixed/my file@2024.txt", "C:/special-chars/root-special@file.txt", "C:/special-chars/symbols/file@home.txt"),

        new UnitTestElement(TestFileLine("Win: RecursiveRegex .txt with special chars"),
                                                   "FakeFSFiles/FakeFS6.Win.json",
                                                           "C:/special-chars/**/*.txt",                   "C:/", "C:/",                        Objects.Files,   MatchCasing.PlatformDefault, false,  "C:/special-chars/brackets/[prefix]file.txt", "C:/special-chars/brackets/array[0].txt", "C:/special-chars/dots-and-dashes/file.name.with.dots.txt", "C:/special-chars/mixed/my file@2024.txt", "C:/special-chars/parentheses/(start)file.txt", "C:/special-chars/parentheses/file(1).txt", "C:/special-chars/root-special@file.txt", "C:/special-chars/spaces in names/file with spaces.txt", "C:/special-chars/symbols/file@home.txt", "C:/special-chars/unicode/naïve.txt", "C:/special-chars/unicode/файл.txt", "C:/special-chars/unicode/Ὀδυσσεύς.txt"),
    ];
}