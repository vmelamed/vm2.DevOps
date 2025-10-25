namespace vm2.DevOps.Globs.Tests;

[ExcludeFromCodeCoverage]
public partial class FakeFileSystemTests
{
    [Theory]
    [MemberData(nameof(Text_To_Add))]
    public void Should_Create_Windows_FS_From_Text(FakeFS_TestData data)
    {
        TestContext.Current.TestOutputHelper?.WriteLine(data.ATestFileLine);
        var fsf = () => new FakeFS(data.TextOrFile);

        if (data.Throws)
            fsf.Should().Throw();
        else
        {
            var fs = fsf.Should().NotThrow().Which;
            var js = fs.ToJsonString();
            if (!string.IsNullOrWhiteSpace(data.Json))
            {
                TestContext.Current.TestOutputHelper?.WriteLine($"Result JSON: {js}");
                js.Should().Be(data.Json);
            }
            // TODO: why pretty print doesn't work???
            //if (data.PrintJson)
            //{
            //    TestContext.Current.TestOutputHelper?.WriteLine("Pretty JSON:");
            //    TestContext.Current.TestOutputHelper?.WriteLine(fs.ToJsonString());
            //}
        }
    }

    [Theory]
    [MemberData(nameof(Text_Files_To_Add))]
    public void Should_Create_FS_From_Text_File(FakeFS_TestData data)
    {
        TestContext.Current.TestOutputHelper?.WriteLine(data.ATestFileLine);
        var fsf = () => new FakeFS(data.TextOrFile, DataFileType.Text);

        if (data.Throws)
            fsf.Should().Throw();
        else
        {
            var fs = fsf.Should().NotThrow().Which;
            var js = fs.ToJsonString();
            if (!string.IsNullOrWhiteSpace(data.Json))
            {
                TestContext.Current.TestOutputHelper?.WriteLine($"Result JSON: {js}");
                js.Should().Be(data.Json);
            }
            //if (data.PrintJson)
            //{
            //    TestContext.Current.TestOutputHelper?.WriteLine("Pretty JSON:");
            //    TestContext.Current.TestOutputHelper?.WriteLine(fs.ToJsonString());
            //}
        }
    }

    [Theory]
    [MemberData(nameof(Json_To_Add))]
    public void Should_Create_Windows_FS_From_Json(Json_To_Add_TestData data)
    {
        TestContext.Current.TestOutputHelper?.WriteLine(data.ATestFileLine);
        var fsf = () => new FakeFS(Encoding.UTF8.GetBytes(data.Json));

        if (data.Throws)
            fsf.Should().Throw();
        else
        {
            var fs = fsf.Should().NotThrow().Which;
            var js = fs.ToJsonString();
            if (!string.IsNullOrWhiteSpace(data.Json))
            {
                //TestContext.Current.TestOutputHelper?.WriteLine($"Result JSON: {js}");
                js.Should().Be(data.Json);
            }
            //if (data.PrintJson)
            //{
            //    TestContext.Current.TestOutputHelper?.WriteLine("Pretty JSON:");
            //    TestContext.Current.TestOutputHelper?.WriteLine(fs.ToJsonString(Folder.JsonSerializerOptions));
            //}
        }
    }

    [Theory]
    [MemberData(nameof(Json_Files_To_Add))]
    public void Should_Create_FS_From_Json_File(Json_To_Add_TestData data)
    {
        TestContext.Current.TestOutputHelper?.WriteLine(data.ATestFileLine);
        var fsf = () => new FakeFS(data.Json, DataFileType.Json);

        if (data.Throws)
            fsf.Should().Throw();
        else
        {
            var fs = fsf.Should().NotThrow().Which;
            var js = fs.ToJson(writeBom: true);
            TestContext.Current.TestOutputHelper?.WriteLine($"Result JSON: {Encoding.UTF8.GetString(js)}");

            var dataJson = File.ReadAllBytes(data.Json); // should not have trailing new line!!!
            var jsBytes = js.ToArray();
            //string dataJsonStr = Encoding.UTF8.GetString(dataJson);
            //string jsBytesStr = Encoding.UTF8.GetString(js);
            //Enumerable.SequenceEqual(jsBytes, dataJson).Should().BeTrue();
            //jsBytes.Length.Should().Be(dataJson.Length);
            //for (int i = 0; i < jsBytes.Length; i++)
            //{
            //    jsBytes[i].Should().Be(dataJson[i], $"byte at position {i} should be equal");
            //}
            //if (data.PrintJson)
            //{
            //    TestContext.Current.TestOutputHelper?.WriteLine("Pretty JSON:");
            //    TestContext.Current.TestOutputHelper?.WriteLine(fs.ToJsonString());
            //}
        }
    }

    [Theory]
    [MemberData(nameof(Set_Current_Folder_TestData))]
    public void Set_Current_Folder_Test(SetCurrentFolder_TestData data)
    {
        var fs = new FakeFS(data.FsJsonFile, DataFileType.Json);
        var curFolder = data.Cwf is not "" ? fs.SetCurrentFolder(data.Cwf) : fs.CurrentFolder;
        var chgCurrent = () => fs.SetCurrentFolder(data.Chf);

        if (data.Throws)
        {
            chgCurrent.Should().Throw<ArgumentException>();
        }
        else
        {
            var cf = chgCurrent.Should().NotThrow().Which;
            fs.CurrentFolder.Path.Should().Be(cf.Path);
            fs.CurrentFolder.Path.Should().Be(data.Rwf);
        }
    }

    [Theory]
    [MemberData(nameof(FromPath_TestDataSet))]
    public void GetPathFromRoot_Test(GetPathFromRoot_TestData data)
    {
        var fs = new FakeFS(data.JsonFile, DataFileType.Json);
        fs.SetCurrentFolder(data.CurrentFolder);
        var fromPath = () => fs.GetPathFromRoot(data.Path);

        if (data.Throws)
        {
            fromPath.Should().Throw<ArgumentException>();
        }
        else
        {
            var (folder, _, file) = fromPath.Should().NotThrow().Which;
            (folder?.Path ?? "").Should().Be(data.ResultPath);
            file.Should().Be(data.ResultFile);
        }
    }

    [Theory]
    [MemberData(nameof(FolderExists_TestDataSet))]
    public void FolderExists_Test(Folder_TestData data)
    {
        var fs = new FakeFS(data.JsonFile, DataFileType.Json);
        fs.SetCurrentFolder(data.CurrentFolder);
        var exists = () => fs.FolderExists(data.Path);

        if (data.Throws)
        {
            exists.Should().Throw<ArgumentException>();
        }
        else
        {
            var existsResult = exists.Should().NotThrow().Which;
            existsResult.Should().Be(data.Result);
        }
    }

    [Theory]
    [MemberData(nameof(FileExists_TestDataSet))]
    public void FileExists_Test(Folder_TestData data)
    {
        var fs = new FakeFS(data.JsonFile, DataFileType.Json);
        fs.SetCurrentFolder(data.CurrentFolder);
        var exists = () => fs.FileExists(data.Path);

        if (data.Throws)
        {
            exists.Should().Throw<ArgumentException>();
        }
        else
        {
            var existsResult = exists.Should().NotThrow().Which;
            existsResult.Should().Be(data.Result);
        }
    }

    [Theory]
    [MemberData(nameof(EnumerateFolders_TestDataSet))]
    public void EnumerateFolders_Test(Enumerate_TestData data)
    {
        var fs = new FakeFS(data.JsonFile, DataFileType.Json);
        fs.SetCurrentFolder(data.CurrentFolder);
        var options = data.Recursive
                        ? new EnumerationOptions { RecurseSubdirectories = true }
                        : new EnumerationOptions { RecurseSubdirectories = false };
        var enumFolders = () => fs.EnumerateFolders(data.Path, data.Pattern, options).ToList();

        if (data.Throws)
        {
            enumFolders.Should().Throw<ArgumentException>();
        }
        else
        {
            var results = new HashSet<string>(enumFolders.Should().NotThrow().Which);
            results.Should().BeEquivalentTo(data.Results);
        }
    }

    [Theory]
    [MemberData(nameof(EnumerateFiles_TestDataSet))]
    public void EnumerateFiles_Test(Enumerate_TestData data)
    {
        var fs = new FakeFS(data.JsonFile, DataFileType.Json);
        fs.SetCurrentFolder(data.CurrentFolder);
        var options = data.Recursive
                        ? new EnumerationOptions { RecurseSubdirectories = true }
                        : new EnumerationOptions { RecurseSubdirectories = false };
        var enumFolders = () => fs.EnumerateFiles(data.Path, data.Pattern, options).ToList();

        if (data.Throws)
        {
            enumFolders.Should().Throw<ArgumentException>();
        }
        else
        {
            var results = new HashSet<string>(enumFolders.Should().NotThrow().Which);
            results.Should().BeEquivalentTo(data.Results);
        }
    }

    [Theory]
    [MemberData(nameof(GetPath_TestDataSet))]
    public void GetPath_Test(GetPath_TestData data)
    {
        var fs = new FakeFS(data.JsonFile, DataFileType.Json);
        fs.SetCurrentFolder(data.CurrentFolder);
        var getPath = () => fs.GetFullPath(data.Path);
        if (data.Throws)
        {
            getPath.Should().Throw<ArgumentException>();
        }
        else
        {
            var result = getPath.Should().NotThrow().Which;
            result.Should().Be(data.Result);
        }
    }
}