namespace vm2.DevOps.Globs.Tests;

public partial class GlobsTests
{

    public class GlobEnumerate_TestData(
        string testFileLine,
        string jsonFile,
        string currentFolder,
        string path,
        string pattern,
        Enumerated enumerated,
        GlobComparison comparison,
        bool throws,
        params string[] results) : IXunitSerializable
    {
        #region boilerplate
        public GlobEnumerate_TestData()
            : this("", "", "", "", "", Enumerated.Both, GlobComparison.Default, false, [])
        {
        }
        #region Properties
        public string AFileLine { get; private set; } = testFileLine;
        public string JsonFile { get; private set; } = jsonFile;
        public string CurrentFolder { get; private set; } = currentFolder;
        public string Path { get; private set; } = path;
        public string Pattern { get; private set; } = pattern;
        public Enumerated Enumerated { get; private set; } = enumerated;
        public GlobComparison Comparison { get; private set; } = comparison;
        public string[] Results { get; private set; } = [.. results];
        public bool Throws { get; private set; } = throws;
        #endregion

        public HashSet<string> ResultsSet => [.. Results];

        public void Deserialize(IXunitSerializationInfo info)
        {
            AFileLine     = info.GetValue<string>(nameof(AFileLine)) ?? "";
            JsonFile      = info.GetValue<string>(nameof(JsonFile)) ?? "";
            CurrentFolder = info.GetValue<string>(nameof(CurrentFolder)) ?? "";
            Path          = info.GetValue<string>(nameof(Path)) ?? "";
            Pattern       = info.GetValue<string>(nameof(Pattern)) ?? "";
            Enumerated    = info.GetValue<Enumerated>(nameof(Enumerated));
            Comparison    = info.GetValue<GlobComparison>(nameof(Comparison));
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
            info.AddValue(nameof(Comparison), Comparison);
            info.AddValue(nameof(Results), Results);
            info.AddValue(nameof(Throws), Throws);
        }
        #endregion
    }

    public static TheoryData<GlobEnumerate_TestData> Enumerate_TestDataSet =
    [
        //                                         fileSys              currentFolder  path   pattern                enumerated              comparison              throws  results...
        new GlobEnumerate_TestData(TestFileLine(), "FakeFS2.Win.json",  "C:/",         "/",   "*",                   Enumerated.Both,        GlobComparison.Default, false,  "C:/folder1/", "C:/folder3/", "C:/root.txt"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFS2.Win.json",  "C:/",         "/",   "*",                   Enumerated.Files,       GlobComparison.Default, false,  "C:/root.txt"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFS2.Win.json",  "C:/",         "/",   "*",                   Enumerated.Directories, GlobComparison.Default, false,  "C:/folder1/", "C:/folder3/"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFS2.Win.json",  "C:/",         "/",   "/folder1",            Enumerated.Both,        GlobComparison.Default, false,  "C:/folder1/"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFS2.Win.json",  "C:/",         "/",   "/folder1",            Enumerated.Files,       GlobComparison.Default, false,  []),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFS2.Win.json",  "C:/",         "/",   "/folder1",            Enumerated.Directories, GlobComparison.Default, false,  "C:/folder1/"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFS2.Win.json",  "C:/",         "/",   "/folder1/*",          Enumerated.Both,        GlobComparison.Default, false,  "C:/folder1/folder2/",  "C:/folder1/file1.txt"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFS2.Win.json",  "C:/",         "/",   "/folder1/*",          Enumerated.Files,       GlobComparison.Default, false,  "C:/folder1/file1.txt"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFS2.Win.json",  "C:/",         "/",   "/folder1/*",          Enumerated.Directories, GlobComparison.Default, false,  "C:/folder1/folder2/"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFS2.Win.json",  "C:/",         "/",   "/folder1/folder2/*",  Enumerated.Both,        GlobComparison.Default, false,  "C:/folder1/folder2/file2.txt"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFS2.Win.json",  "C:/",         "/",   "/folder1/folder2/*",  Enumerated.Files,       GlobComparison.Default, false,  "C:/folder1/folder2/file2.txt"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFS2.Win.json",  "C:/",         "/",   "/folder1/folder2/*",  Enumerated.Directories, GlobComparison.Default, false,  []),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFS2.Win.json",  "C:/",         "/",   "/*/*",                Enumerated.Both,        GlobComparison.Default, false,  "C:/folder1/folder2/", "C:/folder1/file1.txt", "C:/folder3/file3.txt"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFS2.Win.json",  "C:/",         "/",   "/*/*",                Enumerated.Files,       GlobComparison.Default, false,  "C:/folder1/file1.txt", "C:/folder3/file3.txt"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFS2.Win.json",  "C:/",         "/",   "/*/*",                Enumerated.Directories, GlobComparison.Default, false,  "C:/folder1/folder2/"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFS2.Win.json",  "C:/",         "/",   "/**/*",               Enumerated.Both,        GlobComparison.Default, false,  "C:/folder1/folder2/", "C:/folder1/folder2/file2.txt", "C:/folder3/", "C:/folder1/folder2/", "C:/folder1/", "C:/root.txt", "C:/folder1/file1.txt", "C:/folder3/file3.txt"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFS2.Win.json",  "C:/",         "/",   "/**/*",               Enumerated.Files,       GlobComparison.Default, false,  "C:/folder1/folder2/file2.txt", "C:/root.txt", "C:/folder1/file1.txt", "C:/folder3/file3.txt"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFS2.Win.json",  "C:/",         "/",   "/**/*",               Enumerated.Directories, GlobComparison.Default, false,  "C:/folder1/folder2/", "C:/folder3/", "C:/folder1/folder2/", "C:/folder1/"),
        //                                         fileSys              currentFolder  path   pattern                enumerated              comparison              throws  results...
        new GlobEnumerate_TestData(TestFileLine(), "FakeFS2.Unix.json", "/",           "/",   "*",                   Enumerated.Both,        GlobComparison.Default, false,  "/folder1/", "/folder3/", "/root.txt"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFS2.Unix.json", "/",           "/",   "*",                   Enumerated.Files,       GlobComparison.Default, false,  "/root.txt"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFS2.Unix.json", "/",           "/",   "*",                   Enumerated.Directories, GlobComparison.Default, false,  "/folder1/", "/folder3/"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFS2.Unix.json", "/",           "/",   "/folder1",            Enumerated.Both,        GlobComparison.Default, false,  "/folder1/"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFS2.Unix.json", "/",           "/",   "/folder1",            Enumerated.Files,       GlobComparison.Default, false,  []),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFS2.Unix.json", "/",           "/",   "/folder1",            Enumerated.Directories, GlobComparison.Default, false,  "/folder1/"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFS2.Unix.json", "/",           "/",   "/folder1/*",          Enumerated.Both,        GlobComparison.Default, false,  "/folder1/folder2/",  "/folder1/file1.txt"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFS2.Unix.json", "/",           "/",   "/folder1/*",          Enumerated.Files,       GlobComparison.Default, false,  "/folder1/file1.txt"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFS2.Unix.json", "/",           "/",   "/folder1/*",          Enumerated.Directories, GlobComparison.Default, false,  "/folder1/folder2/"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFS2.Unix.json", "/",           "/",   "/folder1/folder2/*",  Enumerated.Both,        GlobComparison.Default, false,  "/folder1/folder2/file2.txt"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFS2.Unix.json", "/",           "/",   "/folder1/folder2/*",  Enumerated.Files,       GlobComparison.Default, false,  "/folder1/folder2/file2.txt"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFS2.Unix.json", "/",           "/",   "/folder1/folder2/*",  Enumerated.Directories, GlobComparison.Default, false,  []),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFS2.Unix.json", "/",           "/",   "/*/*",                Enumerated.Both,        GlobComparison.Default, false,  "/folder1/folder2/", "/folder1/file1.txt", "/folder3/file3.txt"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFS2.Unix.json", "/",           "/",   "/*/*",                Enumerated.Files,       GlobComparison.Default, false,  "/folder1/file1.txt", "/folder3/file3.txt"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFS2.Unix.json", "/",           "/",   "/*/*",                Enumerated.Directories, GlobComparison.Default, false,  "/folder1/folder2/"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFS2.Unix.json", "/",           "/",   "/**/*",               Enumerated.Both,        GlobComparison.Default, false,  "/folder1/folder2/", "/folder1/folder2/file2.txt", "/folder3/", "/folder1/folder2/", "/folder1/", "/root.txt", "/folder1/file1.txt", "/folder3/file3.txt"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFS2.Unix.json", "/",           "/",   "/**/*",               Enumerated.Files,       GlobComparison.Default, false,  "/folder1/folder2/file2.txt", "/root.txt", "/folder1/file1.txt", "/folder3/file3.txt"),
        new GlobEnumerate_TestData(TestFileLine(), "FakeFS2.Unix.json", "/",           "/",   "/**/*",               Enumerated.Directories, GlobComparison.Default, false,  "/folder1/folder2/", "/folder3/", "/folder1/folder2/", "/folder1/"),
    ];
}
