namespace vm2.DevOps.Globs.Tests;

public partial class FakeFileSystemTests
{
    [Theory]
    [MemberData(nameof(Windows_Text_To_Add))]
    public void Should_Create_Windows_FS_From_Text(Windows_Files_To_Add_TestData data)
    {
        TestContext.Current.TestOutputHelper?.WriteLine(data.TestFileLine);
        var fsf = () => new FakeFS(data.Text);

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
            if (data.PrintJson)
            {
                TestContext.Current.TestOutputHelper?.WriteLine("Pretty JSON:");
                TestContext.Current.TestOutputHelper?.WriteLine(fs.ToJsonString(new JsonSerializerOptions { WriteIndented = true }));
            }
        }
    }

    [Theory]
    [MemberData(nameof(Windows_Text_Files_To_Add))]
    public void Should_Create_Windows_FS_From_Text_File(Windows_Files_To_Add_TestData data)
    {
        TestContext.Current.TestOutputHelper?.WriteLine(data.TestFileLine);
        var fsf = () => new FakeFS(data.Text, DataFileType.Text);

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
            if (data.PrintJson)
            {
                TestContext.Current.TestOutputHelper?.WriteLine("Pretty JSON:");
                TestContext.Current.TestOutputHelper?.WriteLine(fs.ToJsonString(new JsonSerializerOptions { WriteIndented = true }));
            }
        }
    }

    [Theory]
    [MemberData(nameof(Windows_Json_To_Add))]
    public void Should_Create_Windows_FS_From_Json(Windows_Json_To_Add_TestData data)
    {
        TestContext.Current.TestOutputHelper?.WriteLine(data.TestFileLine);
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
            if (data.PrintJson)
            {
                //TestContext.Current.TestOutputHelper?.WriteLine("Pretty JSON:");
                //TestContext.Current.TestOutputHelper?.WriteLine(fs.ToJsonString(Folder.JsonSerializerOptions));
            }
        }
    }

    [Theory]
    [MemberData(nameof(Windows_Json_Files_To_Add))]
    public void Should_Create_Windows_FS_From_Json_File(Windows_Json_To_Add_TestData data)
    {
        TestContext.Current.TestOutputHelper?.WriteLine(data.TestFileLine);
        var fsf = () => new FakeFS(data.Json, DataFileType.Json);

        if (data.Throws)
            fsf.Should().Throw();
        else
        {
            var fs = fsf.Should().NotThrow().Which;
            var js = fs.ToJson(Folder.JsonSerializerOptions, writeBom: true);
            if (!string.IsNullOrWhiteSpace(data.Json))
            {
                //TestContext.Current.TestOutputHelper?.WriteLine($"Result JSON: {js}");
                var dataJson = File.ReadAllBytes(data.Json); // should not have trailing new line!!!
                var jsBytes = js.ToArray();
                Enumerable.SequenceEqual(jsBytes, dataJson).Should().BeTrue();
            }
            if (data.PrintJson)
            {
                //TestContext.Current.TestOutputHelper?.WriteLine("Pretty JSON:");
                //TestContext.Current.TestOutputHelper?.WriteLine(fs.ToJsonString(Folder.JsonSerializerOptions));
            }
        }
    }
}
