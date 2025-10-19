namespace vm2.DevOps.Globs.Tests;

public partial class FakeFileSystemTests
{
    public record Windows_Files_To_Add_TestData(string testFileLine, string text, bool throws, string json, bool printJson = false) : IXunitSerializable
    {
        public Windows_Files_To_Add_TestData()
            : this("", "", false, "", false)
        {
        }

        public string TestFileLine { get; private set; } = testFileLine;
        public string Text { get; private set; } = text;
        public bool Throws { get; private set; } = throws;
        public string Json { get; private set; } = json;
        public bool PrintJson { get; private set; } = printJson;

        public void Deserialize(IXunitSerializationInfo info)
        {
            TestFileLine = info.GetValue<string>(nameof(TestFileLine)) ?? "";
            Text         = info.GetValue<string>(nameof(Text)) ?? "";
            Throws       = info.GetValue<bool>(nameof(Throws));
            Json         = info.GetValue<string>(nameof(Json)) ?? "";
            PrintJson    = info.GetValue<bool>(nameof(PrintJson));
        }

        public void Serialize(IXunitSerializationInfo info)
        {
            info.AddValue(nameof(TestFileLine), TestFileLine);
            info.AddValue(nameof(Text), Text);
            info.AddValue(nameof(Throws), Throws);
            info.AddValue(nameof(Json), Json);
            info.AddValue(nameof(PrintJson), PrintJson);
        }
    }

    public static TheoryData<Windows_Files_To_Add_TestData> Windows_Text_To_Add =
    [
        new Windows_Files_To_Add_TestData(TestFileLine(), @"C:/", false, @"{""name"":""C:/"",""folders"":[],""files"":[]}", true),
        new Windows_Files_To_Add_TestData(TestFileLine(), @"C:/f0", false, @"{""name"":""C:/"",""folders"":[],""files"":[""f0""]}", true),
        new Windows_Files_To_Add_TestData(TestFileLine(), @"C:/d0/", false, @"{""name"":""C:/"",""folders"":[{""name"":""d0"",""folders"":[],""files"":[]}],""files"":[]}", true),
        new Windows_Files_To_Add_TestData(TestFileLine(), @"C:/d0/f1", false, @"{""name"":""C:/"",""folders"":[{""name"":""d0"",""folders"":[],""files"":[""f1""]}],""files"":[]}", true),
        new Windows_Files_To_Add_TestData(TestFileLine(), """
            C:/f0
            C:/d0/f1
            """, false, @"{""name"":""C:/"",""folders"":[{""name"":""d0"",""folders"":[],""files"":[""f1""]}],""files"":[""f0""]}", true),
        new Windows_Files_To_Add_TestData(TestFileLine(), """
            C:/f0
            C:/d0/f1
            /dd/ff
            """, false, @"{""name"":""C:/"",""folders"":[{""name"":""d0"",""folders"":[],""files"":[""f1""]},{""name"":""dd"",""folders"":[],""files"":[""ff""]}],""files"":[""f0""]}", true),
    ];

    public static TheoryData<Windows_Files_To_Add_TestData> Windows_Text_Files_To_Add =
    [
        new Windows_Files_To_Add_TestData(TestFileLine(), @"FakeFS1.txt", false, "", false),
    ];

    public record Windows_Json_To_Add_TestData(string testFileLine, string json, bool throws, bool printJson, string text) : IXunitSerializable
    {
        public Windows_Json_To_Add_TestData()
            : this("", "", false, false, "")
        {
        }

        public string TestFileLine { get; private set; } = testFileLine;
        public string Json { get; private set; } = json;
        public bool Throws { get; private set; } = throws;
        public bool PrintJson { get; private set; } = printJson;
        public string Text { get; private set; } = text;

        public void Deserialize(IXunitSerializationInfo info)
        {
            TestFileLine = info.GetValue<string>(nameof(TestFileLine)) ?? "";
            Json         = info.GetValue<string>(nameof(Json)) ?? "";
            Throws       = info.GetValue<bool>(nameof(Throws));
            PrintJson    = info.GetValue<bool>(nameof(PrintJson));
            Text         = info.GetValue<string>(nameof(Text)) ?? "";
        }

        public void Serialize(IXunitSerializationInfo info)
        {
            info.AddValue(nameof(TestFileLine), TestFileLine);
            info.AddValue(nameof(Json), Json);
            info.AddValue(nameof(Throws), Throws);
            info.AddValue(nameof(PrintJson), PrintJson);
            info.AddValue(nameof(Text), Text);
        }
    }

    public static TheoryData<Windows_Json_To_Add_TestData> Windows_Json_To_Add =
    [
        new Windows_Json_To_Add_TestData(TestFileLine(), @"{""name"":""C:/"",""folders"":[],""files"":[]}", false, true, @""),
        new Windows_Json_To_Add_TestData(TestFileLine(), @"{""name"":""C:/"",""folders"":[],""files"":[""f0""]}", false, true, @""),
        new Windows_Json_To_Add_TestData(TestFileLine(), @"{""name"":""C:/"",""folders"":[{""name"":""d0"",""folders"":[],""files"":[]}],""files"":[]}", false, true, @""),
        new Windows_Json_To_Add_TestData(TestFileLine(), @"{""name"":""C:/"",""folders"":[{""name"":""d0"",""folders"":[],""files"":[""f1""]}],""files"":[]}", false, true, @""),
        new Windows_Json_To_Add_TestData(TestFileLine(), @"{""name"":""C:/"",""folders"":[{""name"":""d0"",""folders"":[],""files"":[""f1""]}],""files"":[""f0""]}", false, true, @""),
        new Windows_Json_To_Add_TestData(TestFileLine(), @"{""name"":""C:/"",""folders"":[{""name"":""d0"",""folders"":[],""files"":[""f1""]},{""name"":""dd"",""folders"":[],""files"":[""ff""]}],""files"":[""f0""]}", false, true, @""),
    ];

    public static TheoryData<Windows_Json_To_Add_TestData> Windows_Json_Files_To_Add =
    [
        new Windows_Json_To_Add_TestData(TestFileLine(), @"FakeFS1.json", false, true, @""),
    ];
}
