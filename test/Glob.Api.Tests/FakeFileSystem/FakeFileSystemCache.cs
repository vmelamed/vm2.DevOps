namespace vm2.DevOps.Glob.Api.Tests.FakeFileSystem;

/// <summary>
/// Thread-safe cache for FakeFS instances.
/// </summary>
[ExcludeFromCodeCoverage]
public sealed class FakeFileSystemCache : IFakeFileSystemCache
{
    static readonly Dictionary<string, (DataType DataType, byte[] Bytes)> _fileSystems = [];

    public IFileSystem GetFileSystem(string fileName)
    {
        var present = false;
        (DataType DataType, byte[] Bytes) entry = default;

        lock (_fileSystems)
            present = _fileSystems.TryGetValue(fileName, out entry);

        if (present)
            return new FakeFS(entry.Bytes, entry.DataType);

        var m = OperatingSystem.PathRegex().Match(fileName);

        if (!m.Success)
            throw new ArgumentException($"The path name '{fileName}' format is invalid.", nameof(fileName));
        if (!File.Exists(fileName))
            throw new FileNotFoundException($"File '{fileName}' not found.", fileName);

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

        entry.DataType = lowerSuffix.ReadAll() switch {
            ".json" => DataType.Json,
            ".txt" => DataType.Text,
            _ => throw new ArgumentException(
                                $"Cannot determine the file type from the file extension of '{fileName}'. It should be either .txt or .json",
                                nameof(fileName)),
        };
        entry.Bytes = File.ReadAllBytes(fileName);

        lock (_fileSystems)
            _fileSystems[fileName] = entry;

        return new FakeFS(entry.Bytes, entry.DataType);
    }
}