namespace vm2.DevOps.Glob.Api;

/// <summary>
/// Provides extension methods for the <see cref="IFileSystem"/> interface.
/// </summary>
public static class IFileSystemExtensions
{
    extension(IFileSystem fs)
    {
        /// <summary>
        /// Returns the directory separator character based on the file system's platform.
        /// </summary>
        /// <returns>The directory separator character. Returns <see cref="WinSepChar"/> for Windows platforms and
        /// <see cref="SepChar"/> for non-Windows platforms.</returns>
        public char SepChar => fs.IsWindows ? WinSepChar : GlobConstants.SepChar;

        /// <summary>
        /// Retrieves the set of valid characters for file and directory names based on the file system type.
        /// </summary>
        public string NameCharacter => fs.IsWindows ? WinNameChars : UnixNameChars;

        /// <summary>
        /// A regular expression pattern that matches a sequence of valid file system name characters.
        /// </summary>
        public string NameSequence => fs.NameCharacter+"*";

        /// <summary>
        /// Gets a Regex that matches the root of the file system, e.g. "C:\" for Windows and "/" for Unix-like.
        /// </summary>
        /// <returns></returns>
        public Regex FileSystemRootRegex() => fs.IsWindows ? WindowsFileSystemRootRegex() : UnixFileSystemRootRegex();

        /// <summary>
        /// Gets a <see cref="Regex"/> object for validating pathnames based on the current operating system.
        /// </summary>
        /// <returns>A Regex for path validation.</returns>
        public Regex PathRegex() => fs.IsWindows ? WindowsPathRegex() : UnixPathRgex();

        /// <summary>
        /// Gets a <see cref="Regex"/> object for validating glob patterns based on the current operating system.
        /// </summary>
        /// <returns>A Regex for glob pattern validation.</returns>
        public Regex GlobRegex() => fs.IsWindows ? WindowsGlobRegex() : UnixGlobRgex();

        /// <summary>
        /// Gets a <see cref="Regex"/> object for validating glob patterns based on the current operating system.
        /// </summary>
        /// <returns>A Regex for glob pattern validation.</returns>
        public Regex EnvVarRegex() => fs.IsWindows ? WindowsEnvVarRegex() : UnixEnvVarRegex();
    }
}
