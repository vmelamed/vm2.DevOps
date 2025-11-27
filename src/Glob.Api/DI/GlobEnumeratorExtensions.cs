// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Val Melamed

namespace vm2.DevOps.Glob.Api.DI;

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
                    .AddTransient<GlobEnumerator>()
                    ;

        /// <summary>
        /// Adds the GlobEnumerator and its dependencies to the service collection. Allows for custom configuration of the
        /// GlobEnumerator via the GlobEnumeratorBuilder.
        /// </summary>
        /// <param name="configure">A function to configure the GlobEnumeratorBuilder.</param>
        /// <returns>IServiceCollection for method chaining.</returns>
        public IServiceCollection AddGlobEnumerator(Func<GlobEnumeratorBuilder, GlobEnumeratorBuilder> configure)
            => serviceCollection
                    .AddSingleton<IFileSystem, FileSystem>()
                    .AddTransient(
                        sp => configure(new GlobEnumeratorBuilder())
                                .Configure(new GlobEnumerator(
                                                sp.GetRequiredService<IFileSystem>(),
                                                sp.GetService<ILogger<GlobEnumerator>>())));
    }

    extension(IServiceProvider sp)
    {
        /// <summary>
        /// Gets a GlobEnumerator instance configured via the provided configure function. Use when the GlobEnumerator is
        /// registered without configuration or with default configuration.
        /// </summary>
        /// <param name="configure"></param>
        /// <returns></returns>
        public GlobEnumerator GetGlobEnumerator(
            Func<GlobEnumeratorBuilder, GlobEnumeratorBuilder> configure)
            => configure(new GlobEnumeratorBuilder())
                .Configure(new GlobEnumerator(
                                    sp.GetRequiredService<IFileSystem>(),
                                    sp.GetService<ILogger<GlobEnumerator>>()));
    }
}
