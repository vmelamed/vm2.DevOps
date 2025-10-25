namespace vm2.DevOps.Globs;

#pragma warning disable CA1822 // Mark members as static

/// <summary>
/// Provides methods for interacting with the file system, including operations to check for the existence  of
/// folders and files, retrieve folder and file listings, and resolve full paths. Implements the <see cref="IFileSystem"/>.
/// </summary>
/// <remarks>
/// We use the term "folder" instead of "directory" in classes and method names to avoid confusion with the .NET class <see cref="Directory"/>.
/// </remarks>
public class FileSystem : IFileSystem
{
    /// <summary>
    /// Gets a value indicating whether the current operating system is Windows.
    /// </summary>
    /// <returns>
    /// <see langword="true"/> if the current operating system is Windows; otherwise, <see langword="false"/> - it is Unix-like.
    /// </returns>
    public bool IsWindows => OperatingSystem.IsWindows();

    /// <summary>
    /// Converts a relative or absolute path into a fully qualified path. The returned path is normalized and is not guaranteed
    /// to exist.
    /// </summary>
    /// <param name="path">The relative or absolute path to convert. Cannot be null or empty.</param>
    /// <returns>The fully qualified path that corresponds to the specified <paramref name="path"/>.</returns>
    public string GetFullPath(string path) => Path.GetFullPath(path);

    /// <summary>
    /// Determines whether the specified folder exists.
    /// </summary>
    /// <param name="path">The full path of the folder to check. This can be an absolute or relative path.</param>
    /// <returns><see langword="true"/> if the folder exists; otherwise, <see langword="false"/>.</returns>
    public bool FolderExists(string path) => Directory.Exists(path);

    /// <summary>
    /// Determines whether the specified file exists.
    /// </summary>
    /// <remarks>This method checks the existence of the file at the specified path. It does not validate
    /// whether the caller has permission to access the file.</remarks>
    /// <param name="path">The path of the file to check. This can be an absolute or relative path.</param>
    /// <returns><see langword="true"/> if the file exists at the specified path; otherwise, <see langword="false"/>.</returns>
    public bool FileExists(string path) => File.Exists(path);

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
    public IEnumerable<string> EnumerateFolders(string path, string pattern, EnumerationOptions options)
    {
        try
        {
            return Directory.EnumerateDirectories(path, pattern, options);
        }
        catch (Exception x) when (x is
            DirectoryNotFoundException or
            IOException or
            PathTooLongException or
            SecurityException or
            UnauthorizedAccessException)
        {
            return [];
        }
    }

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
    public IEnumerable<string> EnumerateFiles(string path, string pattern, EnumerationOptions options)
    {
        try
        {
            return Directory.EnumerateFiles(path, pattern, options);
        }
        catch (Exception x) when (x is
            DirectoryNotFoundException or
            IOException or
            PathTooLongException or
            SecurityException or
            UnauthorizedAccessException)
        {
            return [];
        }
    }
}
