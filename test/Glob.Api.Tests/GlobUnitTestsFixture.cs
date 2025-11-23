namespace vm2.DevOps.Glob.Api.Tests;

[ExcludeFromCodeCoverage]
public class GlobUnitTestsFixture : IDisposable
{
    readonly IFakeFileSystemCache _fileSystemCache;

    public IHost TestHost { get; private set; }

    public GlobUnitTestsFixture()
    {
        var configuration = new ConfigurationBuilder()
                                    .AddJsonFile("appsettings.json", optional: true)
                                    .AddJsonFile("appsettings.Development.json", optional: true)
                                    .AddJsonFile($"appsettings.{Environment.GetEnvironmentVariable("USERPROFILE")}.json", optional: true)
                                    .AddEnvironmentVariables()
                                    .Build()
                                    ;

        var builder = Host.CreateApplicationBuilder();

        builder
            .Logging
            .ClearProviders()
            .AddConsole()
            .SetMinimumLevel(LogLevel.Trace)
            ;

        builder
            .Services
            .AddSingleton<IConfiguration>(configuration)
            .AddSingleton<IFileSystem, FileSystem>()
            .AddTransient<GlobEnumerator>()
            .AddTransient<GlobEnumeratorFactory>()
            ;

        TestHost = builder.Build();
        _fileSystemCache = new FakeFileSystemCache();
    }

    public virtual void Dispose()
    {
        TestHost.Dispose();
        GC.SuppressFinalize(this);
    }

    public ITestOutputHelper? Output { get; set; }

    public GlobEnumerator GetGlobEnumerator(
        string fileSystemFile,
        Func<GlobEnumeratorBuilder>? getBuilder = null)
    {
        // Get the file system for this test
        var fileSystem = _fileSystemCache.GetFileSystem(fileSystemFile);
        var enumerator = TestHost
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
        var enumerator = TestHost
                            .Services
                            .GetRequiredService<GlobEnumerator>()
                            ;

        if (getBuilder is null)
            return enumerator;

        return getBuilder().Configure(enumerator);
    }
}
