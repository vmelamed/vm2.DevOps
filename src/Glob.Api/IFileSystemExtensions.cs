// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Val Melamed

namespace vm2.DevOps.Glob.Api;

/// <summary>
/// Provides extension methods for the <see cref="IFileSystem"/> interface.
/// </summary>
[ExcludeFromCodeCoverage]
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
        /// Gets the default string comparer to use for platform-dependent string operations.
        /// </summary>
        public StringComparer Comparer => fs.IsWindows ? StringComparer.OrdinalIgnoreCase : StringComparer.Ordinal;

        /// <summary>
        /// Gets the default string comparison to use for platform-dependent string operations.
        /// </summary>
        public StringComparison Comparison => fs.IsWindows ? StringComparison.OrdinalIgnoreCase : StringComparison.Ordinal;

        /// <summary>
        /// Gets the default Regex options to use for platform-dependent regex operations.
        /// </summary>
        public RegexOptions RegexOptions => fs.IsWindows ? RegexOptions.IgnoreCase : RegexOptions.None;

        /// <summary>
        /// Gets a Regex that matches the root of the file system, e.g. "C:\" for Windows and "/" for Unix-like.
        /// </summary>
        /// <returns></returns>
        public Regex FileSystemRootRegex() => fs.IsWindows ? WindowsFileSystemRootRegex() : UnixFileSystemRootRegex();

        /// <summary>
        /// Gets a <see cref="Regex"/> object for validating pathnames based on the current operating system.
        /// </summary>
        /// <returns>A Regex for path validation.</returns>
        public Regex PathRegex() => fs.IsWindows ? WindowsPathRegex() : UnixPathRegex();

        /// <summary>
        /// Gets a <see cref="Regex"/> object for validating glob patterns based on the current operating system.
        /// </summary>
        /// <returns>A Regex for glob pattern validation.</returns>
        public Regex GlobRegex() => fs.IsWindows ? WindowsGlobRegex() : UnixGlobRegex();

        /// <summary>
        /// Gets a <see cref="Regex"/> object for validating glob patterns based on the current operating system.
        /// </summary>
        /// <returns>A Regex for glob pattern validation.</returns>
        public Regex EnvVarRegex() => fs.IsWindows ? WindowsEnvVarRegex() : UnixEnvVarRegex();
    }

    extension(OperatingSystem os)
    {
        /// <summary>
        /// Gets a Regex that matches the root of the file system, e.g. "C:\" for Windows and "/" for Unix-like.
        /// </summary>
        /// <returns></returns>
        public static Regex FileSystemRootRegex() => OperatingSystem.IsWindows() ? WindowsFileSystemRootRegex() : UnixFileSystemRootRegex();

        /// <summary>
        /// Gets a <see cref="Regex"/> object for validating pathnames based on the current operating system.
        /// </summary>
        /// <returns>A Regex for path validation.</returns>
        public static Regex PathRegex() => OperatingSystem.IsWindows() ? WindowsPathRegex() : UnixPathRegex();

        /// <summary>
        /// Gets a <see cref="Regex"/> object for validating glob patterns based on the current operating system.
        /// </summary>
        /// <returns>A Regex for glob pattern validation.</returns>
        public static Regex GlobRegex() => OperatingSystem.IsWindows() ? WindowsGlobRegex() : UnixGlobRegex();

        /// <summary>
        /// Gets a <see cref="Regex"/> object for validating glob patterns based on the current operating system.
        /// </summary>
        /// <returns>A Regex for glob pattern validation.</returns>
        public static Regex EnvVarRegex() => OperatingSystem.IsWindows() ? WindowsEnvVarRegex() : UnixEnvVarRegex();

        /// <summary>
        /// Gets the default string comparer to use for platform-dependent string operations.
        /// </summary>
        public StringComparer Comparer => OperatingSystem.IsWindows() ? StringComparer.OrdinalIgnoreCase : StringComparer.Ordinal;

        /// <summary>
        /// Gets the default string comparison to use for platform-dependent string operations.
        /// </summary>
        public static StringComparison Comparison => OperatingSystem.IsWindows() ? StringComparison.OrdinalIgnoreCase : StringComparison.Ordinal;

        /// <summary>
        /// Gets the default Regex options to use for platform-dependent regex operations.
        /// </summary>
        public static RegexOptions RegexOptions => OperatingSystem.IsWindows() ? RegexOptions.IgnoreCase : RegexOptions.None;
    }
}
