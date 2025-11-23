namespace vm2.DevOps.Glob.Api;

/// <summary>
/// Provides methods for interacting with the actual file system as implemented in .NET.
/// </summary>
public class FileSystem : IFileSystem
{
    /// <summary>
    /// Gets a value indicating whether the current operating system is Windows.
    /// </summary>
    /// <returns>
    /// <see langword="true"/> if the current operating system is Windows.
    /// </returns>
    public bool IsWindows => OperatingSystem.IsWindows();

    /// <summary>
    /// Converts a relative or absolute path into a fully qualified path. The returned path is normalized but is not guaranteed
    /// to exist.
    /// </summary>
    /// <param name="path">The relative or absolute path to convert. Cannot be null or empty.</param>
    /// <returns>The fully qualified path that corresponds to the specified <paramref name="path"/>.</returns>
    public string GetFullPath(string path) => Path.GetFullPath(path);

    /// <summary>
    /// Retrieves the absolute path of the current working directory.
    /// </summary>
    /// <returns>A string representing the full path of the current working directory.</returns>
    public string GetCurrentDirectory() => Directory.GetCurrentDirectory();

    /// <summary>
    /// Determines whether the specified directory exists.
    /// </summary>
    /// <param name="path">The full path of the directory to check. This can be an absolute or relative path.</param>
    /// <returns><see langword="true"/> if the directory exists; otherwise, <see langword="false"/>.</returns>
    public bool DirectoryExists(string path) => Directory.Exists(path);

    /// <summary>
    /// Determines whether the specified file exists.
    /// </summary>
    /// <remarks>This method checks the existence of the file at the specified path. It does not validate whether the caller has
    /// permission to access the file.
    /// </remarks>
    /// <param name="path">The path of the file to check. This can be an absolute or relative path.</param>
    /// <returns><see langword="true"/> if the file exists at the specified path; otherwise, <see langword="false"/>.</returns>
    public bool FileExists(string path) => File.Exists(path);

    string PathWithSlashes(string path) => IsWindows ? path.Replace(WinSepChar, SepChar) : path;

    static string TerminateWithSlash(string path) => path.EndsWith(SepChar) ? path : path+SepChar;

    /// <summary>
    /// Retrieves the names of sub-directories within the specified directory.
    /// </summary>
    /// <param name="path">
    /// The path of the directory to search. This must be a valid, existing directory path.
    /// </param>
    /// <param name="pattern">
    /// The search string to match against the names of directories in path. This parameter can contain a combination of valid
    /// literal path and wildcard (* and ?) characters, but it doesn't support regular expressions.
    /// </param>
    /// <param name="options">
    /// An object that describes the search and enumeration configuration to use.
    /// </param>
    /// <returns>
    /// An enumerable collection of strings, where each string represents the name of a sub-directory within the
    /// specified directory. If the directory contains no subdirectories, the collection will be empty.
    /// </returns>
    public IEnumerable<string> EnumerateDirectories(string path, string pattern, EnumerationOptions options)
    {
        try
        {
            return Directory
                        .EnumerateDirectories(path, pattern, options)
                        .Select(PathWithSlashes)
                        .Select(TerminateWithSlash)
                        ;
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
    /// Retrieves the names of files within the specified directory.
    /// </summary>
    /// <param name="path">The path of the directory to search. This must be a valid, existing directory path.</param>
    /// <returns>
    /// <param name="pattern">
    /// The search string to match against the names of directories in path. This parameter can contain a combination of valid
    /// literal path and wildcard (* and ?) characters, but it doesn't support regular expressions.
    /// </param>
    /// <param name="options">
    /// An object that describes the search and enumeration configuration to use.
    /// </param>
    /// An enumerable collection of strings, where each string represents the name of a file within the
    /// specified directory. If the directory contains no files, the collection will be empty.
    /// </returns>
    public IEnumerable<string> EnumerateFiles(string path, string pattern, EnumerationOptions options)
    {
        try
        {
            return Directory
                        .EnumerateFiles(path, pattern, options)
                        .Select(PathWithSlashes)
                        ;
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
