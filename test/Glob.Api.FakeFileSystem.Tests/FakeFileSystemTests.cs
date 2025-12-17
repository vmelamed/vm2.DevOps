// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Val Melamed

namespace vm2.DevOps.Glob.Api.FakeFileSystem.Tests;

public partial class FakeFileSystemTests
{
    [Theory]
    [MemberData(nameof(Text_Files_To_Add))]
    public void Should_Create_FS_From_Text_File(FakeFSTheoryElement data)
    {
        var fsf = () => new FakeFS(data.TextOrFile);

        if (data.Throws)
            fsf.Should().Throw();
        else
        {
            var fs = fsf.Should().NotThrow().Which;

            TestContext.Current.TestOutputHelper?.WriteLine($"Result JSON:  {fs.ToJsonString()}");
            TestContext.Current.TestOutputHelper?.WriteLine($"Result Graph: {fs.ToGraph()}");
        }
    }

    [Theory]
    [MemberData(nameof(Json_Files_To_Add))]
    public void Should_Create_FS_From_Json_File(Json_To_Add_TestData data)
    {
        var fsf = () => new FakeFS(data.Json);

        if (data.Throws)
            fsf.Should().Throw();
        else
        {
            var fs = fsf.Should().NotThrow().Which;

            TestContext.Current.TestOutputHelper?.WriteLine($"Result JSON:  {fs.ToJsonString()}");
            TestContext.Current.TestOutputHelper?.WriteLine($"Result Graph: {fs.ToGraph()}");
        }
    }

    [Theory]
    [MemberData(nameof(Set_Current_Folder_TestData))]
    public void Set_Current_Folder_Test(SetCurrentFolder_TestData data)
    {
        var fs = new FakeFS(data.FsJsonFile);
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
        var fs = new FakeFS(data.JsonFile);
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
        var fs = new FakeFS(data.JsonFile);
        fs.SetCurrentFolder(data.CurrentFolder);
        var exists = () => fs.DirectoryExists(data.Path);

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
        var fs = new FakeFS(data.JsonFile);
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
        var fs = new FakeFS(data.JsonFile);
        fs.SetCurrentFolder(data.CurrentFolder);
        var options = data.Recursive
                        ? new EnumerationOptions { RecurseSubdirectories = true }
                        : new EnumerationOptions { RecurseSubdirectories = false };
        var enumFolders = () => fs.EnumerateDirectories(data.Path, data.Pattern, options).ToList();

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
        var fs = new FakeFS(data.JsonFile);
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
        var fs = new FakeFS(data.JsonFile);
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