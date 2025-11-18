namespace vm2.DevOps.Glob.Api.Tests;

public static class GlobDIExtensions
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
                    .AddTransient(
                        sp =>
                        {
                            var ge = new GlobEnumerator(
                                            string.IsNullOrWhiteSpace(fakeFsFile)
                                                ? sp.GetRequiredService<IFileSystem>()
                                                : sp.GetRequiredService<Func<string, IFileSystem>>()(fakeFsFile),
                                            sp.GetRequiredService<ILogger<GlobEnumerator>>()
                                        );
                            if (configure is not null)
                            {
                                var builder = sp.GetRequiredService<GlobEnumeratorBuilder>();
                                return configure(builder).Configure(ge);
                            }

                            return ge;
                        });
    }
}
