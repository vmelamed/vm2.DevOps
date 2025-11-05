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
    /// <returns>The directory separator character. Returns <see cref="GlobEnumerator.WinSepChar"/> for Windows platforms and
    /// <see cref="GlobEnumerator.SepChar"/> for non-Windows platforms.</returns>
    public static char SepChar(this IFileSystem fs) => fs.IsWindows ? GlobEnumerator.WinSepChar : GlobEnumerator.SepChar;

    /// <summary>
    /// Gets a <see cref="Regex"/> object for validating pathnames based on the current operating system.
    /// </summary>
    /// <param name="fs">The file system instance.</param>
    /// <returns>A Regex for path validation.</returns>
    public static Regex Path(this IFileSystem fs) => fs.IsWindows ? GlobConstants.WindowsPath() : GlobConstants.UnixPath();

    /// <summary>
    /// Gets a <see cref="Regex"/> object for validating glob patterns based on the current operating system.
    /// </summary>
    /// <param name="fs">The file system instance.</param>
    /// <returns>A Regex for glob pattern validation.</returns>
    public static Regex Glob(this IFileSystem fs) => fs.IsWindows ? GlobConstants.WindowsGlob() : GlobConstants.UnixGlob();

    /// <summary>
    /// Gets a <see cref="Regex"/> object for validating glob patterns based on the current operating system.
    /// </summary>
    /// <param name="fs">The file system instance.</param>
    /// <returns>A Regex for glob pattern validation.</returns>
    public static Regex EnvVar(this IFileSystem fs) => fs.IsWindows ? GlobConstants.WindowsEnvVar() : GlobConstants.UnixEnvVar();
}
