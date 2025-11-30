// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Val Melamed

namespace vm2.DevOps.Glob.Api;

/// <summary>
/// Provides a builder for configuring and creating glob enumerators to search for files and directories using glob
/// patterns.
/// </summary>
[ExcludeFromCodeCoverage]
public class GlobEnumeratorBuilder
{
    #region fields
    string _glob                              = "*";
    string _fromDirectory                     = ".";
    MatchCasing _matchCasing                  = MatchCasing.PlatformDefault;
    Objects _enumerated                       = Objects.Files;
    bool _distinct                            = false;
    bool _depthFirst                          = false;
    bool _returnSpecialDirectories            = false;
    bool _ignoreInaccessible                  = true;
    FileAttributes _skipObjectsWithAttributes = FileAttributes.Hidden | FileAttributes.System;
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
    /// For full description of the globs syntax please see <see href="https://www.man7.org/linux/man-pages/man7/glob.7.html">
    /// this Linux glob man-page</see>.
    /// <para>
    /// If the method is not invoked the default glob is <c>"*"</c>
    /// </para>
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
    /// Configures the <see cref="GlobEnumerator"/>-s to start searching from the specified directory. The default is the
    /// current directory <c>"."</c>
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
    /// Configures the builder to perform pattern matching with the specified case sensitivity when enumerating file system
    /// objects.
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
    /// Specifies that only files should be enumerated by the <see cref="GlobEnumerator"/> (the default).
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
    /// Specifies that only directories should be enumerated by the <see cref="GlobEnumerator"/> (the default is to enumerate
    /// files only).
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
    /// Specifies that files and directories should be enumerated by the <see cref="GlobEnumerator"/> (the default is to
    /// enumerate files only).
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
    /// Specifies the types of file system objects to include in the enumeration. The default is to enumerate files only.
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
    /// Configures the enumerator to traverse directories using a depth-first or breadth-first search strategy (the default is
    /// breadth-first).
    /// </summary>
    /// <remarks>
    /// Use this method to control how file system entries are visited during glob enumeration. Depth-first traversal explores
    /// the current directory sub-trees before visiting the sibling directories, while breadth-first traversal visits all
    /// entries at the current level before descending into their children. Traverse depth-first is useful when the expectation
    /// is to find files located deep within directory structures.
    /// </remarks>
    /// <param name="depthFirst">
    /// Specifies the traversal order. Set to <see langword="true"/> to use depth-first search; otherwise, breadth-first search
    /// is used.
    /// </param>
    /// <returns>The current <see cref="GlobEnumeratorBuilder"/> instance with the updated traversal order setting.</returns>
    public GlobEnumeratorBuilder TraverseDepthFirst(TraverseOrder depthFirst)
    {
        _depthFirst = depthFirst == TraverseOrder.DepthFirst;
        return this;
    }

    /// <summary>
    /// Configures the enumerator to traverse directories using a depth-first search strategy (the default is breadth-first).
    /// </summary>
    /// <returns>The current <see cref="GlobEnumeratorBuilder"/> instance to allow method chaining.</returns>
    /// <remarks>
    /// Use this method to control how file system entries are visited during glob enumeration. Depth-first traversal explores
    /// the current directory sub-trees before visiting the sibling directories, while breadth-first traversal visits all
    /// entries at the current level before descending into their children. Traverse depth-first is useful when the expectation
    /// is to find files located deep within directory structures.
    /// </remarks>
    /// <returns>The current <see cref="GlobEnumeratorBuilder"/> instance with depth-first traversal enabled.</returns>
    public GlobEnumeratorBuilder DepthFirst()
    {
        _depthFirst = true;
        return this;
    }

    /// <summary>
    /// Configures the enumerator to traverse directories using a breadth-first search strategy (the default).
    /// </summary>
    /// <remarks>
    /// Use this method to control how file system entries are visited during glob enumeration. Depth-first traversal explores
    /// the current directory sub-trees before visiting the sibling directories, while breadth-first traversal visits all
    /// entries at the current level before descending into their children. Traverse breadth-first is useful when the expectation
    /// is to find files located near the root of the directory structure.
    /// </remarks>
    /// <returns>The current <see cref="GlobEnumeratorBuilder"/> instance with breadth-first traversal enabled.</returns>
    public GlobEnumeratorBuilder BreadthFirst()
    {
        _depthFirst = false;
        return this;
    }

    /// <summary>
    /// Enables filtering of duplicate results in the glob enumeration.
    /// </summary>
    /// <returns>The current <see cref="GlobEnumeratorBuilder"/> instance to allow method chaining.</returns>
    /// <remarks>
    /// Some globs that include two or more of the sub-directories wildcard '**' may return duplicate path strings, by default.
    /// Invoke this method to request distinct results, which of course, come at a price paid in memory and performance.
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
    /// <remarks>
    /// Some globs that include two or more of the sub-directories wildcard '**' may return duplicate path strings, by default.
    /// Invoke this method to request distinct results, which of course, come at a price paid in memory and performance.
    /// </remarks>
    public GlobEnumeratorBuilder WithDistinct(bool distinctResults)
    {
        _distinct = distinctResults;
        return this;
    }

    /// <summary>
    /// Indicates whether to return the special directory entries "." and "..". By default, they are not included.
    /// </summary>
    public GlobEnumeratorBuilder WithSpecialDirectories()
    {
        _returnSpecialDirectories = true;
        return this;
    }

    /// <summary>
    /// Indicates whether to skip files or directories for which the access by the current user is denied (i.e. when
    /// access attempts to them would result in <see cref="UnauthorizedAccessException"/> or <see cref="SecurityException"/>).
    /// By default, such files and directories are skipped.
    /// </summary>
    public GlobEnumeratorBuilder WithInaccessible()
    {
        _ignoreInaccessible = false;
        return this;
    }

    /// <summary>
    /// Indicates whether to skip files or directories with the specified attributes.
    /// Default: <c><see cref="FileAttributes.Hidden"/> | <see cref="FileAttributes.System"/></c>
    /// </summary>
    public GlobEnumeratorBuilder SkipObjectsWithAttributes(FileAttributes attributes)
    {
        _skipObjectsWithAttributes = attributes;
        return this;
    }

    /// <summary>
    /// Builds and returns the configured <see cref="GlobEnumeratorBuilder"/> instance.
    /// </summary>
    /// <returns>This builder</returns>
    public GlobEnumeratorBuilder Build() => this;

    /// <summary>
    /// Creates and configures a new instance of the GlobEnumerator class.
    /// </summary>
    /// <returns>
    /// A <see cref="GlobEnumerator"/> instance that has been configured according to the settings in this instance.
    /// </returns>
    public GlobEnumerator Create() => Configure(new GlobEnumerator());

    /// <summary>
    /// Configures and returns the passed instance of <see cref="GlobEnumerator"/> for enumerating file system entries that
    /// match the glob pattern.
    /// </summary>
    /// <returns>A <see cref="GlobEnumerator"/> that can be used to iterate over matching file system entries.</returns>
    public GlobEnumerator Configure(GlobEnumerator ge)
    {
        ge.FromDirectory            = _fromDirectory;
        ge.Enumerated               = _enumerated;
        ge.MatchCasing              = _matchCasing;
        ge.Distinct                 = _distinct;
        ge.DepthFirst               = _depthFirst;
        ge.Glob                     = _glob;
        ge.ReturnSpecialDirectories = _returnSpecialDirectories;
        ge.IgnoreInaccessible       = _ignoreInaccessible;
        ge.AttributesToSkip         = _skipObjectsWithAttributes;

        return ge;
    }
}
