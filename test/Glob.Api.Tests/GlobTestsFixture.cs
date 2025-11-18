namespace vm2.DevOps.Glob.Api.Tests;

using vm2.DevOps.Glob.Api.Tests.FakeFileSystem;

public sealed class GlobTestsFixture : IDisposable
{
    readonly IHost _host;
    readonly IFakeFileSystemCache _fileSystemCache;

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
            .AddSingleton<IFileSystem, FileSystem>()
            .AddTransient<GlobEnumeratorFactory>()
            ;

        _host = builder.Build();
        _fileSystemCache = new FakeFileSystemCache();
    }

    public void Dispose() => _host.Dispose();

    public ITestOutputHelper? Output { get; set; }

    public GlobEnumerator GetGlobEnumerator(
        string fileSystemFile,
        Func<GlobEnumeratorBuilder, GlobEnumeratorBuilder>? configure = null)
    {
        // Get the file system for this test
        var fileSystem = _fileSystemCache.GetFileSystem(fileSystemFile);
        var enumerator = _host
                            .Services
                            .GetRequiredService<GlobEnumeratorFactory>()
                            .Create(fileSystem)
                            ;

        if (configure is null)
            return enumerator;

        return configure(new GlobEnumeratorBuilder()).Configure(enumerator);
    }
}
