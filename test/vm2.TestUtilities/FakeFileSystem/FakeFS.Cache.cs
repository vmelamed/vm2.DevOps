namespace vm2.TestUtilities.FakeFileSystem;

public sealed partial class FakeFS
{
    static readonly Dictionary<string, (DataType DataType, byte[] Bytes)> _fileSystemsData = [];    // fileName => data type, content in UTF8
    static readonly Lock _sync = new();

    [GeneratedRegex(@"^([a-zA-Z]:\\|\\\\|/).*$", RegexOptions.ExplicitCapture)]
    internal static partial Regex FileSystemRoot();

    static (DataType DataType, string Data) GetFileSystemData(
        string fileName,
        DataType dataType = DataType.Default)
    {
        var present = false;
        (DataType DataType, byte[] Bytes) entry = default;

        lock (_sync)
            present = _fileSystemsData.TryGetValue(fileName, out entry);

        string? content = null;

        if (!present)
        {
            content = File.ReadAllText(fileName);
            dataType = Recognize(fileName, content, dataType);

            entry = (dataType, Encoding.UTF8.GetBytes(content));

            lock (_sync)
                _fileSystemsData[fileName] = entry;
        }

        Debug.Assert(entry.DataType is not DataType.Default, "Expect concrete file system description type.");

        return (entry.DataType, content ?? Encoding.UTF8.GetString(entry.Bytes));
    }

    public static DataType Recognize(string fileName, string content, DataType dataType = default)
    {
        if (string.IsNullOrEmpty(fileName))
            throw new ArgumentException($"The path name cannot be null or empty.", nameof(fileName));

        var m = OperatingSystem.PathRegex().Match(fileName);

        if (!m.Success)
            throw new ArgumentException($"The path name '{fileName}' format is invalid.", nameof(fileName));
        if (!File.Exists(fileName))
            throw new FileNotFoundException($"File '{fileName}' not found.", fileName);

        // the caller knew the type already
        if (dataType is DataType.Text or DataType.Json)
            return dataType;

        // try to recognize by suffix first
        dataType = RecognizeBySuffix(m.Groups[FileGr].ValueSpan, m.Groups[SuffixGr].ValueSpan);
        if (dataType is DataType.Text or DataType.Json)
            return dataType;

        // try to recognize by content
        dataType = RecognizeByContent(content);
        if (dataType is DataType.Text or DataType.Json)
            return dataType;

        throw new ArgumentException(
                    $"Could not recognize the file type neither by the file extension, nor from the contents of '{fileName}'.",
                    nameof(fileName));
    }

    static DataType RecognizeBySuffix(ReadOnlySpan<char> fileName, ReadOnlySpan<char> suffix)
    {
        if (suffix.IsEmpty)
        {
            // for some reason the regex did not capture the suffix, try to find it manually
            var si = fileName.LastIndexOf('.');

            if (si < 0 || si + 1 >= fileName.Length)
                return DataType.Default;

            suffix = fileName[(si+1)..];
        }

        return suffix.ToString().ToLower(CultureInfo.InvariantCulture) switch {
            "json" => DataType.Json,
            "txt" => DataType.Text,
            _ => DataType.Default,
        };
    }

    static DataType RecognizeByContent(string content)
    {
        using var reader = new StringReader(content);
        string? firstLine;

        // skip empty lines and comments
        do
            firstLine = reader.ReadLine();
        while (!string.IsNullOrWhiteSpace(firstLine) &&
               (firstLine.StartsWith('#') || firstLine.StartsWith("//")));

        return firstLine switch {
            not null when firstLine.StartsWith('{') => DataType.Json,           // a JSON object {...}
            not null when FileSystemRoot().IsMatch(firstLine) => DataType.Text, // a path line: C:\... or /...
            _ => DataType.Default,
        };
    }
}
