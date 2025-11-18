namespace vm2.DevOps.Glob.Api.Tests;

public sealed class GlobTestsFixture : IDisposable
{
    IHost _host { get; init; }

    public GlobTestsFixture()
    {
        var builder = Host.CreateApplicationBuilder();

        builder
            .Logging
            .ClearProviders()
            .AddConsole()
            .SetMinimumLevel(LogLevel.Trace)
            ;
        builder
            .Services
            // the glob enumerator with a real FS
            .AddGlobEnumerator()
            // the glob enumerator with the FakeFS-es:
            .AddGlobEnumerator("FakeFSFiles/FakeFS1.Unix.txt")
            .AddGlobEnumerator("FakeFSFiles/FakeFS1.Win.txt")
            .AddGlobEnumerator("FakeFSFiles/FakeFS1.Unix.json")
            .AddGlobEnumerator("FakeFSFiles/FakeFS1.Win.json")
            .AddGlobEnumerator("FakeFSFiles/FakeFS2.Unix.json")
            .AddGlobEnumerator("FakeFSFiles/FakeFS2.Win.json")

            .AddGlobEnumerator("FakeFSFiles/FakeFS3.Unix.json")
            .AddGlobEnumerator("FakeFSFiles/FakeFS3.Win.json")
            .AddGlobEnumerator("FakeFSFiles/FakeFS4.Unix.json")
            .AddGlobEnumerator("FakeFSFiles/FakeFS4.Win.json")
            .AddGlobEnumerator("FakeFSFiles/FakeFS5.Unix.json")
            .AddGlobEnumerator("FakeFSFiles/FakeFS5.Win.json")
            .AddGlobEnumerator("FakeFSFiles/FakeFS6.Unix.json")
            .AddGlobEnumerator("FakeFSFiles/FakeFS6.Win.json")
            .AddGlobEnumerator("FakeFSFiles/FakeFS7.Unix.json")
            .AddGlobEnumerator("FakeFSFiles/FakeFS7.Win.json")
            ;

        _host = builder.Build();
    }

    public void Dispose() => _host.Dispose();

    public ITestOutputHelper? Output { get; set; }

    public GlobEnumerator GetGlobEnumerator(
        string fileSystemFile,
        Func<GlobEnumeratorBuilder, GlobEnumeratorBuilder>? configure = null)
    {
        // Get a glob with the file system for this test
        var ge = _host.Services.GetRequiredKeyedService<GlobEnumerator>(fileSystemFile);

        if (configure is null)
            return ge;

        var builder = _host
                        .Services
                        .GetRequiredService<GlobEnumeratorBuilder>()
                        ;
        configure(builder);

        return builder.Configure(ge);
    }

    static Dictionary<string, (DataType DataType, byte[] Bytes)> _fileSystems = [];

    public static FakeFS CreateFileSystem(string fileName)
    {
        var present = false;
        (DataType DataType, byte[] Bytes) entry = default;

        lock (_fileSystems)
            present = _fileSystems.TryGetValue(fileName, out entry);

        if (present)
            return new FakeFS(entry.Bytes, entry.DataType);

        var m = OperatingSystem.IsWindows()
                    ? WindowsPathRegex().Match(fileName)
                    : UnixPathRgex().Match(fileName);

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
