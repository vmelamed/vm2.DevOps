namespace vm2.DevOps.Glob.Api.Tests;

public partial class GlobsTests
{

    [ExcludeFromCodeCoverage]
    public class GlobEnumerate_TestData(
        string testFileLine,
        string fsFile,
        string glob,
        string workingDir,
        string startDir,
        Objects objects,
        MatchCasing matchCasing,
        bool throws,
        params string[] results) : IXunitSerializable
    {
        #region boilerplate
        public GlobEnumerate_TestData()
            : this("", "", "", "", "", Objects.Both, MatchCasing.PlatformDefault, false, [])
        {
        }

        #region Properties
        public string A { get; private set; } = testFileLine;
        public string File { get; private set; } = fsFile;
        public string Glob { get; private set; } = glob;
        public string WorkDir { get; private set; } = workingDir;
        public string StartDir { get; private set; } = startDir;
        public Objects Objects { get; private set; } = objects;
        public MatchCasing MatchCasing { get; private set; } = matchCasing;
        public bool Throws { get; private set; } = throws;
        public string[] Results { get; private set; } = [.. results.AsEnumerable().OrderBy(s => s, StringComparer.Ordinal)];
        #endregion

        public void Deserialize(IXunitSerializationInfo info)
        {
            A           = info.GetValue<string>(nameof(A)) ?? "";
            File        = info.GetValue<string>(nameof(File)) ?? "";
            Glob        = info.GetValue<string>(nameof(Glob)) ?? "";
            WorkDir     = info.GetValue<string>(nameof(WorkDir)) ?? "";
            StartDir    = info.GetValue<string>(nameof(StartDir)) ?? "";
            Objects     = info.GetValue<Objects>(nameof(Objects));
            MatchCasing = info.GetValue<MatchCasing>(nameof(MatchCasing));
            Throws      = info.GetValue<bool>(nameof(Throws));
            Results     = info.GetValue<string[]>(nameof(Results)) ?? [];
        }

        public void Serialize(IXunitSerializationInfo info)
        {
            info.AddValue(nameof(A), A);
            info.AddValue(nameof(File), File);
            info.AddValue(nameof(Glob), Glob);
            info.AddValue(nameof(WorkDir), WorkDir);
            info.AddValue(nameof(StartDir), StartDir);
            info.AddValue(nameof(Objects), Objects);
            info.AddValue(nameof(MatchCasing), MatchCasing);
            info.AddValue(nameof(Throws), Throws);
            info.AddValue(nameof(Results), Results);
        }
        #endregion
    }

    public static TheoryData<GlobEnumerate_TestData> Enumerate_TestDataSet =
    [
        //                                         fileSys                          glob                    curDir  startDir    objects              MatchCasing                  throws  results...
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "",                     "C:/",  "/",        Objects.Both,        MatchCasing.PlatformDefault, true),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "a**/*.txt",            "C:/",  "/",        Objects.Both,        MatchCasing.PlatformDefault, true),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "C:/folder1/f**/*.txt", "C:/",  "/",        Objects.Both,        MatchCasing.PlatformDefault, true),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "C:/folder1/",          "C:/",  "/",        Objects.Files,       MatchCasing.PlatformDefault, true),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "C:/folder1/**",        "C:/",  "/",        Objects.Files,       MatchCasing.PlatformDefault, true),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "*",                    "C:/",  "/",        Objects.Both,        MatchCasing.PlatformDefault, false,  "C:/folder1/"                 , "C:/folder3/", "C:/root.txt"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "*",                    "C:/",  "/",        Objects.Files,       MatchCasing.PlatformDefault, false,  "C:/root.txt"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "*",                    "C:/",  "/",        Objects.Directories, MatchCasing.PlatformDefault, false,  "C:/folder1/"                 , "C:/folder3/"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "/folder1",             "C:/",  "/",        Objects.Both,        MatchCasing.PlatformDefault, false,  "C:/folder1/"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "/FOLDER1",             "C:/",  "/",        Objects.Both,        MatchCasing.PlatformDefault, false,  "C:/folder1/"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "/folder1",             "C:/",  "/",        Objects.Files,       MatchCasing.PlatformDefault, false,  []),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "/folder1",             "C:/",  "/",        Objects.Directories, MatchCasing.PlatformDefault, false,  "C:/folder1/"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "/folder1/*",           "C:/",  "/",        Objects.Both,        MatchCasing.PlatformDefault, false,  "C:/folder1/folder2/"         ,  "C:/folder1/file1.txt"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "/folder1/*",           "C:/",  "/",        Objects.Files,       MatchCasing.PlatformDefault, false,  "C:/folder1/file1.txt"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "/folder1/*",           "C:/",  "/",        Objects.Directories, MatchCasing.PlatformDefault, false,  "C:/folder1/folder2/"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "/folder1/folder2/*",   "C:/",  "/",        Objects.Both,        MatchCasing.PlatformDefault, false,  "C:/folder1/folder2/file2.txt"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "/folder1/folder2/*",   "C:/",  "/",        Objects.Files,       MatchCasing.PlatformDefault, false,  "C:/folder1/folder2/file2.txt"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "folder2/*",            "C:/",  "/folder1", Objects.Files,       MatchCasing.PlatformDefault, false,  "C:/folder1/folder2/file2.txt"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "/folder1/folder2/*",   "C:/",  "/",        Objects.Directories, MatchCasing.PlatformDefault, false),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "folder2/*",            "C:/",  "/folder1", Objects.Directories, MatchCasing.PlatformDefault, false),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "/*/*",                 "C:/",  "/",        Objects.Both,        MatchCasing.PlatformDefault, false,  "C:/folder1/folder2/"         , "C:/folder1/file1.txt", "C:/folder3/file3.txt"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "/*/*",                 "C:/",  "/",        Objects.Files,       MatchCasing.PlatformDefault, false,  "C:/folder1/file1.txt"        , "C:/folder3/file3.txt"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "/*/*",                 "C:/",  "/",        Objects.Directories, MatchCasing.PlatformDefault, false,  "C:/folder1/folder2/"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "/**/*",                "C:/",  "/",        Objects.Both,        MatchCasing.PlatformDefault, false,  "C:/folder1/folder2/"         , "C:/folder1/folder2/file2.txt", "C:/folder3/", "C:/folder1/", "C:/root.txt", "C:/folder1/file1.txt", "C:/folder3/file3.txt"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "/**/*",                "C:/",  "/",        Objects.Files,       MatchCasing.PlatformDefault, false,  "C:/folder1/folder2/file2.txt", "C:/root.txt", "C:/folder1/file1.txt", "C:/folder3/file3.txt"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "/**/*",                "C:/",  "/",        Objects.Directories, MatchCasing.PlatformDefault, false,  "C:/folder1/folder2/"         , "C:/folder3/", "C:/folder1/"),
        //                                         fileSys                          glob                    curDir  startDir    objects              MatchCasing                  throws  results...
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "*",                    "/",    "/",        Objects.Both,        MatchCasing.PlatformDefault, false,  "/folder1/"                   , "/folder3/", "/root.txt"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "*",                    "/",    "/",        Objects.Files,       MatchCasing.PlatformDefault, false,  "/root.txt"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "*",                    "/",    "/",        Objects.Directories, MatchCasing.PlatformDefault, false,  "/folder1/"                   , "/folder3/"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "/folder1",             "/",    "/",        Objects.Both,        MatchCasing.PlatformDefault, false,  "/folder1/"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "/folder1",             "/",    "/",        Objects.Files,       MatchCasing.PlatformDefault, false),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "/folder1",             "/",    "/",        Objects.Directories, MatchCasing.PlatformDefault, false,  "/folder1/"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "/folder1/*",           "/",    "/",        Objects.Both,        MatchCasing.PlatformDefault, false,  "/folder1/folder2/"           ,  "/folder1/file1.txt"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "/folder1/*",           "/",    "/",        Objects.Files,       MatchCasing.PlatformDefault, false,  "/folder1/file1.txt"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "/folder1/*",           "/",    "/",        Objects.Directories, MatchCasing.PlatformDefault, false,  "/folder1/folder2/"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "/folder1/folder2/*",   "/",    "/",        Objects.Both,        MatchCasing.PlatformDefault, false,  "/folder1/folder2/file2.txt"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "/FOLDER1/FOLDER2/*",   "/",    "/",        Objects.Both,        MatchCasing.PlatformDefault, false),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "/FOLDER1/FOLDER2/*",   "/",    "/",        Objects.Both,        MatchCasing.PlatformDefault, false),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "/folder1/folder2/*",   "/",    "/",        Objects.Files,       MatchCasing.PlatformDefault, false,  "/folder1/folder2/file2.txt"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "/folder1/FOLDER2/*",   "/",    "/",        Objects.Files,       MatchCasing.PlatformDefault, false),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "/folder1/folder2/*",   "/",    "/",        Objects.Directories, MatchCasing.PlatformDefault, false),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "/*/*",                 "/",    "/",        Objects.Both,        MatchCasing.PlatformDefault, false,  "/folder1/folder2/"           , "/folder1/file1.txt", "/folder3/file3.txt"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "/*/*",                 "/",    "/",        Objects.Files,       MatchCasing.PlatformDefault, false,  "/folder1/file1.txt"          , "/folder3/file3.txt"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "/*/*",                 "/",    "/",        Objects.Directories, MatchCasing.PlatformDefault, false,  "/folder1/folder2/"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "/**/*",                "/",    "/",        Objects.Both,        MatchCasing.PlatformDefault, false,  "/folder1/folder2/"           , "/folder1/folder2/file2.txt", "/folder3/", "/folder1/", "/root.txt", "/folder1/file1.txt", "/folder3/file3.txt"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "/**/*",                "/",    "/",        Objects.Files,       MatchCasing.PlatformDefault, false,  "/folder1/folder2/file2.txt"  , "/root.txt", "/folder1/file1.txt", "/folder3/file3.txt"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "/**/*",                "/",    "/",        Objects.Directories, MatchCasing.PlatformDefault, false,  "/folder1/folder2/"           , "/folder3/", "/folder1/"),
    ];
}
