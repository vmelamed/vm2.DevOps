namespace vm2.DevOps.Glob.Api.Tests;

public class GlobUnitTestsFixture : IDisposable
{
    protected readonly IHost _host;
    protected readonly IFakeFileSystemCache _fileSystemCache;

    public GlobUnitTestsFixture()
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
            .AddTransient<GlobEnumerator>()
            .AddTransient<GlobEnumeratorFactory>()
            ;

        _host = builder.Build();
        _fileSystemCache = new FakeFileSystemCache();
    }

    public virtual void Dispose() => _host.Dispose();

    public ITestOutputHelper? Output { get; set; }

    public GlobEnumerator GetGlobEnumerator(
        string fileSystemFile,
        Func<GlobEnumeratorBuilder>? getBuilder = null)
    {
        // Get the file system for this test
        var fileSystem = _fileSystemCache.GetFileSystem(fileSystemFile);
        var enumerator = _host
                            .Services
                            .GetRequiredService<GlobEnumeratorFactory>()
                            .Create(fileSystem)
                            ;

        if (getBuilder is null)
            return enumerator;

        return getBuilder().Configure(enumerator);
    }

    public GlobEnumerator GetGlobEnumerator(
        Func<GlobEnumeratorBuilder>? getBuilder = null)
    {
        // Get the file system for this test
        var enumerator = _host
                            .Services
                            .GetRequiredService<GlobEnumerator>()
                            ;

        if (getBuilder is null)
            return enumerator;

        return getBuilder().Configure(enumerator);
    }
}
