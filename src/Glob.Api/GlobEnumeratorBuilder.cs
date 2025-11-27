// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Val Melamed

namespace vm2.DevOps.Glob.Api;

/// <summary>
/// Provides a builder for configuring and creating glob enumerators to search for files and directories using glob
/// patterns.
/// </summary>
public class GlobEnumeratorBuilder
{
    #region fields
    string _glob             = "*";
    string _fromDirectory    = ".";
    MatchCasing _matchCasing = MatchCasing.PlatformDefault;
    Objects _enumerated      = Objects.Files;
    bool _distinct;
    bool _depthFirst;
    #endregion

    /// <summary>
    /// Configures the ge to use the specified glob expression for matching file or directory names. The pattern may
    /// include wildcards such as:
    /// <list type="bullet">
    /// <item>'*' - matches any character sequence of arbitrary length</item>
    /// <item>'?' - matches any single character</item>
    /// <item>'**' - matches any sub-directory and its contents recursively</item>
    /// <item>'[...]' - matches any single character from the specified inside set of characters. Valid content of the set:
    ///     <list type="bullet">
    ///     <item>[abcdef] - represents a single character from the set inside the brackets</item>
    ///     <item>[!...] - any character that is <b>not</b> in the set inside the brackets</item>
    ///     <item>[]...] - a closing bracket as a character from the set, can be specified if it is the first character after
    ///                 the opening bracket or after the negation mark.</item>
    ///     <item>[0-9] - ranges of characters</item>
    ///     <item>[[:alpha:]] - character classes, like alpha, digit, blank, cntrl, etc. </item>
    ///     </list>
    /// </item>
    /// </list>
    /// To "escape" any of the special glob expression characters, use brackets: [*], [?], [[], [!].<para/>
    /// For full descrption of the globs syntax please see <see href="https://www.man7.org/linux/man-pages/man7/glob.7.html">
    /// this Linux glob man-page</see>.
    /// </summary>
    /// <param name="glob">The glob pattern to use for matching files or directories.</param>
    /// <returns>
    /// The updated GlobEnumeratorBuilder instance for method chaining.
    /// </returns>
    public GlobEnumeratorBuilder WithGlob(string glob)
    {
        _glob = glob;
        return this;
    }

    /// <summary>
    /// Configures the ge to start searching from the specified directory.
    /// </summary>
    /// <param name="startDirectory">The directory from which to start the search.</param>
    /// <returns>
    /// The updated GlobEnumeratorBuilder instance for method chaining.
    /// </returns>
    public GlobEnumeratorBuilder FromDirectory(string startDirectory)
    {
        _fromDirectory = startDirectory;
        return this;
    }

    /// <summary>
    /// Configures the builder to perform pattern matching with the specified case sensitivity when enumerating file system.
    /// </summary>
    /// <param name="sensitivity">The desired case sensitivity for pattern matching.</param>
    /// <remarks>
    /// Use this method when you want glob patterns to distinguish between uppercase and lowercase characters during matching.
    /// By default, matching is platform-specific: case-insensitive - on Windows, and case-sensitive - on Unix-like systems.
    /// </remarks>
    /// <returns>The current <see cref="GlobEnumeratorBuilder"/> instance with case-sensitive matching enabled.</returns>
    public GlobEnumeratorBuilder WithCaseSensitivity(MatchCasing sensitivity)
    {
        _matchCasing = sensitivity;
        return this;
    }

    /// <summary>
    /// Configures the builder to perform case-sensitive pattern matching when enumerating file system entries.
    /// </summary>
    /// <remarks>
    /// Use this method when you want glob patterns to distinguish between uppercase and lowercase characters during matching.
    /// By default, matching is platform-specific: case-insensitive - on Windows, and case-sensitive - on Unix-like systems.
    /// </remarks>
    /// <returns>The current <see cref="GlobEnumeratorBuilder"/> instance with case-sensitive matching enabled.</returns>
    public GlobEnumeratorBuilder CaseSensitive()
    {
        _matchCasing = MatchCasing.CaseSensitive;
        return this;
    }

    /// <summary>
    /// Configures the builder to perform case-insensitive pattern matching when enumerating file system entries.
    /// </summary>
    /// <remarks>
    /// Use this method when you want glob patterns to distinguish between uppercase and lowercase characters during matching.
    /// By default, matching is platform-specific: case-insensitive - on Windows, and case-sensitive - on Unix-like systems.
    /// </remarks>
    /// <returns>The current <see cref="GlobEnumeratorBuilder"/> instance with case-sensitive matching enabled.</returns>
    public GlobEnumeratorBuilder CaseInsensitive()
    {
        _matchCasing = MatchCasing.CaseInsensitive;
        return this;
    }

    /// <summary>
    /// Configures the builder to apply the case sensitivity that is the default for the platform when enumerating file system
    /// entries.
    /// </summary>
    /// <remarks>
    /// Use this method when you want glob patterns to distinguish between uppercase and lowercase characters during matching.
    /// By default, matching is platform-specific: case-insensitive - on Windows, and case-sensitive - on Unix-like systems.
    /// </remarks>
    /// <returns>The current <see cref="GlobEnumeratorBuilder"/> instance with case-sensitive matching enabled.</returns>
    public GlobEnumeratorBuilder PlatformSensitive()
    {
        _matchCasing = MatchCasing.PlatformDefault;
        return this;
    }

    /// <summary>
    /// Specifies the types of file system objects to be enumerated by the <see cref="GlobEnumerator"/>.
    /// </summary>
    /// <returns>The current <see cref="GlobEnumeratorBuilder"/> instance with the specified objects set.</returns>
    public GlobEnumeratorBuilder SelectObjects(Objects objects)
    {
        _enumerated = objects;
        return this;
    }

    /// <summary>
    /// Specifies that only directories should be enumerated by the <see cref="GlobEnumerator"/>.
    /// </summary>
    /// <returns>The current <see cref="GlobEnumeratorBuilder"/> instance with the specified objects set.</returns>
    /// <remarks>
    /// Note that the path components of the returned directories are separated by "/" and will include a terminating "/".
    /// </remarks>
    public GlobEnumeratorBuilder SelectDirectories()
    {
        _enumerated = Objects.Directories;
        return this;
    }

    /// <summary>
    /// Specifies that only files should be enumerated by the <see cref="GlobEnumerator"/>.
    /// </summary>
    /// <returns>The current <see cref="GlobEnumeratorBuilder"/> instance with the specified objects set.</returns>
    /// <remarks>
    /// Note that the path components of the returned files are separated by "/".
    /// </remarks>
    public GlobEnumeratorBuilder SelectFiles()
    {
        _enumerated = Objects.Files;
        return this;
    }

    /// <summary>
    /// Specifies the types of file system objects to include in the enumeration.
    /// </summary>
    /// <param name="typeOfFileSystemObjects">
    /// An <see cref="Objects"/> value that determines which file system object types will be selected for enumeration.
    /// This parameter controls whether files, directories, or other supported object types are included.
    /// </param>
    /// <returns>The current <see cref="GlobEnumeratorBuilder"/> instance with the selection criteria applied. This enables
    /// method chaining for further configuration.
    /// </returns>
    public GlobEnumeratorBuilder Select(Objects typeOfFileSystemObjects)
    {
        _enumerated = typeOfFileSystemObjects;
        return this;
    }

    /// <summary>
    /// Specifies that only directories should be enumerated by the <see cref="GlobEnumerator"/>.
    /// </summary>
    /// <returns>The current <see cref="GlobEnumeratorBuilder"/> instance with the specified objects set.</returns>
    /// <remarks>
    /// Note that the path components of the returned files and directories are separated by "/" and that the the paths of the
    /// directories will include a terminating "/".
    /// </remarks>
    public GlobEnumeratorBuilder SelectDirectoriesAndFiles()
    {
        _enumerated = Objects.FilesAndDirectories;
        return this;
    }

    /// <summary>
    /// Configures the enumerator to traverse directories using a depth-first search strategy.
    /// </summary>
    /// <remarks>
    /// Use this method when you want directory enumeration to process all files and subdirectories within a directory before
    /// moving to sibling directories. This can be useful for scenarios where processing order matters, such as when working
    /// with too deeply nested directory structures or too wide directory trees. The default is breadth-first traversal.
    /// </remarks>
    /// <returns>The current <see cref="GlobEnumeratorBuilder"/> instance with depth-first traversal enabled.</returns>
    public GlobEnumeratorBuilder DepthFirst()
    {
        _depthFirst = true;
        return this;
    }

    /// <summary>
    /// Configures the enumerator to traverse directories using a breadth-first search strategy.
    /// </summary>
    /// <remarks>
    /// Use this method when you want directory enumeration to process all files and subdirectories within a directory before
    /// moving to sibling directories. This can be useful for scenarios where processing order matters, such as when working
    /// with too wide directory trees or too deeply nested directory structures. The default is breadth-first traversal.
    /// </remarks>
    /// <returns>The current <see cref="GlobEnumeratorBuilder"/> instance with breadth-first traversal enabled.</returns>
    public GlobEnumeratorBuilder BreadthFirst()
    {
        _depthFirst = false;
        return this;
    }

    /// <summary>
    /// Configures the traversal order for glob enumeration to use either depth-first or breadth-first search.
    /// </summary>
    /// <remarks>Use this method to control how file system entries are visited during glob enumeration.
    /// Depth-first traversal explores directory trees before visiting sibling directories, while breadth-first
    /// traversal visits all entries at the current level before descending.
    /// </remarks>
    /// <param name="depthFirst">
    /// Specifies the traversal order. Set to <see langword="true"/> to use depth-first search; otherwise, breadth-first search
    /// is used.
    /// </param>
    /// <returns>The current <see cref="GlobEnumeratorBuilder"/> instance with the updated traversal order setting.</returns>
    public GlobEnumeratorBuilder TraverseDepthFirst(bool depthFirst)
    {
        _depthFirst = depthFirst;
        return this;
    }

    /// <summary>
    /// Enables or disables filtering of duplicate results in the glob enumeration.
    /// </summary>
    /// <returns>The current <see cref="GlobEnumeratorBuilder"/> instance to allow method chaining.</returns>
    /// <remarks>
    /// Some globs that include two or more of the sub-directories wildcard '**' may return duplicate path strings, by default.
    /// Invoke this method to request distinct results, which of course, come at a price payed in memory and performance.
    /// </remarks>
    public GlobEnumeratorBuilder Distinct()
    {
        _distinct = true;
        return this;
    }

    /// <summary>
    /// Enables or disables filtering of duplicate results in the glob enumeration.
    /// </summary>
    /// <param name="distinctResults"></param>
    /// <returns>The current <see cref="GlobEnumeratorBuilder"/> instance to allow method chaining.</returns>
    public GlobEnumeratorBuilder WithDistinct(bool distinctResults)
    {
        _distinct = distinctResults;
        return this;
    }

    /// <summary>
    /// Builds and returns the configured <see cref="GlobEnumeratorBuilder"/> instance.
    /// </summary>
    /// <returns>This builder</returns>
    public GlobEnumeratorBuilder Build() => this;

    /// <summary>
    /// Creates and returns a new instance of <see cref="GlobEnumerator"/> for enumerating file system entries that
    /// match the configured glob pattern.
    /// </summary>
    /// <returns>A <see cref="GlobEnumerator"/> that can be used to iterate over matching file system entries.</returns>
    public GlobEnumerator Configure(GlobEnumerator ge)
    {
        ge.FromDirectory   = _fromDirectory;
        ge.Enumerated      = _enumerated;
        ge.MatchCasing     = _matchCasing;
        ge.Distinct = _distinct;
        ge.DepthFirst      = _depthFirst;
        ge.Glob            = _glob;

        return ge;
    }
}
