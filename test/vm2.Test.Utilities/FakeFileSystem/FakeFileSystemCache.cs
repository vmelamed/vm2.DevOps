namespace vm2.Test.Utilities.FakeFileSystem;

/// <summary>
/// Thread-safe cache for FakeFS instances.
/// </summary>
[ExcludeFromCodeCoverage]
public sealed class FakeFileSystemCache : IFakeFileSystemCache
{
    static readonly Dictionary<string, (DataType DataType, byte[] Bytes)> _fileSystems = [];
    static readonly Lock _sync = new();

    public static (DataType DataType, byte[] Bytes) AddFileSystemFile(string fileName, DataType dataType = default)
    {
        var m = OperatingSystem.PathRegex().Match(fileName);

        if (!m.Success)
            throw new ArgumentException($"The path name '{fileName}' format is invalid.", nameof(fileName));
        if (!File.Exists(fileName))
            throw new FileNotFoundException($"File '{fileName}' not found.", fileName);

        if (dataType is not DataType.Text and not DataType.Json and not DataType.Default)
            throw new ArgumentException(
                $"Cannot add file system file '{fileName}' with data type '{dataType}'. It should be either DataType.Text or DataType.Json.",
                nameof(dataType));

        if (dataType == DataType.Default)
        {
            var file = m.Groups[FileGr].ValueSpan;
            var si = file.LastIndexOf('.');

            if (si < 0)
                throw new ArgumentException(
                    $"Cannot determine the file type from the file extension of '{fileName}'. It should be either .txt or .json.",
                    nameof(fileName));

            var lowerSuffix = new SpanReader(
                                file[si..]
                                    .ToString()
                                    .ToLower(CultureInfo.InvariantCulture));

            dataType = lowerSuffix.ReadAll() switch {
                ".json" => DataType.Json,
                ".txt" => DataType.Text,
                _ => throw new ArgumentException(
                                    $"Cannot determine the file type from the file extension of '{fileName}'. It should be either .txt or .json",
                                    nameof(fileName)),
            };
        }

        var entry = (dataType, File.ReadAllBytes(fileName));

        lock (_sync)
            _fileSystems[fileName] = entry;

        return entry;
    }

    public IFileSystem GetFileSystem(string fileName)
    {
        var present = false;
        (DataType DataType, byte[] Bytes) entry = default;

        lock (_fileSystems)
            present = _fileSystems.TryGetValue(fileName, out entry);

        if (present)
            return new FakeFS(entry.Bytes, entry.DataType);

        entry = AddFileSystemFile(fileName);

        return new FakeFS(entry.Bytes, entry.DataType);
    }
}