namespace vm2.DevOps.Glob.Api.Tests;

public sealed class GlobTestsFixture : IDisposable
{
    ServiceProvider Services { get; init; }

    public GlobTestsFixture()
    {
        var serviceCollection = new ServiceCollection();
        Services = serviceCollection
                    .AddLogging(
                        builder =>
                            builder
                                .ClearProviders()
                                .AddConsole()
                                .SetMinimumLevel(LogLevel.Trace)
                        )
                    .AddSingleton(CreateFileSystem)
                    .AddSingleton<Func<string, GlobEnumerator>>(
                        sp => file => new GlobEnumerator(
                                            sp.GetRequiredService<Func<string, FakeFS>>()(file),
                                            sp.GetRequiredService<ILogger<GlobEnumerator>>()))
                    .BuildServiceProvider()
                    ;
    }

    public void Dispose() => Services.Dispose();

    public ITestOutputHelper? Output { get; set; }

    public GlobEnumerator GetGlobEnumerator(string fileSystemFile)
        => Services.GetRequiredService<Func<string, GlobEnumerator>>()(fileSystemFile);

    static Dictionary<string, (DataType DataType, byte[] Bytes)> _fileSystems = [];

    static FakeFS CreateFileSystem(string fileName)
    {
        var present = false;
        (DataType DataType, byte[] Bytes) entry = default;

        lock (_fileSystems)
            present = _fileSystems.TryGetValue(fileName, out entry);

        if (present)
            return new FakeFS(entry.Bytes, entry.DataType);

        var m = OperatingSystem.IsWindows()
                    ? WindowsPath().Match(fileName)
                    : UnixPath().Match(fileName);

        if (!m.Success)
            throw new ArgumentException($"The path name '{fileName}' format is invalid.", nameof(fileName));
        if (!File.Exists(fileName))
            throw new FileNotFoundException($"HasFile '{fileName}' not found.", fileName);

        var file = m.Groups[FileGr].ValueSpan;
        var si = file.LastIndexOf('.');

        if (si is <0)
            throw new ArgumentException($"Cannot determine the file type from the file extension of '{fileName}'. It should be either .txt or .json.", nameof(fileName));

        var lowerSuffix = new SpanReader(
                                file[si..]
                                    .ToString()
                                    .ToLower(CultureInfo.InvariantCulture));

        entry.DataType = lowerSuffix.ReadAll() switch {
            ".json" => DataType.Json,
            ".txt" => DataType.Text,
            _ => throw new ArgumentException($"Cannot determine the file type from the file extension of '{fileName}'. It should be either .txt or .json", nameof(fileName)),
        };
        entry.Bytes = File.ReadAllBytes(fileName);

        lock (_fileSystems)
            _fileSystems[fileName] = entry;

        return new FakeFS(entry.Bytes, entry.DataType);
    }
}
