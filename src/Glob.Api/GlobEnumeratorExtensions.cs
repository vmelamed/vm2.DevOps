namespace vm2.DevOps.Glob.Api;

/// <summary>
/// Provides extension methods for adding the GlobEnumerator to an IServiceCollection.
/// </summary>
public static class GlobEnumeratorExtensions
{
    extension(IServiceCollection serviceCollection)
    {
        /// <summary>
        /// Adds the GlobEnumerator and its dependencies to the service collection.
        /// </summary>
        /// <returns>The service collection for method chaining.</returns>
        public IServiceCollection AddGlobEnumerator()
            => serviceCollection
                    .AddSingleton<IFileSystem, FileSystem>()
                    .AddTransient(
                        sp => new GlobEnumerator(
                                    sp.GetRequiredService<IFileSystem>(),
                                    sp.GetRequiredService<ILogger<GlobEnumerator>>()))
                    ;

        /// <summary>
        /// Adds the GlobEnumerator and its dependencies to the service collection.
        /// </summary>
        /// <returns>IServiceCollection for method chaining.</returns>
        public IServiceCollection AddGlobEnumerator(Func<GlobEnumeratorBuilder, GlobEnumeratorBuilder> configure)
            => serviceCollection
                    .AddSingleton<IFileSystem, FileSystem>()
                    .AddTransient<GlobEnumeratorBuilder>()
                    .AddTransient(
                        sp => configure(new GlobEnumeratorBuilder())
                                .Configure(new GlobEnumerator(
                                                    sp.GetRequiredService<IFileSystem>(),
                                                    sp.GetRequiredService<ILogger<GlobEnumerator>>())))
                    ;
    }
}
