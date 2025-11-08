namespace vm2.DevOps.Glob.Api.Tests;

public partial class GlobsTests
{

    [ExcludeFromCodeCoverage]
    public class GlobEnumerate_TestData(
        string testFileLine,
        string jsonFile,
        string pattern,
        string currentFolder,
        string path,
        Enumerated enumerated,
        bool throws,
        params string[] results) : IXunitSerializable
    {
        #region boilerplate
        public GlobEnumerate_TestData()
            : this("", "", "", "", "", Enumerated.Both, false, [])
        {
        }
        #region Properties
        public string AFileLine { get; private set; } = testFileLine;
        public string JsonFile { get; private set; } = jsonFile;
        public string CurrentFolder { get; private set; } = currentFolder;
        public string Path { get; private set; } = path;
        public string Pattern { get; private set; } = pattern;
        public Enumerated Enumerated { get; private set; } = enumerated;
        public string[] Results { get; private set; } = [.. results.AsEnumerable().OrderBy(s => s, StringComparer.Ordinal)];
        public bool Throws { get; private set; } = throws;
        #endregion

        public void Deserialize(IXunitSerializationInfo info)
        {
            AFileLine     = info.GetValue<string>(nameof(AFileLine)) ?? "";
            JsonFile      = info.GetValue<string>(nameof(JsonFile)) ?? "";
            CurrentFolder = info.GetValue<string>(nameof(CurrentFolder)) ?? "";
            Path          = info.GetValue<string>(nameof(Path)) ?? "";
            Pattern       = info.GetValue<string>(nameof(Pattern)) ?? "";
            Enumerated    = info.GetValue<Enumerated>(nameof(Enumerated));
            Results       = info.GetValue<string[]>(nameof(Results)) ?? [];
            Throws        = info.GetValue<bool>(nameof(Throws));
        }

        public void Serialize(IXunitSerializationInfo info)
        {
            info.AddValue(nameof(AFileLine), AFileLine);
            info.AddValue(nameof(JsonFile), JsonFile);
            info.AddValue(nameof(CurrentFolder), CurrentFolder);
            info.AddValue(nameof(Path), Path);
            info.AddValue(nameof(Pattern), Pattern);
            info.AddValue(nameof(Enumerated), Enumerated);
            info.AddValue(nameof(Results), Results);
            info.AddValue(nameof(Throws), Throws);
        }
        #endregion
    }

    public static TheoryData<GlobEnumerate_TestData> Enumerate_TestDataSet =
    [
        //                                         fileSys                          pattern                 curDir  path        enumerated              throws  results...
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "",                     "C:/",  "/",        Enumerated.Both,        true),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "a**/*.txt",            "C:/",  "/",        Enumerated.Both,        true),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "C:/folder1/f**/*.txt", "C:/",  "/",        Enumerated.Both,        true),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "C:/folder1/",          "C:/",  "/",        Enumerated.Files,       true),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "C:/folder1/**",        "C:/",  "/",        Enumerated.Files,       true),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "*",                    "C:/",  "/",        Enumerated.Both,        false,  "C:/folder1/"                 , "C:/folder3/", "C:/root.txt"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "*",                    "C:/",  "/",        Enumerated.Files,       false,  "C:/root.txt"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "*",                    "C:/",  "/",        Enumerated.Directories, false,  "C:/folder1/"                 , "C:/folder3/"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "/folder1",             "C:/",  "/",        Enumerated.Both,        false,  "C:/folder1/"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "/FOLDER1",             "C:/",  "/",        Enumerated.Both,        false,  "C:/folder1/"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "/folder1",             "C:/",  "/",        Enumerated.Files,       false,  []),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "/folder1",             "C:/",  "/",        Enumerated.Directories, false,  "C:/folder1/"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "/folder1/*",           "C:/",  "/",        Enumerated.Both,        false,  "C:/folder1/folder2/"         ,  "C:/folder1/file1.txt"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "/folder1/*",           "C:/",  "/",        Enumerated.Files,       false,  "C:/folder1/file1.txt"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "/folder1/*",           "C:/",  "/",        Enumerated.Directories, false,  "C:/folder1/folder2/"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "/folder1/folder2/*",   "C:/",  "/",        Enumerated.Both,        false,  "C:/folder1/folder2/file2.txt"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "/folder1/folder2/*",   "C:/",  "/",        Enumerated.Files,       false,  "C:/folder1/folder2/file2.txt"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "folder2/*",            "C:/",  "/folder1", Enumerated.Files,       false,  "C:/folder1/folder2/file2.txt"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "/folder1/folder2/*",   "C:/",  "/",        Enumerated.Directories, false),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "folder2/*",            "C:/",  "/folder1", Enumerated.Directories, false),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "/*/*",                 "C:/",  "/",        Enumerated.Both,        false,  "C:/folder1/folder2/"         , "C:/folder1/file1.txt", "C:/folder3/file3.txt"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "/*/*",                 "C:/",  "/",        Enumerated.Files,       false,  "C:/folder1/file1.txt"        , "C:/folder3/file3.txt"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "/*/*",                 "C:/",  "/",        Enumerated.Directories, false,  "C:/folder1/folder2/"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "/**/*",                "C:/",  "/",        Enumerated.Both,        false,  "C:/folder1/folder2/"         , "C:/folder1/folder2/file2.txt", "C:/folder3/", "C:/folder1/", "C:/root.txt", "C:/folder1/file1.txt", "C:/folder3/file3.txt"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "/**/*",                "C:/",  "/",        Enumerated.Files,       false,  "C:/folder1/folder2/file2.txt", "C:/root.txt", "C:/folder1/file1.txt", "C:/folder3/file3.txt"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "/**/*",                "C:/",  "/",        Enumerated.Directories, false,  "C:/folder1/folder2/"         , "C:/folder3/", "C:/folder1/"),
        //                                         fileSys                          pattern                 curDir  path        enumerated              throws  results...
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "*",                    "/",    "/",        Enumerated.Both,        false,  "/folder1/"                   , "/folder3/", "/root.txt"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "*",                    "/",    "/",        Enumerated.Files,       false,  "/root.txt"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "*",                    "/",    "/",        Enumerated.Directories, false,  "/folder1/"                   , "/folder3/"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "/folder1",             "/",    "/",        Enumerated.Both,        false,  "/folder1/"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "/folder1",             "/",    "/",        Enumerated.Files,       false),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "/folder1",             "/",    "/",        Enumerated.Directories, false,  "/folder1/"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "/folder1/*",           "/",    "/",        Enumerated.Both,        false,  "/folder1/folder2/"           ,  "/folder1/file1.txt"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "/folder1/*",           "/",    "/",        Enumerated.Files,       false,  "/folder1/file1.txt"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "/folder1/*",           "/",    "/",        Enumerated.Directories, false,  "/folder1/folder2/"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "/folder1/folder2/*",   "/",    "/",        Enumerated.Both,        false,  "/folder1/folder2/file2.txt"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "/FOLDER1/FOLDER2/*",   "/",    "/",        Enumerated.Both,        false),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "/FOLDER1/FOLDER2/*",   "/",    "/",        Enumerated.Both,        false),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "/folder1/folder2/*",   "/",    "/",        Enumerated.Files,       false,  "/folder1/folder2/file2.txt"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "/folder1/FOLDER2/*",   "/",    "/",        Enumerated.Files,       false),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "/folder1/folder2/*",   "/",    "/",        Enumerated.Directories, false),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "/*/*",                 "/",    "/",        Enumerated.Both,        false,  "/folder1/folder2/"           , "/folder1/file1.txt", "/folder3/file3.txt"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "/*/*",                 "/",    "/",        Enumerated.Files,       false,  "/folder1/file1.txt"          , "/folder3/file3.txt"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "/*/*",                 "/",    "/",        Enumerated.Directories, false,  "/folder1/folder2/"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "/**/*",                "/",    "/",        Enumerated.Both,        false,  "/folder1/folder2/"           , "/folder1/folder2/file2.txt", "/folder3/", "/folder1/", "/root.txt", "/folder1/file1.txt", "/folder3/file3.txt"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "/**/*",                "/",    "/",        Enumerated.Files,       false,  "/folder1/folder2/file2.txt"  , "/root.txt", "/folder1/file1.txt", "/folder3/file3.txt"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "/**/*",                "/",    "/",        Enumerated.Directories, false,  "/folder1/folder2/"           , "/folder3/", "/folder1/"),
    ];
}
