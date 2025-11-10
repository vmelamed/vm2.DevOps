namespace vm2.DevOps.Glob.Api;

/// <summary>
/// Provides extension methods for the <see cref="IFileSystem"/> interface.
/// </summary>
public static class IFileSystemExtensions
{
    /// <summary>
    /// Returns the directory separator character based on the file system's platform.
    /// </summary>
    /// <param name="fs">The file system instance used to determine the platform.</param>
    /// <returns>The directory separator character. Returns <see cref="WinSepChar"/> for Windows platforms and
    /// <see cref="SepChar"/> for non-Windows platforms.</returns>
    public static char SepChar(this IFileSystem fs) => fs.IsWindows ? WinSepChar : GlobConstants.SepChar;

    /// <summary>
    /// Gets a Regex that matches the root of the file system, e.g. "C:\" for Windows and "/" for Unix-like.
    /// </summary>
    /// <param name="fs"></param>
    /// <returns></returns>
    public static Regex FileSystemRoot(this IFileSystem fs) => fs.IsWindows ? WindowsFileSystemRoot() : UnixFileSystemRoot();

    /// <summary>
    /// Gets a <see cref="Regex"/> object for validating pathnames based on the current operating system.
    /// </summary>
    /// <param name="fs">The file system instance.</param>
    /// <returns>A Regex for path validation.</returns>
    public static Regex Path(this IFileSystem fs) => fs.IsWindows ? WindowsPath() : UnixPath();

    /// <summary>
    /// Gets a <see cref="Regex"/> object for validating glob patterns based on the current operating system.
    /// </summary>
    /// <param name="fs">The file system instance.</param>
    /// <returns>A Regex for glob pattern validation.</returns>
    public static Regex Glob(this IFileSystem fs) => fs.IsWindows ? WindowsGlob() : UnixGlob();

    /// <summary>
    /// Gets a <see cref="Regex"/> object for validating glob patterns based on the current operating system.
    /// </summary>
    /// <param name="fs">The file system instance.</param>
    /// <returns>A Regex for glob pattern validation.</returns>
    public static Regex EnvVar(this IFileSystem fs) => fs.IsWindows ? WindowsEnvVar() : UnixEnvVar();
}
