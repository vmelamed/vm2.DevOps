// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Val Melamed

namespace vm2.DevOps.Glob.Api.FakeFileSystem.DI;

/// <summary>
/// Provides extension methods for adding the GlobEnumerator to an IServiceCollection.
/// </summary>
[ExcludeFromCodeCoverage]
public static class GlobEnumeratorExtensions
{
    extension(IServiceCollection serviceCollection)
    {
        /// <summary>
        /// Adds the GlobEnumerator and its dependencies to the service collection.
        /// </summary>
        /// <returns>The service collection for method chaining.</returns>
        public IServiceCollection AddGlobEnumeratorFactory()
            => serviceCollection
                    .AddTransient<IFileSystem, FileSystem>()
                    .AddTransient<GlobEnumeratorFactory>()                      // for the integration tests
                    ;

        /// <summary>
        /// Adds the GlobEnumerator and its dependencies to the service collection. Allows for custom configuration of the
        /// GlobEnumerator via the GlobEnumeratorBuilder.
        /// </summary>
        /// <param name="configure">A function to configure the GlobEnumeratorBuilder.</param>
        /// <returns>IServiceCollection for method chaining.</returns>
        public IServiceCollection AddGlobEnumerator(Func<GlobEnumeratorBuilder, GlobEnumeratorBuilder> configure)
            => serviceCollection
                    .AddTransient<IFileSystem, FakeFS>()
                    .AddTransient<GlobEnumeratorFactory>()                      // for the unit tests
                    .AddTransient<GlobEnumerator>(
                        sp => configure(new GlobEnumeratorBuilder())
                                .Configure(new GlobEnumerator(
                                                sp.GetRequiredService<IFileSystem>(),
                                                sp.GetService<ILogger<GlobEnumerator>>())));
    }

    extension(IServiceProvider serviceProvider)
    {
        public GlobEnumerator GetGlobEnumerator(
            string fakeFSDescriptionFile,
            DataType dataType = DataType.Default)
            => serviceProvider
                    .GetRequiredService<GlobEnumeratorFactory>()
                    .Create(new FakeFS(fakeFSDescriptionFile, dataType));

        public GlobEnumerator GetGlobEnumerator(
            Func<GlobEnumeratorBuilder, GlobEnumeratorBuilder> configure,
            string fakeFSDescriptionFile,
            DataType dataType = DataType.Default)
            => configure(new GlobEnumeratorBuilder())
                .Configure(
                    serviceProvider.GetGlobEnumerator(fakeFSDescriptionFile, dataType));
    }
}
