namespace vm2.DevOps.Glob.Api;
/// <summary>
/// Represents a glob pattern searcher.
/// </summary>
public sealed partial class GlobEnumerator
{
    #region Fields and private properties
    RegexOptions _regexOptions  = RegexOptions.IgnorePatternWhitespace
                                | RegexOptions.ExplicitCapture
                                | (OperatingSystem.IsWindows() ? RegexOptions.IgnoreCase : RegexOptions.None); // see also MatchCasing property

    EnumerationOptions _options = new() {
        MatchCasing              = MatchCasing.PlatformDefault, // see also MatchCasing property
        RecurseSubdirectories    = false,                       // we control it ourselves
        MatchType                = MatchType.Simple,            // don't touch it - this is bs
        // in future we may expose these as well:
        ReturnSpecialDirectories = false,
        IgnoreInaccessible       = true,
        AttributesToSkip         = FileAttributes.Hidden | FileAttributes.System,
    };
    IFileSystem _fileSystem;
    string _pattern              = "";
    Queue<(string dir, Range patternComponentRange, bool recursively)> _enumerationQueue = [];

    /// <summary>
    /// Gets a rex that matches the root of the file system in a path.
    /// </summary>
    /// <returns>Regex</returns>
    Regex FileSystemRoot { get; init; }
    #endregion

    #region Public Properties
    /// <summary>
    /// Gets or sets what to search for - files, directories, or both.
    /// </summary>
    public Objects Enumerated { get; set; } = Objects.Files;

    /// <summary>
    /// Gets or sets the folder dirPath from which the search operation begins. Default - from the current working folder.
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
    /// Gets or sets the case sensitivity behavior for matching operations.
    /// </summary>
    public MatchCasing MatchCasing
    {
        get => _options.MatchCasing;
        set
        {
            _options.MatchCasing = value;
            _ = _options.MatchCasing switch {
                MatchCasing.CaseSensitive => _regexOptions &= ~RegexOptions.IgnoreCase,
                MatchCasing.CaseInsensitive => _regexOptions |= RegexOptions.IgnoreCase,
                MatchCasing.PlatformDefault => _fileSystem.IsWindows
                                                    ? (_regexOptions |= RegexOptions.IgnoreCase)
                                                    : (_regexOptions &= ~RegexOptions.IgnoreCase),
                _ => throw new ArgumentOutOfRangeException(nameof(value), "Invalid MatchCasing value."),
            };
        }
    }

    /// <summary>
    /// Gets or sets a value indicating whether the results should be distinct.
    /// </summary>
    /// <remarks>
    /// When set to <c>true</c>, duplicate results will be removed from the final output. This is useful when patterns may lead
    /// to overlapping matches, e.g., /**/docs/**/*.txt.
    /// </remarks>
    public bool DistinctResults { get; set; } = false;

    /// <summary>
    /// Gets or sets the logger instance used to log messages for the <see cref="GlobEnumerator"/> class.
    /// </summary>
    public ILogger<GlobEnumerator> Logger { get; init; }
    #endregion

    #region Constructors
    /// <summary>
    /// Initializes a new instance of the <see cref="GlobEnumerator"/> class with <see cref="FileSystem"/> as the f system.
    /// </summary>
    public GlobEnumerator(IFileSystem fileSystem, ILogger<GlobEnumerator> logger)
    {
        _fileSystem    = fileSystem ?? throw new ArgumentNullException(nameof(fileSystem));
        MatchCasing    = MatchCasing.PlatformDefault;
        FileSystemRoot = _fileSystem.IsWindows ? WindowsFileSystemRoot() : UnixFileSystemRoot();
        Logger         = logger ?? throw new ArgumentNullException(nameof(logger));
    }
    #endregion

    #region Public methods
    /// <summary>
    /// Searches for files or directories that match the specified pattern within the configured folder.
    /// </summary>
    public IEnumerable<string> Enumerate(string pattern)
    {
        ArgumentException.ThrowIfNullOrEmpty(pattern, "Pattern cannot be null, or empty");

        if (Enumerated.HasFlag(Objects.Files) && pattern.Last() is '/' or '\\')
            throw new ArgumentException("Pattern cannot end with a '/' or '\\' when searching for files.", nameof(pattern));
        if (Enumerated is Objects.Files && RecursiveAtEnd().IsMatch(pattern))
            throw new ArgumentException("Pattern cannot end with a recursively wildcard '**' when searching for files.", nameof(pattern));

        string fromDir;
        (_pattern, fromDir) = NormalizePatternStartFromDir(pattern);

        if (!_fileSystem.Glob().IsMatch(_pattern))
            throw new ArgumentException("Invalid glob-pattern.", nameof(pattern));

        if (Logger.IsEnabled(LogLevel.Debug))
            Logger.LogDebug("""
                ================================
                Matching the pattern:       "{Pattern}" => "{NormalizedPattern}"
                Current directory:          "{CurrentFolder}"
                Enumerate from folder:      "{FromFolder}" => "{ResFromFolder}"
                Objects:                    "{Enumerated}"
                """,
                pattern, _pattern, _fileSystem.GetCurrentDirectory(), EnumerateFromFolder, fromDir, Enumerated);

        Debug.Assert(!_enumerationQueue.Any(), "The queue must be empty after the previous search!");
        _enumerationQueue.Clear();  // just in case

        // enqueue the first search
        _enumerationQueue.Enqueue((fromDir, FirstPatternComponentRange(), false));

        // dive-into the enumeration
        var enumerable = EnumerateImpl();

        if (DistinctResults && Recursive().Matches(_pattern).Count > 1)
            enumerable = enumerable.Distinct();

        return enumerable;
    }
    #endregion

    #region Private methods
    Range FirstPatternComponentRange()
        => ..(_pattern.IndexOf(SepChar) is int nextEnd && nextEnd is >=0 ? nextEnd : _pattern.Length);
    // first pattern patternComponent always starts at 0 and ends at the first SepChar, or at the end of the pattern


    Range NextPatternComponentRange(Range range)
        => IsLastPatternComponentRange(range)
                ? _pattern.Length.._pattern.Length // no next patternComponent
                : (range.End.Value+1)..(_pattern.IndexOf(SepChar, range.End.Value+1) is int nextEnd &&
                                          nextEnd is -1 ? _pattern.Length : nextEnd);
    // the nextStart is after the separator of the current range,
    // the nextEnd is at the next SepChar after this, or at the end of the pattern

    bool IsLastPatternComponentRange(Range range)
        => range.End.Value >= _pattern.Length;

    IEnumerable<string> EnumerateImpl()
    {
        while (_enumerationQueue.TryDequeue(out var p))
        {
            var (dir, patternComponentRange, recursively) = p;

            var isLast           = IsLastPatternComponentRange(patternComponentRange);
            var patternComponent = _pattern[patternComponentRange];
            var (pattern, regex) = GlobToRegex(patternComponent);   // glob pattern and regex for the name(s) of the file(s)/dir(s) to search for in the dir

            if (Logger.IsEnabled(LogLevel.Debug))
                Logger.LogDebug("""
                --------------------------------
                searching in:               "{Directory}" {Recursively}
                pattern component:          "{Component}" {IsLastComponent}
                    glob pattern:               "{Pattern}"
                    match regex:                "{Regex}"
                """,
                    dir, recursively ? "recursively" : "", patternComponent, isLast ? "(the last)" : "", pattern, regex);

            var nextPatternComponentRange = NextPatternComponentRange(patternComponentRange);

            switch (patternComponent)
            {
                case CurrentDir:
                    // enqueue searching again in the current dir but this time recursively
                    _enumerationQueue.Enqueue((dir, nextPatternComponentRange, false));
                    continue;

                case ParentDir:
                    // enqueue searching in the parent dir
                    _enumerationQueue.Enqueue((_fileSystem.GetFullPath($"{dir}/.."), nextPatternComponentRange, false));
                    continue;

                case RecursiveWildcard:
                    // enqueue searching again in the current dir but this time recursively
                    _enumerationQueue.Enqueue((dir, nextPatternComponentRange, true));
                    continue;
            }

            if (isLast)
            {
                // We are at the last patternComponent: search objects (files and/or directories) that match this patternComponent
                // in the current "dir".
                // Just list the requested objects to be enumerated in the current directory
                // that match this last patternComponent:
                if (Enumerated.HasFlag(Objects.Directories))
                    foreach (var d in EnumerateDirectories(dir, pattern, regex, recursively))
                        yield return d;

                if (Enumerated.HasFlag(Objects.Files))
                    foreach (var f in EnumerateFiles(dir, pattern, regex, recursively))
                        yield return f;
            }
            else
            {
                // enqueue sub-directories for further searching
                foreach (var subDir in EnumerateDirectories(dir, pattern, regex, recursively))
                    // recursively go into the sub-tree and enumerate both files and directories recursively as well if the next component is the last
                    _enumerationQueue.Enqueue((subDir, nextPatternComponentRange, false));
            }
        }
    }

    IEnumerable<string> EnumerateFiles(
        string dir,
        string pattern,
        string regex,
        bool recursively)
    {
        _options.RecurseSubdirectories = recursively;

        var result = _fileSystem
                        .EnumerateFiles(dir, pattern, _options)
                        ;

        if (regex != "" && regex != _fileSystem.SequenceRegex())
        {
            // add filtering on top of the pattern matching in EnumerateFiles
            var rex = new Regex($"(^|/){regex}$", _regexOptions);

            result = result
                        .Where(file => rex.IsMatch(LastComponent(file)))
                        ;
        }
        return result;

#if false
        var list = result
                        .ToList()
                        ;

        if (Logger.IsEnabled(LogLevel.Debug))
            Logger.LogDebug("""
                --------------------------------
                enumerate files in:         "{Dir}" {Recursively}
                files:
                    file: {Files}
                """,
                dir, recursively ? "(recursively)" : "", string.Join("\n          file: ", list));

        return list;
#endif
    }

    IEnumerable<string> EnumerateDirectories(
        string dir,
        string pattern,
        string regex,
        bool recursively)
    {
        _options.RecurseSubdirectories = recursively;

        var result = _fileSystem
                        .EnumerateFolders(dir, pattern, _options)
                        ;

        if (regex != "" && regex != _fileSystem.SequenceRegex())
        {
            // add filtering on top of the pattern matching in EnumerateFiles
            var rex = new Regex($"(^|/){regex}(/|$)", _regexOptions);

            result = result
                        .Where(dir => rex.IsMatch(LastComponent(dir)))
                        ;
        }

        return result.Select(p => p.EndsWith(SepChar) ? p : p + SepChar);
#if false
        var list = result
                        .Select(p => p.EndsWith(SepChar) ? p : p + SepChar)
                        .ToList()
                        ;

        if (Logger.IsEnabled(LogLevel.Debug))
            Logger.LogDebug("""
            --------------------------------
            enumerate directories in:   "{Dir}" {Recursively}
            directories:
                dir:  {Dirs}
            """,
            dir, recursively, string.Join("\n          dir:  ", list));

        return list;
#endif
    }

    /// <summary>
    /// Gets the last component of a path - the name of the file or directory at the end of the path.
    /// </summary>
    /// <param name="path"></param>
    /// <returns>
    /// A span representing the last component of the specified <paramref name="path"/>.
    /// </returns>
    static ReadOnlySpan<char> LastComponent(string path)
    {
        var span = path.EndsWith(SepChar) ? path.AsSpan()[..^1] : path.AsSpan();

        if (span.Length is <= 0)
            return span;

        if (span.LastIndexOf(SepChar) is int lastSep && lastSep is > 0)
        {
            Debug.Assert(lastSep < span.Length);
            return span[(lastSep + 1)..];
        }

        return span;
    }
    #endregion
}
