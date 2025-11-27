// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Val Melamed

// MIT License
//
// Copyright (c) 2025 Val Melamed
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

namespace vm2.DevOps.Glob.Api;

/// <summary>
/// Provides extension methods for registering glob services with dependency injection.
/// </summary>
public static class ServiceCollectionExtensions
{
    /// <summary>
    /// Registers <see cref="GlobEnumerator"/> and default <see cref="FileSystem"/> implementation.
    /// </summary>
    /// <param name="services">The service collection to add services to.</param>
    /// <returns>The service collection for method chaining.</returns>
    public static IServiceCollection AddGlobEnumerator(this IServiceCollection services)
    {
        services.AddSingleton<IFileSystem, FileSystem>();
        services.AddTransient<GlobEnumerator>();
        return services;
    }

    /// <summary>
    /// Registers <see cref="GlobEnumerator"/> with a custom <see cref="IFileSystem"/> implementation.
    /// </summary>
    /// <typeparam name="TFileSystem">The file system implementation type.</typeparam>
    /// <param name="services">The service collection to add services to.</param>
    /// <returns>The service collection for method chaining.</returns>
    public static IServiceCollection AddGlobEnumerator<TFileSystem>(this IServiceCollection services)
        where TFileSystem : class, IFileSystem
    {
        services.AddSingleton<IFileSystem, TFileSystem>();
        services.AddTransient<GlobEnumerator>();
        return services;
    }

    /// <summary>
    /// Registers <see cref="GlobEnumerator"/> with a custom <see cref="IFileSystem"/> instance.
    /// </summary>
    /// <param name="services">The service collection to add services to.</param>
    /// <param name="fileSystem">The file system instance to register.</param>
    /// <returns>The service collection for method chaining.</returns>
    public static IServiceCollection AddGlobEnumerator(this IServiceCollection services, IFileSystem fileSystem)
    {
        services.AddSingleton(fileSystem);
        services.AddTransient<GlobEnumerator>();
        return services;
    }
}