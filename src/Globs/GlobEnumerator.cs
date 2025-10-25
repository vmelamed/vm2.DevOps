namespace vm2.DevOps.Globs;

/// <summary>
/// Represents a glob pattern searcher.
/// </summary>
public sealed partial class GlobEnumerator
{
    /// <summary>
    /// Represents the character used to separate the drive letter from the path in file system paths.
    /// </summary>
    /// <remarks>Typically used in Windows.</remarks>
    public const char DriveSep = ':';

    /// <summary>
    /// Represents the more popular character used to separate the folders or directories in a path for Windows.
    /// </summary>
    public const char WinSepChar = '\\';    // always converted to '/' - Windows takes both '/' and '\'

    /// <summary>
    /// Represents the character used to separate the folders or directories in a path for both Unix and Windows.
    /// </summary>
    public const char SepChar = '/';

    /// <summary>
    /// Represents the path of the current working directory as a path segment.
    /// </summary>
    public const string CurrentDir = ".";

    /// <summary>
    /// Represents the path of the parent directory of the current working directory as a path segment.
    /// </summary>
    public const string ParentDir = "..";

    /// <summary>
    /// Represents a recursive wildcard pattern that matches all levels of a directory hierarchy from "here" - down.
    /// </summary>
    public const string RecursiveWc = "**";

    /// <summary>
    /// Represents a wildcard for any sequence of characters in a path.
    /// </summary>
    public const string SequenceWc  = "*";

    /// <summary>
    /// Represents a wildcard for any single character in a path.
    /// </summary>
    public const string CharacterWc = "?";

    /// <summary>
    /// Gets a regex that matches if a pattern starts from the root of the file system.
    /// </summary>
    /// <returns>Regex</returns>
    static Regex StartFromRoot() => OperatingSystem.IsWindows()
                                        ? PathRegex.WinFromRoot()
                                        : PathRegex.UnixFromRoot();

    IFileSystem _fileSystem;
    string _pattern             = "";
    string _fromDir             = ".";
    RegexOptions _regexOptions  = RegexOptions.None;
    EnumerationOptions _options = new() {
        IgnoreInaccessible       = true,
        MatchCasing              = OperatingSystem.IsWindows() ? MatchCasing.CaseInsensitive : MatchCasing.CaseSensitive,
        MatchType                = OperatingSystem.IsWindows() ? MatchType.Win32 : MatchType.Simple,
        RecurseSubdirectories    = false,
        ReturnSpecialDirectories = true,
    };

    /// <summary>
    /// Gets or sets what to search for - files, directories, or both.
    /// </summary>
    public Enumerated Enumerated { get; set; } = Enumerated.Files;

    /// <summary>
    /// Gets or sets the folder path from which the search operation begins. Default - from the current working folder.
    /// </summary>
    public string EnumerateFromFolder
    {
        get => field;
        set
        {
            var fullPath = _fileSystem.GetFullPath(value);

            if (!_fileSystem.FolderExists(fullPath))
                throw new ArgumentException("The specified folder to search from does not exist.", nameof(value));

            field = OperatingSystem.IsWindows() ? value.Replace(WinSepChar, SepChar) : value;
        }
    } = ".";

    /// <summary>
    /// Gets or sets how the items to search for (files, directories, or both) are compared.
    /// </summary>
    public GlobComparison Comparison
    {
        get => field;
        set
        {
            field = value switch {
                GlobComparison.Windows => GlobComparison.Windows,
                GlobComparison.Unix => GlobComparison.Unix,
                _ => OperatingSystem.IsWindows()
                            ? GlobComparison.Windows
                            : GlobComparison.Unix,
            };
            _regexOptions = field is GlobComparison.Windows or GlobComparison.OrdinalIgnoreCase
                                        ? _regexOptions | RegexOptions.IgnoreCase
                                        : _regexOptions & ~RegexOptions.IgnoreCase;
            _options.MatchCasing = field is GlobComparison.Windows or GlobComparison.OrdinalIgnoreCase
                                        ? MatchCasing.CaseInsensitive
                                        : MatchCasing.CaseSensitive;
        }
    } = GlobComparison.Default;

    /// <summary>
    /// Initializes a new instance of the <see cref="GlobEnumerator"/> class with <see cref="FileSystem"/> as the file system.
    /// </summary>
    public GlobEnumerator(IFileSystem fileSystem)
    {
        _fileSystem = fileSystem ?? throw new ArgumentNullException(nameof(fileSystem));
        Comparison  = fileSystem.IsWindows ? GlobComparison.Windows : GlobComparison.Unix;
    }

    /// <summary>
    /// Searches for files or directories that match the specified pattern within the configured folder.
    /// </summary>
    public IEnumerable<string> Enumerate(string pattern)
    {
        ArgumentException.ThrowIfNullOrEmpty(pattern, "Pattern cannot be null, or empty");

        if (PathRegex.InvalidRecursive().IsMatch(pattern))
            throw new ArgumentException("The recursive wildcard '**' must appear immediately after a '/' or at the beginning of the pattern string; " +
                                        "and also must be immediately followed by '/' or be at the end of the pattern.", nameof(pattern));

        if (Enumerated.HasFlag(Enumerated.Files) && pattern.Last() is '/' or '\\')
            throw new ArgumentException("Pattern cannot end with a '/' or '\\' when searching for files.", nameof(pattern));

        if (Enumerated == Enumerated.Files && PathRegex.RecursiveAtEnd().IsMatch(pattern))
            throw new ArgumentException("Pattern cannot end with a recursive wildcard '**' when searching for files.", nameof(pattern));

        var m = StartFromRoot().Match(pattern);  // if it starts with a root or drive like `D:\`, `C:/` or just `/` or `\` then ignore EnumerateFromFolder and start from the root
        if (m.Success)
        {
            _pattern = pattern[m.Length..]; // start from root
            _fromDir = m.Value;
        }
        else
        {
            _pattern = pattern;
            _fromDir = EnumerateFromFolder;
        }

        if (_fileSystem.IsWindows)
        {
            _pattern = _pattern.Replace(WinSepChar, SepChar);
            _fromDir = _fromDir.Replace(WinSepChar, SepChar);
        }

        // call the actual search
        return EnumerateImpl(_fromDir, GetFirstComponentRange());
    }

    // TODO: implement when we go for full glob support or regex-based matching
    //static bool IsPatternComponent(string component)
    //    => component.Contains(SequenceWc) || component.Contains(CharacterWc);

    //Regex RegexFromPattern(string pattern)
    //    => new("^"+Regex.Escape(pattern).Replace(@"\*", ".*").Replace(@"\?", ".")+"$", _regexOptions);

    Range GetFirstComponentRange()
        => new( // always starts at
                0,
                // the end is the first SepChar, or the end of the pattern
                _pattern.IndexOf(SepChar) is int nextEnd && nextEnd != -1 ? nextEnd : _pattern.Length);

    Range GetNextComponentRange(Range range)
        => new( // the nextStart is just after the previous end
                range.End.Value + 1,
                // the nextEnd is the next SepChar after the nextStart, or the end of the pattern
                _pattern.IndexOf(SepChar, range.End.Value + 1) is int nextEnd && nextEnd != -1 ? nextEnd : _pattern.Length);

    bool IsLastComponentRange(Range range)
        => range.End.Value == _pattern.Length;

    IEnumerable<string> EnumerateImpl(string dir, Range componentRange, bool recursive = false)
    {
        var component = _pattern[componentRange];

        if (IsLastComponentRange(componentRange))
        {
            // no more components after this one - just list the files and directories in this dir that match the last component
            if (Enumerated.HasFlag(Enumerated.Directories))
                foreach (var d in EnumerateDirectories(dir, component, recursive))
                    yield return d;
            if (Enumerated.HasFlag(Enumerated.Files))
                foreach (var f in EnumerateFiles(dir, component, recursive))
                    yield return f;

            yield break;
        }
        else
        if (component is RecursiveWc)
        {
            // in the next call "dir" doesn't change, but the search becomes recursive for the pattern components after the "**".
            foreach (var e in EnumerateImpl(dir, GetNextComponentRange(componentRange), true))
                yield return e;
            yield break;
        }
        else
        {
            // else, because there are more components after this one, we need to find all *sub-directories*
            // that match the current component and continue searching in them
            var nextRange = GetNextComponentRange(componentRange);

            // find one or more sub-directories (recursive sub-trees) that match the current component and continue searching in all of them
            foreach (var subDir in EnumerateDirectories(dir, component, recursive))
                // recursively keep searching into this sub-tree
                foreach (var e in EnumerateImpl(subDir, nextRange, recursive))
                    yield return e;
        }
    }

    IEnumerable<string> EnumerateFiles(string dir, string pattern, bool recursively = false)
    {
        if (string.IsNullOrEmpty(pattern))
            throw new ArgumentException("Pattern cannot be null or empty.", nameof(pattern));
        if (pattern == RecursiveWc)
            throw new ArgumentException("Recursive wildcard '**' is not valid here.", nameof(pattern));

        _options.RecurseSubdirectories = recursively;

        return _fileSystem
                    .EnumerateFiles(dir, pattern, _options)
                    .Select(f => _fileSystem.IsWindows ? f.Replace(WinSepChar, SepChar) : f)
                    ;
    }

    IEnumerable<string> EnumerateDirectories(string dir, string pattern, bool recursively = false)
    {
        if (string.IsNullOrEmpty(pattern))
            throw new ArgumentException("Pattern cannot be null or empty.", nameof(pattern));
        if (pattern == RecursiveWc)
            throw new ArgumentException("Recursive wildcard '**' is not valid here.", nameof(pattern));

        _options.RecurseSubdirectories = recursively;

        return _fileSystem
                    .EnumerateFolders(dir, pattern, _options)
                    .Select(d => _fileSystem.IsWindows ? d.Replace(WinSepChar, SepChar) : d)
                    ;
    }
}