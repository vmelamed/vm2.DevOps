namespace vm2.DevOps.Glob.Api;

/// <summary>
/// Represents a file system abstraction used by the glob pattern searching.
/// </summary>
/// <remarks>
/// We use the term "folder" instead of "directory" in method names to avoid confusion with the .NET class <see cref="Directory"/>.
/// </remarks>
public interface IFileSystem
{
    /// <summary>
    /// Gets a value indicating whether the current operating system is Windows.
    /// </summary>
    /// <returns>
    /// <see langword="true"/> if the current operating system is Windows; otherwise, <see langword="false"/> - it is Unix-like.
    /// </returns>
    bool IsWindows => OperatingSystem.IsWindows();

    /// <summary>
    /// Converts a relative or absolute path into a fully qualified path. The returned path is normalized and is not guaranteed
    /// to exist.
    /// </summary>
    /// <param name="path">The relative or absolute path to convert. Cannot be null or empty.</param>
    /// <returns>The fully qualified path that corresponds to the specified <paramref name="path"/>.</returns>
    string GetFullPath(string path);

    /// <summary>
    /// Determines whether the specified folder exists.
    /// </summary>
    /// <param name="path">The full path of the folder to check. This can be an absolute or relative path.</param>
    /// <returns><see langword="true"/> if the folder exists; otherwise, <see langword="false"/>.</returns>
    bool FolderExists(string path);

    /// <summary>
    /// Determines whether the specified file exists at the given path.
    /// </summary>
    /// <param name="path">The full path of the file to check. This can be an absolute or relative path.</param>
    /// <returns><see langword="true"/> if the file exists at the specified path; otherwise, <see langword="false"/>.</returns>
    bool FileExists(string path);

    /// <summary>
    /// Retrieves the names of subfolders within the specified folder.
    /// </summary>
    /// <param name="path">
    /// The path of the folder to search. This must be a valid, existing folder path.
    /// </param>
    /// <param name="pattern">
    /// The search string to match against the names of folders in path. This parameter can contain a combination of valid
    /// literal path and wildcard (* and ?) characters, but it doesn't support regular expressions.
    /// </param>
    /// <param name="options">
    /// An object that describes the search and enumeration configuration to use.
    /// </param>
    /// <returns>
    /// An enumerable collection of strings, where each string represents the name of a subfolder within the
    /// specified folder. If the folder contains no subfolders, the collection will be empty.
    /// </returns>
    IEnumerable<string> EnumerateFolders(string path, string pattern, EnumerationOptions options);

    /// <summary>
    /// Retrieves the names of files within the specified folder.
    /// </summary>
    /// <param name="path">The path of the folder to search. This must be a valid, existing folder path.</param>
    /// <returns>
    /// <param name="pattern">
    /// The search string to match against the names of folders in path. This parameter can contain a combination of valid
    /// literal path and wildcard (* and ?) characters, but it doesn't support regular expressions.
    /// </param>
    /// <param name="options">
    /// An object that describes the search and enumeration configuration to use.
    /// </param>
    /// An enumerable collection of strings, where each string represents the name of a file within the
    /// specified folder. If the folder contains no files, the collection will be empty.
    /// </returns>
    IEnumerable<string> EnumerateFiles(string path, string pattern, EnumerationOptions options);
}
