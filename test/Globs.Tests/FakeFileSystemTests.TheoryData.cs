namespace vm2.DevOps.Globs.Tests;

public partial class FakeFileSystemTests
{
    public class FakeFS_TestData(
        string testFileLine,
        string textOrFile,
        bool throws,
        string json,
        bool printJson = false) : IXunitSerializable
    {
        #region boilerplate
        public FakeFS_TestData()
            : this("", "", false, "", false)
        {
        }

        public string ATestFileLine { get; private set; } = testFileLine;
        public string TextOrFile { get; private set; } = textOrFile;
        public bool Throws { get; private set; } = throws;
        public string Json { get; private set; } = json;
        public bool PrintJson { get; private set; } = printJson;

        public void Deserialize(IXunitSerializationInfo info)
        {
            ATestFileLine = info.GetValue<string>(nameof(ATestFileLine)) ?? "";
            TextOrFile    = info.GetValue<string>(nameof(TextOrFile)) ?? "";
            Throws        = info.GetValue<bool>(nameof(Throws));
            Json          = info.GetValue<string>(nameof(Json)) ?? "";
            PrintJson     = info.GetValue<bool>(nameof(PrintJson));
        }

        public void Serialize(IXunitSerializationInfo info)
        {
            info.AddValue(nameof(ATestFileLine), ATestFileLine);
            info.AddValue(nameof(TextOrFile), TextOrFile);
            info.AddValue(nameof(Throws), Throws);
            info.AddValue(nameof(Json), Json);
            info.AddValue(nameof(PrintJson), PrintJson);
        }
        #endregion
    }

    public static TheoryData<FakeFS_TestData> Text_To_Add =
    [
        // Windows paths
        new FakeFS_TestData(TestFileLine(), @"C:/", false, @"{""name"":""C:/"",""folders"":[],""files"":[]}", true),
        new FakeFS_TestData(TestFileLine(), @"C:/f0", false, @"{""name"":""C:/"",""folders"":[],""files"":[""f0""]}", true),
        new FakeFS_TestData(TestFileLine(), @"C:/d0/", false, @"{""name"":""C:/"",""folders"":[{""name"":""d0"",""folders"":[],""files"":[]}],""files"":[]}", true),
        new FakeFS_TestData(TestFileLine(), @"C:/d0/f1", false, @"{""name"":""C:/"",""folders"":[{""name"":""d0"",""folders"":[],""files"":[""f1""]}],""files"":[]}", true),
        new FakeFS_TestData(TestFileLine(), """
            C:/f0
            C:/d0/f1
            """, false, @"{""name"":""C:/"",""folders"":[{""name"":""d0"",""folders"":[],""files"":[""f1""]}],""files"":[""f0""]}", true),
        new FakeFS_TestData(TestFileLine(), """
            C:/f0
            C:/d0/f1
            /dd/ff
            """, false, @"{""name"":""C:/"",""folders"":[{""name"":""d0"",""folders"":[],""files"":[""f1""]},{""name"":""dd"",""folders"":[],""files"":[""ff""]}],""files"":[""f0""]}", true),
        // Unix paths
        new FakeFS_TestData(TestFileLine(), @"/", false, @"{""name"":""/"",""folders"":[],""files"":[]}", true),
        new FakeFS_TestData(TestFileLine(), @"/f0", false, @"{""name"":""/"",""folders"":[],""files"":[""f0""]}", true),
        new FakeFS_TestData(TestFileLine(), @"/d0/", false, @"{""name"":""/"",""folders"":[{""name"":""d0"",""folders"":[],""files"":[]}],""files"":[]}", true),
        new FakeFS_TestData(TestFileLine(), @"/d0/f1", false, @"{""name"":""/"",""folders"":[{""name"":""d0"",""folders"":[],""files"":[""f1""]}],""files"":[]}", true),
        new FakeFS_TestData(TestFileLine(), """
            /f0
            /d0/f1
            """, false, @"{""name"":""/"",""folders"":[{""name"":""d0"",""folders"":[],""files"":[""f1""]}],""files"":[""f0""]}", true),
        new FakeFS_TestData(TestFileLine(), """
            /f0
            /d0/f1
            /dd/ff
            """, false, @"{""name"":""/"",""folders"":[{""name"":""d0"",""folders"":[],""files"":[""f1""]},{""name"":""dd"",""folders"":[],""files"":[""ff""]}],""files"":[""f0""]}", true),
    ];

    public static TheoryData<FakeFS_TestData> Text_Files_To_Add =
    [
        new FakeFS_TestData(TestFileLine(), @"FakeFS1.Win.txt",  false, "", false),
        new FakeFS_TestData(TestFileLine(), @"FakeFS1.Unix.txt", false, "", false),
    ];

    public class Json_To_Add_TestData(
        string testFileLine,
        string json,
        bool throws,
        bool printJson,
        string text) : IXunitSerializable
    {
        #region boilerplate
        public Json_To_Add_TestData()
            : this("", "", false, false, "")
        {
        }

        public string ATestFileLine { get; private set; } = testFileLine;
        public string Json { get; private set; } = json;
        public bool Throws { get; private set; } = throws;
        public bool PrintJson { get; private set; } = printJson;
        public string Text { get; private set; } = text;

        public void Deserialize(IXunitSerializationInfo info)
        {
            ATestFileLine = info.GetValue<string>(nameof(ATestFileLine)) ?? "";
            Json          = info.GetValue<string>(nameof(Json)) ?? "";
            Throws        = info.GetValue<bool>(nameof(Throws));
            PrintJson     = info.GetValue<bool>(nameof(PrintJson));
            Text          = info.GetValue<string>(nameof(Text)) ?? "";
        }

        public void Serialize(IXunitSerializationInfo info)
        {
            info.AddValue(nameof(ATestFileLine), ATestFileLine);
            info.AddValue(nameof(Json), Json);
            info.AddValue(nameof(Throws), Throws);
            info.AddValue(nameof(PrintJson), PrintJson);
            info.AddValue(nameof(Text), Text);
        }
        #endregion
    }

    public static TheoryData<Json_To_Add_TestData> Json_To_Add =
    [
        // Windows JSONs
        new Json_To_Add_TestData(TestFileLine(), @"{""name"":""C:/"",""folders"":[],""files"":[]}", false, true, @""),
        new Json_To_Add_TestData(TestFileLine(), @"{""name"":""C:/"",""folders"":[],""files"":[""f0""]}", false, true, @""),
        new Json_To_Add_TestData(TestFileLine(), @"{""name"":""C:/"",""folders"":[{""name"":""d0"",""folders"":[],""files"":[]}],""files"":[]}", false, true, @""),
        new Json_To_Add_TestData(TestFileLine(), @"{""name"":""C:/"",""folders"":[{""name"":""d0"",""folders"":[],""files"":[""f1""]}],""files"":[]}", false, true, @""),
        new Json_To_Add_TestData(TestFileLine(), @"{""name"":""C:/"",""folders"":[{""name"":""d0"",""folders"":[],""files"":[""f1""]}],""files"":[""f0""]}", false, true, @""),
        new Json_To_Add_TestData(TestFileLine(), @"{""name"":""C:/"",""folders"":[{""name"":""d0"",""folders"":[],""files"":[""f1""]},{""name"":""dd"",""folders"":[],""files"":[""ff""]}],""files"":[""f0""]}", false, true, @""),
        // Unix paths
        new Json_To_Add_TestData(TestFileLine(), @"{""name"":""/"",""folders"":[],""files"":[]}", false, true, @""),
        new Json_To_Add_TestData(TestFileLine(), @"{""name"":""/"",""folders"":[],""files"":[""f0""]}", false, true, @""),
        new Json_To_Add_TestData(TestFileLine(), @"{""name"":""/"",""folders"":[{""name"":""d0"",""folders"":[],""files"":[]}],""files"":[]}", false, true, @""),
        new Json_To_Add_TestData(TestFileLine(), @"{""name"":""/"",""folders"":[{""name"":""d0"",""folders"":[],""files"":[""f1""]}],""files"":[]}", false, true, @""),
        new Json_To_Add_TestData(TestFileLine(), @"{""name"":""/"",""folders"":[{""name"":""d0"",""folders"":[],""files"":[""f1""]}],""files"":[""f0""]}", false, true, @""),
        new Json_To_Add_TestData(TestFileLine(), @"{""name"":""/"",""folders"":[{""name"":""d0"",""folders"":[],""files"":[""f1""]},{""name"":""dd"",""folders"":[],""files"":[""ff""]}],""files"":[""f0""]}", false, true, @""),
    ];

    public static TheoryData<Json_To_Add_TestData> Json_Files_To_Add =
    [
        new Json_To_Add_TestData(TestFileLine(), @"FakeFS1.Win.json",  false, true, @""),
        new Json_To_Add_TestData(TestFileLine(), @"FakeFS1.Unix.json", false, true, @""),
    ];

    public class SetCurrentFolder_TestData(
        string testFileLine,
        string fsJsonFile,
        string cwf,
        string chf,
        string rwf,
        bool throws) : IXunitSerializable
    {
        #region boilerplate
        public SetCurrentFolder_TestData()
            : this("", "", "", "", "", false)
        {
        }

        public string ATestFileLine { get; private set; } = testFileLine;
        public string FsJsonFile { get; private set; } = fsJsonFile;
        public string Cwf { get; private set; } = cwf;
        public string Chf { get; private set; } = chf;
        public string Rwf { get; private set; } = rwf;
        public bool Throws { get; private set; } = throws;

        public void Deserialize(IXunitSerializationInfo info)
        {
            ATestFileLine = info.GetValue<string>(nameof(ATestFileLine)) ?? "";
            FsJsonFile   = info.GetValue<string>(nameof(FsJsonFile)) ?? "";
            Cwf          = info.GetValue<string>(nameof(Cwf)) ?? "";
            Chf          = info.GetValue<string>(nameof(Chf)) ?? "";
            Rwf          = info.GetValue<string>(nameof(Rwf)) ?? "";
            Throws       = info.GetValue<bool>(nameof(Throws));
        }
        public void Serialize(IXunitSerializationInfo info)
        {
            info.AddValue(nameof(ATestFileLine), ATestFileLine);
            info.AddValue(nameof(FsJsonFile), FsJsonFile);
            info.AddValue(nameof(Cwf), Cwf);
            info.AddValue(nameof(Chf), Chf);
            info.AddValue(nameof(Rwf), Rwf);
            info.AddValue(nameof(Throws), Throws);
        }
        #endregion
    }

    public static TheoryData<SetCurrentFolder_TestData> Set_Current_Folder_TestData =
    [
        new SetCurrentFolder_TestData(TestFileLine(), "FakeFS2.Win.json",  "",                    "",                     "C:/",                 false),
        new SetCurrentFolder_TestData(TestFileLine(), "FakeFS2.Win.json",  "",                    "C:",                   "C:/",                 false),
        new SetCurrentFolder_TestData(TestFileLine(), "FakeFS2.Win.json",  "",                    "C:/",                  "C:/",                 false),
        new SetCurrentFolder_TestData(TestFileLine(), "FakeFS2.Win.json",  "",                    "/",                    "C:/",                 false),
        new SetCurrentFolder_TestData(TestFileLine(), "FakeFS2.Win.json",  "",                    "C:/folder1/",          "C:/folder1/",         false),
        new SetCurrentFolder_TestData(TestFileLine(), "FakeFS2.Win.json",  "",                    "/folder1/",            "C:/folder1/",         false),
        new SetCurrentFolder_TestData(TestFileLine(), "FakeFS2.Win.json",  "C:/folder1/",         "..",                   "C:/",                 false),
        new SetCurrentFolder_TestData(TestFileLine(), "FakeFS2.Win.json",  "/folder1/",           "..",                   "C:/",                 false),
        new SetCurrentFolder_TestData(TestFileLine(), "FakeFS2.Win.json",  "C:/folder1/",         ".",                    "C:/folder1/",         false),
        new SetCurrentFolder_TestData(TestFileLine(), "FakeFS2.Win.json",  "/folder1/",           ".",                    "C:/folder1/",         false),
        new SetCurrentFolder_TestData(TestFileLine(), "FakeFS2.Win.json",  "",                    "C:/folder1/folder2/",  "C:/folder1/folder2/", false),
        new SetCurrentFolder_TestData(TestFileLine(), "FakeFS2.Win.json",  "",                    "/folder1/folder2/",    "C:/folder1/folder2/", false),
        new SetCurrentFolder_TestData(TestFileLine(), "FakeFS2.Win.json",  "C:/folder1/folder2/", "..",                   "C:/folder1/",         false),
        new SetCurrentFolder_TestData(TestFileLine(), "FakeFS2.Win.json",  "/folder1/folder2/",   "..",                   "C:/folder1/",         false),
        new SetCurrentFolder_TestData(TestFileLine(), "FakeFS2.Win.json",  "C:/folder1/folder2/", ".",                    "C:/folder1/folder2/", false),
        new SetCurrentFolder_TestData(TestFileLine(), "FakeFS2.Win.json",  "/folder1/folder2/",   ".",                    "C:/folder1/folder2/", false),

        new SetCurrentFolder_TestData(TestFileLine(), "FakeFS2.Win.json",  "",                    "C:/root.txt",          "",                    true),
        new SetCurrentFolder_TestData(TestFileLine(), "FakeFS2.Win.json",  "",                    "/root.txt",            "",                    true),
        new SetCurrentFolder_TestData(TestFileLine(), "FakeFS2.Win.json",  "",                    "D:/folder1/",          "",                    true),
        new SetCurrentFolder_TestData(TestFileLine(), "FakeFS2.Win.json",  "",                    "C:/folder2/",          "",                    true),
        new SetCurrentFolder_TestData(TestFileLine(), "FakeFS2.Win.json",  "",                    "C:/folder3/file3.txt", "",                    true),

        new SetCurrentFolder_TestData(TestFileLine(), "FakeFS2.Unix.json", "",                    "",                     "/",                   false),
        new SetCurrentFolder_TestData(TestFileLine(), "FakeFS2.Unix.json", "",                    "/",                    "/",                   false),
        new SetCurrentFolder_TestData(TestFileLine(), "FakeFS2.Unix.json", "",                    "/folder1/",            "/folder1/",           false),
        new SetCurrentFolder_TestData(TestFileLine(), "FakeFS2.Unix.json", "/folder1/",           "..",                   "/",                   false),
        new SetCurrentFolder_TestData(TestFileLine(), "FakeFS2.Unix.json", "/folder1/",           ".",                    "/folder1/",           false),
        new SetCurrentFolder_TestData(TestFileLine(), "FakeFS2.Unix.json", "",                    "/folder1/folder2/",    "/folder1/folder2/",   false),
        new SetCurrentFolder_TestData(TestFileLine(), "FakeFS2.Unix.json", "/folder1/folder2/",   "..",                   "/folder1/",           false),
        new SetCurrentFolder_TestData(TestFileLine(), "FakeFS2.Unix.json", "/folder1/folder2/",   ".",                    "/folder1/folder2/",   false),

        new SetCurrentFolder_TestData(TestFileLine(), "FakeFS2.Unix.json", "",                     "/root.txt",           "",                    true),
        new SetCurrentFolder_TestData(TestFileLine(), "FakeFS2.Unix.json", "",                     "/root.txt",           "",                    true),
        new SetCurrentFolder_TestData(TestFileLine(), "FakeFS2.Unix.json", "",                     "D:/folder1/",         "",                    true),
        new SetCurrentFolder_TestData(TestFileLine(), "FakeFS2.Unix.json", "",                     "/folder2/",           "",                    true),
        new SetCurrentFolder_TestData(TestFileLine(), "FakeFS2.Unix.json", "",                     "/folder3/file3.txt",  "",                    true),
    ];

    public class GetPathFromRoot_TestData(
        string testFileLine,
        string jsonFile,
        string currentFolder,
        string path,
        string resultPath,
        string resultFile,
        bool throws) : IXunitSerializable
    {
        #region boilerplate
        public GetPathFromRoot_TestData()
            : this("", "", "", "", "", "", false)
        {
        }

        #region Properties
        public string AFileLine { get; private set; } = testFileLine;
        public string JsonFile { get; private set; } = jsonFile;
        public string CurrentFolder { get; private set; } = currentFolder;
        public string Path { get; private set; } = path;
        public string ResultPath { get; private set; } = resultPath;
        public string ResultFile { get; private set; } = resultFile;
        public bool Throws { get; private set; } = throws;
        #endregion

        public void Deserialize(IXunitSerializationInfo info)
        {
            AFileLine = info.GetValue<string>(nameof(AFileLine)) ?? "";
            JsonFile     = info.GetValue<string>(nameof(JsonFile)) ?? "";
            Path         = info.GetValue<string>(nameof(Path)) ?? "";
            CurrentFolder   = info.GetValue<string>(nameof(CurrentFolder)) ?? "";
            ResultPath   = info.GetValue<string>(nameof(ResultPath)) ?? "";
            ResultFile   = info.GetValue<string>(nameof(ResultFile)) ?? "";
            Throws       = info.GetValue<bool>(nameof(Throws));
        }

        public void Serialize(IXunitSerializationInfo info)
        {
            info.AddValue(nameof(AFileLine), AFileLine);
            info.AddValue(nameof(JsonFile), JsonFile);
            info.AddValue(nameof(CurrentFolder), CurrentFolder);
            info.AddValue(nameof(Path), Path);
            info.AddValue(nameof(ResultPath), ResultPath);
            info.AddValue(nameof(ResultFile), ResultFile);
            info.AddValue(nameof(Throws), Throws);
        }
        #endregion
    }

    public static TheoryData<GetPathFromRoot_TestData> FromPath_TestDataSet =
    [
        new GetPathFromRoot_TestData(TestFileLine(), "FakeFS2.Win.json", "C:/folder1/",         "",                     "C:/folder1/",          "",          false),
        new GetPathFromRoot_TestData(TestFileLine(), "FakeFS2.Win.json", "C:/folder1/",         "C:/",                  "C:/",                  "",          false),
        new GetPathFromRoot_TestData(TestFileLine(), "FakeFS2.Win.json", "C:/folder1/",         "C:/folder1",           "C:/folder1/",          "",          false),
        new GetPathFromRoot_TestData(TestFileLine(), "FakeFS2.Win.json", "C:/folder1/",         "file1.txt",            "C:/folder1/",          "file1.txt", false),
        new GetPathFromRoot_TestData(TestFileLine(), "FakeFS2.Win.json", "C:/folder1/",         "C:/folder1/file1.txt", "C:/folder1/",          "file1.txt", false),
        new GetPathFromRoot_TestData(TestFileLine(), "FakeFS2.Win.json", "C:/folder1/",         ".",                    "C:/folder1/",          "",          false),
        new GetPathFromRoot_TestData(TestFileLine(), "FakeFS2.Win.json", "C:/folder1/folder2/", "..",                   "C:/folder1/",          "",          false),
        new GetPathFromRoot_TestData(TestFileLine(), "FakeFS2.Win.json", "C:/folder1/folder2/", "C:/folder1",           "C:/folder1/",          "",          false),
        new GetPathFromRoot_TestData(TestFileLine(), "FakeFS2.Win.json", "C:/folder1/folder2/", "../file1.txt",         "C:/folder1/",          "file1.txt", false),
        new GetPathFromRoot_TestData(TestFileLine(), "FakeFS2.Win.json", "C:/folder1/folder2/", "file2.txt",            "C:/folder1/folder2/",  "file2.txt", false),
        new GetPathFromRoot_TestData(TestFileLine(), "FakeFS2.Win.json", "C:/folder1/folder2/", "./file2.txt",          "C:/folder1/folder2/",  "file2.txt", false),
        new GetPathFromRoot_TestData(TestFileLine(), "FakeFS2.Win.json", "C:/folder1/folder2/", "C:/folder3/file3.txt", "C:/folder3/",          "file3.txt", false),

        new GetPathFromRoot_TestData(TestFileLine(), "FakeFS2.Unix.json", "/folder1/",          "",                     "/folder1/",            "",          false),
        new GetPathFromRoot_TestData(TestFileLine(), "FakeFS2.Unix.json", "/folder1/",          "/",                    "/",                    "",          false),
        new GetPathFromRoot_TestData(TestFileLine(), "FakeFS2.Unix.json", "/folder1/",          "/folder1",             "/folder1/",            "",          false),
        new GetPathFromRoot_TestData(TestFileLine(), "FakeFS2.Unix.json", "/folder1/",          "file1.txt",            "/folder1/",            "file1.txt", false),
        new GetPathFromRoot_TestData(TestFileLine(), "FakeFS2.Unix.json", "/folder1/",          "/folder1/file1.txt",   "/folder1/",            "file1.txt", false),
        new GetPathFromRoot_TestData(TestFileLine(), "FakeFS2.Unix.json", "/folder1/",          ".",                    "/folder1/",            "",          false),
        new GetPathFromRoot_TestData(TestFileLine(), "FakeFS2.Unix.json", "/folder1/folder2/",  "..",                   "/folder1/",            "",          false),
        new GetPathFromRoot_TestData(TestFileLine(), "FakeFS2.Unix.json", "/folder1/folder2/",  "/folder1",             "/folder1/",            "",          false),
        new GetPathFromRoot_TestData(TestFileLine(), "FakeFS2.Unix.json", "/folder1/folder2/",  "../file1.txt",         "/folder1/",            "file1.txt", false),
        new GetPathFromRoot_TestData(TestFileLine(), "FakeFS2.Unix.json", "/folder1/folder2/",  "file2.txt",            "/folder1/folder2/",    "file2.txt", false),
        new GetPathFromRoot_TestData(TestFileLine(), "FakeFS2.Unix.json", "/folder1/folder2/",  "./file2.txt",          "/folder1/folder2/",    "file2.txt", false),
        new GetPathFromRoot_TestData(TestFileLine(), "FakeFS2.Unix.json", "/folder1/folder2/",  "/folder3/file3.txt",   "/folder3/",            "file3.txt", false),
    ];

    public class FolderExists_TestData(
        string testFileLine,
        string jsonFile,
        string currentFolder,
        string path,
        bool result,
        bool throws) : IXunitSerializable
    {
        #region boilerplate
        public FolderExists_TestData()
            : this("", "", "", "", false, false)
        {
        }

        #region Properties
        public string AFileLine { get; private set; } = testFileLine;
        public string JsonFile { get; private set; } = jsonFile;
        public string CurrentFolder { get; private set; } = currentFolder;
        public string Path { get; private set; } = path;
        public bool Result { get; private set; } = result;
        public bool Throws { get; private set; } = throws;
        #endregion

        public void Deserialize(IXunitSerializationInfo info)
        {
            AFileLine       = info.GetValue<string>(nameof(AFileLine)) ?? "";
            JsonFile        = info.GetValue<string>(nameof(JsonFile)) ?? "";
            Path            = info.GetValue<string>(nameof(Path)) ?? "";
            CurrentFolder   = info.GetValue<string>(nameof(CurrentFolder)) ?? "";
            Result          = info.GetValue<bool>(nameof(Result));
            Throws          = info.GetValue<bool>(nameof(Throws));
        }

        public void Serialize(IXunitSerializationInfo info)
        {
            info.AddValue(nameof(AFileLine), AFileLine);
            info.AddValue(nameof(JsonFile), JsonFile);
            info.AddValue(nameof(CurrentFolder), CurrentFolder);
            info.AddValue(nameof(Path), Path);
            info.AddValue(nameof(Result), Result);
            info.AddValue(nameof(Throws), Throws);
        }
        #endregion
    }

    public static TheoryData<FolderExists_TestData> FolderExists_TestDataSet =
    [
        new FolderExists_TestData(TestFileLine(), "FakeFS2.Win.json",  "",                    "",                     true,  false),
        new FolderExists_TestData(TestFileLine(), "FakeFS2.Win.json",  "",                    "C:",                   true,  false),
        new FolderExists_TestData(TestFileLine(), "FakeFS2.Win.json",  "",                    "C:/",                  true,  false),
        new FolderExists_TestData(TestFileLine(), "FakeFS2.Win.json",  "",                    "/",                    true,  false),
        new FolderExists_TestData(TestFileLine(), "FakeFS2.Win.json",  "",                    "C:/folder1/",          true,  false),
        new FolderExists_TestData(TestFileLine(), "FakeFS2.Win.json",  "",                    "/folder1/",            true,  false),
        new FolderExists_TestData(TestFileLine(), "FakeFS2.Win.json",  "C:/folder1/",         "..",                   true,  false),
        new FolderExists_TestData(TestFileLine(), "FakeFS2.Win.json",  "/folder1/",           "..",                   true,  false),
        new FolderExists_TestData(TestFileLine(), "FakeFS2.Win.json",  "C:/folder1/",         ".",                    true,  false),
        new FolderExists_TestData(TestFileLine(), "FakeFS2.Win.json",  "/folder1/",           ".",                    true,  false),
        new FolderExists_TestData(TestFileLine(), "FakeFS2.Win.json",  "",                    "C:/folder1/folder2/",  true,  false),
        new FolderExists_TestData(TestFileLine(), "FakeFS2.Win.json",  "",                    "/folder1/folder2/",    true,  false),
        new FolderExists_TestData(TestFileLine(), "FakeFS2.Win.json",  "C:/folder1/folder2/", "..",                   true,  false),
        new FolderExists_TestData(TestFileLine(), "FakeFS2.Win.json",  "/folder1/folder2/",   "..",                   true,  false),
        new FolderExists_TestData(TestFileLine(), "FakeFS2.Win.json",  "C:/folder1/folder2/", ".",                    true,  false),
        new FolderExists_TestData(TestFileLine(), "FakeFS2.Win.json",  "/folder1/folder2/",   ".",                    true,  false),
        new FolderExists_TestData(TestFileLine(), "FakeFS2.Win.json",  "/folder1/folder2/",   "../file2.txt",         false, false),    // TODO: is this right?
        new FolderExists_TestData(TestFileLine(), "FakeFS2.Win.json",  "/folder1/folder2/",   "../file1.txt",         false, false),
        new FolderExists_TestData(TestFileLine(), "FakeFS2.Win.json",  "/folder1/folder2/",   "./file2.txt",          false, false),
        new FolderExists_TestData(TestFileLine(), "FakeFS2.Win.json",  "/folder1/folder2/",   "./file1.txt",          false, false),    // TODO: is this right?

        new FolderExists_TestData(TestFileLine(), "FakeFS2.Win.json",  "",                    "D:",                   false, false),
        new FolderExists_TestData(TestFileLine(), "FakeFS2.Win.json",  "",                    "D:/",                  false, false),
        new FolderExists_TestData(TestFileLine(), "FakeFS2.Win.json",  "",                    "D:/folder1/",          false, false),
        new FolderExists_TestData(TestFileLine(), "FakeFS2.Win.json",  "",                    "/folder2/",            false, false),
        new FolderExists_TestData(TestFileLine(), "FakeFS2.Win.json",  "",                    "C:/folder2/",          false, false),
        new FolderExists_TestData(TestFileLine(), "FakeFS2.Win.json",  "",                    "/folder2/",            false, false),
        new FolderExists_TestData(TestFileLine(), "FakeFS2.Win.json",  "C:/",                 "..",                   false, true),
        new FolderExists_TestData(TestFileLine(), "FakeFS2.Win.json",  "",                    "C:/folder1/file1.txt", false, false),
        new FolderExists_TestData(TestFileLine(), "FakeFS2.Win.json",  "",                    "/folder1/file1.txt",   false, false),
        new FolderExists_TestData(TestFileLine(), "FakeFS2.Win.json",  "C:/folder1/folder2/", "../file1.txt",         false, false),
        new FolderExists_TestData(TestFileLine(), "FakeFS2.Win.json",  "/folder1/folder2/",   "../file2.txt",         false, false),    // TODO: is this right?
        new FolderExists_TestData(TestFileLine(), "FakeFS2.Win.json",  "C:/folder1/folder2/", "./file1.txt",          false, false),    // TODO: is this right?
        new FolderExists_TestData(TestFileLine(), "FakeFS2.Win.json",  "/folder1/folder2/",   "./file2.txt",          false, false),
    ];

    public static TheoryData<FolderExists_TestData> FileExists_TestDataSet =
    [
        new FolderExists_TestData(TestFileLine(), "FakeFS2.Win.json",  "",                    "C:/folder1",           false, false),
        new FolderExists_TestData(TestFileLine(), "FakeFS2.Win.json",  "",                    "C:/folder1/file1.txt", true,  false),
        new FolderExists_TestData(TestFileLine(), "FakeFS2.Win.json",  "",                    "C:/folder1/file2.txt", false, false),
        new FolderExists_TestData(TestFileLine(), "FakeFS2.Win.json",  "",                    "/folder1",             false, false),
        new FolderExists_TestData(TestFileLine(), "FakeFS2.Win.json",  "",                    "/folder1/file1.txt",   true,  false),
        new FolderExists_TestData(TestFileLine(), "FakeFS2.Win.json",  "C:/folder1/",         "../file1.txt",         false, false),
        new FolderExists_TestData(TestFileLine(), "FakeFS2.Win.json",  "C:/folder1/",         "../root.txt",          true,  false),
        new FolderExists_TestData(TestFileLine(), "FakeFS2.Win.json",  "C:/folder1/",         "./file1.txt",          true,  false),
        new FolderExists_TestData(TestFileLine(), "FakeFS2.Win.json",  "/folder1/",           "./root.txt",           false, false),

        new FolderExists_TestData(TestFileLine(), "FakeFS2.Unix.json", "",                    "/folder1",             false, false),
        new FolderExists_TestData(TestFileLine(), "FakeFS2.Unix.json", "",                    "/folder1/file1.txt",   true,  false),
        new FolderExists_TestData(TestFileLine(), "FakeFS2.Unix.json", "",                    "/folder1/file2.txt",   false, false),
        new FolderExists_TestData(TestFileLine(), "FakeFS2.Unix.json", "",                    "/folder1",             false, false),
        new FolderExists_TestData(TestFileLine(), "FakeFS2.Unix.json", "",                    "/folder1/file1.txt",   true,  false),
        new FolderExists_TestData(TestFileLine(), "FakeFS2.Unix.json", "/folder1/",           "../file1.txt",         false, false),
        new FolderExists_TestData(TestFileLine(), "FakeFS2.Unix.json", "/folder1/",           "../root.txt",          true,  false),
        new FolderExists_TestData(TestFileLine(), "FakeFS2.Unix.json", "/folder1/",           "./file1.txt",          true,  false),
        new FolderExists_TestData(TestFileLine(), "FakeFS2.Unix.json", "/folder1/",           "./root.txt",           false, false),
    ];

    public class Enumerate_TestData(
        string testFileLine,
        string jsonFile,
        string currentFolder,
        string path,
        string pattern,
        bool recursive,
        string[] results,
        bool throws) : IXunitSerializable
    {
        #region boilerplate
        public Enumerate_TestData()
            : this("", "", "", "", "", false, [], false)
        {
        }
        #region Properties
        public string AFileLine { get; private set; } = testFileLine;
        public string JsonFile { get; private set; } = jsonFile;
        public string CurrentFolder { get; private set; } = currentFolder;
        public string Path { get; private set; } = path;
        public string Pattern { get; private set; } = pattern;
        public bool Recursive { get; set; } = recursive;
        public string[] Results { get; private set; } = [.. results];
        public bool Throws { get; private set; } = throws;
        #endregion

        public HashSet<string> ResultsSet => [.. Results];

        public void Deserialize(IXunitSerializationInfo info)
        {
            AFileLine      = info.GetValue<string>(nameof(AFileLine)) ?? "";
            JsonFile       = info.GetValue<string>(nameof(JsonFile)) ?? "";
            CurrentFolder  = info.GetValue<string>(nameof(CurrentFolder)) ?? "";
            Path           = info.GetValue<string>(nameof(Path)) ?? "";
            Pattern        = info.GetValue<string>(nameof(Pattern)) ?? "";
            Recursive      = info.GetValue<bool>(nameof(Recursive));
            Results        = info.GetValue<string[]>(nameof(Results)) ?? [];
            Throws         = info.GetValue<bool>(nameof(Throws));
        }

        public void Serialize(IXunitSerializationInfo info)
        {
            info.AddValue(nameof(AFileLine), AFileLine);
            info.AddValue(nameof(JsonFile), JsonFile);
            info.AddValue(nameof(CurrentFolder), CurrentFolder);
            info.AddValue(nameof(Path), Path);
            info.AddValue(nameof(Pattern), Pattern);
            info.AddValue(nameof(Recursive), Recursive);
            info.AddValue(nameof(Results), Results);
            info.AddValue(nameof(Throws), Throws);
        }
        #endregion
    }

    public static TheoryData<Enumerate_TestData> EnumerateFolders_TestDataSet =
    [
        new Enumerate_TestData(TestFileLine(), "FakeFS2.Win.json", "", "C:/", ""                , false, [], false),
        new Enumerate_TestData(TestFileLine(), "FakeFS2.Win.json", "", "C:/", "*"               , false, ["C:/folder1/", "C:/folder3/"], false),
        new Enumerate_TestData(TestFileLine(), "FakeFS2.Win.json", "", "C:/", "*"               , true,  ["C:/folder1/", "C:/folder3/", "C:/folder1/folder2/", ], false),
        new Enumerate_TestData(TestFileLine(), "FakeFS2.Win.json", "", "C:/", "fold*"           , false, ["C:/folder1/", "C:/folder3/"], false),
        new Enumerate_TestData(TestFileLine(), "FakeFS2.Win.json", "", "C:/", "fold*"           , true,  ["C:/folder1/", "C:/folder3/", "C:/folder1/folder2/", ], false),
        new Enumerate_TestData(TestFileLine(), "FakeFS2.Win.json", "", "C:/", "*er?"            , false, ["C:/folder1/", "C:/folder3/"], false),
        new Enumerate_TestData(TestFileLine(), "FakeFS2.Win.json", "", "C:/", "*er?"            , true,  ["C:/folder1/", "C:/folder3/", "C:/folder1/folder2/", ], false),
        new Enumerate_TestData(TestFileLine(), "FakeFS2.Win.json", "", "C:/folder1", "*er?"     , false, ["C:/folder1/folder2/", ], false),
        new Enumerate_TestData(TestFileLine(), "FakeFS2.Win.json", "", "C:/folder1", "*er?"     , true,  ["C:/folder1/folder2/", ], false),
        new Enumerate_TestData(TestFileLine(), "FakeFS2.Win.json", "C:/folder1", ".", "*er?"    , false, ["C:/folder1/folder2/", ], false),
        new Enumerate_TestData(TestFileLine(), "FakeFS2.Win.json", "C:/folder1", ".", "*er?"    , true,  ["C:/folder1/folder2/", ], false),

        new Enumerate_TestData(TestFileLine(), "FakeFS2.Unix.json", "", "/", ""                , false, [], false),
        new Enumerate_TestData(TestFileLine(), "FakeFS2.Unix.json", "", "/", "*"               , false, ["/folder1/", "/folder3/"], false),
        new Enumerate_TestData(TestFileLine(), "FakeFS2.Unix.json", "", "/", "*"               , true,  ["/folder1/", "/folder3/", "/folder1/folder2/", ], false),
        new Enumerate_TestData(TestFileLine(), "FakeFS2.Unix.json", "", "/", "fold*"           , false, ["/folder1/", "/folder3/"], false),
        new Enumerate_TestData(TestFileLine(), "FakeFS2.Unix.json", "", "/", "fold*"           , true,  ["/folder1/", "/folder3/", "/folder1/folder2/", ], false),
        new Enumerate_TestData(TestFileLine(), "FakeFS2.Unix.json", "", "/", "*er?"            , false, ["/folder1/", "/folder3/"], false),
        new Enumerate_TestData(TestFileLine(), "FakeFS2.Unix.json", "", "/", "*er?"            , true,  ["/folder1/", "/folder3/", "/folder1/folder2/", ], false),
        new Enumerate_TestData(TestFileLine(), "FakeFS2.Unix.json", "", "/folder1", "*er?"     , false, ["/folder1/folder2/", ], false),
        new Enumerate_TestData(TestFileLine(), "FakeFS2.Unix.json", "", "/folder1", "*er?"     , true,  ["/folder1/folder2/", ], false),
        new Enumerate_TestData(TestFileLine(), "FakeFS2.Unix.json", "/folder1", ".", "*er?"    , false, ["/folder1/folder2/", ], false),
        new Enumerate_TestData(TestFileLine(), "FakeFS2.Unix.json", "/folder1", ".", "*er?"    , true,  ["/folder1/folder2/", ], false),
    ];

    public static TheoryData<Enumerate_TestData> EnumerateFiles_TestDataSet =
    [
        new Enumerate_TestData(TestFileLine(), "FakeFS2.Win.json", "", "C:/", ""                , false, [], false),
        new Enumerate_TestData(TestFileLine(), "FakeFS2.Win.json", "", "C:/", "*"               , false, ["C:/root.txt"], false),
        new Enumerate_TestData(TestFileLine(), "FakeFS2.Win.json", "", "C:/", "*"               , true,  ["C:/root.txt", "C:/folder1/file1.txt", "C:/folder3/file3.txt", "C:/folder1/folder2/file2.txt", ], false),
        new Enumerate_TestData(TestFileLine(), "FakeFS2.Win.json", "", "C:/", "file*"           , false, [], false),
        new Enumerate_TestData(TestFileLine(), "FakeFS2.Win.json", "", "C:/", "file*"           , true,  ["C:/folder1/file1.txt", "C:/folder3/file3.txt", "C:/folder1/folder2/file2.txt", ], false),
        new Enumerate_TestData(TestFileLine(), "FakeFS2.Win.json", "", "C:/", "file?"           , false, [], false),
        new Enumerate_TestData(TestFileLine(), "FakeFS2.Win.json", "", "C:/", "file?"           , true,  ["C:/folder1/file1.txt", "C:/folder3/file3.txt", "C:/folder1/folder2/file2.txt", ], false),
        new Enumerate_TestData(TestFileLine(), "FakeFS2.Win.json", "", "C:/", "root*.*"         , true,  ["C:/root.txt", ], false),
        new Enumerate_TestData(TestFileLine(), "FakeFS2.Win.json", "", "C:/", "root*.*"         , true,  ["C:/root.txt", ], false),
        new Enumerate_TestData(TestFileLine(), "FakeFS2.Win.json", "C:/folder1", ".", "file?"   , false, ["C:/folder1/file1.txt", ], false),
        new Enumerate_TestData(TestFileLine(), "FakeFS2.Win.json", "C:/folder1", ".", "file?"   , true,  ["C:/folder1/file1.txt", "C:/folder1/folder2/file2.txt"], false),

        new Enumerate_TestData(TestFileLine(), "FakeFS2.Unix.json", "", "/", ""                , false, [], false),
        new Enumerate_TestData(TestFileLine(), "FakeFS2.Unix.json", "", "/", "*"               , false, ["/root.txt"], false),
        new Enumerate_TestData(TestFileLine(), "FakeFS2.Unix.json", "", "/", "*"               , true,  ["/root.txt", "/folder1/file1.txt", "/folder3/file3.txt", "/folder1/folder2/file2.txt", ], false),
        new Enumerate_TestData(TestFileLine(), "FakeFS2.Unix.json", "", "/", "file*"           , false, [], false),
        new Enumerate_TestData(TestFileLine(), "FakeFS2.Unix.json", "", "/", "file*"           , true,  ["/folder1/file1.txt", "/folder3/file3.txt", "/folder1/folder2/file2.txt", ], false),
        new Enumerate_TestData(TestFileLine(), "FakeFS2.Unix.json", "", "/", "file?"           , false, [], false),
        new Enumerate_TestData(TestFileLine(), "FakeFS2.Unix.json", "", "/", "file?"           , true,  ["/folder1/file1.txt", "/folder3/file3.txt", "/folder1/folder2/file2.txt", ], false),
        new Enumerate_TestData(TestFileLine(), "FakeFS2.Unix.json", "", "/", "root*.*"         , true,  ["/root.txt", ], false),
        new Enumerate_TestData(TestFileLine(), "FakeFS2.Unix.json", "", "/", "root*.*"         , true,  ["/root.txt", ], false),
        new Enumerate_TestData(TestFileLine(), "FakeFS2.Unix.json", "/folder1", ".", "file?"   , false, ["/folder1/file1.txt", ], false),
        new Enumerate_TestData(TestFileLine(), "FakeFS2.Unix.json", "/folder1", ".", "file?"   , true,  ["/folder1/file1.txt", "/folder1/folder2/file2.txt"], false),
    ];
}
