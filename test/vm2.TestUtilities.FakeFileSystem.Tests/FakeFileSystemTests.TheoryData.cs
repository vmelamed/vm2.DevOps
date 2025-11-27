// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Val Melamed

namespace vm2.DevOps.Glob.Api.Tests.FakeFileSystem.Tests;

public partial class FakeFileSystemTests
{
    [ExcludeFromCodeCoverage]
    public class FakeFSTheoryElement(
        string testFileLine,
        string textOrFile,
        bool throws,
        string json,
        bool printJson = false) : IXunitSerializable
    {
        #region boilerplate
        public FakeFSTheoryElement()
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

    public static TheoryData<FakeFSTheoryElement> Text_To_Add =
    [
        // Windows paths
        new FakeFSTheoryElement(TestFileLine(), @"C:/", false, @"{""name"":""C:/"",""folders"":[],""files"":[]}", true),
        new FakeFSTheoryElement(TestFileLine(), @"C:/f0", false, @"{""name"":""C:/"",""folders"":[],""files"":[""f0""]}", true),
        new FakeFSTheoryElement(TestFileLine(), @"C:/d0/", false, @"{""name"":""C:/"",""folders"":[{""name"":""d0"",""folders"":[],""files"":[]}],""files"":[]}", true),
        new FakeFSTheoryElement(TestFileLine(), @"C:/d0/f1", false, @"{""name"":""C:/"",""folders"":[{""name"":""d0"",""folders"":[],""files"":[""f1""]}],""files"":[]}", true),
        new FakeFSTheoryElement(TestFileLine(), """
            C:/f0
            C:/d0/f1
            """, false, @"{""name"":""C:/"",""folders"":[{""name"":""d0"",""folders"":[],""files"":[""f1""]}],""files"":[""f0""]}", true),
        new FakeFSTheoryElement(TestFileLine(), """
            C:/f0
            C:/d0/f1
            /dd/ff
            """, false, @"{""name"":""C:/"",""folders"":[{""name"":""d0"",""folders"":[],""files"":[""f1""]},{""name"":""dd"",""folders"":[],""files"":[""ff""]}],""files"":[""f0""]}", true),
        // Unix paths
        new FakeFSTheoryElement(TestFileLine(), @"/", false, @"{""name"":""/"",""folders"":[],""files"":[]}", true),
        new FakeFSTheoryElement(TestFileLine(), @"/f0", false, @"{""name"":""/"",""folders"":[],""files"":[""f0""]}", true),
        new FakeFSTheoryElement(TestFileLine(), @"/d0/", false, @"{""name"":""/"",""folders"":[{""name"":""d0"",""folders"":[],""files"":[]}],""files"":[]}", true),
        new FakeFSTheoryElement(TestFileLine(), @"/d0/f1", false, @"{""name"":""/"",""folders"":[{""name"":""d0"",""folders"":[],""files"":[""f1""]}],""files"":[]}", true),
        new FakeFSTheoryElement(TestFileLine(), """
            /f0
            /d0/f1
            """, false, @"{""name"":""/"",""folders"":[{""name"":""d0"",""folders"":[],""files"":[""f1""]}],""files"":[""f0""]}", true),
        new FakeFSTheoryElement(TestFileLine(), """
            /f0
            /d0/f1
            /dd/ff
            """, false, @"{""name"":""/"",""folders"":[{""name"":""d0"",""folders"":[],""files"":[""f1""]},{""name"":""dd"",""folders"":[],""files"":[""ff""]}],""files"":[""f0""]}", true),
    ];

    public static TheoryData<FakeFSTheoryElement> Text_Files_To_Add =
    [
        new FakeFSTheoryElement(TestFileLine(), @"FakeFSFiles/FakeFS1.Win.txt",  false, "", false),
        new FakeFSTheoryElement(TestFileLine(), @"FakeFSFiles/FakeFS1.Unix.txt", false, "", false),
    ];

    [ExcludeFromCodeCoverage]
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

        public string A { get; private set; } = testFileLine;
        public string Json { get; private set; } = json;
        public bool Throws { get; private set; } = throws;
        public bool PrintJson { get; private set; } = printJson;
        public string Text { get; private set; } = text;

        public void Deserialize(IXunitSerializationInfo info)
        {
            A         = info.GetValue<string>(nameof(A)) ?? "";
            Json      = info.GetValue<string>(nameof(Json)) ?? "";
            Throws    = info.GetValue<bool>(nameof(Throws));
            PrintJson = info.GetValue<bool>(nameof(PrintJson));
            Text      = info.GetValue<string>(nameof(Text)) ?? "";
        }

        public void Serialize(IXunitSerializationInfo info)
        {
            info.AddValue(nameof(A), A);
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
        new Json_To_Add_TestData(TestFileLine(), @"FakeFSFiles/FakeFS1.Win.json",  false, true, @""),
        new Json_To_Add_TestData(TestFileLine(), @"FakeFSFiles/FakeFS1.Unix.json", false, true, @""),
    ];

    [ExcludeFromCodeCoverage]
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

        public string A { get; private set; } = testFileLine;
        public string FsJsonFile { get; private set; } = fsJsonFile;
        public string Cwf { get; private set; } = cwf;
        public string Chf { get; private set; } = chf;
        public string Rwf { get; private set; } = rwf;
        public bool Throws { get; private set; } = throws;

        public void Deserialize(IXunitSerializationInfo info)
        {
            A          = info.GetValue<string>(nameof(A)) ?? "";
            FsJsonFile = info.GetValue<string>(nameof(FsJsonFile)) ?? "";
            Cwf        = info.GetValue<string>(nameof(Cwf)) ?? "";
            Chf        = info.GetValue<string>(nameof(Chf)) ?? "";
            Rwf        = info.GetValue<string>(nameof(Rwf)) ?? "";
            Throws     = info.GetValue<bool>(nameof(Throws));
        }
        public void Serialize(IXunitSerializationInfo info)
        {
            info.AddValue(nameof(A), A);
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
        new SetCurrentFolder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "",                    "",                     "C:/",                 false),
        new SetCurrentFolder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "",                    "C:",                   "C:/",                 false),
        new SetCurrentFolder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "",                    "C:/",                  "C:/",                 false),
        new SetCurrentFolder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "",                    "/",                    "C:/",                 false),
        new SetCurrentFolder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "",                    "C:/folder1/",          "C:/folder1/",         false),
        new SetCurrentFolder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "",                    "/folder1/",            "C:/folder1/",         false),
        new SetCurrentFolder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "C:/folder1/",         "..",                   "C:/",                 false),
        new SetCurrentFolder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "/folder1/",           "..",                   "C:/",                 false),
        new SetCurrentFolder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "C:/folder1/",         ".",                    "C:/folder1/",         false),
        new SetCurrentFolder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "/folder1/",           ".",                    "C:/folder1/",         false),
        new SetCurrentFolder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "",                    "C:/folder1/folder2/",  "C:/folder1/folder2/", false),
        new SetCurrentFolder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "",                    "/folder1/folder2/",    "C:/folder1/folder2/", false),
        new SetCurrentFolder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "C:/folder1/folder2/", "..",                   "C:/folder1/",         false),
        new SetCurrentFolder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "/folder1/folder2/",   "..",                   "C:/folder1/",         false),
        new SetCurrentFolder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "C:/folder1/folder2/", ".",                    "C:/folder1/folder2/", false),
        new SetCurrentFolder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "/folder1/folder2/",   ".",                    "C:/folder1/folder2/", false),

        new SetCurrentFolder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "",                    "C:/root.txt",          "",                    true),
        new SetCurrentFolder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "",                    "/root.txt",            "",                    true),
        new SetCurrentFolder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "",                    "D:/folder1/",          "",                    true),
        new SetCurrentFolder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "",                    "C:/folder2/",          "",                    true),
        new SetCurrentFolder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "",                    "C:/folder3/file3.txt", "",                    true),

        new SetCurrentFolder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "",                    "",                     "/",                   false),
        new SetCurrentFolder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "",                    "/",                    "/",                   false),
        new SetCurrentFolder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "",                    "/folder1/",            "/folder1/",           false),
        new SetCurrentFolder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "/folder1/",           "..",                   "/",                   false),
        new SetCurrentFolder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "/folder1/",           ".",                    "/folder1/",           false),
        new SetCurrentFolder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "",                    "/folder1/folder2/",    "/folder1/folder2/",   false),
        new SetCurrentFolder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "/folder1/folder2/",   "..",                   "/folder1/",           false),
        new SetCurrentFolder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "/folder1/folder2/",   ".",                    "/folder1/folder2/",   false),

        new SetCurrentFolder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "",                     "/root.txt",           "",                    true),
        new SetCurrentFolder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "",                     "/root.txt",           "",                    true),
        new SetCurrentFolder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "",                     "D:/folder1/",         "",                    true),
        new SetCurrentFolder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "",                     "/folder2/",           "",                    true),
        new SetCurrentFolder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "",                     "/folder3/file3.txt",  "",                    true),
    ];

    [ExcludeFromCodeCoverage]
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
        new GetPathFromRoot_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json", "C:/folder1/",         "",                     "C:/folder1/",          "",          false),
        new GetPathFromRoot_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json", "C:/folder1/",         "C:/",                  "C:/",                  "",          false),
        new GetPathFromRoot_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json", "C:/folder1/",         "C:/folder1",           "C:/folder1/",          "",          false),
        new GetPathFromRoot_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json", "C:/folder1/",         "file1.txt",            "C:/folder1/",          "file1.txt", false),
        new GetPathFromRoot_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json", "C:/folder1/",         "C:/folder1/file1.txt", "C:/folder1/",          "file1.txt", false),
        new GetPathFromRoot_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json", "C:/folder1/",         ".",                    "C:/folder1/",          "",          false),
        new GetPathFromRoot_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json", "C:/folder1/folder2/", "..",                   "C:/folder1/",          "",          false),
        new GetPathFromRoot_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json", "C:/folder1/folder2/", "C:/folder1",           "C:/folder1/",          "",          false),
        new GetPathFromRoot_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json", "C:/folder1/folder2/", "../file1.txt",         "C:/folder1/",          "file1.txt", false),
        new GetPathFromRoot_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json", "C:/folder1/folder2/", "file2.txt",            "C:/folder1/folder2/",  "file2.txt", false),
        new GetPathFromRoot_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json", "C:/folder1/folder2/", "./file2.txt",          "C:/folder1/folder2/",  "file2.txt", false),
        new GetPathFromRoot_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json", "C:/folder1/folder2/", "C:/folder3/file3.txt", "C:/folder3/",          "file3.txt", false),

        new GetPathFromRoot_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "/folder1/",          "",                     "/folder1/",            "",          false),
        new GetPathFromRoot_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "/folder1/",          "/",                    "/",                    "",          false),
        new GetPathFromRoot_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "/folder1/",          "/folder1",             "/folder1/",            "",          false),
        new GetPathFromRoot_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "/folder1/",          "file1.txt",            "/folder1/",            "file1.txt", false),
        new GetPathFromRoot_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "/folder1/",          "/folder1/file1.txt",   "/folder1/",            "file1.txt", false),
        new GetPathFromRoot_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "/folder1/",          ".",                    "/folder1/",            "",          false),
        new GetPathFromRoot_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "/folder1/folder2/",  "..",                   "/folder1/",            "",          false),
        new GetPathFromRoot_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "/folder1/folder2/",  "/folder1",             "/folder1/",            "",          false),
        new GetPathFromRoot_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "/folder1/folder2/",  "../file1.txt",         "/folder1/",            "file1.txt", false),
        new GetPathFromRoot_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "/folder1/folder2/",  "file2.txt",            "/folder1/folder2/",    "file2.txt", false),
        new GetPathFromRoot_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "/folder1/folder2/",  "./file2.txt",          "/folder1/folder2/",    "file2.txt", false),
        new GetPathFromRoot_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "/folder1/folder2/",  "/folder3/file3.txt",   "/folder3/",            "file3.txt", false),
    ];

    [ExcludeFromCodeCoverage]
    public class Folder_TestData(
        string testFileLine,
        string jsonFile,
        string currentFolder,
        string path,
        bool result,
        bool throws) : IXunitSerializable
    {
        #region boilerplate
        public Folder_TestData()
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

    public static TheoryData<Folder_TestData> FolderExists_TestDataSet =
    [
        new Folder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "",                    "",                     true,  false),
        new Folder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "",                    "C:",                   true,  false),
        new Folder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "",                    "C:/",                  true,  false),
        new Folder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "",                    "/",                    true,  false),
        new Folder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "",                    "C:/folder1/",          true,  false),
        new Folder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "",                    "/folder1/",            true,  false),
        new Folder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "C:/folder1/",         "..",                   true,  false),
        new Folder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "/folder1/",           "..",                   true,  false),
        new Folder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "C:/folder1/",         ".",                    true,  false),
        new Folder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "/folder1/",           ".",                    true,  false),
        new Folder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "",                    "C:/folder1/folder2/",  true,  false),
        new Folder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "",                    "/folder1/folder2/",    true,  false),
        new Folder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "C:/folder1/folder2/", "..",                   true,  false),
        new Folder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "/folder1/folder2/",   "..",                   true,  false),
        new Folder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "C:/folder1/folder2/", ".",                    true,  false),
        new Folder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "/folder1/folder2/",   ".",                    true,  false),
        new Folder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "/folder1/folder2/",   "../file2.txt",         false, false),    // TODO: is this right?
        new Folder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "/folder1/folder2/",   "../file1.txt",         false, false),
        new Folder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "/folder1/folder2/",   "./file2.txt",          false, false),
        new Folder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "/folder1/folder2/",   "./file1.txt",          false, false),    // TODO: is this right?

        new Folder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "",                    "D:",                   false, true),
        new Folder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "",                    "D:/",                  false, true),
        new Folder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "",                    "D:/folder1/",          false, true),
        new Folder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "",                    "/folder2/",            false, false),
        new Folder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "",                    "C:/folder2/",          false, false),
        new Folder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "",                    "/folder2/",            false, false),
        new Folder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "C:/",                 "..",                   false, true),
        new Folder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "",                    "C:/folder1/file1.txt", false, false),
        new Folder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "",                    "/folder1/file1.txt",   false, false),
        new Folder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "C:/folder1/folder2/", "../file1.txt",         false, false),
        new Folder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "/folder1/folder2/",   "../file2.txt",         false, false),    // TODO: is this right?
        new Folder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "C:/folder1/folder2/", "./file1.txt",          false, false),    // TODO: is this right?
        new Folder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "/folder1/folder2/",   "./file2.txt",          false, false),
    ];

    public static TheoryData<Folder_TestData> FileExists_TestDataSet =
    [
        new Folder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "",                    "C:/folder1",           false, false),
        new Folder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "",                    "C:/folder1/file1.txt", true,  false),
        new Folder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "",                    "C:/folder1/file2.txt", false, false),
        new Folder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "",                    "/folder1",             false, false),
        new Folder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "",                    "/folder1/file1.txt",   true,  false),
        new Folder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "C:/folder1/",         "../file1.txt",         false, false),
        new Folder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "C:/folder1/",         "../root.txt",          true,  false),
        new Folder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "C:/folder1/",         "./file1.txt",          true,  false),
        new Folder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "/folder1/",           "./root.txt",           false, false),

        new Folder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "",                    "/folder1",             false, false),
        new Folder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "",                    "/folder1/file1.txt",   true,  false),
        new Folder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "",                    "/folder1/file2.txt",   false, false),
        new Folder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "",                    "/folder1",             false, false),
        new Folder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "",                    "/folder1/file1.txt",   true,  false),
        new Folder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "/folder1/",           "../file1.txt",         false, false),
        new Folder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "/folder1/",           "../root.txt",          true,  false),
        new Folder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "/folder1/",           "./file1.txt",          true,  false),
        new Folder_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "/folder1/",           "./root.txt",           false, false),
    ];

    [ExcludeFromCodeCoverage]
    public class GetPath_TestData(
        string testFileLine,
        string jsonFile,
        string currentFolder,
        string path,
        bool throws,
        string result) : IXunitSerializable
    {
        #region boilerplate
        public GetPath_TestData()
            : this("", "", "", "", false, "")
        {
        }

        #region Properties
        public string AFileLine { get; private set; } = testFileLine;
        public string JsonFile { get; private set; } = jsonFile;
        public string CurrentFolder { get; private set; } = currentFolder;
        public string Path { get; private set; } = path;
        public string Result { get; private set; } = result;
        public bool Throws { get; private set; } = throws;
        #endregion

        public void Deserialize(IXunitSerializationInfo info)
        {
            AFileLine       = info.GetValue<string>(nameof(AFileLine)) ?? "";
            JsonFile        = info.GetValue<string>(nameof(JsonFile)) ?? "";
            Path            = info.GetValue<string>(nameof(Path)) ?? "";
            CurrentFolder   = info.GetValue<string>(nameof(CurrentFolder)) ?? "";
            Result          = info.GetValue<string>(nameof(Result)) ?? "";
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

    public static TheoryData<GetPath_TestData> GetPath_TestDataSet =
    [
        new GetPath_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "",            "D:/folder1",           true,  ""),
        new GetPath_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "",            "..",                   true,  ""),
        new GetPath_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "",            "../root.txt",          false, "C:/root.txt"),

        new GetPath_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "",            "C:/folder1",           false, "C:/folder1"),
        new GetPath_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "",            "C:/folder1/file1.txt", false, "C:/folder1/file1.txt"),
        new GetPath_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "",            "C:/folder1/file2.txt", false, "C:/folder1/file2.txt"),
        new GetPath_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "",            "/folder1",             false, "C:/folder1"),
        new GetPath_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "",            "/folder1/file1.txt",   false, "C:/folder1/file1.txt"),
        new GetPath_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "C:/folder1/", "../file1.txt",         false, "C:/file1.txt"),
        new GetPath_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "C:/folder1/", "../root.txt",          false, "C:/root.txt"),
        new GetPath_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "C:/folder1/", "./file1.txt",          false, "C:/folder1/file1.txt"),
        new GetPath_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "/folder1/",   "./root.txt",           false,  "C:/folder1/root.txt"),

        new GetPath_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "",            "..",                   true,  ""),
        new GetPath_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json",  "",            "../root.txt",          false,  "C:/root.txt"),

        new GetPath_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "",            "/folder1",             false, "/folder1"),
        new GetPath_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "",            "/folder1/file1.txt",   false, "/folder1/file1.txt"),
        new GetPath_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "",            "/folder1/file2.txt",   false, "/folder1/file2.txt"),
        new GetPath_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "",            "/folder1",             false, "/folder1"),
        new GetPath_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "",            "/folder1/file1.txt",   false, "/folder1/file1.txt"),
        new GetPath_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "/folder1/",   "../file1.txt",         false, "/file1.txt"),
        new GetPath_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "/folder1/",   "../root.txt",          false, "/root.txt"),
        new GetPath_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "/folder1/",   "./file1.txt",          false, "/folder1/file1.txt"),
        new GetPath_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "/folder1/",   "./root.txt",           false, "/folder1/root.txt"),
    ];

    [ExcludeFromCodeCoverage]
    public class Enumerate_TestData(
        string testFileLine,
        string jsonFile,
        string currentFolder,
        string path,
        string pattern,
        bool recursive,
        bool throws,
        string[] results) : IXunitSerializable
    {
        #region boilerplate
        public Enumerate_TestData()
            : this("", "", "", "", "", false, false, [])
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
        new Enumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json", "", "C:/", ""                , false, false, ["C:/folder1/", "C:/folder3/"]),
        new Enumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json", "", "C:/", "*"               , false, false, ["C:/folder1/", "C:/folder3/"]),
        new Enumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json", "", "C:/", "*"               , true,  false, ["C:/folder1/", "C:/folder3/", "C:/folder1/folder2/", ]),
        new Enumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json", "", "C:/", "fold*"           , false, false, ["C:/folder1/", "C:/folder3/"]),
        new Enumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json", "", "C:/", "fold*"           , true,  false, ["C:/folder1/", "C:/folder3/", "C:/folder1/folder2/", ]),
        new Enumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json", "", "C:/", "*er?"            , false, false, ["C:/folder1/", "C:/folder3/"]),
        new Enumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json", "", "C:/", "*er?"            , true,  false, ["C:/folder1/", "C:/folder3/", "C:/folder1/folder2/", ]),
        new Enumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json", "", "C:/folder1", "*er?"     , false, false, ["C:/folder1/folder2/", ]),
        new Enumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json", "", "C:/folder1", "*er?"     , true,  false, ["C:/folder1/folder2/", ]),
        new Enumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json", "C:/folder1", ".", "*er?"    , false, false, ["C:/folder1/folder2/", ]),
        new Enumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json", "C:/folder1", ".", "*er?"    , true,  false, ["C:/folder1/folder2/", ]),
        new Enumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json", "C:/folder1", "", ""         , false, false, ["C:/folder1/folder2/"]),
        new Enumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json", "C:/folder1", "", ""         , true,  false, ["C:/folder1/folder2/"]),

        new Enumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "", "/", ""                 , false, false, ["/folder1/", "/folder3/"]),
        new Enumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "", "/", "*"                , false, false, ["/folder1/", "/folder3/"]),
        new Enumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "", "/", "*"                , true,  false, ["/folder1/", "/folder3/", "/folder1/folder2/", ]),
        new Enumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "", "/", "fold*"            , false, false, ["/folder1/", "/folder3/"]),
        new Enumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "", "/", "fold*"            , true,  false, ["/folder1/", "/folder3/", "/folder1/folder2/", ]),
        new Enumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "", "/", "*er?"             , false, false, ["/folder1/", "/folder3/"]),
        new Enumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "", "/", "*er?"             , true,  false, ["/folder1/", "/folder3/", "/folder1/folder2/", ]),
        new Enumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "", "/folder1", "*er?"      , false, false, ["/folder1/folder2/", ]),
        new Enumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "", "/folder1", "*er?"      , true,  false, ["/folder1/folder2/", ]),
        new Enumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "/folder1", ".", "*er?"     , false, false, ["/folder1/folder2/", ]),
        new Enumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "/folder1", ".", "*er?"     , true,  false, ["/folder1/folder2/", ]),
        new Enumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "/folder1", "", ""          , false, false, ["/folder1/folder2/"]),
        new Enumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "/folder1", "", ""          , true,  false, ["/folder1/folder2/"]),
    ];

    public static TheoryData<Enumerate_TestData> EnumerateFiles_TestDataSet =
    [
        new Enumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json", "", "C:/", ""                , false, false, ["C:/root.txt"]),
        new Enumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json", "", "C:/", "*"               , false, false, ["C:/root.txt"]),
        new Enumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json", "", "C:/", "*"               , true,  false, ["C:/root.txt", "C:/folder1/file1.txt", "C:/folder3/file3.txt", "C:/folder1/folder2/file2.txt", ]),
        new Enumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json", "", "C:/", "file*"           , false, false, []),
        new Enumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json", "", "C:/", "file*"           , true,  false, ["C:/folder1/file1.txt", "C:/folder3/file3.txt", "C:/folder1/folder2/file2.txt", ]),
        new Enumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json", "", "C:/", "file?"           , false, false, []),
        new Enumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json", "", "C:/", "file?"           , true,  false, ["C:/folder1/file1.txt", "C:/folder3/file3.txt", "C:/folder1/folder2/file2.txt", ]),
        new Enumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json", "", "C:/", "root*.*"         , true,  false, ["C:/root.txt", ]),
        new Enumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json", "", "C:/", "root*.*"         , true,  false, ["C:/root.txt", ]),
        new Enumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json", "C:/folder1", ".", "file?"   , false, false, ["C:/folder1/file1.txt", ]),
        new Enumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Win.json", "C:/folder1", ".", "file?"   , true,  false, ["C:/folder1/file1.txt", "C:/folder1/folder2/file2.txt"]),

        new Enumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "", "/", ""                 , false, false, ["/root.txt"]),
        new Enumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "", "/", "*"                , false, false, ["/root.txt"]),
        new Enumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "", "/", "*"                , true,  false, ["/root.txt", "/folder1/file1.txt", "/folder3/file3.txt", "/folder1/folder2/file2.txt", ]),
        new Enumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "", "/", "file*"            , false, false, []),
        new Enumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "", "/", "file*"            , true,  false, ["/folder1/file1.txt", "/folder3/file3.txt", "/folder1/folder2/file2.txt", ]),
        new Enumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "", "/", "file?"            , false, false, []),
        new Enumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "", "/", "file?"            , true,  false, ["/folder1/file1.txt", "/folder3/file3.txt", "/folder1/folder2/file2.txt", ]),
        new Enumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "", "/", "root*.*"          , true,  false, ["/root.txt", ]),
        new Enumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "", "/", "root*.*"          , true,  false, ["/root.txt", ]),
        new Enumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "/folder1", ".", "file?"    , false, false, ["/folder1/file1.txt", ]),
        new Enumerate_TestData(TestFileLine(), "FakeFSFiles/FakeFS2.Unix.json", "/folder1", ".", "file?"    , true,  false, ["/folder1/file1.txt", "/folder1/folder2/file2.txt"]),
    ];
}
