namespace vm2.DevOps.Glob.Api.Tests;

public partial class GlobsTests
{
    public static TheoryData<GlobEnumerateTheoryElement> Enumerate_Win_TestDataLargeSet =
    [
        // ==========================================================================================================
        // BASIC WILDCARDS: * (asterisk) - matches any string, including empty string
        // ==========================================================================================================
        //                                         fsFile  glob                                   cwd      start          objects          MatchCasing                  throws  results...
        new GlobEnumerateTheoryElement(TestFileLine("Match all files in root"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "*",                                   "C:/",   "C:/",         Objects.Files,   MatchCasing.PlatformDefault, false, "C:/boot.img", "C:/vmlinuz"),

        new GlobEnumerateTheoryElement(TestFileLine("Match all directories in root"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "*",                                   "C:/",   "C:/",         Objects.Directories, MatchCasing.PlatformDefault, false, "C:/home/", "C:/var/", "C:/etc/", "C:/opt/", "C:/test/"),

        new GlobEnumerateTheoryElement(TestFileLine("Match all in root (files and directories)"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "*",                                   "C:/",   "C:/",         Objects.Both,    MatchCasing.PlatformDefault, false, "C:/home/", "C:/var/", "C:/etc/", "C:/opt/", "C:/test/", "C:/boot.img", "C:/vmlinuz"),

        new GlobEnumerateTheoryElement(TestFileLine("Match all .txt files in specific folder"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/home/user/docs/*.txt",             "C:/",   "C:/",         Objects.Files,   MatchCasing.PlatformDefault, false, "C:/home/user/docs/notes.txt", "C:/home/user/docs/readme.txt", "C:/home/user/docs/file1.txt"),

        new GlobEnumerateTheoryElement(TestFileLine("Match files starting with 'file'"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/home/user/docs/file*",             "C:/",   "C:/",         Objects.Files,   MatchCasing.PlatformDefault, false, "C:/home/user/docs/file1.txt", "C:/home/user/docs/file2.dat"),

        new GlobEnumerateTheoryElement(TestFileLine("Match files ending with specific extension pattern"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/home/user/docs/*.gz",              "C:/",   "C:/",         Objects.Files,   MatchCasing.PlatformDefault, false, "C:/home/user/docs/archive.tar.gz"),

        new GlobEnumerateTheoryElement(TestFileLine("Match complex extensions"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/home/user/docs/*.tar.*",           "C:/",   "C:/",         Objects.Files,   MatchCasing.PlatformDefault, false, "C:/home/user/docs/archive.tar.gz", "C:/home/user/docs/backup.tar.bz2"),

        // ==========================================================================================================
        // BASIC WILDCARDS: ? (question mark) - matches exactly one character
        // ==========================================================================================================
        //                                         fsFile  glob                                   cwd      start          objects          MatchCasing                  throws  results...
        new GlobEnumerateTheoryElement(TestFileLine("Match log files with single character difference"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/var/log/app?.log",                 "C:/",    "C:/",        Objects.Files,   MatchCasing.PlatformDefault, false, "C:/var/log/app1.log", "C:/var/log/app2.log"),

        new GlobEnumerateTheoryElement(TestFileLine("Match files with 4-letter name ending in .log"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/var/log/????.log",                 "C:/",    "C:/",        Objects.Files,   MatchCasing.PlatformDefault, false, "C:/var/log/auth.log",  "C:/var/log/app1.log",  "C:/var/log/app2.log"),

        new GlobEnumerateTheoryElement(TestFileLine("Match tools with exactly 5 characters"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/opt/app/bin/tool?",                "C:/",    "C:/",        Objects.Files,   MatchCasing.PlatformDefault, false, "C:/opt/app/bin/tool1", "C:/opt/app/bin/tool2"),

        new GlobEnumerateTheoryElement(TestFileLine("Combine * and ? (file?.???)"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/home/user/docs/file?.???",         "C:/",    "C:/",        Objects.Files,   MatchCasing.PlatformDefault, false, "C:/home/user/docs/file1.txt", "C:/home/user/docs/file2.dat"),

        new GlobEnumerateTheoryElement(TestFileLine("Multiple ? in sequence"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/home/user/docs/?????.txt",         "C:/",    "C:/",        Objects.Files,   MatchCasing.PlatformDefault, false, "C:/home/user/docs/notes.txt", "C:/home/user/docs/file1.txt"),

        new GlobEnumerateTheoryElement(TestFileLine("? should NOT match app10.log (two digits)"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/var/log/app?.log",                 "C:/",    "C:/",        Objects.Files,   MatchCasing.PlatformDefault, false, "C:/var/log/app1.log", "C:/var/log/app2.log"),

        new GlobEnumerateTheoryElement(TestFileLine("?? should match app10.log"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/var/log/app??.log",                "C:/",    "C:/",        Objects.Files,   MatchCasing.PlatformDefault, false, "C:/var/log/app10.log"),

        // ==========================================================================================================
        // BRACKET EXPRESSIONS: [abc] - matches one character from the set
        // ==========================================================================================================
        //                                         fsFile  glob                                   cwd      start          objects          MatchCasing                  throws  results...
        new GlobEnumerateTheoryElement(TestFileLine("Match single lowercase letters a, b, or c"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/test/bracket-tests/[abc]",         "C:/",    "C:/",        Objects.Files,   MatchCasing.PlatformDefault, false, "C:/test/bracket-tests/A", "C:/test/bracket-tests/B", "C:/test/bracket-tests/C"),

        new GlobEnumerateTheoryElement(TestFileLine("Match single digits 1, 2, or 3"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/test/bracket-tests/[123]",         "C:/",    "C:/",        Objects.Files,   MatchCasing.PlatformDefault, false, "C:/test/bracket-tests/1", "C:/test/bracket-tests/2", "C:/test/bracket-tests/3"),

        new GlobEnumerateTheoryElement(TestFileLine("Match uppercase letters A, B, C"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/test/bracket-tests/[XYZ]",         "C:/",    "C:/",        Objects.Files,   MatchCasing.PlatformDefault, false, "C:/test/bracket-tests/x", "C:/test/bracket-tests/y", "C:/test/bracket-tests/z"),

        new GlobEnumerateTheoryElement(TestFileLine("Match files starting with 'file-' followed by specific letters"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/test/bracket-tests/file-[ab].txt", "C:/",    "C:/",        Objects.Files,   MatchCasing.PlatformDefault, false, "C:/test/bracket-tests/file-a.txt", "C:/test/bracket-tests/file-b.txt"),

        new GlobEnumerateTheoryElement(TestFileLine("Match files with specific digits"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/test/bracket-tests/file-[12].txt", "C:/",    "C:/",        Objects.Files,   MatchCasing.PlatformDefault, false, "C:/test/bracket-tests/file-1.txt", "C:/test/bracket-tests/file-2.txt"),

        // ==========================================================================================================
        // BRACKET EXPRESSIONS: [a-z] - matches one character from the range
        // ==========================================================================================================
        //                                         fsFile  glob                                   cwd      start          objects          MatchCasing                  throws  results...
        new GlobEnumerateTheoryElement(TestFileLine("Match single lowercase letters from a to z"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/test/bracket-tests/[a-z]",         "C:/",    "C:/",        Objects.Files,   MatchCasing.PlatformDefault, false, "C:/test/bracket-tests/A", "C:/test/bracket-tests/B", "C:/test/bracket-tests/C", "C:/test/bracket-tests/x", "C:/test/bracket-tests/y", "C:/test/bracket-tests/z"),

        new GlobEnumerateTheoryElement(TestFileLine("Match single digits from 0 to 9"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/test/bracket-tests/[0-9]",         "C:/",    "C:/",        Objects.Files,   MatchCasing.PlatformDefault, false, "C:/test/bracket-tests/1", "C:/test/bracket-tests/2", "C:/test/bracket-tests/3", "C:/test/bracket-tests/9"),

        new GlobEnumerateTheoryElement(TestFileLine("Match files with digit suffix in range"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/test/bracket-tests/file-[1-2].txt","C:/",    "C:/",        Objects.Files,   MatchCasing.PlatformDefault, false, "C:/test/bracket-tests/file-1.txt", "C:/test/bracket-tests/file-2.txt"),

        new GlobEnumerateTheoryElement(TestFileLine("Match uppercase letters A-C"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/test/bracket-tests/[A-C]",         "C:/",    "C:/",        Objects.Files,   MatchCasing.PlatformDefault, false, "C:/test/bracket-tests/A", "C:/test/bracket-tests/B", "C:/test/bracket-tests/C"),

        new GlobEnumerateTheoryElement(TestFileLine("Combined ranges [a-cx-z]"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/test/bracket-tests/[a-cx-z]",      "C:/",    "C:/",        Objects.Files,   MatchCasing.PlatformDefault, false, "C:/test/bracket-tests/A", "C:/test/bracket-tests/B", "C:/test/bracket-tests/C", "C:/test/bracket-tests/x", "C:/test/bracket-tests/y", "C:/test/bracket-tests/z"),

        new GlobEnumerateTheoryElement(TestFileLine("Range with explicit characters [a-c1-3]"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/test/bracket-tests/[a-c1-3]",      "C:/",    "C:/",        Objects.Files,   MatchCasing.PlatformDefault, false, "C:/test/bracket-tests/A", "C:/test/bracket-tests/B", "C:/test/bracket-tests/C", "C:/test/bracket-tests/1", "C:/test/bracket-tests/2", "C:/test/bracket-tests/3"),

        // ==========================================================================================================
        // BRACKET EXPRESSIONS: [!abc] or [^abc] - matches one character NOT in the set (negation)
        // ==========================================================================================================
        //                                         fsFile  glob                                   cwd      start          objects          MatchCasing                  throws  results...
        new GlobEnumerateTheoryElement(TestFileLine("Match single characters that are NOT a, b, or c"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/test/bracket-tests/[!abc]",        "C:/",  "C:/",          Objects.Files,   MatchCasing.PlatformDefault, false, "C:/test/bracket-tests/x", "C:/test/bracket-tests/y", "C:/test/bracket-tests/z", "C:/test/bracket-tests/1", "C:/test/bracket-tests/2", "C:/test/bracket-tests/3", "C:/test/bracket-tests/9"),

        new GlobEnumerateTheoryElement(TestFileLine("Match single characters that are NOT digits"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/test/bracket-tests/[!0-9]",        "C:/",  "C:/",          Objects.Files,   MatchCasing.PlatformDefault, false, "C:/test/bracket-tests/A", "C:/test/bracket-tests/B", "C:/test/bracket-tests/C", "C:/test/bracket-tests/x", "C:/test/bracket-tests/y", "C:/test/bracket-tests/z"),

        new GlobEnumerateTheoryElement(TestFileLine("Match files NOT starting with specific letters"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/test/bracket-tests/file-[!ab].txt","C:/",  "C:/",          Objects.Files,   MatchCasing.PlatformDefault, false, "C:/test/bracket-tests/file-1.txt", "C:/test/bracket-tests/file-2.txt"),

        new GlobEnumerateTheoryElement(TestFileLine("Negation of range [!a-m]"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/test/bracket-tests/[!a-m]",        "C:/",  "C:/",          Objects.Files,   MatchCasing.PlatformDefault, false, "C:/test/bracket-tests/x", "C:/test/bracket-tests/y", "C:/test/bracket-tests/z", "C:/test/bracket-tests/1", "C:/test/bracket-tests/2", "C:/test/bracket-tests/3", "C:/test/bracket-tests/9"),

        // ==========================================================================================================
        // CHARACTER CLASSES: [[:alnum:]], [[:alpha:]], [[:digit:]], [[:lower:]], [[:upper:]]
        // ==========================================================================================================
        //                                         fsFile  glob                                   cwd      start          objects          MatchCasing                  throws  results...
        new GlobEnumerateTheoryElement(TestFileLine("Match single alphanumeric characters [[:alnum:]]"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/test/bracket-tests/[[:alnum:]]",    "C:/",  "C:/",         Objects.Files,   MatchCasing.PlatformDefault, false, "C:/test/bracket-tests/x", "C:/test/bracket-tests/y", "C:/test/bracket-tests/z", "C:/test/bracket-tests/A", "C:/test/bracket-tests/B", "C:/test/bracket-tests/C", "C:/test/bracket-tests/1", "C:/test/bracket-tests/2", "C:/test/bracket-tests/3", "C:/test/bracket-tests/9"),

        new GlobEnumerateTheoryElement(TestFileLine("Match single alphabetic characters [[:alpha:]]"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/test/bracket-tests/[[:alpha:]]",    "C:/",  "C:/",         Objects.Files,   MatchCasing.PlatformDefault, false, "C:/test/bracket-tests/x", "C:/test/bracket-tests/y", "C:/test/bracket-tests/z", "C:/test/bracket-tests/A", "C:/test/bracket-tests/B", "C:/test/bracket-tests/C"),

        new GlobEnumerateTheoryElement(TestFileLine("Match single digit characters [[:digit:]]"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/test/bracket-tests/[[:digit:]]",    "C:/",  "C:/",         Objects.Files,   MatchCasing.PlatformDefault, false, "C:/test/bracket-tests/1", "C:/test/bracket-tests/2", "C:/test/bracket-tests/3", "C:/test/bracket-tests/9"),

        new GlobEnumerateTheoryElement(TestFileLine("Match single lowercase letters [[:lower:]]"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/test/bracket-tests/[[:lower:]]",    "C:/",  "C:/",         Objects.Files,   MatchCasing.PlatformDefault, false, "C:/test/bracket-tests/A", "C:/test/bracket-tests/B", "C:/test/bracket-tests/C", "C:/test/bracket-tests/x", "C:/test/bracket-tests/y", "C:/test/bracket-tests/z"),

        new GlobEnumerateTheoryElement(TestFileLine("Match single uppercase letters [[:upper:]]"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/test/bracket-tests/[[:upper:]]",    "C:/",  "C:/",         Objects.Files,   MatchCasing.PlatformDefault, false, "C:/test/bracket-tests/A", "C:/test/bracket-tests/B", "C:/test/bracket-tests/C", "C:/test/bracket-tests/x", "C:/test/bracket-tests/y", "C:/test/bracket-tests/z"),

        // ==========================================================================================================
        // RECURSIVE WILDCARDS: ** - matches zero or more directories
        // ==========================================================================================================
        //                                         fsFile  glob                                   cwd      start          objects          MatchCasing                  throws  results...
        new GlobEnumerateTheoryElement(TestFileLine("Find all .txt files recursively from /home"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/home/**/*.txt",                    "C:/",    "C:/",        Objects.Files,   MatchCasing.PlatformDefault, false, "C:/home/user/docs/readme.txt", "C:/home/user/docs/notes.txt", "C:/home/user/docs/file1.txt", "C:/home/user/data.txt", "C:/home/user/projects/project-list.txt"),

        new GlobEnumerateTheoryElement(TestFileLine("Find all .py files recursively"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/home/**/*.py",                     "C:/",    "C:/",        Objects.Files,   MatchCasing.PlatformDefault, false, "C:/home/projects/alpha.py", "C:/home/projects/alpha/alpha.py", "C:/home/projects/beta/beta.py", "C:/home/user/projects/beta/app.py", "C:/home/user/projects/beta/test.py"),

        new GlobEnumerateTheoryElement(TestFileLine("Find all .log files recursively from root"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/**/*.log",                         "C:/",    "C:/",        Objects.Files,   MatchCasing.PlatformDefault, false, "C:/var/log/access.log", "C:/var/log/app1.log", "C:/var/log/app10.log", "C:/var/log/app2.log", "C:/var/log/auth.log", "C:/var/log/debug.log", "C:/var/log/error.log", "C:/home/projects/alpha/alpha.log", "C:/home/projects/beta/beta.log"),

        new GlobEnumerateTheoryElement(TestFileLine("Find all directories recursively under /home/user"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/home/user/**/*",                   "C:/",    "C:/",        Objects.Directories, MatchCasing.PlatformDefault, false, "C:/home/user/docs/", "C:/home/user/projects/", "C:/home/user/media/", "C:/home/user/projects/alpha/", "C:/home/user/projects/beta/", "C:/home/user/projects/gamma/", "C:/home/user/media/images/", "C:/home/user/media/videos/"),

        new GlobEnumerateTheoryElement(TestFileLine("Find everything recursively under /opt"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/opt/**/*",                         "C:/",    "C:/",        Objects.Both,    MatchCasing.PlatformDefault, false, "C:/opt/app/", "C:/opt/app/bin/", "C:/opt/app/lib/", "C:/opt/app/README", "C:/opt/app/bin/app", "C:/opt/app/bin/tool1", "C:/opt/app/bin/tool2", "C:/opt/app/lib/libcore.so", "C:/opt/app/lib/libutil.so", "C:/opt/app/lib/libhelper.so.1"),

        new GlobEnumerateTheoryElement(TestFileLine("Recursive with specific starting pattern"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/home/**/file*.txt",                "C:/",    "C:/",        Objects.Files,   MatchCasing.PlatformDefault, false, "C:/home/user/docs/file1.txt"),

        // ==========================================================================================================
        // CASE SENSITIVITY (Unix is case-sensitive)
        // ==========================================================================================================
        //                                         fsFile  glob                                   cwd      start          objects          MatchCasing                  throws  results...
        new GlobEnumerateTheoryElement(TestFileLine("Should NOT match uppercase when looking for lowercase"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/home/user/docs/readme*",           "C:/",    "C:/",        Objects.Files,  MatchCasing.PlatformDefault, false, "C:/home/user/docs/README.md", "C:/home/user/docs/readme.txt"),

        new GlobEnumerateTheoryElement(TestFileLine("Should NOT match lowercase when looking for uppercase"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/home/user/docs/README*",           "C:/",    "C:/",        Objects.Files,  MatchCasing.PlatformDefault, false, "C:/home/user/docs/README.md", "C:/home/user/docs/readme.txt"),

        new GlobEnumerateTheoryElement(TestFileLine("Case sensitivity - match 'Test' but not 'TEST'"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/test/bracket-tests/Test",          "C:/",    "C:/",        Objects.Files,  MatchCasing.PlatformDefault, false, "C:/test/bracket-tests/TEST"),

        new GlobEnumerateTheoryElement(TestFileLine("Case sensitivity - exact match"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/test/bracket-tests/TEST",          "C:/",    "C:/",        Objects.Files,  MatchCasing.PlatformDefault, false, "C:/test/bracket-tests/TEST"),

        // ==========================================================================================================
        // HIDDEN FILES (starting with dot) are returned by GlobEnumerator
        // ==========================================================================================================
        //                                         fsFile  glob                                   cwd      start          objects          MatchCasing                  throws  results...
        new GlobEnumerateTheoryElement(TestFileLine("Match hidden files explicitly"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/home/user/.*",                     "C:/",    "C:/",        Objects.Files,   MatchCasing.PlatformDefault, false, "C:/home/user/.bashrc", "C:/home/user/.profile", "C:/home/user/.vimrc"),

        new GlobEnumerateTheoryElement(TestFileLine("* should NOT match hidden files - only visible files"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/home/user/*",                      "C:/",    "C:/",        Objects.Files,   MatchCasing.PlatformDefault, false, "C:/home/user/data.txt", "C:/home/user/.bashrc", "C:/home/user/.profile", "C:/home/user/.vimrc"),

        new GlobEnumerateTheoryElement(TestFileLine("Match hidden files with bracket expression"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/home/user/.[a-z]*",                "C:/",    "C:/",        Objects.Files,   MatchCasing.PlatformDefault, false, "C:/home/user/.bashrc", "C:/home/user/.profile", "C:/home/user/.vimrc"),

        new GlobEnumerateTheoryElement(TestFileLine("Match specific hidden file pattern"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/home/user/.bash*",                 "C:/",    "C:/",        Objects.Files,   MatchCasing.PlatformDefault, false, "C:/home/user/.bashrc"),

        // ==========================================================================================================
        // COMPLEX COMBINATIONS
        // ==========================================================================================================
        //                                         fsFile  glob                                   cwd      start          objects          MatchCasing                  throws  results...
        new GlobEnumerateTheoryElement(TestFileLine("Combine ** with character classes"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/home/**/[a-z]*.txt",               "C:/",    "C:/",        Objects.Files,   MatchCasing.PlatformDefault, false, "C:/home/user/docs/notes.txt", "C:/home/user/docs/readme.txt", "C:/home/user/docs/file1.txt", "C:/home/user/data.txt", "C:/home/user/projects/project-list.txt"),

        new GlobEnumerateTheoryElement(TestFileLine("Combine * and ? with brackets"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/test/bracket-tests/*-[ab].*",      "C:/",    "C:/",        Objects.Files,   MatchCasing.PlatformDefault, false, "C:/test/bracket-tests/file-a.txt", "C:/test/bracket-tests/file-b.txt"),

        new GlobEnumerateTheoryElement(TestFileLine("Multiple wildcards in path"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/home/*/projects/*/main.c",         "C:/",    "C:/",        Objects.Files,   MatchCasing.PlatformDefault, false, "C:/home/user/projects/alpha/main.c"),

        new GlobEnumerateTheoryElement(TestFileLine("Negation with wildcards"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/test/bracket-tests/file-[!0-9].*", "C:/",    "C:/",        Objects.Files,   MatchCasing.PlatformDefault, false, "C:/test/bracket-tests/file-a.txt", "C:/test/bracket-tests/file-b.txt"),

        new GlobEnumerateTheoryElement(TestFileLine("Complex pattern with multiple components"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/home/user/*/*/photo[12].*",        "C:/",    "C:/",        Objects.Files,   MatchCasing.PlatformDefault, false, "C:/home/user/media/images/photo1.jpg", "C:/home/user/media/images/photo2.png"),

        new GlobEnumerateTheoryElement(TestFileLine("Combine character class with negation"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/test/bracket-tests/[![:digit:]]",  "C:/",    "C:/",        Objects.Files,   MatchCasing.PlatformDefault, false, "C:/test/bracket-tests/A", "C:/test/bracket-tests/B", "C:/test/bracket-tests/C", "C:/test/bracket-tests/x", "C:/test/bracket-tests/y", "C:/test/bracket-tests/z"),

        // ==========================================================================================================
        // EDGE CASES AND SPECIAL SCENARIOS
        // ==========================================================================================================
        //                                         fsFile  glob                                   cwd      start          objects          MatchCasing                  throws  results...
        new GlobEnumerateTheoryElement(TestFileLine("Empty pattern should throw"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "",                                    "C:/",    "C:/",        Objects.Both,    MatchCasing.PlatformDefault, true),

        new GlobEnumerateTheoryElement(TestFileLine("Glob ending with / when searching for files should throw"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/home/user/docs/",                  "C:/",    "C:/",        Objects.Files,   MatchCasing.PlatformDefault, true),

        new GlobEnumerateTheoryElement(TestFileLine("Glob ending with ** when searching for files only should throw"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/home/**",                          "C:/",    "C:/",        Objects.Files,   MatchCasing.PlatformDefault, true),

        new GlobEnumerateTheoryElement(TestFileLine("Match exact file name (no wildcards)"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/etc/hosts",                        "C:/",    "C:/",        Objects.Files,   MatchCasing.PlatformDefault, false, "C:/etc/hosts"),

        new GlobEnumerateTheoryElement(TestFileLine("Match exact directory name"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/home/user/docs",                   "C:/",    "C:/",        Objects.Directories, MatchCasing.PlatformDefault, false, "C:/home/user/docs/"),

        new GlobEnumerateTheoryElement(TestFileLine("No matches should return empty"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/home/user/docs/*.exe",             "C:/",    "C:/",        Objects.Files,   MatchCasing.PlatformDefault, false),

        new GlobEnumerateTheoryElement(TestFileLine("Match multiple directory levels with *"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/*/*/*.conf",                       "C:/",    "C:/",        Objects.Files,   MatchCasing.PlatformDefault, false, "C:/etc/config/app.conf", "C:/etc/config/system.conf", "C:/etc/config/network.conf"),

        new GlobEnumerateTheoryElement(TestFileLine("Match files with complex multiple extensions"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/opt/**/*.so*",                     "C:/",    "C:/",        Objects.Files,   MatchCasing.PlatformDefault, false, "C:/opt/app/lib/libcore.so", "C:/opt/app/lib/libutil.so", "C:/opt/app/lib/libhelper.so.1"),

        new GlobEnumerateTheoryElement(TestFileLine("Using relative path from different current folder"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "docs/*.txt",                          "C:/",    "C:/home/user",Objects.Files,  MatchCasing.PlatformDefault, false, "C:/home/user/docs/readme.txt", "C:/home/user/docs/notes.txt", "C:/home/user/docs/file1.txt"),

        new GlobEnumerateTheoryElement(TestFileLine("Glob with only bracket expression"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/var/log/[aes]*",                   "C:/",    "C:/",        Objects.Files,   MatchCasing.PlatformDefault, false, "C:/var/log/syslog", "C:/var/log/auth.log", "C:/var/log/error.log", "C:/var/log/access.log", "C:/var/log/app1.log", "C:/var/log/app2.log", "C:/var/log/app10.log"),

        // ==========================================================================================================
        // PRACTICAL REAL-WORLD SCENARIOS
        // ==========================================================================================================
        //                                         fsFile  glob                                   cwd      start          objects          MatchCasing                  throws  results...
        new GlobEnumerateTheoryElement(TestFileLine("Find all C source and header files"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/home/user/projects/**/*.[ch]",     "C:/",    "C:/",        Objects.Files,  MatchCasing.PlatformDefault, false, "C:/home/user/projects/alpha/main.c", "C:/home/user/projects/alpha/test.c", "C:/home/user/projects/alpha/helper.h"),

        new GlobEnumerateTheoryElement(TestFileLine("Find all configuration files"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/**/*.conf",                        "C:/",    "C:/",        Objects.Files,  MatchCasing.PlatformDefault, false, "C:/etc/config/app.conf", "C:/etc/config/system.conf", "C:/etc/config/network.conf"),

        new GlobEnumerateTheoryElement(TestFileLine("Find all shared libraries"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/**/*.so*",                         "C:/",    "C:/",        Objects.Files,  MatchCasing.PlatformDefault, false, "C:/opt/app/lib/libcore.so", "C:/opt/app/lib/libutil.so", "C:/opt/app/lib/libhelper.so.1"),

        new GlobEnumerateTheoryElement(TestFileLine("Find all temporary files"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/var/tmp/*.tmp",                    "C:/",    "C:/",        Objects.Files,  MatchCasing.PlatformDefault, false, "C:/var/tmp/temp1.tmp", "C:/var/tmp/temp2.tmp"),

        new GlobEnumerateTheoryElement(TestFileLine("Find all image files"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/home/**/images/*.*",               "C:/",    "C:/",        Objects.Files,  MatchCasing.PlatformDefault, false, "C:/home/user/media/images/photo1.jpg", "C:/home/user/media/images/photo2.png", "C:/home/user/media/images/icon.svg"),

        new GlobEnumerateTheoryElement(TestFileLine("Find all project directories"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/home/user/projects/*",             "C:/",    "C:/",        Objects.Directories, MatchCasing.PlatformDefault, false, "C:/home/user/projects/alpha/", "C:/home/user/projects/beta/", "C:/home/user/projects/gamma/"),

        new GlobEnumerateTheoryElement(TestFileLine("Find all backup/archive files"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/**/*.[zb][ia][pk]*",               "C:/",    "C:/",        Objects.Files,  MatchCasing.PlatformDefault, false, "C:/test/special/archive-2024.zip", "C:/test/special/file.bak"),

        new GlobEnumerateTheoryElement(TestFileLine("Find all markdown and text documentation"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/**/[Rr][Ee][Aa][Dd][Mm][Ee]*",     "C:/",    "C:/",        Objects.Files,  MatchCasing.PlatformDefault, false, "C:/home/user/docs/README.md", "C:/home/user/docs/readme.txt", "C:/opt/app/README"),

        new GlobEnumerateTheoryElement(TestFileLine("Find all log files with numeric suffixes"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/var/log/*[0-9].log",               "C:/",    "C:/",        Objects.Files,  MatchCasing.PlatformDefault, false, "C:/var/log/app1.log", "C:/var/log/app2.log", "C:/var/log/app10.log"),

        new GlobEnumerateTheoryElement(TestFileLine("Find all Python files in all projects"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/home/**/projects/**/*.py",          "C:/",    "C:/",       Objects.Files,  MatchCasing.PlatformDefault, false, "C:/home/user/projects/beta/app.py", "C:/home/user/projects/beta/test.py", "C:/home/projects/alpha.py", "C:/home/projects/alpha/alpha.py", "C:/home/projects/beta/beta.py"),

        // ==========================================================================================================
        // CATEGORY A: MULTIPLE RECURSIVE WILDCARDS (Glob Normalization - Future Feature)
        // ==========================================================================================================
        // NOTE: These tests verify current behavior - no duplicates. When de-normalization is implemented, these should produce duplicates.
        //                                         fsFile  glob                                   cwd      start          objects          MatchCasing                  throws  results...
        new GlobEnumerateTheoryElement(TestFileLine("Double ** should be semantically equivalent to single **"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/home/**/user/**/*.txt",             "C:/",   "C:/",        Objects.Files,  MatchCasing.PlatformDefault, false, "C:/home/user/data.txt", "C:/home/user/docs/readme.txt", "C:/home/user/docs/notes.txt", "C:/home/user/docs/file1.txt", "C:/home/user/projects/project-list.txt"),

        new GlobEnumerateTheoryElement(TestFileLine("Triple ** in path"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/**/user/**/docs/**/*.txt",          "C:/",   "C:/",        Objects.Files,  MatchCasing.PlatformDefault, false, "C:/home/user/docs/readme.txt", "C:/home/user/docs/notes.txt", "C:/home/user/docs/file1.txt"),

        new GlobEnumerateTheoryElement(TestFileLine("Adjacent ** wildcards"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/home/**/**/data.txt",               "C:/",   "C:/",        Objects.Files,  MatchCasing.PlatformDefault, false, "C:/home/user/data.txt"),

        // ==========================================================================================================
        // CATEGORY B: EMPTY/MISSING PATH COMPONENTS AND BOUNDARY CONDITIONS
        // ==========================================================================================================
        //                                         fsFile  glob                                   cwd      start          objects          MatchCasing                  throws  results...
        new GlobEnumerateTheoryElement(TestFileLine("Match empty folder (folder with no files)"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/home/user/media/*",                "C:/",    "C:/",        Objects.Files,  MatchCasing.PlatformDefault, false),

        new GlobEnumerateTheoryElement(TestFileLine("Match empty folder as directory"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/home/user/media",                  "C:/",    "C:/",        Objects.Directories, MatchCasing.PlatformDefault, false, "C:/home/user/media/"),

        new GlobEnumerateTheoryElement(TestFileLine("Non-existent path should return empty"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/nonexistent/**/*.txt",             "C:/",    "C:/",        Objects.Files,  MatchCasing.PlatformDefault, false),

        new GlobEnumerateTheoryElement(TestFileLine("Non-existent deep path should return empty"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/home/user/missing/folder/*.txt",   "C:/",    "C:/",        Objects.Files,  MatchCasing.PlatformDefault, false),

        new GlobEnumerateTheoryElement(TestFileLine("Glob with multiple consecutive slashes"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/home///user///docs/*.txt",         "C:/",    "C:/",        Objects.Files,  MatchCasing.PlatformDefault, false, "C:/home/user/docs/readme.txt", "C:/home/user/docs/notes.txt", "C:/home/user/docs/file1.txt"),

        new GlobEnumerateTheoryElement(TestFileLine("Root pattern with trailing slash"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/",                                 "C:/",    "C:/",        Objects.Directories, MatchCasing.PlatformDefault, false, "C:/home/", "C:/var/", "C:/etc/", "C:/opt/", "C:/test/"),

        // ==========================================================================================================
        // CATEGORY D: COMPLEX BRACKET EXPRESSIONS
        // ==========================================================================================================/
        //                                         fsFile  glob                                   cwd      start          objects          MatchCasing                  throws  results...
        new GlobEnumerateTheoryElement(TestFileLine("Multiple ranges in single bracket [a-zA-Z0-9]"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/test/bracket-tests/[a-zA-Z0-9]",   "C:/",    "C:/",        Objects.Files,  MatchCasing.PlatformDefault, false, "C:/test/bracket-tests/x", "C:/test/bracket-tests/y", "C:/test/bracket-tests/z", "C:/test/bracket-tests/A", "C:/test/bracket-tests/B", "C:/test/bracket-tests/C", "C:/test/bracket-tests/1", "C:/test/bracket-tests/2", "C:/test/bracket-tests/3", "C:/test/bracket-tests/9"),

        new GlobEnumerateTheoryElement(TestFileLine("Single character in brackets [a]"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/test/bracket-tests/[a]",           "C:/",    "C:/",        Objects.Files,  MatchCasing.PlatformDefault, false, "C:/test/bracket-tests/A"),

        new GlobEnumerateTheoryElement(TestFileLine("Negation of character class [![:lower:]]"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/test/bracket-tests/[![:lower:]]",  "C:/",    "C:/",        Objects.Files, MatchCasing.PlatformDefault, false, "C:/test/bracket-tests/1", "C:/test/bracket-tests/2", "C:/test/bracket-tests/3", "C:/test/bracket-tests/9"),

        new GlobEnumerateTheoryElement(TestFileLine("Negation of character class with range [![:digit:]]"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/test/bracket-tests/[![:digit:]]",  "C:/",    "C:/",        Objects.Files, MatchCasing.PlatformDefault, false, "C:/test/bracket-tests/x", "C:/test/bracket-tests/y", "C:/test/bracket-tests/z", "C:/test/bracket-tests/A", "C:/test/bracket-tests/B", "C:/test/bracket-tests/C"),

        new GlobEnumerateTheoryElement(TestFileLine("Complex bracket with multiple character classes [[:alpha:][:digit:]]"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/test/bracket-tests/[-[:alpha:].[:digit:]_]","C:/","C:/",   Objects.Files,  MatchCasing.PlatformDefault, false, "C:/test/bracket-tests/x", "C:/test/bracket-tests/y", "C:/test/bracket-tests/z", "C:/test/bracket-tests/A", "C:/test/bracket-tests/B", "C:/test/bracket-tests/C", "C:/test/bracket-tests/1", "C:/test/bracket-tests/2", "C:/test/bracket-tests/3", "C:/test/bracket-tests/9"),

        new GlobEnumerateTheoryElement(TestFileLine("Bracket with range and explicit chars [a-c5-7xyz]"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/test/bracket-tests/[a-c5-7xyz]",   "C:/",    "C:/",        Objects.Files,  MatchCasing.PlatformDefault, false, "C:/test/bracket-tests/A", "C:/test/bracket-tests/B", "C:/test/bracket-tests/C", "C:/test/bracket-tests/x", "C:/test/bracket-tests/y", "C:/test/bracket-tests/z"),

        // ==========================================================================================================
        // CATEGORY E: EXTREME PATTERNS AND CONSECUTIVE WILDCARDS
        // ==========================================================================================================
        //                                         fsFile  glob                                   cwd      start          objects          MatchCasing                  throws  results...
        new GlobEnumerateTheoryElement(TestFileLine("Many consecutive asterisks *** should work like *"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/etc/***",                          "C:/",  "C:/",          Objects.Files,  MatchCasing.PlatformDefault, true,  "C:/etc/hosts", "C:/etc/passwd", "C:/etc/group", "C:/etc/fstab"),

        new GlobEnumerateTheoryElement(TestFileLine("Four asterisks **** should work like *"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/var/log/app****.log",              "C:/",  "C:/",          Objects.Files,  MatchCasing.PlatformDefault, true,  "C:/var/log/app1.log", "C:/var/log/app2.log", "C:/var/log/app10.log"),

        new GlobEnumerateTheoryElement(TestFileLine("Many question marks (16 chars)"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/var/log/????????????????",         "C:/",  "C:/",          Objects.Files,  MatchCasing.PlatformDefault, false),

        new GlobEnumerateTheoryElement(TestFileLine("Many levels of single asterisk"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/*/*/*/*",                          "C:/",  "C:/",          Objects.Files,  MatchCasing.PlatformDefault, false, "C:/home/projects/alpha/alpha.data", "C:/home/projects/alpha/alpha.log", "C:/home/projects/alpha/alpha.py", "C:/home/projects/beta/beta.data", "C:/home/projects/beta/beta.log", "C:/home/projects/beta/beta.py", "C:/home/user/docs/README.md", "C:/home/user/docs/archive.tar.gz", "C:/home/user/docs/backup.tar.bz2", "C:/home/user/docs/file1.txt", "C:/home/user/docs/file2.dat", "C:/home/user/docs/notes.txt", "C:/home/user/docs/readme.txt", "C:/home/user/projects/project-list.txt", "C:/opt/app/bin/app", "C:/opt/app/bin/tool1", "C:/opt/app/bin/tool2", "C:/opt/app/lib/libcore.so", "C:/opt/app/lib/libhelper.so.1", "C:/opt/app/lib/libutil.so"),

        new GlobEnumerateTheoryElement(TestFileLine("Very specific pattern with many components"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/home/*/projects/*/test.*",         "C:/",  "C:/",          Objects.Files,  MatchCasing.PlatformDefault, false, "C:/home/user/projects/alpha/test.c", "C:/home/user/projects/beta/test.py"),

        new GlobEnumerateTheoryElement(TestFileLine("Glob with all wildcard types combined"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/home/**/p?ojects/[ab]*/test.*",    "C:/",  "C:/",          Objects.Files,  MatchCasing.PlatformDefault, false, "C:/home/user/projects/alpha/test.c", "C:/home/user/projects/beta/test.py"),

        // ==========================================================================================================
        // CATEGORY F: RELATIVE PATH EDGE CASES
        // ==========================================================================================================
        //                                         fsFile  glob                                   cwd      start          objects          MatchCasing                  throws  results...
        new GlobEnumerateTheoryElement(TestFileLine("Current directory notation ./docs/*.txt"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "./docs/*.txt",                      "C:/",    "C:/home/user",Objects.Files,  MatchCasing.PlatformDefault, false,  "C:/home/user/docs/readme.txt", "C:/home/user/docs/notes.txt", "C:/home/user/docs/file1.txt"),

        new GlobEnumerateTheoryElement(TestFileLine("Relative path with subdirectory"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "user/docs/*.txt",                   "C:/",    "C:/home",    Objects.Files,   MatchCasing.PlatformDefault, false,  "C:/home/user/docs/readme.txt", "C:/home/user/docs/notes.txt", "C:/home/user/docs/file1.txt"),

        new GlobEnumerateTheoryElement(TestFileLine("Relative path from nested directory"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "alpha/*.c",                         "C:/",    "C:/home/user/projects",Objects.Files,  MatchCasing.PlatformDefault, false,  "C:/home/user/projects/alpha/main.c", "C:/home/user/projects/alpha/test.c"),

        new GlobEnumerateTheoryElement(TestFileLine("Relative path with wildcard subdirectory"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "projects/*/test.*",                 "C:/",    "C:/home/user",Objects.Files,  MatchCasing.PlatformDefault, false, "C:/home/user/projects/alpha/test.c", "C:/home/user/projects/beta/test.py"),

        // ==========================================================================================================
        // CATEGORY H: ERROR CASES (throws = MatchCasing.PlatformDefault, true)
        // ==========================================================================================================
        //                                         fsFile  glob                                   cwd       start       objects          throws results...
        new GlobEnumerateTheoryElement(TestFileLine("Glob with unmatched opening bracket [abc"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/test/bracket-tests/[abc",          "C:/",    "C:/",        Objects.Files,   MatchCasing.PlatformDefault, false),

        new GlobEnumerateTheoryElement(TestFileLine("Glob with unmatched closing bracket abc]"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/test/bracket-tests/abc]",          "C:/",    "C:/",        Objects.Files,   MatchCasing.PlatformDefault, false),

        new GlobEnumerateTheoryElement(TestFileLine("Glob with empty brackets []"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/test/bracket-tests/file[]",        "C:/",    "C:/",        Objects.Files,   MatchCasing.PlatformDefault, true),

        new GlobEnumerateTheoryElement(TestFileLine("Glob with only negation [!]"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/test/bracket-tests/[!]",           "C:/",    "C:/",        Objects.Files,   MatchCasing.PlatformDefault, false),

        new GlobEnumerateTheoryElement(TestFileLine("Glob with only closing bracket []]"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/test/bracket-tests/[]]",           "C:/",    "C:/",        Objects.Files,   MatchCasing.PlatformDefault, false),

        new GlobEnumerateTheoryElement(TestFileLine("Glob with negated closing bracket [!]]"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/test/bracket-tests/[!]]",          "C:/",    "C:/",        Objects.Files,   MatchCasing.PlatformDefault, false),

        new GlobEnumerateTheoryElement(TestFileLine("Glob with invalid character class [[:invalid:]]"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/test/bracket-tests/[[:invalid:]]", "C:/",    "C:/",        Objects.Files,   MatchCasing.PlatformDefault, false),

        new GlobEnumerateTheoryElement(TestFileLine("Glob with backslash \\home\\user"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "\\home\\user\\*.txt",                 "C:/",    "C:/",        Objects.Files,   MatchCasing.PlatformDefault, false, "C:/home/user/data.txt"),

        new GlobEnumerateTheoryElement(TestFileLine("Glob starting with ** without separator **docs"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "**docs/*.txt",                        "C:/",    "C:/",        Objects.Files,   MatchCasing.PlatformDefault, true),

        new GlobEnumerateTheoryElement(TestFileLine("Glob with ** in middle without separators home**user"),
                                                   "FakeFSFiles/FakeFS3.Win.json",
                                                           "C:/home**user/*.txt",                 "C:/",    "C:/",        Objects.Files,   MatchCasing.PlatformDefault, true),
    ];
}