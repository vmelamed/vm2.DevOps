namespace vm2.DevOps.Glob.Api.Tests;

public static class GlobEnumeratorTestExtensions
{
    extension(IServiceCollection serviceCollection)
    {
        public IServiceCollection AddGlobEnumerator(
            string fakeFsFile = "",
            Func<GlobEnumeratorBuilder, GlobEnumeratorBuilder>? configure = null)
            => serviceCollection
                    .AddSingleton<IFileSystem, FileSystem>()
                    .AddSingleton<Func<string, IFileSystem>>(GlobTestsFixture.CreateFileSystem)
                    .AddTransient<GlobEnumeratorBuilder>()
                    .AddKeyedTransient(
                        fakeFsFile,
                        (sp, key) =>
                        {
                            var ge = new GlobEnumerator(
                                            string.IsNullOrWhiteSpace(fakeFsFile)
                                                ? sp.GetRequiredService<IFileSystem>()
                                                : sp.GetRequiredService<Func<string, IFileSystem>>()(fakeFsFile),
                                            sp.GetRequiredService<ILogger<GlobEnumerator>>()
                                        );
                            return configure is not null
                                        ? configure(sp.GetRequiredService<GlobEnumeratorBuilder>()).Configure(ge)
                                        : ge;
                        });
    }
}
