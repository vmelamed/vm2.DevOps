// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Val Melamed

namespace vm2.DevOps.Glob.Api.Tests;

public partial class GlobEnumeratorUnitTests
{
    public static TheoryData<UnitTestElement> Enumerate_Unix_LargeSet =
    [
        // ==========================================================================================================
        // BASIC WILDCARDS: * (asterisk) - matches any string, including empty string
        // ==========================================================================================================
        //                                         fsFile  glob                                 cwd    start        objects          _matchCasing                 throws  results...
        new UnitTestElement(TestFileLine("Match all files in root"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "*",                                 "/",   "/",         Objects.Files,   MatchCasing.PlatformDefault, false, "/boot.img", "/vmlinuz"),

        new UnitTestElement(TestFileLine("Match all directories in root"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "*",                                 "/",   "/",         Objects.Directories, MatchCasing.PlatformDefault, false, "/home/", "/var/", "/etc/", "/opt/", "/test/"),

        new UnitTestElement(TestFileLine("Match all in root (files and directories)"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "*",                                 "/",   "/",         Objects.FilesAndDirectories,    MatchCasing.PlatformDefault, false, "/home/", "/var/", "/etc/", "/opt/", "/test/", "/boot.img", "/vmlinuz"),

        new UnitTestElement(TestFileLine("Match all .txt files in specific folder"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/home/user/docs/*.txt",             "/",   "/",         Objects.Files,   MatchCasing.PlatformDefault, false, "/home/user/docs/readme.txt", "/home/user/docs/notes.txt", "/home/user/docs/file1.txt"),

        new UnitTestElement(TestFileLine("Match files starting with 'file'"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/home/user/docs/file*",             "/",   "/",         Objects.Files,   MatchCasing.PlatformDefault, false, "/home/user/docs/file1.txt", "/home/user/docs/file2.dat"),

        new UnitTestElement(TestFileLine("Match files ending with specific extension pattern"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/home/user/docs/*.gz",              "/",   "/",         Objects.Files,   MatchCasing.PlatformDefault, false, "/home/user/docs/archive.tar.gz"),

        new UnitTestElement(TestFileLine("Match complex extensions"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/home/user/docs/*.tar.*",           "/",   "/",         Objects.Files,   MatchCasing.PlatformDefault, false, "/home/user/docs/archive.tar.gz", "/home/user/docs/backup.tar.bz2"),

        // ==========================================================================================================
        // BASIC WILDCARDS: ? (question mark) - matches exactly one character
        // ==========================================================================================================
        //                                         fsFile  glob                                 cwd    start        objects          _matchCasing                 throws  results...
        new UnitTestElement(TestFileLine("Match log files with single character difference"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/var/log/app?.log",                 "/",    "/",        Objects.Files,   MatchCasing.PlatformDefault, false, "/var/log/app1.log", "/var/log/app2.log"),

        new UnitTestElement(TestFileLine("Match files with 4-letter name ending in .log"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/var/log/????.log",                 "/",    "/",        Objects.Files,   MatchCasing.PlatformDefault, false, "/var/log/auth.log",  "/var/log/app1.log",  "/var/log/app2.log"),

        new UnitTestElement(TestFileLine("Match tools with exactly 5 characters"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/opt/app/bin/tool?",                "/",    "/",        Objects.Files,   MatchCasing.PlatformDefault, false, "/opt/app/bin/tool1", "/opt/app/bin/tool2"),

        new UnitTestElement(TestFileLine("Combine * and ? (file?.???)"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/home/user/docs/file?.???",         "/",    "/",        Objects.Files,   MatchCasing.PlatformDefault, false, "/home/user/docs/file1.txt", "/home/user/docs/file2.dat"),

        new UnitTestElement(TestFileLine("Multiple ? in sequence"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/home/user/docs/?????.txt",         "/",    "/",        Objects.Files,   MatchCasing.PlatformDefault, false, "/home/user/docs/notes.txt", "/home/user/docs/file1.txt"),

        new UnitTestElement(TestFileLine("? should NOT match app10.log (two digits)"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/var/log/app?.log",                 "/",    "/",        Objects.Files,   MatchCasing.PlatformDefault, false, "/var/log/app1.log", "/var/log/app2.log"),

        new UnitTestElement(TestFileLine("?? should match app10.log"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/var/log/app??.log",                "/",    "/",        Objects.Files,   MatchCasing.PlatformDefault, false, "/var/log/app10.log"),

        // ==========================================================================================================
        // BRACKET EXPRESSIONS: [abc] - matches one character from the set
        // ==========================================================================================================
        //                                         fsFile  glob                                 cwd    start        objects          _matchCasing                 throws  results...
        new UnitTestElement(TestFileLine("Match single lowercase letters a, b, or c"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/test/bracket-tests/[abc]",         "/",    "/",        Objects.Files,   MatchCasing.PlatformDefault, false, "/test/bracket-tests/a", "/test/bracket-tests/b", "/test/bracket-tests/c"),

        new UnitTestElement(TestFileLine("Match single digits 1, 2, or 3"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/test/bracket-tests/[123]",         "/",    "/",        Objects.Files,   MatchCasing.PlatformDefault, false, "/test/bracket-tests/1", "/test/bracket-tests/2", "/test/bracket-tests/3"),

        new UnitTestElement(TestFileLine("Match uppercase letters D, B, C"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/test/bracket-tests/[ABC]",         "/",    "/",        Objects.Files,   MatchCasing.PlatformDefault, false, "/test/bracket-tests/A", "/test/bracket-tests/B", "/test/bracket-tests/C"),

        new UnitTestElement(TestFileLine("Match files starting with 'file-' followed by specific letters"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/test/bracket-tests/file-[ab].txt", "/",    "/",        Objects.Files,   MatchCasing.PlatformDefault, false, "/test/bracket-tests/file-a.txt", "/test/bracket-tests/file-b.txt"),

        new UnitTestElement(TestFileLine("Match files with specific digits"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/test/bracket-tests/file-[12].txt", "/",    "/",        Objects.Files,   MatchCasing.PlatformDefault, false, "/test/bracket-tests/file-1.txt", "/test/bracket-tests/file-2.txt"),

        // ==========================================================================================================
        // BRACKET EXPRESSIONS: [a-z] - matches one character from the range
        // ==========================================================================================================
        //                                         fsFile  glob                                 cwd    start        objects          _matchCasing                 throws  results...
        new UnitTestElement(TestFileLine("Match single lowercase letters from a to z"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/test/bracket-tests/[a-z]",         "/",    "/",        Objects.Files,   MatchCasing.PlatformDefault, false, "/test/bracket-tests/a", "/test/bracket-tests/b", "/test/bracket-tests/c", "/test/bracket-tests/x", "/test/bracket-tests/y", "/test/bracket-tests/z"),

        new UnitTestElement(TestFileLine("Match single digits from 0 to 9"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/test/bracket-tests/[0-9]",         "/",    "/",        Objects.Files,   MatchCasing.PlatformDefault, false, "/test/bracket-tests/1", "/test/bracket-tests/2", "/test/bracket-tests/3", "/test/bracket-tests/9"),

        new UnitTestElement(TestFileLine("Match files with digit suffix in range"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/test/bracket-tests/file-[1-2].txt","/",    "/",        Objects.Files,   MatchCasing.PlatformDefault, false, "/test/bracket-tests/file-1.txt", "/test/bracket-tests/file-2.txt"),

        new UnitTestElement(TestFileLine("Match uppercase letters D-C"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/test/bracket-tests/[A-C]",         "/",    "/",        Objects.Files,   MatchCasing.PlatformDefault, false, "/test/bracket-tests/A", "/test/bracket-tests/B", "/test/bracket-tests/C"),

        new UnitTestElement(TestFileLine("Combined ranges [a-cx-z]"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/test/bracket-tests/[a-cx-z]",      "/",    "/",        Objects.Files,   MatchCasing.PlatformDefault, false, "/test/bracket-tests/a", "/test/bracket-tests/b", "/test/bracket-tests/c", "/test/bracket-tests/x", "/test/bracket-tests/y", "/test/bracket-tests/z"),

        new UnitTestElement(TestFileLine("Range with explicit characters [a-c1-3]"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/test/bracket-tests/[a-c1-3]",      "/",    "/",        Objects.Files,   MatchCasing.PlatformDefault, false, "/test/bracket-tests/a", "/test/bracket-tests/b", "/test/bracket-tests/c", "/test/bracket-tests/1", "/test/bracket-tests/2", "/test/bracket-tests/3"),

        // ==========================================================================================================
        // BRACKET EXPRESSIONS: [!abc] or [^abc] - matches one character NOT in the set (negation)
        // ==========================================================================================================
        //                                         fsFile  glob                                 cwd    start        objects          _matchCasing                 throws  results...
        new UnitTestElement(TestFileLine("Match single characters that are NOT a, b, or c"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/test/bracket-tests/[!abc]",        "/",  "/",          Objects.Files,   MatchCasing.PlatformDefault, false, "/test/bracket-tests/x", "/test/bracket-tests/y", "/test/bracket-tests/z", "/test/bracket-tests/A", "/test/bracket-tests/B", "/test/bracket-tests/C", "/test/bracket-tests/1", "/test/bracket-tests/2", "/test/bracket-tests/3", "/test/bracket-tests/9"),

        new UnitTestElement(TestFileLine("Match single characters that are NOT digits"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/test/bracket-tests/[!0-9]",        "/",  "/",          Objects.Files,   MatchCasing.PlatformDefault, false, "/test/bracket-tests/a", "/test/bracket-tests/b", "/test/bracket-tests/c", "/test/bracket-tests/x", "/test/bracket-tests/y", "/test/bracket-tests/z", "/test/bracket-tests/A", "/test/bracket-tests/B", "/test/bracket-tests/C"),

        new UnitTestElement(TestFileLine("Match files NOT starting with specific letters"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/test/bracket-tests/file-[!ab].txt","/",  "/",          Objects.Files,   MatchCasing.PlatformDefault, false, "/test/bracket-tests/file-1.txt", "/test/bracket-tests/file-2.txt"),

        new UnitTestElement(TestFileLine("Negation of range [!a-m]"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/test/bracket-tests/[!a-m]",        "/",  "/",          Objects.Files,   MatchCasing.PlatformDefault, false, "/test/bracket-tests/x", "/test/bracket-tests/y", "/test/bracket-tests/z", "/test/bracket-tests/A", "/test/bracket-tests/B", "/test/bracket-tests/C", "/test/bracket-tests/1", "/test/bracket-tests/2", "/test/bracket-tests/3", "/test/bracket-tests/9"),

        // ==========================================================================================================
        // CHARACTER CLASSES: [[:alnum:]], [[:alpha:]], [[:digit:]], [[:lower:]], [[:upper:]]
        // ==========================================================================================================
        //                                         fsFile  glob                                 cwd    start        objects          _matchCasing                 throws  results...
        new UnitTestElement(TestFileLine("Match single alphanumeric characters [[:alnum:]]"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/test/bracket-tests/[[:alnum:]]",    "/",  "/",         Objects.Files,   MatchCasing.PlatformDefault, false, "/test/bracket-tests/a", "/test/bracket-tests/b", "/test/bracket-tests/c", "/test/bracket-tests/x", "/test/bracket-tests/y", "/test/bracket-tests/z", "/test/bracket-tests/A", "/test/bracket-tests/B", "/test/bracket-tests/C", "/test/bracket-tests/1", "/test/bracket-tests/2", "/test/bracket-tests/3", "/test/bracket-tests/9"),

        new UnitTestElement(TestFileLine("Match single alphabetic characters [[:alpha:]]"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/test/bracket-tests/[[:alpha:]]",    "/",  "/",         Objects.Files,   MatchCasing.PlatformDefault, false, "/test/bracket-tests/a", "/test/bracket-tests/b", "/test/bracket-tests/c", "/test/bracket-tests/x", "/test/bracket-tests/y", "/test/bracket-tests/z", "/test/bracket-tests/A", "/test/bracket-tests/B", "/test/bracket-tests/C"),

        new UnitTestElement(TestFileLine("Match single digit characters [[:digit:]]"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/test/bracket-tests/[[:digit:]]",    "/",  "/",         Objects.Files,   MatchCasing.PlatformDefault, false, "/test/bracket-tests/1", "/test/bracket-tests/2", "/test/bracket-tests/3", "/test/bracket-tests/9"),

        new UnitTestElement(TestFileLine("Match single lowercase letters [[:lower:]]"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/test/bracket-tests/[[:lower:]]",    "/",  "/",         Objects.Files,   MatchCasing.PlatformDefault, false, "/test/bracket-tests/a", "/test/bracket-tests/b", "/test/bracket-tests/c", "/test/bracket-tests/x", "/test/bracket-tests/y", "/test/bracket-tests/z"),

        new UnitTestElement(TestFileLine("Match single uppercase letters [[:upper:]]"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/test/bracket-tests/[[:upper:]]",    "/",  "/",         Objects.Files,   MatchCasing.PlatformDefault, false, "/test/bracket-tests/A", "/test/bracket-tests/B", "/test/bracket-tests/C"),

        // ==========================================================================================================
        // GLOBSTARS: ** - matches zero or more directories
        // ==========================================================================================================
        //                                         fsFile  glob                                 cwd    start        objects          _matchCasing                 throws  results...
        new UnitTestElement(TestFileLine("Find all .txt files recursively from /home"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/home/**/*.txt",                    "/",    "/",        Objects.Files,   MatchCasing.PlatformDefault, false, "/home/user/docs/readme.txt", "/home/user/docs/notes.txt", "/home/user/docs/file1.txt", "/home/user/data.txt", "/home/user/projects/project-list.txt"),

        new UnitTestElement(TestFileLine("Find all .py files recursively"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/home/**/*.py",                     "/",    "/",        Objects.Files,   MatchCasing.PlatformDefault, false, "/home/projects/alpha.py", "/home/projects/alpha/alpha.py", "/home/projects/beta/beta.py", "/home/user/projects/beta/app.py", "/home/user/projects/beta/test.py"),

        new UnitTestElement(TestFileLine("Find all .log files recursively from root"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/**/*.log",                         "/",    "/",        Objects.Files,   MatchCasing.PlatformDefault, false, "/var/log/access.log", "/var/log/app1.log", "/var/log/app10.log", "/var/log/app2.log", "/var/log/auth.log", "/var/log/debug.log", "/var/log/error.log", "/home/projects/alpha/alpha.log", "/home/projects/beta/beta.log"),

        new UnitTestElement(TestFileLine("Find all directories recursively under /home/user"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/home/user/**/*",                   "/",    "/",        Objects.Directories, MatchCasing.PlatformDefault, false, "/home/user/docs/", "/home/user/projects/", "/home/user/media/", "/home/user/projects/alpha/", "/home/user/projects/beta/", "/home/user/projects/gamma/", "/home/user/media/images/", "/home/user/media/videos/"),

        new UnitTestElement(TestFileLine("Find everything recursively under /opt"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/opt/**/*",                         "/",    "/",        Objects.FilesAndDirectories,    MatchCasing.PlatformDefault, false, "/opt/app/", "/opt/app/bin/", "/opt/app/lib/", "/opt/app/README", "/opt/app/bin/app", "/opt/app/bin/tool1", "/opt/app/bin/tool2", "/opt/app/lib/libcore.so", "/opt/app/lib/libutil.so", "/opt/app/lib/libhelper.so.1"),

        new UnitTestElement(TestFileLine("GlobstarRegex with specific starting pattern"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/home/**/file*.txt",                "/",    "/",        Objects.Files,   MatchCasing.PlatformDefault, false, "/home/user/docs/file1.txt"),

        // ==========================================================================================================
        // CASE SENSITIVITY (Unix is case-sensitive)
        // ==========================================================================================================
        //                                         fsFile  glob                                 cwd    start        objects          _matchCasing                 throws  results...
        new UnitTestElement(TestFileLine("Should NOT match uppercase when looking for lowercase"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/home/user/docs/readme*",           "/",    "/",        Objects.Files,  MatchCasing.PlatformDefault, false, "/home/user/docs/readme.txt"),

        new UnitTestElement(TestFileLine("Should NOT match lowercase when looking for uppercase"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/home/user/docs/README*",           "/",    "/",        Objects.Files,  MatchCasing.PlatformDefault, false, "/home/user/docs/README.md"),

        new UnitTestElement(TestFileLine("Case sensitivity - match 'Test' but not 'TEST'"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/test/bracket-tests/Test",          "/",    "/",        Objects.Files,  MatchCasing.PlatformDefault, false, "/test/bracket-tests/Test"),

        new UnitTestElement(TestFileLine("Case sensitivity - exact match"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/test/bracket-tests/TEST",          "/",    "/",        Objects.Files,  MatchCasing.PlatformDefault, false, "/test/bracket-tests/TEST"),

        // ==========================================================================================================
        // HIDDEN FILES (starting with dot) are returned by GlobEnumerator
        // ==========================================================================================================
        //                                         fsFile  glob                                 cwd    start        objects          _matchCasing                 throws  results...
        new UnitTestElement(TestFileLine("Match hidden files explicitly"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/home/user/.*",                     "/",    "/",        Objects.Files,   MatchCasing.PlatformDefault, false, "/home/user/.bashrc", "/home/user/.profile", "/home/user/.vimrc"),

        new UnitTestElement(TestFileLine("* should NOT match hidden files - only visible files"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/home/user/*",                      "/",    "/",        Objects.Files,   MatchCasing.PlatformDefault, false, "/home/user/data.txt", "/home/user/.bashrc", "/home/user/.profile", "/home/user/.vimrc"),

        new UnitTestElement(TestFileLine("Match hidden files with bracket expression"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/home/user/.[a-z]*",                "/",    "/",        Objects.Files,   MatchCasing.PlatformDefault, false, "/home/user/.bashrc", "/home/user/.profile", "/home/user/.vimrc"),

        new UnitTestElement(TestFileLine("Match specific hidden file pattern"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/home/user/.bash*",                 "/",    "/",        Objects.Files,   MatchCasing.PlatformDefault, false, "/home/user/.bashrc"),

        // ==========================================================================================================
        // COMPLEX COMBINATIONS
        // ==========================================================================================================
        //                                         fsFile  glob                                 cwd    start        objects          _matchCasing                 throws  results...
        new UnitTestElement(TestFileLine("Combine ** with character classes"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/home/**/[a-z]*.txt",                 "/",  "/",        Objects.Files,   MatchCasing.PlatformDefault, false, "/home/user/docs/readme.txt", "/home/user/docs/notes.txt", "/home/user/docs/file1.txt", "/home/user/data.txt", "/home/user/projects/project-list.txt"),

        new UnitTestElement(TestFileLine("Combine * and ? with brackets"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/test/bracket-tests/*-[ab].*",        "/",  "/",        Objects.Files,   MatchCasing.PlatformDefault, false, "/test/bracket-tests/file-a.txt", "/test/bracket-tests/file-b.txt"),

        new UnitTestElement(TestFileLine("Multiple wildcards in path"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/home/*/projects/*/main.c",           "/",  "/",        Objects.Files,   MatchCasing.PlatformDefault, false, "/home/user/projects/alpha/main.c"),

        new UnitTestElement(TestFileLine("Negation with wildcards"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/test/bracket-tests/file-[!0-9].*",   "/",  "/",        Objects.Files,   MatchCasing.PlatformDefault, false, "/test/bracket-tests/file-a.txt", "/test/bracket-tests/file-b.txt"),

        new UnitTestElement(TestFileLine("Complex pattern with multiple components"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/home/user/*/*/photo[12].*",          "/",  "/",        Objects.Files,   MatchCasing.PlatformDefault, false, "/home/user/media/images/photo1.jpg", "/home/user/media/images/photo2.png"),

        new UnitTestElement(TestFileLine("Combine character class with negation"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/test/bracket-tests/[![:digit:]]",    "/",  "/",        Objects.Files,   MatchCasing.PlatformDefault, false, "/test/bracket-tests/a", "/test/bracket-tests/b", "/test/bracket-tests/c", "/test/bracket-tests/x", "/test/bracket-tests/y", "/test/bracket-tests/z", "/test/bracket-tests/A", "/test/bracket-tests/B", "/test/bracket-tests/C"),

        // ==========================================================================================================
        // EDGE CASES AND SPECIAL SCENARIOS
        // ==========================================================================================================
        //                                         fsFile  glob                                 cwd    start        objects          _matchCasing                 throws  results...
        new UnitTestElement(TestFileLine("Empty pattern should throw"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "",                                  "/",    "/",        Objects.FilesAndDirectories,    MatchCasing.PlatformDefault, false, "/boot.img", "/etc/", "/home/", "/opt/", "/test/", "/var/", "/vmlinuz"),

        new UnitTestElement(TestFileLine("GlobRegex ending with / when searching for files should throw"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/home/user/docs/",                  "/",    "/",        Objects.Files,   MatchCasing.PlatformDefault, true),

        new UnitTestElement(TestFileLine("GlobRegex ending with ** when searching for files only should throw"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/home/**",                          "/",    "/",        Objects.Files,   MatchCasing.PlatformDefault, true),

        new UnitTestElement(TestFileLine("Match exact file name (no wildcards)"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/etc/hosts",                        "/",    "/",        Objects.Files,   MatchCasing.PlatformDefault, false, "/etc/hosts"),

        new UnitTestElement(TestFileLine("Match exact directory name"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/home/user/docs",                   "/",    "/",        Objects.Directories, MatchCasing.PlatformDefault, false, "/home/user/docs/"),

        new UnitTestElement(TestFileLine("No matches should return empty"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/home/user/docs/*.exe",             "/",    "/",        Objects.Files,   MatchCasing.PlatformDefault, false),

        new UnitTestElement(TestFileLine("Match multiple directory levels with *"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/*/*/*.conf",                       "/",    "/",        Objects.Files,   MatchCasing.PlatformDefault, false, "/etc/config/app.conf", "/etc/config/system.conf", "/etc/config/network.conf"),

        new UnitTestElement(TestFileLine("Match files with complex multiple extensions"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/opt/**/*.so*",                     "/",    "/",        Objects.Files,   MatchCasing.PlatformDefault, false, "/opt/app/lib/libcore.so", "/opt/app/lib/libutil.so", "/opt/app/lib/libhelper.so.1"),

        new UnitTestElement(TestFileLine("Using relative path from different current folder"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "docs/*.txt",                        "/",    "/home/user",Objects.Files,  MatchCasing.PlatformDefault, false, "/home/user/docs/readme.txt", "/home/user/docs/notes.txt", "/home/user/docs/file1.txt"),

        new UnitTestElement(TestFileLine("GlobRegex with only bracket expression"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/var/log/[aes]*",                   "/",    "/",        Objects.Files,   MatchCasing.PlatformDefault, false, "/var/log/syslog", "/var/log/auth.log", "/var/log/error.log", "/var/log/access.log", "/var/log/app1.log", "/var/log/app2.log", "/var/log/app10.log"),

        // ==========================================================================================================
        // PRACTICAL REAL-WORLD SCENARIOS
        // ==========================================================================================================
        //                                         fsFile  glob                                 cwd    start        objects          _matchCasing                 throws  results...
        new UnitTestElement(TestFileLine("Find all C source and header files"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/home/user/projects/**/*.[ch]",     "/",    "/",        Objects.Files,  MatchCasing.PlatformDefault, false, "/home/user/projects/alpha/main.c", "/home/user/projects/alpha/test.c", "/home/user/projects/alpha/helper.h"),

        new UnitTestElement(TestFileLine("Find all configuration files"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/**/*.conf",                        "/",    "/",        Objects.Files,  MatchCasing.PlatformDefault, false, "/etc/config/app.conf", "/etc/config/system.conf", "/etc/config/network.conf"),

        new UnitTestElement(TestFileLine("Find all shared libraries"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/**/*.so*",                         "/",    "/",        Objects.Files,  MatchCasing.PlatformDefault, false, "/opt/app/lib/libcore.so", "/opt/app/lib/libutil.so", "/opt/app/lib/libhelper.so.1"),

        new UnitTestElement(TestFileLine("Find all temporary files"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/var/tmp/*.tmp",                    "/",    "/",        Objects.Files,  MatchCasing.PlatformDefault, false, "/var/tmp/temp1.tmp", "/var/tmp/temp2.tmp"),

        new UnitTestElement(TestFileLine("Find all image files"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/home/**/images/*.*",               "/",    "/",        Objects.Files,  MatchCasing.PlatformDefault, false, "/home/user/media/images/photo1.jpg", "/home/user/media/images/photo2.png", "/home/user/media/images/icon.svg"),

        new UnitTestElement(TestFileLine("Find all project directories"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/home/user/projects/*",             "/",    "/",        Objects.Directories, MatchCasing.PlatformDefault, false, "/home/user/projects/alpha/", "/home/user/projects/beta/", "/home/user/projects/gamma/"),

        new UnitTestElement(TestFileLine("Find all backup/archive files"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/**/*.[zb][ia][pk]*",               "/",    "/",        Objects.Files,  MatchCasing.PlatformDefault, false, "/test/special/archive-2024.zip", "/test/special/file.bak"),

        new UnitTestElement(TestFileLine("Find all markdown and text documentation"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/**/[Rr][Ee][Aa][Dd][Mm][Ee]*",     "/",    "/",        Objects.Files,  MatchCasing.PlatformDefault, false, "/home/user/docs/README.md", "/home/user/docs/readme.txt", "/opt/app/README"),

        new UnitTestElement(TestFileLine("Find all log files with numeric suffixes"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/var/log/*[0-9].log",               "/",    "/",        Objects.Files,  MatchCasing.PlatformDefault, false, "/var/log/app1.log", "/var/log/app2.log", "/var/log/app10.log"),

        new UnitTestElement(TestFileLine("Find all Python files in all projects"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/home/**/projects/**/*.py",          "/",    "/",       Objects.Files,  MatchCasing.PlatformDefault, false, "/home/user/projects/beta/app.py", "/home/user/projects/beta/test.py", "/home/projects/alpha.py", "/home/projects/alpha/alpha.py", "/home/projects/beta/beta.py"),

        // ==========================================================================================================
        // CATEGORY D: MULTIPLE GLOBSTARS (GlobRegex Normalization - Future Feature)
        // ==========================================================================================================
        // NOTE: These tests verify current behavior - no duplicates. When de-normalization is implemented, these should produce duplicates.
        //                                         fsFile  glob                                 cwd    start        objects          _matchCasing                 throws  results...
        new UnitTestElement(TestFileLine("Double ** should be semantically equivalent to single **"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/home/**/user/**/*.txt",             "/",   "/",        Objects.Files,  MatchCasing.PlatformDefault, false, "/home/user/data.txt", "/home/user/docs/readme.txt", "/home/user/docs/notes.txt", "/home/user/docs/file1.txt", "/home/user/projects/project-list.txt"),

        new UnitTestElement(TestFileLine("Triple ** in path"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/**/user/**/docs/**/*.txt",          "/",   "/",        Objects.Files,  MatchCasing.PlatformDefault, false, "/home/user/docs/readme.txt", "/home/user/docs/notes.txt", "/home/user/docs/file1.txt"),

        new UnitTestElement(TestFileLine("Adjacent ** wildcards"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/home/**/**/data.txt",               "/",   "/",        Objects.Files,  MatchCasing.PlatformDefault, false, "/home/user/data.txt"),

        // ==========================================================================================================
        // CATEGORY B: EMPTY/MISSING PATH COMPONENTS AND BOUNDARY CONDITIONS
        // ==========================================================================================================
        //                                         fsFile  glob                                 cwd    start        objects          _matchCasing                 throws  results...
        new UnitTestElement(TestFileLine("Match empty folder (folder with no files)"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/home/user/media/*",                "/",    "/",        Objects.Files,  MatchCasing.PlatformDefault, false),

        new UnitTestElement(TestFileLine("Match empty folder as directory"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/home/user/media",                  "/",    "/",        Objects.Directories, MatchCasing.PlatformDefault, false, "/home/user/media/"),

        new UnitTestElement(TestFileLine("Non-existent path should return empty"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/nonexistent/**/*.txt",             "/",    "/",        Objects.Files,  MatchCasing.PlatformDefault, false),

        new UnitTestElement(TestFileLine("Non-existent deep path should return empty"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/home/user/missing/folder/*.txt",   "/",    "/",        Objects.Files,  MatchCasing.PlatformDefault, false),

        new UnitTestElement(TestFileLine("GlobRegex with multiple consecutive slashes"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/home///user///docs/*.txt",         "/",    "/",        Objects.Files,  MatchCasing.PlatformDefault, false, "/home/user/docs/readme.txt", "/home/user/docs/notes.txt", "/home/user/docs/file1.txt"),

        new UnitTestElement(TestFileLine("Root pattern with trailing slash"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/",                                 "/",    "/",        Objects.Directories, MatchCasing.PlatformDefault, false, "/home/", "/var/", "/etc/", "/opt/", "/test/"),

        // ==========================================================================================================
        // CATEGORY C: SPECIAL CHARACTERS (using FakeFS1.Unix.json)
        // ==========================================================================================================/
        //                                         fsFile  glob                                 cwd    start        objects          _matchCasing                 throws  results...
        new UnitTestElement(TestFileLine("Match files with spaces in names"),
                                                   "FakeFSFiles/FakeFS1.Unix.json",
                                                           "/home/valo/Downloads/*Order*.pdf",  "/",    "/",        Objects.Files, MatchCasing.PlatformDefault, false, "/home/valo/Downloads/Amazon Order.pdf"),

        new UnitTestElement(TestFileLine("Match files with parentheses in names"),
                                                   "FakeFSFiles/FakeFS1.Unix.json",
                                                           "/home/valo/Downloads/*(*).zip",     "/",    "/",        Objects.Files, MatchCasing.PlatformDefault, false, "/home/valo/Downloads/benchmark-summaries-ubuntu-latest (1).zip"),

        new UnitTestElement(TestFileLine("Match files with dates and timestamps"),
                                                   "FakeFSFiles/FakeFS1.Unix.json",
                                                           "/home/valo/Downloads/2025-??-??T*", "/",    "/",        Objects.Files,MatchCasing.PlatformDefault, false, "/home/valo/Downloads/2025-09-30T01_44_59-FedEx-Transaction-Record.pdf"),

        new UnitTestElement(TestFileLine("Match partial download files (crdownload)"),
                                                   "FakeFSFiles/FakeFS1.Unix.json",
                                                           "/home/valo/Downloads/*.crdownload", "/",    "/",        Objects.Files,MatchCasing.PlatformDefault, false, "/home/valo/Downloads/Resume.pdf.crdownload", "/home/valo/Downloads/Unconfirmed 365032.crdownload"),

        new UnitTestElement(TestFileLine("Match files with multiple dots in name"),
                                                   "FakeFSFiles/FakeFS1.Unix.json",
                                                           "/home/valo/Downloads/vm2.*.json",   "/",    "/",        Objects.Files, MatchCasing.PlatformDefault, false, "/home/valo/Downloads/vm2.UlidType.Benchmarks.NewUlid-report-full-compressed.json", "/home/valo/Downloads/vm2.UlidType.Benchmarks.NewUlid-report.json", "/home/valo/Downloads/vm2.UlidType.Benchmarks.ParseUlid-report-full-compressed.json", "/home/valo/Downloads/vm2.UlidType.Benchmarks.ParseUlid-report.json", "/home/valo/Downloads/vm2.UlidType.Benchmarks.UlidToString-report-full-compressed.json", "/home/valo/Downloads/vm2.UlidType.Benchmarks.UlidToString-report.json"),

        new UnitTestElement(TestFileLine("Match files with hyphens and underscores"),
                                                   "FakeFSFiles/FakeFS1.Unix.json",
                                                           "/home/valo/Downloads/**/*-report-*.md","/", "/",        Objects.Files, MatchCasing.PlatformDefault, false, "/home/valo/Downloads/benchmark-summaries-ubuntu-latest/results/vm2.UlidType.Benchmarks.NewUlid-report-github.md", "/home/valo/Downloads/benchmark-summaries-ubuntu-latest/results/vm2.UlidType.Benchmarks.ParseUlid-report-github.md", "/home/valo/Downloads/benchmark-summaries-ubuntu-latest/results/vm2.UlidType.Benchmarks.UlidToString-report-github.md"),

        new UnitTestElement(TestFileLine("GlobstarRegex search with complex nested names"),
                                                   "FakeFSFiles/FakeFS1.Unix.json",
                                                           "/**/*summary.json",                 "/",    "/",        Objects.Files, MatchCasing.PlatformDefault, false, "/home/valo/Downloads/benchmark-summaries-ubuntu-latest/summaries/vm2.UlidType.Benchmarks.NewUlid-summary.json", "/home/valo/Downloads/benchmark-summaries-ubuntu-latest/summaries/vm2.UlidType.Benchmarks.ParseUlid-summary.json", "/home/valo/Downloads/benchmark-summaries-ubuntu-latest/summaries/vm2.UlidType.Benchmarks.UlidToString-summary.json"),

        // ==========================================================================================================
        // CATEGORY D: COMPLEX BRACKET EXPRESSIONS
        // ==========================================================================================================/
        //                                         fsFile  glob                                 cwd    start        objects          _matchCasing                 throws  results...
        new UnitTestElement(TestFileLine("Multiple ranges in single bracket [a-zA-Z0-9]"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/test/bracket-tests/[a-zA-Z0-9]",   "/",    "/",        Objects.Files,  MatchCasing.PlatformDefault, false, "/test/bracket-tests/a", "/test/bracket-tests/b", "/test/bracket-tests/c", "/test/bracket-tests/x", "/test/bracket-tests/y", "/test/bracket-tests/z", "/test/bracket-tests/A", "/test/bracket-tests/B", "/test/bracket-tests/C", "/test/bracket-tests/1", "/test/bracket-tests/2", "/test/bracket-tests/3", "/test/bracket-tests/9"),

        new UnitTestElement(TestFileLine("Single character in brackets [a]"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/test/bracket-tests/[a]",           "/",    "/",        Objects.Files,  MatchCasing.PlatformDefault, false, "/test/bracket-tests/a"),

        new UnitTestElement(TestFileLine("Negation of character class [![:lower:]]"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/test/bracket-tests/[![:lower:]]",  "/",    "/",        Objects.Files, MatchCasing.PlatformDefault, false, "/test/bracket-tests/A", "/test/bracket-tests/B", "/test/bracket-tests/C", "/test/bracket-tests/1", "/test/bracket-tests/2", "/test/bracket-tests/3", "/test/bracket-tests/9"),

        new UnitTestElement(TestFileLine("Negation of character class with range [![:digit:]]"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/test/bracket-tests/[![:digit:]]",  "/",    "/",        Objects.Files, MatchCasing.PlatformDefault, false, "/test/bracket-tests/a", "/test/bracket-tests/b", "/test/bracket-tests/c", "/test/bracket-tests/x", "/test/bracket-tests/y", "/test/bracket-tests/z", "/test/bracket-tests/A", "/test/bracket-tests/B", "/test/bracket-tests/C"),

        new UnitTestElement(TestFileLine("Complex bracket with multiple character classes [[:alpha:][:digit:]]"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/test/bracket-tests/[-[:alpha:].[:digit:]_]","/","/",   Objects.Files,  MatchCasing.PlatformDefault, false, "/test/bracket-tests/a", "/test/bracket-tests/b", "/test/bracket-tests/c", "/test/bracket-tests/x", "/test/bracket-tests/y", "/test/bracket-tests/z", "/test/bracket-tests/A", "/test/bracket-tests/B", "/test/bracket-tests/C", "/test/bracket-tests/1", "/test/bracket-tests/2", "/test/bracket-tests/3", "/test/bracket-tests/9"),

        new UnitTestElement(TestFileLine("Bracket with range and explicit chars [a-c5-7xyz]"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/test/bracket-tests/[a-c5-7xyz]",   "/",    "/",        Objects.Files,  MatchCasing.PlatformDefault, false, "/test/bracket-tests/a", "/test/bracket-tests/b", "/test/bracket-tests/c", "/test/bracket-tests/x", "/test/bracket-tests/y", "/test/bracket-tests/z"),

        // ==========================================================================================================
        // CATEGORY E: EXTREME PATTERNS AND CONSECUTIVE WILDCARDS
        // ==========================================================================================================
        //                                         fsFile  glob                                 cwd    start        objects          _matchCasing                 throws  results...
        new UnitTestElement(TestFileLine("Many consecutive asterisks *** should work like *"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/etc/***",                          "/",  "/",          Objects.Files,  MatchCasing.PlatformDefault, true,  "/etc/hosts", "/etc/passwd", "/etc/group", "/etc/fstab"),

        new UnitTestElement(TestFileLine("Four asterisks **** should work like *"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/var/log/app****.log",              "/",  "/",          Objects.Files,  MatchCasing.PlatformDefault, true,  "/var/log/app1.log", "/var/log/app2.log", "/var/log/app10.log"),

        new UnitTestElement(TestFileLine("Many question marks (16 chars)"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/var/log/????????????????",         "/",  "/",          Objects.Files,  MatchCasing.PlatformDefault, false),

        new UnitTestElement(TestFileLine("Many levels of single asterisk"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/*/*/*/*",                          "/",  "/",          Objects.Files,  MatchCasing.PlatformDefault, false, "/home/projects/alpha/alpha.data", "/home/projects/alpha/alpha.log", "/home/projects/alpha/alpha.py", "/home/projects/beta/beta.data", "/home/projects/beta/beta.log", "/home/projects/beta/beta.py", "/home/user/docs/README.md", "/home/user/docs/archive.tar.gz", "/home/user/docs/backup.tar.bz2", "/home/user/docs/file1.txt", "/home/user/docs/file2.dat", "/home/user/docs/notes.txt", "/home/user/docs/readme.txt", "/home/user/projects/project-list.txt", "/opt/app/bin/app", "/opt/app/bin/tool1", "/opt/app/bin/tool2", "/opt/app/lib/libcore.so", "/opt/app/lib/libhelper.so.1", "/opt/app/lib/libutil.so"),

        new UnitTestElement(TestFileLine("Very specific pattern with many components"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/home/*/projects/*/test.*",         "/",  "/",          Objects.Files,  MatchCasing.PlatformDefault, false, "/home/user/projects/alpha/test.c", "/home/user/projects/beta/test.py"),

        new UnitTestElement(TestFileLine("GlobRegex with all wildcard types combined"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/home/**/p?ojects/[ab]*/test.*",    "/",  "/",          Objects.Files,  MatchCasing.PlatformDefault, false, "/home/user/projects/alpha/test.c", "/home/user/projects/beta/test.py"),

        // ==========================================================================================================
        // CATEGORY F: RELATIVE PATH EDGE CASES
        // ==========================================================================================================
        //                                         fsFile  glob                                 cwd    start        objects          _matchCasing                 throws  results...
        new UnitTestElement(TestFileLine("Current directory notation ./docs/*.txt"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "./docs/*.txt",                      "/",    "/home/user",Objects.Files,  MatchCasing.PlatformDefault, false,  "/home/user/docs/readme.txt", "/home/user/docs/notes.txt", "/home/user/docs/file1.txt"),

        new UnitTestElement(TestFileLine("Relative path with subdirectory"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "user/docs/*.txt",                   "/",    "/home",    Objects.Files,   MatchCasing.PlatformDefault, false,  "/home/user/docs/readme.txt", "/home/user/docs/notes.txt", "/home/user/docs/file1.txt"),

        new UnitTestElement(TestFileLine("Relative path from nested directory"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "alpha/*.c",                         "/",    "/home/user/projects",Objects.Files,  MatchCasing.PlatformDefault, false,  "/home/user/projects/alpha/main.c", "/home/user/projects/alpha/test.c"),

        new UnitTestElement(TestFileLine("Relative path with wildcard subdirectory"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "projects/*/test.*",                 "/",    "/home/user",Objects.Files,  MatchCasing.PlatformDefault, false, "/home/user/projects/alpha/test.c", "/home/user/projects/beta/test.py"),

        // ==========================================================================================================
        // CATEGORY G: BOUNDARY CONDITIONS WITH SIMPLE fsFile TEM (FakeFS2.Unix.json)
        // ==========================================================================================================
        //                                         fsFile  glob                                 cwd    start        objects          _matchCasing                 throws  results...
        new UnitTestElement(TestFileLine("Simple FS: Match all files from root"),
                                                   "FakeFSFiles/FakeFS2.Unix.json",
                                                           "/**/*.txt",                         "/",    "/",        Objects.Files,   MatchCasing.PlatformDefault, false, "/root.txt", "/folder1/file1.txt", "/folder1/folder2/file2.txt", "/folder3/file3.txt"),

        new UnitTestElement(TestFileLine("Simple FS: Single level wildcard"),
                                                   "FakeFSFiles/FakeFS2.Unix.json",
                                                           "/*",                                "/",    "/",        Objects.FilesAndDirectories,    MatchCasing.PlatformDefault, false, "/folder1/", "/folder3/", "/root.txt"),

        new UnitTestElement(TestFileLine("Simple FS: Two level path"),
                                                   "FakeFSFiles/FakeFS2.Unix.json",
                                                           "/*/*",                              "/",    "/",        Objects.Files,   MatchCasing.PlatformDefault, false, "/folder1/file1.txt", "/folder3/file3.txt"),

        new UnitTestElement(TestFileLine("Simple FS: Exact path to nested file"),
                                                   "FakeFSFiles/FakeFS2.Unix.json",
                                                           "/folder1/folder2/file2.txt",        "/",    "/",        Objects.Files,   MatchCasing.PlatformDefault, false, "/folder1/folder2/file2.txt"),

        new UnitTestElement(TestFileLine("Simple FS: All directories recursively"),
                                                   "FakeFSFiles/FakeFS2.Unix.json",
                                                           "/**/*",                             "/",    "/",        Objects.Directories, MatchCasing.PlatformDefault, false, "/folder1/", "/folder3/", "/folder1/folder2/"),

        new UnitTestElement(TestFileLine("Simple FS: Everything recursively"),
                                                   "FakeFSFiles/FakeFS2.Unix.json",
                                                           "/**/*",                             "/",    "/",        Objects.FilesAndDirectories,    MatchCasing.PlatformDefault, false, "/folder1/", "/folder3/", "/root.txt", "/folder1/folder2/", "/folder1/file1.txt", "/folder1/folder2/file2.txt", "/folder3/file3.txt"),

        // ==========================================================================================================
        // CATEGORY H: ERROR CASES (throws = _matchCasing.PlatformDefault, true)
        // ==========================================================================================================
        //                                         fsFile  glob                                 cwd    start        objects          _matchCasing                 throws  results...
        new UnitTestElement(TestFileLine("GlobRegex with unmatched opening bracket [abc"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/test/bracket-tests/[abc",          "/",    "/",        Objects.Files,   MatchCasing.PlatformDefault, false),

        new UnitTestElement(TestFileLine("GlobRegex with unmatched closing bracket abc]"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/test/bracket-tests/abc]",          "/",    "/",        Objects.Files,   MatchCasing.PlatformDefault, false),

        new UnitTestElement(TestFileLine("GlobRegex with empty brackets []"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/test/bracket-tests/file[]",        "/",    "/",        Objects.Files,   MatchCasing.PlatformDefault, true),

        new UnitTestElement(TestFileLine("GlobRegex with only negation [!]"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/test/bracket-tests/[!]",           "/",    "/",        Objects.Files,   MatchCasing.PlatformDefault, false),

        new UnitTestElement(TestFileLine("GlobRegex with only closing bracket []]"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/test/bracket-tests/[]]",           "/",    "/",        Objects.Files,   MatchCasing.PlatformDefault, false),

        new UnitTestElement(TestFileLine("GlobRegex with negated closing bracket [!]]"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/test/bracket-tests/[!]]",           "/",    "/",        Objects.Files,   MatchCasing.PlatformDefault, false),

        new UnitTestElement(TestFileLine("GlobRegex with invalid character class [[:invalid:]]"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/test/bracket-tests/[[:invalid:]]", "/",    "/",        Objects.Files,   MatchCasing.PlatformDefault, false),

        new UnitTestElement(TestFileLine("GlobRegex with backslash \\home\\user"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "\\home\\user\\*.txt",               "/",    "/",        Objects.Files,   MatchCasing.PlatformDefault, false),

        new UnitTestElement(TestFileLine("GlobRegex starting with ** without separator **docs"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "**docs/*.txt",                      "/",    "/",        Objects.Files,   MatchCasing.PlatformDefault, true),

        new UnitTestElement(TestFileLine("GlobRegex with ** in middle without separators home**user"),
                                                   "FakeFSFiles/FakeFS3.Unix.json",
                                                           "/home**user/*.txt",                 "/",    "/",        Objects.Files,   MatchCasing.PlatformDefault, true),
    ];
}
