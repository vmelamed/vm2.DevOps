namespace vm2.Test.Utilities.FakeFileSystem;

/// <summary>
/// Cache for managing FakeFS instances to avoid reloading file systems for each test.
/// </summary>
public interface IFakeFileSystemCache
{
    /// <summary>
    /// Gets or creates a file system instance for the specified file.
    /// </summary>
    /// <param name="fileName">The file containing the fake file system definition.</param>
    /// <returns>An IFileSystem instance.</returns>
    IFileSystem GetFileSystem(string fileName);
}