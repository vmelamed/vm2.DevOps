namespace vm2.DevOps.Glob.Api.Tests;

public sealed class GlobTestsFixture : IDisposable
{
    IHost _host { get; init; }

    public GlobTestsFixture()
    {
        var builder = Host.CreateApplicationBuilder();

        builder.Logging
                    .ClearProviders()
                    .AddConsole()
                    .SetMinimumLevel(LogLevel.Trace)
                    ;
        builder.Services
        ;

        //var serviceCollection = new ServiceCollection();
        //Services = serviceCollection
        //            .AddLogging(
        //                builder =>
        //                    builder
        //                        .ClearProviders()
        //                        .AddConsole()
        //                        .SetMinimumLevel(LogLevel.Trace)
        //                )
        //            .AddSingleton(CreateFileSystem)
        //            .AddSingleton<Func<string, GlobEnumerator>>(
        //                sp => file => new GlobEnumerator(
        //                                    sp.GetRequiredService<Func<string, FakeFS>>()(file),    // should return CreateFileSystem
        //                                    sp.GetRequiredService<ILogger<GlobEnumerator>>()))      // should return the console logger
        //            .BuildServiceProvider()
        //            ;

        _host = builder.Build();
    }

    public void Dispose() => _host.Dispose();

    public ITestOutputHelper? Output { get; set; }

    public GlobEnumerator GetGlobEnumerator(
        string fileSystemFile,
        Func<GlobEnumeratorBuilder, GlobEnumerator>? configure = null)
    {
        // Set the file system for this test
        var factory = _host.Services.GetRequiredService<IFileSystemFactory>();
        factory.SetFileSystem(fileSystemFile);

        if (configure is null)
        {
            return _host.Services.GetRequiredService<GlobEnumerator>();
        }

        var builder = _host.Services.GetRequiredService<GlobEnumeratorBuilder>();
        return configure(builder);
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
