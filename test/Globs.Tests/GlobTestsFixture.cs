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
                                //.AddProvider(new XunitLoggerProvider())
                                .AddConsole()
                                .SetMinimumLevel(LogLevel.Trace)
                        )
                    .AddSingleton<Func<string, FakeFS>>(file => new FakeFS(file))
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
}
