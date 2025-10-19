namespace vm2.DevOps.Globs;

/// <summary>
/// Represents a glob pattern searcher.
/// </summary>
public sealed partial class Searcher
{
    const string SequenceWildcard  = "*";
    const string CharacterWildcard = "?";
    const string RecursiveWildcard = $"{SequenceWildcard}{CharacterWildcard}";

    const char WinFolderSeparator  = '\\';
    const char UnixFolderSeparator = '/';
    const char FolderSeparator     = UnixFolderSeparator;

    // Recursive wildcard '**' cannot be preceded by anything other than a '/' or be at the beginning of the pattern string and
    // cannot be followed by anything other than a '/' or be at the end of the pattern.
    // Examples of invalid patterns: "a**", "**a", "a/**b", "a**/b", "a/**b".
    // Examples of valid patterns: "**", "**/", "/**", "/**/", "a/**", "**/a", "a/**/", "/**/a", "a/**/b", "/**/a/b", "a/**/b/**/c".
    [GeneratedRegex(@"(?<!^|/)\*\*|\*\*(?!$|/)")]
    public static partial Regex InvalidRecursive();

    [GeneratedRegex(@"\*\*$")]
    public static partial Regex RecursiveAtEnd();

    [GeneratedRegex(@"^(?:/|\\|[a-zA-Z]:[/\\]?)")]
    public static partial Regex WinFromRoot();

    [GeneratedRegex(@"^/")]
    public static partial Regex UnixFromRoot();

    /// <summary>
    /// Gets a regex that matches if a pattern starts from the root of the file system.
    /// </summary>
    /// <returns>Regex</returns>
    public static Regex FromRoot() => OperatingSystem.IsWindows()
                                        ? WinFromRoot()
                                        : UnixFromRoot();

    IFileSystem _fileSystem;
    string _pattern = "";
    string _fromDir = ".";
    RegexOptions _regexOptions = RegexOptions.None;
    EnumerationOptions _options = new() {
        IgnoreInaccessible       = true,
        MatchCasing              = OperatingSystem.IsWindows() ? MatchCasing.CaseInsensitive : MatchCasing.CaseSensitive,
        MatchType                = OperatingSystem.IsWindows() ? MatchType.Win32 : MatchType.Simple,
        RecurseSubdirectories    = false,
        ReturnSpecialDirectories = true,
    };
    List<string> _found = [];

    /// <summary>
    /// Gets or sets what to search for - files, directories, or both.
    /// </summary>
    public SearchFor SearchFor { get; set; } = SearchFor.Files;

    /// <summary>
    /// Gets or sets the folder path from which the search operation begins.
    /// </summary>
    public string SearchFromFolder
    {
        get => field;
        set
        {
            var fullPath = Path.GetFullPath(value);
            if (!_fileSystem.FolderExists(fullPath))
                throw new ArgumentException("The specified folder to search from does not exist.", nameof(value));
            field = OperatingSystem.IsWindows() ? value.Replace(WinFolderSeparator, FolderSeparator) : value;
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
            field = value;
            _regexOptions = value is GlobComparison.Windows or GlobComparison.OrdinalIgnoreCase
                                        ? _regexOptions | RegexOptions.IgnoreCase
                                        : _regexOptions & ~RegexOptions.IgnoreCase;
            _options.MatchCasing = value is GlobComparison.Windows or GlobComparison.OrdinalIgnoreCase
                                        ? MatchCasing.CaseInsensitive
                                        : MatchCasing.CaseSensitive;
        }
    } = GlobComparison.Default;

    /// <summary>
    /// Initializes a new instance of the <see cref="Searcher"/> class with <see cref="FileSystem"/> as the file system.
    /// </summary>
    public Searcher(IFileSystem fileSystem)
        => _fileSystem = fileSystem ?? throw new ArgumentNullException(nameof(fileSystem));

    /// <summary>
    /// Searches for files or directories that match the specified pattern within the configured folder.
    /// </summary>
    public IEnumerable<string> Search(string pattern)
    {
        ArgumentException.ThrowIfNullOrEmpty(pattern, "Pattern cannot be null, or empty");

        if (InvalidRecursive().IsMatch(pattern))
            throw new ArgumentException("The recursive wildcard '**' must appear immediately after a '/' or at the beginning of the pattern string; " +
                                        "and also must be immediately followed by '/' or be at the end of the pattern.", nameof(pattern));

        if (SearchFor.HasFlag(SearchFor.Files) && pattern.Last() is '/' or '\\')
            throw new ArgumentException("Pattern cannot end with a '/' or '\\' when searching for files.", nameof(pattern));

        if (SearchFor == SearchFor.Files && RecursiveAtEnd().IsMatch(pattern))
            throw new ArgumentException("Pattern cannot end with a recursive wildcard '**' when searching for files.", nameof(pattern));

        _found = [];
        var m = FromRoot().Match(pattern);  // if it starts with a root or drive like `D:\`, `C:/` or just `/` or `\` then ignore SearchFromFolder and start from the root
        if (m.Success)
        {
            _pattern = pattern[m.Length..]; // start from root
            _fromDir = m.Value;
        }
        else
        {
            _pattern = pattern;
            _fromDir = SearchFromFolder;
        }

        if (_fileSystem.IsWindows)
        {
            _pattern = _pattern.Replace(WinFolderSeparator, FolderSeparator);
            _fromDir = _fromDir.Replace(WinFolderSeparator, FolderSeparator);
        }

        // call the actual search
        Search(_fromDir, GetFirstComponentRange());

        return _found;
    }

    // TODO: implement when we go for full glob support or regex-based matching
    //static bool IsPatternComponent(string component)
    //    => component.Contains(SequenceWildcard) || component.Contains(CharacterWildcard);

    //Regex RegexFromPattern(string pattern)
    //    => new("^"+Regex.Escape(pattern).Replace(@"\*", ".*").Replace(@"\?", ".")+"$", _regexOptions);

    Range GetFirstComponentRange()
        => new(0,
               _pattern.IndexOf(FolderSeparator) is int firstEnd && firstEnd != -1
                    ? firstEnd
                    : _pattern.Length);

    Range GetNextComponentRange(Range range)
        => new(range.End.Value + 1,
               _pattern.IndexOf(FolderSeparator, range.End.Value + 1) is int nextEnd && nextEnd != -1
                    ? nextEnd
                    : _pattern.Length);

    bool IsLastComponentRange(Range range)
        => range.End.Value == _pattern.Length;

    void Search(string dir, Range componentRange, bool recursive = false)
    {
        var component = _pattern[componentRange];

        if (IsLastComponentRange(componentRange))
        {
            // no more components after this one - just list the files and directories in this dir that match the component
            if (SearchFor.HasFlag(SearchFor.Directories))
                _found.AddRange(
                    SearchDirectories(dir, component, component is RecursiveWildcard));
            if (SearchFor.HasFlag(SearchFor.Files))
                _found.AddRange(
                    SearchFiles(dir, component, component is RecursiveWildcard));
            return;
        }

        // else, because there are more components after this one, we need to find all *subdirectories*
        // that match the current component and continue searching in them

        if (component is RecursiveWildcard)
        {
            // in the next call "dir" doesn't change, but the search becomes recursive for the component after the "**"
            Search(dir, GetNextComponentRange(componentRange), true);
            return;
        }

        // find one or more (recursive sub-tree) subdirectories that match the current component and continue searching in all of them
        var subDirs = SearchDirectories(dir, component, recursive);

        if (!subDirs.Any())
            // this is a dead-end - no subdirectories match the current component
            return;

        // recursively keep searching into this sub-tree
        var range = GetNextComponentRange(componentRange);

        foreach (var subDir in subDirs)
            Search(subDir, range);
    }

    IEnumerable<string> SearchFiles(string dir, string pattern, bool recursively = false)
    {
        if (string.IsNullOrEmpty(pattern))
            throw new ArgumentException("Pattern cannot be null or empty.", nameof(pattern));
        if (pattern == RecursiveWildcard)
            throw new ArgumentException("Recursive wildcard '**' is not valid here.", nameof(pattern));

        _options.RecurseSubdirectories = recursively;

        return _fileSystem
                    .EnumerateFiles(dir, pattern, _options)
                    .Select(f => _fileSystem.IsWindows ? f.Replace(WinFolderSeparator, FolderSeparator) : f)
                    ;
    }

    IEnumerable<string> SearchDirectories(string dir, string pattern, bool recursively = false)
    {
        if (string.IsNullOrEmpty(pattern))
            throw new ArgumentException("Pattern cannot be null or empty.", nameof(pattern));
        if (pattern == RecursiveWildcard)
            throw new ArgumentException("Recursive wildcard '**' is not valid here.", nameof(pattern));

        _options.RecurseSubdirectories = recursively;

        return _fileSystem
                    .EnumerateFolders(dir, pattern, _options)
                    .Where(d => File.GetAttributes(d).HasFlag(FileAttributes.Directory))
                    .Select(d => _fileSystem.IsWindows ? d.Replace(WinFolderSeparator, FolderSeparator) : d)
                    ;
    }
}