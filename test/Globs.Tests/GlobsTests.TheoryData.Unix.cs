
namespace vm2.DevOps.Glob.Api.Tests;

public partial class GlobsTests
{
    public static TheoryData<GlobEnumerate_TestData> GlobEnumerate_Unix_Exhaustive_TestDataSet =
    [
        // ==========================================================================================================
        // BASIC WILDCARDS: * (asterisk) - matches any string, including empty string
        // ==========================================================================================================

        //                                         fileSys                  currentFolder  path           pattern                            enumerated              throws  results...
        new GlobEnumerate_TestData(TestFileLine("Match all files in root"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                                             "/",           "/",           "*",                               Enumerated.Files,       false,  "/boot.img", "/vmlinuz"),

        new GlobEnumerate_TestData(TestFileLine("Match all directories in root"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                                             "/",           "/",           "*",                               Enumerated.Directories, false,  "/home/", "/var/", "/etc/", "/opt/", "/test/"),

        new GlobEnumerate_TestData(TestFileLine("Match all in root (files and directories)"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                                             "/",           "/",           "*",                               Enumerated.Both,        false,  "/home/", "/var/", "/etc/", "/opt/", "/test/", "/boot.img", "/vmlinuz"),

        new GlobEnumerate_TestData(TestFileLine("Match all .txt files in specific folder"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                                             "/",           "/",           "/home/user/docs/*.txt",           Enumerated.Files,       false,  "/home/user/docs/readme.txt", "/home/user/docs/notes.txt", "/home/user/docs/file1.txt"),

        new GlobEnumerate_TestData(TestFileLine("Match files starting with 'file'"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                                             "/",           "/",           "/home/user/docs/file*",           Enumerated.Files,       false,  "/home/user/docs/file1.txt", "/home/user/docs/file2.dat"),

        new GlobEnumerate_TestData(TestFileLine("Match files ending with specific extension pattern"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                                             "/",           "/",           "/home/user/docs/*.gz",            Enumerated.Files,       false,  "/home/user/docs/archive.tar.gz"),

        new GlobEnumerate_TestData(TestFileLine("Match complex extensions"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                                             "/",           "/",           "/home/user/docs/*.tar.*",         Enumerated.Files,       false,  "/home/user/docs/archive.tar.gz", "/home/user/docs/backup.tar.bz2"),

        // ==========================================================================================================
        // BASIC WILDCARDS: ? (question mark) - matches exactly one character
        // ==========================================================================================================

        new GlobEnumerate_TestData(TestFileLine("Match log files with single character difference"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                                             "/",           "/",           "/var/log/app?.log",               Enumerated.Files,       false,  "/var/log/app1.log", "/var/log/app2.log"),

        new GlobEnumerate_TestData(TestFileLine("Match files with 4-letter name ending in .log"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                                             "/",           "/",           "/var/log/????.log",               Enumerated.Files,       false,  "/var/log/auth.log",  "/var/log/app1.log",  "/var/log/app2.log"),

        new GlobEnumerate_TestData(TestFileLine("Match tools with exactly 5 characters"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                                             "/",           "/",           "/opt/app/bin/tool?",              Enumerated.Files,       false,  "/opt/app/bin/tool1", "/opt/app/bin/tool2"),

        new GlobEnumerate_TestData(TestFileLine("Combine * and ? (file?.???)"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                                             "/",           "/",           "/home/user/docs/file?.???",       Enumerated.Files,       false,  "/home/user/docs/file1.txt", "/home/user/docs/file2.dat"),

        new GlobEnumerate_TestData(TestFileLine("Multiple ? in sequence"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                                             "/",           "/",           "/home/user/docs/?????.txt",       Enumerated.Files,       false,  "/home/user/docs/notes.txt", "/home/user/docs/file1.txt"),

        new GlobEnumerate_TestData(TestFileLine("? should NOT match app10.log (two digits)"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                                             "/",           "/",           "/var/log/app?.log",               Enumerated.Files,       false,  "/var/log/app1.log", "/var/log/app2.log"),

        new GlobEnumerate_TestData(TestFileLine("?? should match app10.log"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                                             "/",           "/",           "/var/log/app??.log",              Enumerated.Files,       false,  "/var/log/app10.log"),

        // ==========================================================================================================
        // BRACKET EXPRESSIONS: [abc] - matches one character from the set
        // ==========================================================================================================

        new GlobEnumerate_TestData(TestFileLine("Match single lowercase letters a, b, or c"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                                             "/",           "/",           "/test/bracket-tests/[abc]",       Enumerated.Files,       false,  "/test/bracket-tests/a", "/test/bracket-tests/b", "/test/bracket-tests/c"),

        new GlobEnumerate_TestData(TestFileLine("Match single digits 1, 2, or 3"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                                             "/",           "/",           "/test/bracket-tests/[123]",       Enumerated.Files,       false,  "/test/bracket-tests/1", "/test/bracket-tests/2", "/test/bracket-tests/3"),

        new GlobEnumerate_TestData(TestFileLine("Match uppercase letters A, B, C"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                                             "/",           "/",           "/test/bracket-tests/[ABC]",       Enumerated.Files,       false,  "/test/bracket-tests/A", "/test/bracket-tests/B", "/test/bracket-tests/C"),

        new GlobEnumerate_TestData(TestFileLine("Match files starting with 'file-' followed by specific letters"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                                             "/",           "/",           "/test/bracket-tests/file-[ab].txt", Enumerated.Files,     false,  "/test/bracket-tests/file-a.txt", "/test/bracket-tests/file-b.txt"),

        new GlobEnumerate_TestData(TestFileLine("Match files with specific digits"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                                             "/",           "/",           "/test/bracket-tests/file-[12].txt", Enumerated.Files,     false,  "/test/bracket-tests/file-1.txt", "/test/bracket-tests/file-2.txt"),

        // ==========================================================================================================
        // BRACKET EXPRESSIONS: [a-z] - matches one character from the range
        // ==========================================================================================================

        new GlobEnumerate_TestData(TestFileLine("Match single lowercase letters from a to z"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                                             "/",           "/",           "/test/bracket-tests/[a-z]",       Enumerated.Files,       false,  "/test/bracket-tests/a", "/test/bracket-tests/b", "/test/bracket-tests/c", "/test/bracket-tests/x", "/test/bracket-tests/y", "/test/bracket-tests/z"),

        new GlobEnumerate_TestData(TestFileLine("Match single digits from 0 to 9"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                                             "/",           "/",           "/test/bracket-tests/[0-9]",       Enumerated.Files,       false,  "/test/bracket-tests/1", "/test/bracket-tests/2", "/test/bracket-tests/3", "/test/bracket-tests/9"),

        new GlobEnumerate_TestData(TestFileLine("Match files with digit suffix in range"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                                             "/",           "/",           "/test/bracket-tests/file-[1-2].txt", Enumerated.Files,    false,  "/test/bracket-tests/file-1.txt", "/test/bracket-tests/file-2.txt"),

        new GlobEnumerate_TestData(TestFileLine("Match uppercase letters A-C"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                                             "/",           "/",           "/test/bracket-tests/[A-C]",       Enumerated.Files,       false,  "/test/bracket-tests/A", "/test/bracket-tests/B", "/test/bracket-tests/C"),

        new GlobEnumerate_TestData(TestFileLine("Combined ranges [a-cx-z]"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                                             "/",           "/",           "/test/bracket-tests/[a-cx-z]",    Enumerated.Files,       false,  "/test/bracket-tests/a", "/test/bracket-tests/b", "/test/bracket-tests/c", "/test/bracket-tests/x", "/test/bracket-tests/y", "/test/bracket-tests/z"),

        new GlobEnumerate_TestData(TestFileLine("Range with explicit characters [a-c1-3]"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                                             "/",           "/",           "/test/bracket-tests/[a-c1-3]",    Enumerated.Files,       false,  "/test/bracket-tests/a", "/test/bracket-tests/b", "/test/bracket-tests/c", "/test/bracket-tests/1", "/test/bracket-tests/2", "/test/bracket-tests/3"),

        // ==========================================================================================================
        // BRACKET EXPRESSIONS: [!abc] or [^abc] - matches one character NOT in the set (negation)
        // ==========================================================================================================

        new GlobEnumerate_TestData(TestFileLine("Match single characters that are NOT a, b, or c"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                                             "/",           "/",           "/test/bracket-tests/[!abc]",      Enumerated.Files,       false,  "/test/bracket-tests/x", "/test/bracket-tests/y", "/test/bracket-tests/z", "/test/bracket-tests/A", "/test/bracket-tests/B", "/test/bracket-tests/C", "/test/bracket-tests/1", "/test/bracket-tests/2", "/test/bracket-tests/3", "/test/bracket-tests/9"),

        new GlobEnumerate_TestData(TestFileLine("Match single characters that are NOT digits"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                                             "/",           "/",           "/test/bracket-tests/[!0-9]",      Enumerated.Files,       false,  "/test/bracket-tests/a", "/test/bracket-tests/b", "/test/bracket-tests/c", "/test/bracket-tests/x", "/test/bracket-tests/y", "/test/bracket-tests/z", "/test/bracket-tests/A", "/test/bracket-tests/B", "/test/bracket-tests/C"),

        new GlobEnumerate_TestData(TestFileLine("Match files NOT starting with specific letters"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                                             "/",           "/",           "/test/bracket-tests/file-[!ab].txt", Enumerated.Files,    false,  "/test/bracket-tests/file-1.txt", "/test/bracket-tests/file-2.txt"),

        new GlobEnumerate_TestData(TestFileLine("Negation of range [!a-m]"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                                             "/",           "/",           "/test/bracket-tests/[!a-m]",      Enumerated.Files,       false,  "/test/bracket-tests/x", "/test/bracket-tests/y", "/test/bracket-tests/z", "/test/bracket-tests/A", "/test/bracket-tests/B", "/test/bracket-tests/C", "/test/bracket-tests/1", "/test/bracket-tests/2", "/test/bracket-tests/3", "/test/bracket-tests/9"),

        // ==========================================================================================================
        // CHARACTER CLASSES: [[:alnum:]], [[:alpha:]], [[:digit:]], [[:lower:]], [[:upper:]]
        // ==========================================================================================================

        new GlobEnumerate_TestData(TestFileLine("Match single alphanumeric characters [[:alnum:]]"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                                             "/",           "/",           "/test/bracket-tests/[[:alnum:]]", Enumerated.Files,       false,  "/test/bracket-tests/a", "/test/bracket-tests/b", "/test/bracket-tests/c", "/test/bracket-tests/x", "/test/bracket-tests/y", "/test/bracket-tests/z", "/test/bracket-tests/A", "/test/bracket-tests/B", "/test/bracket-tests/C", "/test/bracket-tests/1", "/test/bracket-tests/2", "/test/bracket-tests/3", "/test/bracket-tests/9"),

        new GlobEnumerate_TestData(TestFileLine("Match single alphabetic characters [[:alpha:]]"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                                             "/",           "/",           "/test/bracket-tests/[[:alpha:]]", Enumerated.Files,       false,  "/test/bracket-tests/a", "/test/bracket-tests/b", "/test/bracket-tests/c", "/test/bracket-tests/x", "/test/bracket-tests/y", "/test/bracket-tests/z", "/test/bracket-tests/A", "/test/bracket-tests/B", "/test/bracket-tests/C"),

        new GlobEnumerate_TestData(TestFileLine("Match single digit characters [[:digit:]]"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                                             "/",           "/",           "/test/bracket-tests/[[:digit:]]", Enumerated.Files,       false,  "/test/bracket-tests/1", "/test/bracket-tests/2", "/test/bracket-tests/3", "/test/bracket-tests/9"),

        new GlobEnumerate_TestData(TestFileLine("Match single lowercase letters [[:lower:]]"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                                             "/",           "/",           "/test/bracket-tests/[[:lower:]]", Enumerated.Files,       false,  "/test/bracket-tests/a", "/test/bracket-tests/b", "/test/bracket-tests/c", "/test/bracket-tests/x", "/test/bracket-tests/y", "/test/bracket-tests/z"),

        new GlobEnumerate_TestData(TestFileLine("Match single uppercase letters [[:upper:]]"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                                             "/",           "/",           "/test/bracket-tests/[[:upper:]]", Enumerated.Files,       false,  "/test/bracket-tests/A", "/test/bracket-tests/B", "/test/bracket-tests/C"),

        // ==========================================================================================================
        // RECURSIVE WILDCARDS: ** - matches zero or more directories
        // ==========================================================================================================

        new GlobEnumerate_TestData(TestFileLine("Find all .txt files recursively from /home"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                                             "/",           "/",           "/home/**/*.txt",                  Enumerated.Files,       false,  "/home/user/docs/readme.txt", "/home/user/docs/notes.txt", "/home/user/docs/file1.txt", "/home/user/data.txt", "/home/user/projects/project-list.txt"),

        new GlobEnumerate_TestData(TestFileLine("Find all .py files recursively"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                                             "/",           "/",           "/home/**/*.py",                   Enumerated.Files,       false,  "/home/projects/alpha.py", "/home/projects/alpha/alpha.py", "/home/projects/beta/beta.py", "/home/user/projects/beta/app.py", "/home/user/projects/beta/test.py"),

        new GlobEnumerate_TestData(TestFileLine("Find all .log files recursively from root"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                                             "/",           "/",           "/**/*.log",                       Enumerated.Files,       false,  "/var/log/access.log", "/var/log/app1.log", "/var/log/app10.log", "/var/log/app2.log", "/var/log/auth.log", "/var/log/debug.log", "/var/log/error.log", "/home/projects/alpha/alpha.log", "/home/projects/beta/beta.log"),

        new GlobEnumerate_TestData(TestFileLine("Find all directories recursively under /home/user"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                                             "/",           "/",           "/home/user/**/*",                 Enumerated.Directories, false,  "/home/user/docs/", "/home/user/projects/", "/home/user/media/", "/home/user/projects/alpha/", "/home/user/projects/beta/", "/home/user/projects/gamma/", "/home/user/media/images/", "/home/user/media/videos/"),

        new GlobEnumerate_TestData(TestFileLine("Find everything recursively under /opt"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                                             "/",           "/",           "/opt/**/*",                       Enumerated.Both,        false,  "/opt/app/", "/opt/app/bin/", "/opt/app/lib/", "/opt/app/README", "/opt/app/bin/app", "/opt/app/bin/tool1", "/opt/app/bin/tool2", "/opt/app/lib/libcore.so", "/opt/app/lib/libutil.so", "/opt/app/lib/libhelper.so.1"),

        new GlobEnumerate_TestData(TestFileLine("Recursive with specific starting pattern"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                                             "/",           "/",           "/home/**/file*.txt",              Enumerated.Files,       false,  "/home/user/docs/file1.txt"),

        // ==========================================================================================================
        // CASE SENSITIVITY (Unix is case-sensitive)
        // ==========================================================================================================

        new GlobEnumerate_TestData(TestFileLine("Should NOT match uppercase when looking for lowercase"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                                             "/",           "/",           "/home/user/docs/readme*",         Enumerated.Files,       false,  "/home/user/docs/readme.txt"),

        new GlobEnumerate_TestData(TestFileLine("Should NOT match lowercase when looking for uppercase"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                                             "/",           "/",           "/home/user/docs/README*",         Enumerated.Files,       false,  "/home/user/docs/README.md"),

        new GlobEnumerate_TestData(TestFileLine("Case sensitivity - match 'Test' but not 'TEST'"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                                             "/",           "/",           "/test/bracket-tests/Test",        Enumerated.Files,       false,  "/test/bracket-tests/Test"),

        new GlobEnumerate_TestData(TestFileLine("Case sensitivity - exact match"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                                             "/",           "/",           "/test/bracket-tests/TEST",        Enumerated.Files,       false,  "/test/bracket-tests/TEST"),

        // ==========================================================================================================
        // HIDDEN FILES (starting with dot)
        // ==========================================================================================================

        new GlobEnumerate_TestData(TestFileLine("Match hidden files explicitly"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                                             "/",           "/",           "/home/user/.*",                   Enumerated.Files,       false,  "/home/user/.bashrc", "/home/user/.profile", "/home/user/.vimrc"),

        new GlobEnumerate_TestData(TestFileLine("* should NOT match hidden files - only visible files"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                                             "/",           "/",           "/home/user/*",                    Enumerated.Files,       false,  "/home/user/data.txt", "/home/user/.bashrc", "/home/user/.profile", "/home/user/.vimrc"),

        new GlobEnumerate_TestData(TestFileLine("Match hidden files with bracket expression"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                                             "/",           "/",           "/home/user/.[a-z]*",              Enumerated.Files,       false,  "/home/user/.bashrc", "/home/user/.profile", "/home/user/.vimrc"),

        new GlobEnumerate_TestData(TestFileLine("Match specific hidden file pattern"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                                             "/",           "/",           "/home/user/.bash*",               Enumerated.Files,       false,  "/home/user/.bashrc"),

        // ==========================================================================================================
        // COMPLEX COMBINATIONS
        // ==========================================================================================================

        new GlobEnumerate_TestData(TestFileLine("Combine ** with character classes"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                                             "/",           "/",           "/home/**/[a-z]*.txt",             Enumerated.Files,       false,  "/home/user/docs/readme.txt", "/home/user/docs/notes.txt", "/home/user/docs/file1.txt", "/home/user/data.txt", "/home/user/projects/project-list.txt"),

        new GlobEnumerate_TestData(TestFileLine("Combine * and ? with brackets"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                                             "/",           "/",           "/test/bracket-tests/*-[ab].*",    Enumerated.Files,       false,  "/test/bracket-tests/file-a.txt", "/test/bracket-tests/file-b.txt"),

        new GlobEnumerate_TestData(TestFileLine("Multiple wildcards in path"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                                             "/",           "/",           "/home/*/projects/*/main.c",       Enumerated.Files,       false,  "/home/user/projects/alpha/main.c"),

        new GlobEnumerate_TestData(TestFileLine("Negation with wildcards"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                                             "/",           "/",           "/test/bracket-tests/file-[!0-9].*", Enumerated.Files,     false,  "/test/bracket-tests/file-a.txt", "/test/bracket-tests/file-b.txt"),

        new GlobEnumerate_TestData(TestFileLine("Complex pattern with multiple components"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                                             "/",           "/",           "/home/user/*/*/photo[12].*",       Enumerated.Files,       false,  "/home/user/media/images/photo1.jpg", "/home/user/media/images/photo2.png"),

        new GlobEnumerate_TestData(TestFileLine("Combine character class with negation"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                                             "/",           "/",           "/test/bracket-tests/[![:digit:]]", Enumerated.Files,      false,  "/test/bracket-tests/a", "/test/bracket-tests/b", "/test/bracket-tests/c", "/test/bracket-tests/x", "/test/bracket-tests/y", "/test/bracket-tests/z", "/test/bracket-tests/A", "/test/bracket-tests/B", "/test/bracket-tests/C"),

        // ==========================================================================================================
        // EDGE CASES AND SPECIAL SCENARIOS
        // ==========================================================================================================

        new GlobEnumerate_TestData(TestFileLine("Empty pattern should throw"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                                             "/",           "/",           "",                                Enumerated.Both,        true,   []),

        new GlobEnumerate_TestData(TestFileLine("Pattern ending with / when searching for files should throw"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                                             "/",           "/",           "/home/user/docs/",                Enumerated.Files,       true,   []),

        new GlobEnumerate_TestData(TestFileLine("Pattern ending with ** when searching for files only should throw"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                                             "/",           "/",           "/home/**",                        Enumerated.Files,       true,   []),

        new GlobEnumerate_TestData(TestFileLine("Match exact file name (no wildcards)"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                                             "/",           "/",           "/etc/hosts",                      Enumerated.Files,       false,  "/etc/hosts"),

        new GlobEnumerate_TestData(TestFileLine("Match exact directory name"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                                             "/",           "/",           "/home/user/docs",                 Enumerated.Directories, false,  "/home/user/docs/"),

        new GlobEnumerate_TestData(TestFileLine("No matches should return empty"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                                             "/",           "/",           "/home/user/docs/*.exe",           Enumerated.Files,       false,  []),

        new GlobEnumerate_TestData(TestFileLine("Match multiple directory levels with *"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                                             "/",           "/",           "/*/*/*.conf",                     Enumerated.Files,       false,  "/etc/config/app.conf", "/etc/config/system.conf", "/etc/config/network.conf"),

        new GlobEnumerate_TestData(TestFileLine("Match files with complex multiple extensions"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                                             "/",           "/",           "/opt/**/*.so*",                   Enumerated.Files,       false,  "/opt/app/lib/libcore.so", "/opt/app/lib/libutil.so", "/opt/app/lib/libhelper.so.1"),

        new GlobEnumerate_TestData(TestFileLine("Using relative path from different current folder"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                                             "/",           "/home/user",  "docs/*.txt",                      Enumerated.Files,       false,  "/home/user/docs/readme.txt", "/home/user/docs/notes.txt", "/home/user/docs/file1.txt"),

        new GlobEnumerate_TestData(TestFileLine("Pattern with only bracket expression"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                                             "/",           "/",           "/var/log/[aes]*",                 Enumerated.Files,       false,  "/var/log/syslog", "/var/log/auth.log", "/var/log/error.log", "/var/log/access.log", "/var/log/app1.log", "/var/log/app2.log", "/var/log/app10.log"),

        // ==========================================================================================================
        // PRACTICAL REAL-WORLD SCENARIOS
        // ==========================================================================================================

        new GlobEnumerate_TestData(TestFileLine("Find all C source and header files"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                                             "/",           "/",           "/home/user/projects/**/*.[ch]",   Enumerated.Files,       false,  "/home/user/projects/alpha/main.c", "/home/user/projects/alpha/test.c", "/home/user/projects/alpha/helper.h"),

        new GlobEnumerate_TestData(TestFileLine("Find all configuration files"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                                             "/",           "/",           "/**/*.conf",                      Enumerated.Files,       false,  "/etc/config/app.conf", "/etc/config/system.conf", "/etc/config/network.conf"),

        new GlobEnumerate_TestData(TestFileLine("Find all shared libraries"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                                             "/",           "/",           "/**/*.so*",                       Enumerated.Files,       false,  "/opt/app/lib/libcore.so", "/opt/app/lib/libutil.so", "/opt/app/lib/libhelper.so.1"),

        new GlobEnumerate_TestData(TestFileLine("Find all temporary files"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                                             "/",           "/",           "/var/tmp/*.tmp",                  Enumerated.Files,       false,  "/var/tmp/temp1.tmp", "/var/tmp/temp2.tmp"),

        new GlobEnumerate_TestData(TestFileLine("Find all image files"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                                             "/",           "/",           "/home/**/images/*.*",             Enumerated.Files,       false,  "/home/user/media/images/photo1.jpg", "/home/user/media/images/photo2.png", "/home/user/media/images/icon.svg"),

        new GlobEnumerate_TestData(TestFileLine("Find all project directories"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                                             "/",           "/",           "/home/user/projects/*",           Enumerated.Directories, false,  "/home/user/projects/alpha/", "/home/user/projects/beta/", "/home/user/projects/gamma/"),

        new GlobEnumerate_TestData(TestFileLine("Find all backup/archive files"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                                             "/",           "/",           "/**/*.[zb][ia][pk]*",             Enumerated.Files,       false,  "/test/special/archive-2024.zip", "/test/special/file.bak"),

        new GlobEnumerate_TestData(TestFileLine("Find all markdown and text documentation"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                                             "/",           "/",           "/**/[Rr][Ee][Aa][Dd][Mm][Ee]*",  Enumerated.Files,       false,  "/home/user/docs/README.md", "/home/user/docs/readme.txt", "/opt/app/README"),

        new GlobEnumerate_TestData(TestFileLine("Find all log files with numeric suffixes"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                                             "/",           "/",           "/var/log/*[0-9].log",             Enumerated.Files,       false,  "/var/log/app1.log", "/var/log/app2.log", "/var/log/app10.log"),

        new GlobEnumerate_TestData(TestFileLine("Find all Python files in all projects"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                                             "/",           "/",           "/home/**/projects/**/*.py",       Enumerated.Files,       false,  "/home/user/projects/beta/app.py", "/home/user/projects/beta/test.py", "/home/projects/alpha.py", "/home/projects/alpha/alpha.py", "/home/projects/beta/beta.py"),

    ];
}