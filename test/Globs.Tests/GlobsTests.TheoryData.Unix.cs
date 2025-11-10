namespace vm2.DevOps.Glob.Api.Tests;

public partial class GlobsTests
{
    public static TheoryData<GlobEnumerate_TestData> GlobEnumerate_Unix_TestDataLargeSet =
    [
        // ==========================================================================================================
        // BASIC WILDCARDS: * (asterisk) - matches any string, including empty string
        // ==========================================================================================================
        //                                         fsFile  glob                                 cwd    start        objects             throws  results...
        new GlobEnumerate_TestData(TestFileLine("Match all files in root"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "*",                                 "/",   "/",         Objects.Files,   false, "/boot.img", "/vmlinuz"),

        new GlobEnumerate_TestData(TestFileLine("Match all directories in root"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "*",                                 "/",   "/",         Objects.Directories, false, "/home/", "/var/", "/etc/", "/opt/", "/test/"),

        new GlobEnumerate_TestData(TestFileLine("Match all in root (files and directories)"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "*",                                 "/",   "/",         Objects.Both,    false, "/home/", "/var/", "/etc/", "/opt/", "/test/", "/boot.img", "/vmlinuz"),

        new GlobEnumerate_TestData(TestFileLine("Match all .txt files in specific folder"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/home/user/docs/*.txt",             "/",   "/",         Objects.Files,   false, "/home/user/docs/readme.txt", "/home/user/docs/notes.txt", "/home/user/docs/file1.txt"),

        new GlobEnumerate_TestData(TestFileLine("Match files starting with 'file'"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/home/user/docs/file*",             "/",   "/",         Objects.Files,   false, "/home/user/docs/file1.txt", "/home/user/docs/file2.dat"),

        new GlobEnumerate_TestData(TestFileLine("Match files ending with specific extension pattern"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/home/user/docs/*.gz",              "/",   "/",         Objects.Files,   false, "/home/user/docs/archive.tar.gz"),

        new GlobEnumerate_TestData(TestFileLine("Match complex extensions"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/home/user/docs/*.tar.*",           "/",   "/",         Objects.Files,   false, "/home/user/docs/archive.tar.gz", "/home/user/docs/backup.tar.bz2"),

        // ==========================================================================================================
        // BASIC WILDCARDS: ? (question mark) - matches exactly one character
        // ==========================================================================================================
        //                                         fsFile  glob                                 cwd     start       objects             throws results...
        new GlobEnumerate_TestData(TestFileLine("Match log files with single character difference"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/var/log/app?.log",                 "/",    "/",        Objects.Files,   false, "/var/log/app1.log", "/var/log/app2.log"),

        new GlobEnumerate_TestData(TestFileLine("Match files with 4-letter name ending in .log"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/var/log/????.log",                 "/",    "/",        Objects.Files,   false, "/var/log/auth.log",  "/var/log/app1.log",  "/var/log/app2.log"),

        new GlobEnumerate_TestData(TestFileLine("Match tools with exactly 5 characters"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/opt/app/bin/tool?",                "/",    "/",        Objects.Files,   false, "/opt/app/bin/tool1", "/opt/app/bin/tool2"),

        new GlobEnumerate_TestData(TestFileLine("Combine * and ? (file?.???)"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/home/user/docs/file?.???",         "/",    "/",        Objects.Files,   false, "/home/user/docs/file1.txt", "/home/user/docs/file2.dat"),

        new GlobEnumerate_TestData(TestFileLine("Multiple ? in sequence"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/home/user/docs/?????.txt",         "/",    "/",        Objects.Files,   false, "/home/user/docs/notes.txt", "/home/user/docs/file1.txt"),

        new GlobEnumerate_TestData(TestFileLine("? should NOT match app10.log (two digits)"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/var/log/app?.log",                 "/",    "/",        Objects.Files,   false, "/var/log/app1.log", "/var/log/app2.log"),

        new GlobEnumerate_TestData(TestFileLine("?? should match app10.log"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/var/log/app??.log",                "/",    "/",        Objects.Files,   false, "/var/log/app10.log"),

        // ==========================================================================================================
        // BRACKET EXPRESSIONS: [abc] - matches one character from the set
        // ==========================================================================================================
        //                                         fsFile  glob                                 cwd     start       objects             throws results...
        new GlobEnumerate_TestData(TestFileLine("Match single lowercase letters a, b, or c"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/test/bracket-tests/[abc]",         "/",    "/",        Objects.Files,   false, "/test/bracket-tests/a", "/test/bracket-tests/b", "/test/bracket-tests/c"),

        new GlobEnumerate_TestData(TestFileLine("Match single digits 1, 2, or 3"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/test/bracket-tests/[123]",         "/",    "/",        Objects.Files,   false, "/test/bracket-tests/1", "/test/bracket-tests/2", "/test/bracket-tests/3"),

        new GlobEnumerate_TestData(TestFileLine("Match uppercase letters A, B, C"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/test/bracket-tests/[ABC]",         "/",    "/",        Objects.Files,   false, "/test/bracket-tests/A", "/test/bracket-tests/B", "/test/bracket-tests/C"),

        new GlobEnumerate_TestData(TestFileLine("Match files starting with 'file-' followed by specific letters"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/test/bracket-tests/file-[ab].txt", "/",    "/",        Objects.Files,   false, "/test/bracket-tests/file-a.txt", "/test/bracket-tests/file-b.txt"),

        new GlobEnumerate_TestData(TestFileLine("Match files with specific digits"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/test/bracket-tests/file-[12].txt", "/",    "/",        Objects.Files,   false, "/test/bracket-tests/file-1.txt", "/test/bracket-tests/file-2.txt"),

        // ==========================================================================================================
        // BRACKET EXPRESSIONS: [a-z] - matches one character from the range
        // ==========================================================================================================
        //                                         fsFile  glob                                 cwd     start       objects             throws results...
        new GlobEnumerate_TestData(TestFileLine("Match single lowercase letters from a to z"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/test/bracket-tests/[a-z]",         "/",    "/",        Objects.Files,   false, "/test/bracket-tests/a", "/test/bracket-tests/b", "/test/bracket-tests/c", "/test/bracket-tests/x", "/test/bracket-tests/y", "/test/bracket-tests/z"),

        new GlobEnumerate_TestData(TestFileLine("Match single digits from 0 to 9"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/test/bracket-tests/[0-9]",         "/",    "/",        Objects.Files,   false, "/test/bracket-tests/1", "/test/bracket-tests/2", "/test/bracket-tests/3", "/test/bracket-tests/9"),

        new GlobEnumerate_TestData(TestFileLine("Match files with digit suffix in range"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/test/bracket-tests/file-[1-2].txt","/",    "/",        Objects.Files,   false, "/test/bracket-tests/file-1.txt", "/test/bracket-tests/file-2.txt"),

        new GlobEnumerate_TestData(TestFileLine("Match uppercase letters A-C"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/test/bracket-tests/[A-C]",         "/",    "/",        Objects.Files,   false, "/test/bracket-tests/A", "/test/bracket-tests/B", "/test/bracket-tests/C"),

        new GlobEnumerate_TestData(TestFileLine("Combined ranges [a-cx-z]"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/test/bracket-tests/[a-cx-z]",      "/",    "/",        Objects.Files,   false, "/test/bracket-tests/a", "/test/bracket-tests/b", "/test/bracket-tests/c", "/test/bracket-tests/x", "/test/bracket-tests/y", "/test/bracket-tests/z"),

        new GlobEnumerate_TestData(TestFileLine("Range with explicit characters [a-c1-3]"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/test/bracket-tests/[a-c1-3]",      "/",    "/",        Objects.Files,   false, "/test/bracket-tests/a", "/test/bracket-tests/b", "/test/bracket-tests/c", "/test/bracket-tests/1", "/test/bracket-tests/2", "/test/bracket-tests/3"),

        // ==========================================================================================================
        // BRACKET EXPRESSIONS: [!abc] or [^abc] - matches one character NOT in the set (negation)
        // ==========================================================================================================
        //                                         fsFile  glob                                 cwd     start       objects             throws results...
        new GlobEnumerate_TestData(TestFileLine("Match single characters that are NOT a, b, or c"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/test/bracket-tests/[!abc]",        "/",  "/",          Objects.Files,   false, "/test/bracket-tests/x", "/test/bracket-tests/y", "/test/bracket-tests/z", "/test/bracket-tests/A", "/test/bracket-tests/B", "/test/bracket-tests/C", "/test/bracket-tests/1", "/test/bracket-tests/2", "/test/bracket-tests/3", "/test/bracket-tests/9"),

        new GlobEnumerate_TestData(TestFileLine("Match single characters that are NOT digits"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/test/bracket-tests/[!0-9]",        "/",  "/",          Objects.Files,   false, "/test/bracket-tests/a", "/test/bracket-tests/b", "/test/bracket-tests/c", "/test/bracket-tests/x", "/test/bracket-tests/y", "/test/bracket-tests/z", "/test/bracket-tests/A", "/test/bracket-tests/B", "/test/bracket-tests/C"),

        new GlobEnumerate_TestData(TestFileLine("Match files NOT starting with specific letters"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/test/bracket-tests/file-[!ab].txt","/",  "/",          Objects.Files,   false, "/test/bracket-tests/file-1.txt", "/test/bracket-tests/file-2.txt"),

        new GlobEnumerate_TestData(TestFileLine("Negation of range [!a-m]"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/test/bracket-tests/[!a-m]",        "/",  "/",          Objects.Files,   false, "/test/bracket-tests/x", "/test/bracket-tests/y", "/test/bracket-tests/z", "/test/bracket-tests/A", "/test/bracket-tests/B", "/test/bracket-tests/C", "/test/bracket-tests/1", "/test/bracket-tests/2", "/test/bracket-tests/3", "/test/bracket-tests/9"),

        // ==========================================================================================================
        // CHARACTER CLASSES: [[:alnum:]], [[:alpha:]], [[:digit:]], [[:lower:]], [[:upper:]]
        // ==========================================================================================================
        //                                         fsFile  glob                                 cwd     start       objects             throws results...
        new GlobEnumerate_TestData(TestFileLine("Match single alphanumeric characters [[:alnum:]]"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/test/bracket-tests/[[:alnum:]]",    "/",  "/",         Objects.Files,   false, "/test/bracket-tests/a", "/test/bracket-tests/b", "/test/bracket-tests/c", "/test/bracket-tests/x", "/test/bracket-tests/y", "/test/bracket-tests/z", "/test/bracket-tests/A", "/test/bracket-tests/B", "/test/bracket-tests/C", "/test/bracket-tests/1", "/test/bracket-tests/2", "/test/bracket-tests/3", "/test/bracket-tests/9"),

        new GlobEnumerate_TestData(TestFileLine("Match single alphabetic characters [[:alpha:]]"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/test/bracket-tests/[[:alpha:]]",    "/",  "/",         Objects.Files,   false, "/test/bracket-tests/a", "/test/bracket-tests/b", "/test/bracket-tests/c", "/test/bracket-tests/x", "/test/bracket-tests/y", "/test/bracket-tests/z", "/test/bracket-tests/A", "/test/bracket-tests/B", "/test/bracket-tests/C"),

        new GlobEnumerate_TestData(TestFileLine("Match single digit characters [[:digit:]]"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/test/bracket-tests/[[:digit:]]",    "/",  "/",         Objects.Files,   false, "/test/bracket-tests/1", "/test/bracket-tests/2", "/test/bracket-tests/3", "/test/bracket-tests/9"),

        new GlobEnumerate_TestData(TestFileLine("Match single lowercase letters [[:lower:]]"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/test/bracket-tests/[[:lower:]]",    "/",  "/",         Objects.Files,   false, "/test/bracket-tests/a", "/test/bracket-tests/b", "/test/bracket-tests/c", "/test/bracket-tests/x", "/test/bracket-tests/y", "/test/bracket-tests/z"),

        new GlobEnumerate_TestData(TestFileLine("Match single uppercase letters [[:upper:]]"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/test/bracket-tests/[[:upper:]]",    "/",  "/",         Objects.Files,   false, "/test/bracket-tests/A", "/test/bracket-tests/B", "/test/bracket-tests/C"),

        // ==========================================================================================================
        // RECURSIVE WILDCARDS: ** - matches zero or more directories
        // ==========================================================================================================
        //                                         fsFile  glob                                 cwd     start       objects             throws results...
        new GlobEnumerate_TestData(TestFileLine("Find all .txt files recursively from /home"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/home/**/*.txt",                    "/",    "/",        Objects.Files,   false, "/home/user/docs/readme.txt", "/home/user/docs/notes.txt", "/home/user/docs/file1.txt", "/home/user/data.txt", "/home/user/projects/project-list.txt"),

        new GlobEnumerate_TestData(TestFileLine("Find all .py files recursively"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/home/**/*.py",                     "/",    "/",        Objects.Files,   false, "/home/projects/alpha.py", "/home/projects/alpha/alpha.py", "/home/projects/beta/beta.py", "/home/user/projects/beta/app.py", "/home/user/projects/beta/test.py"),

        new GlobEnumerate_TestData(TestFileLine("Find all .log files recursively from root"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/**/*.log",                         "/",    "/",        Objects.Files,   false, "/var/log/access.log", "/var/log/app1.log", "/var/log/app10.log", "/var/log/app2.log", "/var/log/auth.log", "/var/log/debug.log", "/var/log/error.log", "/home/projects/alpha/alpha.log", "/home/projects/beta/beta.log"),

        new GlobEnumerate_TestData(TestFileLine("Find all directories recursively under /home/user"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/home/user/**/*",                   "/",    "/",        Objects.Directories, false, "/home/user/docs/", "/home/user/projects/", "/home/user/media/", "/home/user/projects/alpha/", "/home/user/projects/beta/", "/home/user/projects/gamma/", "/home/user/media/images/", "/home/user/media/videos/"),

        new GlobEnumerate_TestData(TestFileLine("Find everything recursively under /opt"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/opt/**/*",                         "/",    "/",        Objects.Both,    false, "/opt/app/", "/opt/app/bin/", "/opt/app/lib/", "/opt/app/README", "/opt/app/bin/app", "/opt/app/bin/tool1", "/opt/app/bin/tool2", "/opt/app/lib/libcore.so", "/opt/app/lib/libutil.so", "/opt/app/lib/libhelper.so.1"),

        new GlobEnumerate_TestData(TestFileLine("Recursive with specific starting pattern"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/home/**/file*.txt",                "/",    "/",        Objects.Files,   false, "/home/user/docs/file1.txt"),

        // ==========================================================================================================
        // CASE SENSITIVITY (Unix is case-sensitive)
        // ==========================================================================================================
        //                                         fsFile  glob                                 cwd     start       objects             throws results...
        new GlobEnumerate_TestData(TestFileLine("Should NOT match uppercase when looking for lowercase"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/home/user/docs/readme*",           "/",    "/",        Objects.Files,  false, "/home/user/docs/readme.txt"),

        new GlobEnumerate_TestData(TestFileLine("Should NOT match lowercase when looking for uppercase"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/home/user/docs/README*",           "/",    "/",        Objects.Files,  false, "/home/user/docs/README.md"),

        new GlobEnumerate_TestData(TestFileLine("Case sensitivity - match 'Test' but not 'TEST'"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/test/bracket-tests/Test",          "/",    "/",        Objects.Files,  false, "/test/bracket-tests/Test"),

        new GlobEnumerate_TestData(TestFileLine("Case sensitivity - exact match"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/test/bracket-tests/TEST",          "/",    "/",        Objects.Files,  false, "/test/bracket-tests/TEST"),

        // ==========================================================================================================
        // HIDDEN FILES (starting with dot) are returned by GlobEnumerator
        // ==========================================================================================================
        //                                         fsFile  glob                                 cwd     start       objects             throws results...
        new GlobEnumerate_TestData(TestFileLine("Match hidden files explicitly"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/home/user/.*",                     "/",    "/",        Objects.Files,   false, "/home/user/.bashrc", "/home/user/.profile", "/home/user/.vimrc"),

        new GlobEnumerate_TestData(TestFileLine("* should NOT match hidden files - only visible files"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/home/user/*",                      "/",    "/",        Objects.Files,   false, "/home/user/data.txt", "/home/user/.bashrc", "/home/user/.profile", "/home/user/.vimrc"),

        new GlobEnumerate_TestData(TestFileLine("Match hidden files with bracket expression"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/home/user/.[a-z]*",                "/",    "/",        Objects.Files,   false, "/home/user/.bashrc", "/home/user/.profile", "/home/user/.vimrc"),

        new GlobEnumerate_TestData(TestFileLine("Match specific hidden file pattern"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/home/user/.bash*",                 "/",    "/",        Objects.Files,   false, "/home/user/.bashrc"),

        // ==========================================================================================================
        // COMPLEX COMBINATIONS
        // ==========================================================================================================
        //                                         fsFile  glob                                 cwd     start       objects             throws results...
        new GlobEnumerate_TestData(TestFileLine("Combine ** with character classes"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/home/**/[a-z]*.txt",                 "/",  "/",        Objects.Files,   false, "/home/user/docs/readme.txt", "/home/user/docs/notes.txt", "/home/user/docs/file1.txt", "/home/user/data.txt", "/home/user/projects/project-list.txt"),

        new GlobEnumerate_TestData(TestFileLine("Combine * and ? with brackets"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/test/bracket-tests/*-[ab].*",        "/",  "/",        Objects.Files,   false, "/test/bracket-tests/file-a.txt", "/test/bracket-tests/file-b.txt"),

        new GlobEnumerate_TestData(TestFileLine("Multiple wildcards in path"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/home/*/projects/*/main.c",           "/",  "/",        Objects.Files,   false, "/home/user/projects/alpha/main.c"),

        new GlobEnumerate_TestData(TestFileLine("Negation with wildcards"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/test/bracket-tests/file-[!0-9].*",   "/",  "/",        Objects.Files,   false, "/test/bracket-tests/file-a.txt", "/test/bracket-tests/file-b.txt"),

        new GlobEnumerate_TestData(TestFileLine("Complex pattern with multiple components"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/home/user/*/*/photo[12].*",          "/",  "/",        Objects.Files,   false, "/home/user/media/images/photo1.jpg", "/home/user/media/images/photo2.png"),

        new GlobEnumerate_TestData(TestFileLine("Combine character class with negation"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/test/bracket-tests/[![:digit:]]",    "/",  "/",        Objects.Files,   false, "/test/bracket-tests/a", "/test/bracket-tests/b", "/test/bracket-tests/c", "/test/bracket-tests/x", "/test/bracket-tests/y", "/test/bracket-tests/z", "/test/bracket-tests/A", "/test/bracket-tests/B", "/test/bracket-tests/C"),

        // ==========================================================================================================
        // EDGE CASES AND SPECIAL SCENARIOS
        // ==========================================================================================================
        //                                         fsFile  glob                                 cwd     start       objects             throws results...
        new GlobEnumerate_TestData(TestFileLine("Empty pattern should throw"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "",                                  "/",    "/",        Objects.Both,    true),

        new GlobEnumerate_TestData(TestFileLine("Glob ending with / when searching for files should throw"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/home/user/docs/",                  "/",    "/",        Objects.Files,   true),

        new GlobEnumerate_TestData(TestFileLine("Glob ending with ** when searching for files only should throw"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/home/**",                          "/",    "/",        Objects.Files,   true),

        new GlobEnumerate_TestData(TestFileLine("Match exact file name (no wildcards)"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/etc/hosts",                        "/",    "/",        Objects.Files,   false, "/etc/hosts"),

        new GlobEnumerate_TestData(TestFileLine("Match exact directory name"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/home/user/docs",                   "/",    "/",        Objects.Directories, false, "/home/user/docs/"),

        new GlobEnumerate_TestData(TestFileLine("No matches should return empty"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/home/user/docs/*.exe",             "/",    "/",        Objects.Files,   false),

        new GlobEnumerate_TestData(TestFileLine("Match multiple directory levels with *"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/*/*/*.conf",                       "/",    "/",        Objects.Files,   false, "/etc/config/app.conf", "/etc/config/system.conf", "/etc/config/network.conf"),

        new GlobEnumerate_TestData(TestFileLine("Match files with complex multiple extensions"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/opt/**/*.so*",                     "/",    "/",        Objects.Files,   false, "/opt/app/lib/libcore.so", "/opt/app/lib/libutil.so", "/opt/app/lib/libhelper.so.1"),

        new GlobEnumerate_TestData(TestFileLine("Using relative path from different current folder"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "docs/*.txt",                        "/",    "/home/user",Objects.Files,  false, "/home/user/docs/readme.txt", "/home/user/docs/notes.txt", "/home/user/docs/file1.txt"),

        new GlobEnumerate_TestData(TestFileLine("Glob with only bracket expression"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/var/log/[aes]*",                   "/",    "/",        Objects.Files,   false, "/var/log/syslog", "/var/log/auth.log", "/var/log/error.log", "/var/log/access.log", "/var/log/app1.log", "/var/log/app2.log", "/var/log/app10.log"),

        // ==========================================================================================================
        // PRACTICAL REAL-WORLD SCENARIOS
        // ==========================================================================================================
        //                                         fsFile  glob                                 cwd     start       objects             throws results...
        new GlobEnumerate_TestData(TestFileLine("Find all C source and header files"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/home/user/projects/**/*.[ch]",     "/",    "/",        Objects.Files,  false, "/home/user/projects/alpha/main.c", "/home/user/projects/alpha/test.c", "/home/user/projects/alpha/helper.h"),

        new GlobEnumerate_TestData(TestFileLine("Find all configuration files"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/**/*.conf",                        "/",    "/",        Objects.Files,  false, "/etc/config/app.conf", "/etc/config/system.conf", "/etc/config/network.conf"),

        new GlobEnumerate_TestData(TestFileLine("Find all shared libraries"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/**/*.so*",                         "/",    "/",        Objects.Files,  false, "/opt/app/lib/libcore.so", "/opt/app/lib/libutil.so", "/opt/app/lib/libhelper.so.1"),

        new GlobEnumerate_TestData(TestFileLine("Find all temporary files"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/var/tmp/*.tmp",                    "/",    "/",        Objects.Files,  false, "/var/tmp/temp1.tmp", "/var/tmp/temp2.tmp"),

        new GlobEnumerate_TestData(TestFileLine("Find all image files"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/home/**/images/*.*",               "/",    "/",        Objects.Files,  false, "/home/user/media/images/photo1.jpg", "/home/user/media/images/photo2.png", "/home/user/media/images/icon.svg"),

        new GlobEnumerate_TestData(TestFileLine("Find all project directories"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/home/user/projects/*",             "/",    "/",        Objects.Directories, false, "/home/user/projects/alpha/", "/home/user/projects/beta/", "/home/user/projects/gamma/"),

        new GlobEnumerate_TestData(TestFileLine("Find all backup/archive files"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/**/*.[zb][ia][pk]*",               "/",    "/",        Objects.Files,  false, "/test/special/archive-2024.zip", "/test/special/file.bak"),

        new GlobEnumerate_TestData(TestFileLine("Find all markdown and text documentation"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/**/[Rr][Ee][Aa][Dd][Mm][Ee]*",     "/",    "/",        Objects.Files,  false, "/home/user/docs/README.md", "/home/user/docs/readme.txt", "/opt/app/README"),

        new GlobEnumerate_TestData(TestFileLine("Find all log files with numeric suffixes"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/var/log/*[0-9].log",               "/",    "/",        Objects.Files,  false, "/var/log/app1.log", "/var/log/app2.log", "/var/log/app10.log"),

        new GlobEnumerate_TestData(TestFileLine("Find all Python files in all projects"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/home/**/projects/**/*.py",          "/",    "/",       Objects.Files,  false, "/home/user/projects/beta/app.py", "/home/user/projects/beta/test.py", "/home/projects/alpha.py", "/home/projects/alpha/alpha.py", "/home/projects/beta/beta.py"),

        // ==========================================================================================================
        // CATEGORY A: MULTIPLE RECURSIVE WILDCARDS (Glob Normalization - Future Feature)
        // ==========================================================================================================
        // NOTE: These tests verify current behavior - no duplicates. When de-normalization is implemented, these should produce duplicates.
        //                                         fsFile  glob                                 cwd     start       objects             throws results...
        new GlobEnumerate_TestData(TestFileLine("Double ** should be semantically equivalent to single **"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/home/**/user/**/*.txt",             "/",   "/",        Objects.Files,  false, "/home/user/data.txt", "/home/user/docs/readme.txt", "/home/user/docs/notes.txt", "/home/user/docs/file1.txt", "/home/user/projects/project-list.txt"),

        new GlobEnumerate_TestData(TestFileLine("Triple ** in path"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/**/user/**/docs/**/*.txt",          "/",   "/",        Objects.Files,  false, "/home/user/docs/readme.txt", "/home/user/docs/notes.txt", "/home/user/docs/file1.txt"),

        new GlobEnumerate_TestData(TestFileLine("Adjacent ** wildcards"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/home/**/**/data.txt",               "/",   "/",        Objects.Files,  false, "/home/user/data.txt"),

        // ==========================================================================================================
        // CATEGORY B: EMPTY/MISSING PATH COMPONENTS AND BOUNDARY CONDITIONS
        // ==========================================================================================================
        //                                         fsFile  glob                                 cwd     start       objects             throws results...
        new GlobEnumerate_TestData(TestFileLine("Match empty folder (folder with no files)"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/home/user/media/*",                "/",    "/",        Objects.Files,  false),

        new GlobEnumerate_TestData(TestFileLine("Match empty folder as directory"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/home/user/media",                  "/",    "/",        Objects.Directories, false, "/home/user/media/"),

        new GlobEnumerate_TestData(TestFileLine("Non-existent path should return empty"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/nonexistent/**/*.txt",             "/",    "/",        Objects.Files,  false),

        new GlobEnumerate_TestData(TestFileLine("Non-existent deep path should return empty"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/home/user/missing/folder/*.txt",   "/",    "/",        Objects.Files,  false),

        new GlobEnumerate_TestData(TestFileLine("Glob with multiple consecutive slashes"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/home///user///docs/*.txt",         "/",    "/",        Objects.Files,  false, "/home/user/docs/readme.txt", "/home/user/docs/notes.txt", "/home/user/docs/file1.txt"),

        new GlobEnumerate_TestData(TestFileLine("Root pattern with trailing slash"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/",                                 "/",    "/",        Objects.Directories, false, "/home/", "/var/", "/etc/", "/opt/", "/test/"),

        // ==========================================================================================================
        // CATEGORY C: SPECIAL CHARACTERS (using FakeFS1.Unix.json)
        // ==========================================================================================================/
        //                                         fsFile  glob                                 cwd     start       objects             throws results...
        new GlobEnumerate_TestData(TestFileLine("Match files with spaces in names"),
                                                   "FakeFSFiles/FakeFS1.Unix.json",
                                                           "/home/valo/Downloads/*Order*.pdf",  "/",    "/",        Objects.Files, false, "/home/valo/Downloads/Amazon Order.pdf"),

        new GlobEnumerate_TestData(TestFileLine("Match files with parentheses in names"),
                                                   "FakeFSFiles/FakeFS1.Unix.json",
                                                           "/home/valo/Downloads/*(*).zip",     "/",    "/",        Objects.Files, false, "/home/valo/Downloads/benchmark-summaries-ubuntu-latest (1).zip"),

        new GlobEnumerate_TestData(TestFileLine("Match files with dates and timestamps"),
                                                   "FakeFSFiles/FakeFS1.Unix.json",
                                                           "/home/valo/Downloads/2025-??-??T*", "/",    "/",        Objects.Files,false, "/home/valo/Downloads/2025-09-30T01_44_59-FedEx-Transaction-Record.pdf"),

        new GlobEnumerate_TestData(TestFileLine("Match partial download files (crdownload)"),
                                                   "FakeFSFiles/FakeFS1.Unix.json",
                                                           "/home/valo/Downloads/*.crdownload", "/",    "/",        Objects.Files,false, "/home/valo/Downloads/Resume.pdf.crdownload", "/home/valo/Downloads/Unconfirmed 365032.crdownload"),

        new GlobEnumerate_TestData(TestFileLine("Match files with multiple dots in name"),
                                                   "FakeFSFiles/FakeFS1.Unix.json",
                                                           "/home/valo/Downloads/vm2.*.json",   "/",    "/",        Objects.Files, false, "/home/valo/Downloads/vm2.UlidType.Benchmarks.NewUlid-report-full-compressed.json", "/home/valo/Downloads/vm2.UlidType.Benchmarks.NewUlid-report.json", "/home/valo/Downloads/vm2.UlidType.Benchmarks.ParseUlid-report-full-compressed.json", "/home/valo/Downloads/vm2.UlidType.Benchmarks.ParseUlid-report.json", "/home/valo/Downloads/vm2.UlidType.Benchmarks.UlidToString-report-full-compressed.json", "/home/valo/Downloads/vm2.UlidType.Benchmarks.UlidToString-report.json"),

        new GlobEnumerate_TestData(TestFileLine("Match files with hyphens and underscores"),
                                                   "FakeFSFiles/FakeFS1.Unix.json",
                                                           "/home/valo/Downloads/**/*-report-*.md","/", "/",        Objects.Files, false, "/home/valo/Downloads/benchmark-summaries-ubuntu-latest/results/vm2.UlidType.Benchmarks.NewUlid-report-github.md", "/home/valo/Downloads/benchmark-summaries-ubuntu-latest/results/vm2.UlidType.Benchmarks.ParseUlid-report-github.md", "/home/valo/Downloads/benchmark-summaries-ubuntu-latest/results/vm2.UlidType.Benchmarks.UlidToString-report-github.md"),

        new GlobEnumerate_TestData(TestFileLine("Recursive search with complex nested names"),
                                                   "FakeFSFiles/FakeFS1.Unix.json",
                                                           "/**/*summary.json",                 "/",    "/",        Objects.Files, false, "/home/valo/Downloads/benchmark-summaries-ubuntu-latest/summaries/vm2.UlidType.Benchmarks.NewUlid-summary.json", "/home/valo/Downloads/benchmark-summaries-ubuntu-latest/summaries/vm2.UlidType.Benchmarks.ParseUlid-summary.json", "/home/valo/Downloads/benchmark-summaries-ubuntu-latest/summaries/vm2.UlidType.Benchmarks.UlidToString-summary.json"),

        // ==========================================================================================================
        // CATEGORY D: COMPLEX BRACKET EXPRESSIONS
        // ==========================================================================================================/
        //                                         fsFile  glob                                 cwd     start       objects             throws results...
        new GlobEnumerate_TestData(TestFileLine("Multiple ranges in single bracket [a-zA-Z0-9]"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/test/bracket-tests/[a-zA-Z0-9]",   "/",    "/",        Objects.Files,  false, "/test/bracket-tests/a", "/test/bracket-tests/b", "/test/bracket-tests/c", "/test/bracket-tests/x", "/test/bracket-tests/y", "/test/bracket-tests/z", "/test/bracket-tests/A", "/test/bracket-tests/B", "/test/bracket-tests/C", "/test/bracket-tests/1", "/test/bracket-tests/2", "/test/bracket-tests/3", "/test/bracket-tests/9"),

        new GlobEnumerate_TestData(TestFileLine("Single character in brackets [a]"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/test/bracket-tests/[a]",           "/",    "/",        Objects.Files,  false, "/test/bracket-tests/a"),

        new GlobEnumerate_TestData(TestFileLine("Negation of character class [![:lower:]]"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/test/bracket-tests/[![:lower:]]",  "/",    "/",        Objects.Files, false, "/test/bracket-tests/A", "/test/bracket-tests/B", "/test/bracket-tests/C", "/test/bracket-tests/1", "/test/bracket-tests/2", "/test/bracket-tests/3", "/test/bracket-tests/9"),

        new GlobEnumerate_TestData(TestFileLine("Negation of character class with range [![:digit:]]"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/test/bracket-tests/[![:digit:]]",  "/",    "/",        Objects.Files, false, "/test/bracket-tests/a", "/test/bracket-tests/b", "/test/bracket-tests/c", "/test/bracket-tests/x", "/test/bracket-tests/y", "/test/bracket-tests/z", "/test/bracket-tests/A", "/test/bracket-tests/B", "/test/bracket-tests/C"),

        new GlobEnumerate_TestData(TestFileLine("Complex bracket with multiple character classes [[:alpha:][:digit:]]"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/test/bracket-tests/[-[:alpha:].[:digit:]_]","/","/",   Objects.Files,  false, "/test/bracket-tests/a", "/test/bracket-tests/b", "/test/bracket-tests/c", "/test/bracket-tests/x", "/test/bracket-tests/y", "/test/bracket-tests/z", "/test/bracket-tests/A", "/test/bracket-tests/B", "/test/bracket-tests/C", "/test/bracket-tests/1", "/test/bracket-tests/2", "/test/bracket-tests/3", "/test/bracket-tests/9"),

        new GlobEnumerate_TestData(TestFileLine("Bracket with range and explicit chars [a-c5-7xyz]"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/test/bracket-tests/[a-c5-7xyz]",   "/",    "/",        Objects.Files,  false, "/test/bracket-tests/a", "/test/bracket-tests/b", "/test/bracket-tests/c", "/test/bracket-tests/x", "/test/bracket-tests/y", "/test/bracket-tests/z"),

        // ==========================================================================================================
        // CATEGORY E: EXTREME PATTERNS AND CONSECUTIVE WILDCARDS
        // ==========================================================================================================
        //                                         fsFile  glob                                 cwd     start       objects             throws results...
        new GlobEnumerate_TestData(TestFileLine("Many consecutive asterisks *** should work like *"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/etc/***",                          "/",  "/",          Objects.Files,  true,  "/etc/hosts", "/etc/passwd", "/etc/group", "/etc/fstab"),

        new GlobEnumerate_TestData(TestFileLine("Four asterisks **** should work like *"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/var/log/app****.log",              "/",  "/",          Objects.Files,  true,  "/var/log/app1.log", "/var/log/app2.log", "/var/log/app10.log"),

        new GlobEnumerate_TestData(TestFileLine("Many question marks (16 chars)"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/var/log/????????????????",         "/",  "/",          Objects.Files,  false),

        new GlobEnumerate_TestData(TestFileLine("Many levels of single asterisk"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/*/*/*/*",                          "/",  "/",          Objects.Files,  false, "/home/projects/alpha/alpha.data", "/home/projects/alpha/alpha.log", "/home/projects/alpha/alpha.py", "/home/projects/beta/beta.data", "/home/projects/beta/beta.log", "/home/projects/beta/beta.py", "/home/user/docs/README.md", "/home/user/docs/archive.tar.gz", "/home/user/docs/backup.tar.bz2", "/home/user/docs/file1.txt", "/home/user/docs/file2.dat", "/home/user/docs/notes.txt", "/home/user/docs/readme.txt", "/home/user/projects/project-list.txt", "/opt/app/bin/app", "/opt/app/bin/tool1", "/opt/app/bin/tool2", "/opt/app/lib/libcore.so", "/opt/app/lib/libhelper.so.1", "/opt/app/lib/libutil.so"),

        new GlobEnumerate_TestData(TestFileLine("Very specific pattern with many components"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/home/*/projects/*/test.*",         "/",  "/",          Objects.Files,  false, "/home/user/projects/alpha/test.c", "/home/user/projects/beta/test.py"),

        new GlobEnumerate_TestData(TestFileLine("Glob with all wildcard types combined"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/home/**/p?ojects/[ab]*/test.*",    "/",  "/",          Objects.Files,  false, "/home/user/projects/alpha/test.c", "/home/user/projects/beta/test.py"),

        // ==========================================================================================================
        // CATEGORY F: RELATIVE PATH EDGE CASES
        // ==========================================================================================================
        //                                         fsFile  glob                                 cwd     start       objects             throws results...
        new GlobEnumerate_TestData(TestFileLine("Current directory notation ./docs/*.txt"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "./docs/*.txt",                      "/",    "/home/user",Objects.Files,  false,  "/home/user/docs/readme.txt", "/home/user/docs/notes.txt", "/home/user/docs/file1.txt"),

        new GlobEnumerate_TestData(TestFileLine("Relative path with subdirectory"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "user/docs/*.txt",                   "/",    "/home",    Objects.Files,   false,  "/home/user/docs/readme.txt", "/home/user/docs/notes.txt", "/home/user/docs/file1.txt"),

        new GlobEnumerate_TestData(TestFileLine("Relative path from nested directory"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "alpha/*.c",                         "/",    "/home/user/projects",Objects.Files,  false,  "/home/user/projects/alpha/main.c", "/home/user/projects/alpha/test.c"),

        new GlobEnumerate_TestData(TestFileLine("Relative path with wildcard subdirectory"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "projects/*/test.*",                 "/",    "/home/user",Objects.Files,  false, "/home/user/projects/alpha/test.c", "/home/user/projects/beta/test.py"),

        // ==========================================================================================================
        // CATEGORY G: BOUNDARY CONDITIONS WITH SIMPLE fsFile TEM (FakeFS2.Unix.json)
        // ==========================================================================================================
        //                                         fsFile  glob                                 cwd     start       objects             throws results...
        new GlobEnumerate_TestData(TestFileLine("Simple FS: Match all files from root"),
                                                   "FakeFSFiles/FakeFS2.Unix.json",
                                                           "/**/*.txt",                         "/",    "/",        Objects.Files,   false, "/root.txt", "/folder1/file1.txt", "/folder1/folder2/file2.txt", "/folder3/file3.txt"),

        new GlobEnumerate_TestData(TestFileLine("Simple FS: Single level wildcard"),
                                                   "FakeFSFiles/FakeFS2.Unix.json",
                                                           "/*",                                "/",    "/",        Objects.Both,    false, "/folder1/", "/folder3/", "/root.txt"),

        new GlobEnumerate_TestData(TestFileLine("Simple FS: Two level path"),
                                                   "FakeFSFiles/FakeFS2.Unix.json",
                                                           "/*/*",                              "/",    "/",        Objects.Files,   false, "/folder1/file1.txt", "/folder3/file3.txt"),

        new GlobEnumerate_TestData(TestFileLine("Simple FS: Exact path to nested file"),
                                                   "FakeFSFiles/FakeFS2.Unix.json",
                                                           "/folder1/folder2/file2.txt",        "/",    "/",        Objects.Files,   false, "/folder1/folder2/file2.txt"),

        new GlobEnumerate_TestData(TestFileLine("Simple FS: All directories recursively"),
                                                   "FakeFSFiles/FakeFS2.Unix.json",
                                                           "/**/*",                             "/",    "/",        Objects.Directories, false, "/folder1/", "/folder3/", "/folder1/folder2/"),

        new GlobEnumerate_TestData(TestFileLine("Simple FS: Everything recursively"),
                                                   "FakeFSFiles/FakeFS2.Unix.json",
                                                           "/**/*",                             "/",    "/",        Objects.Both,    false, "/folder1/", "/folder3/", "/root.txt", "/folder1/folder2/", "/folder1/file1.txt", "/folder1/folder2/file2.txt", "/folder3/file3.txt"),

        // ==========================================================================================================
        // CATEGORY H: ERROR CASES (throws = true)
        // ==========================================================================================================
        //                                         fsFile  glob                                 cwd     start       objects             throws results...
        new GlobEnumerate_TestData(TestFileLine("Glob with unmatched opening bracket [abc"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/test/bracket-tests/[abc",          "/",    "/",        Objects.Files,   false),

        new GlobEnumerate_TestData(TestFileLine("Glob with unmatched closing bracket abc]"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/test/bracket-tests/abc]",          "/",    "/",        Objects.Files,   false),

        new GlobEnumerate_TestData(TestFileLine("Glob with empty brackets []"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/test/bracket-tests/file[]",        "/",    "/",        Objects.Files,   true),

        new GlobEnumerate_TestData(TestFileLine("Glob with only negation [!]"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/test/bracket-tests/[!]",           "/",    "/",        Objects.Files,   false),

        new GlobEnumerate_TestData(TestFileLine("Glob with only closing bracket []]"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/test/bracket-tests/[]]",           "/",    "/",        Objects.Files,   false),

        new GlobEnumerate_TestData(TestFileLine("Glob with negated closing bracket [!]]"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/test/bracket-tests/[!]]",           "/",    "/",        Objects.Files,   false),

        new GlobEnumerate_TestData(TestFileLine("Glob with invalid character class [[:invalid:]]"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/test/bracket-tests/[[:invalid:]]", "/",    "/",        Objects.Files,   false),

        new GlobEnumerate_TestData(TestFileLine("Glob with backslash \\home\\user"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "\\home\\user\\*.txt",               "/",    "/",        Objects.Files,   false),

        new GlobEnumerate_TestData(TestFileLine("Glob starting with ** without separator **docs"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "**docs/*.txt",                      "/",    "/",        Objects.Files,   true),

        new GlobEnumerate_TestData(TestFileLine("Glob with ** in middle without separators home**user"),
                                                   "FakeFSFiles/FakeFS.UnixGlob.json",
                                                           "/home**user/*.txt",                 "/",    "/",        Objects.Files,   true),
    ];
}