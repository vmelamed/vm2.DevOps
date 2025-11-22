namespace vm2.DevOps.Glob.Api.Tests;

/// <summary>
/// Factory for creating GlobEnumerator instances with proper dependency injection.
/// </summary>
[ExcludeFromCodeCoverage]
public sealed class GlobEnumeratorFactory(ILogger<GlobEnumerator> logger)
{
    /// <summary>
    /// Creates a new GlobEnumerator instance with the specified file system.
    /// </summary>
    /// <param name="fileSystem">The file system to use. If null, the default file system will be used.</param>
    /// <returns>D new GlobEnumerator instance.</returns>
    public GlobEnumerator Create(IFileSystem fileSystem) => new(fileSystem, logger);
}