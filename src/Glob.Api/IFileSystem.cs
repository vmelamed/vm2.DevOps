namespace vm2.DevOps.Glob.Api;

/// <summary>
/// Represents a file system abstraction used by the glob pattern searching.
/// </summary>
public interface IFileSystem
{
    /// <summary>
    /// Gets a value indicating whether the current operating system is Windows.
    /// </summary>
    /// <returns>
    /// <see langword="true"/> if the current operating system is Windows.
    /// </returns>
    bool IsWindows => OperatingSystem.IsWindows();

    /// <summary>
    /// Converts a relative or absolute path into a fully qualified path. The returned path is normalized but is not guaranteed
    /// to exist.
    /// </summary>
    /// <param name="path">The relative or absolute path to convert. Cannot be null or empty.</param>
    /// <returns>The fully qualified path that corresponds to the specified <paramref name="path"/>.</returns>
    string GetFullPath(string path);

    /// <summary>
    /// Retrieves the absolute path of the current working directory.
    /// </summary>
    /// <returns>A string representing the full path of the current working directory.</returns>
    string GetCurrentDirectory();

    /// <summary>
    /// Determines whether the specified directory exists.
    /// </summary>
    /// <param name="path">The full path of the directory to check. This can be an absolute or relative path.</param>
    /// <returns><see langword="true"/> if the directory exists; otherwise, <see langword="false"/>.</returns>
    bool DirectoryExists(string path);

    /// <summary>
    /// Determines whether the specified file exists at the given path.
    /// </summary>
    /// <param name="path">The full path of the file to check. This can be an absolute or relative path.</param>
    /// <returns><see langword="true"/> if the file exists at the specified path; otherwise, <see langword="false"/>.</returns>
    bool FileExists(string path);

    /// <summary>
    /// Retrieves the full paths of the subdirectories within the specified directory. The path components must be separated by slash
    /// characters '/' and <b>must be</b> terminated by a slash character '/'.
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
    /// See also <seealso href="https://learn.microsoft.com/en-us/dotnet/api/system.io.enumerationoptions?view=net-10.0">the .NET documentation.</seealso>
    /// </param>
    /// <returns>
    /// An enumerable collection of strings, where each string represents the name of a subdirectory within the specified directory.
    /// If the directory contains no subdirectories, the collection will be empty.
    /// </returns>
    IEnumerable<string> EnumerateDirectories(string path, string pattern, EnumerationOptions options);

    /// <summary>
    /// Retrieves the full paths of files within the specified directory. The path components must be separated by slash
    /// characters '/', but <b>should not</b> be terminated by '/'.
    /// </summary>
    /// <param name="path">The path of the directory to search. This must be a valid, existing directory path.</param>
    /// <param name="pattern">
    /// The search string to match against the names of directories in path. This parameter can contain a combination of valid
    /// literal path and wildcard (* and ?) characters, but it doesn't support regular expressions.
    /// </param>
    /// <param name="options">
    /// An object that describes the search and enumeration configuration to use.
    /// </param>
    /// <returns>
    /// An enumerable collection of strings, where each string represents the name of a file from the specified directory. If the
    /// directory contains no files, the collection will be empty.
    /// </returns>
    IEnumerable<string> EnumerateFiles(string path, string pattern, EnumerationOptions options);
}
