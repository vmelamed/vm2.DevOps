namespace vm2.DevOps.Glob.Api;

/// <summary>
/// Represents a pattern pattern searcher.
/// </summary>
public sealed partial class GlobEnumerator
{
    #region Fields and private properties
    RegexOptions _regexOptions  = RegexOptions.IgnorePatternWhitespace
                                | RegexOptions.ExplicitCapture
                                | (OperatingSystem.IsWindows() ? RegexOptions.IgnoreCase : RegexOptions.None);

    EnumerationOptions _options = new() {
        MatchCasing              = MatchCasing.PlatformDefault, // see also _matchCasing property
        RecurseSubdirectories    = false,                       // we control it ourselves
        MatchType                = MatchType.Simple,            // don't touch it - this is bs
        // in future we may expose these as well:
        ReturnSpecialDirectories = false,
        IgnoreInaccessible       = true,
        AttributesToSkip         = FileAttributes.Hidden | FileAttributes.System,
    };

    ILogger<GlobEnumerator>? _logger;
    IFileSystem _fileSystem;
    string _glob = "";
    Deque<(string dir, Range patternComponentRange, bool recursively)> _deque = new();

    /// <summary>
    /// Gets a regex object that matches the root of the file system in a path.
    /// </summary>
    /// <returns>Regex</returns>
    Regex FileSystemRoot { get; init; }
    #endregion

    #region Public Properties
    /// <summary>
    /// Gets or sets the glob used to match file or directory names. Default - an empty string, which is equivalent to "*".
    /// </summary>
    public string Glob
    {
        get;
        set
        {
            ArgumentNullException.ThrowIfNull(value);
            field = value;
        }
    } = "";

    /// <summary>
    /// Gets or sets the directory dirPath from which the enumeration operation begins. Default - from the current working directory.
    /// </summary>
    public string FromDirectory
    {
        get;
        set
        {
            var fullPath = _fileSystem.GetFullPath(value);

            if (!_fileSystem.DirectoryExists(fullPath))
                throw new ArgumentException("The specified directory to enumerate from does not exist.", nameof(value));

            field = _fileSystem.IsWindows ? value.Replace(WinSepChar, SepChar) : value;
        }
    } = ".";

    /// <summary>
    /// Gets or sets the type of file system objects to search for - files, directories, or both.
    /// </summary>
    public Objects Enumerated { get; set; } = Objects.Files;

    /// <summary>
    /// Gets or sets a value indicating whether the enumeration should be performed in depth-first order vs breadth-first. The
    /// default is <c>false</c> - breadth-first.
    /// </summary>
    public bool DepthFirst { get; set; }

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
                _ => throw new ArgumentOutOfRangeException(nameof(value), "Invalid _matchCasing value."),
            };
        }
    }

    /// <summary>
    /// Gets or sets a value indicating whether the results should be distinct. When set to <c>true</c>, duplicate results will
    /// be removed from the final output.
    /// </summary>
    /// <remarks>
    /// Some globs may lead to repeating matches, e.g., /**/docs/**/*.txt, whichj may not be desireable. But also it comes with
    /// a price in memory, performance, and loss of lazy enumeration. Therefore use judiciously.
    /// </remarks>
    public bool Distinct { get; set; } = false;
    #endregion

    #region Constructors
    /// <summary>
    /// Initializes a new instance of the <see cref="GlobEnumerator"/> class with <see cref="FileSystem"/> as the file system
    /// and <see cref="ILogger{GlobEnumerator}"/> logger.
    /// </summary>
    public GlobEnumerator(IFileSystem? fileSystem = null, ILogger<GlobEnumerator>? logger = null)
    {
        _fileSystem    = fileSystem ?? new FileSystem();
        _logger         = logger;
        MatchCasing    = MatchCasing.PlatformDefault;
        FileSystemRoot = _fileSystem.IsWindows ? WindowsFileSystemRootRegex() : UnixFileSystemRootRegex();
    }
    #endregion

    #region Public methods
    /// <summary>
    /// Searches for files or directories that match the specified pattern within the configured directory.
    /// </summary>
    public IEnumerable<string> Enumerate()
    {
        if (Enumerated is Objects.Files &&
            Glob is not "" &&
            (Glob.Last() is '/' or '\\' || RecursiveAtEndRegex().IsMatch(Glob)))
            throw new ArgumentException("Pattern cannot end with '/', '\\', or '**' when searching for files.");

        Debug.Assert(_deque?.Count is 0, "The queue must be empty after the previous search!");

        string fromDir;
        (_glob, fromDir) = NormalizeGlobAndStartDir();
        if (!_fileSystem.GlobRegex().IsMatch(_glob))
            throw new ArgumentException("Invalid pattern.");

        if (_logger?.IsEnabled(LogLevel.Debug) is true)
            _logger.LogDebug("""
                ================================
                Matching the pattern:       "{Pattern}" => "{NormalizedPattern}"
                Current directory:          "{CurrentDir}"
                Enumerate from directory:      "{FromDir}" => "{NormalizedFromDir}"
                Objects:                    "{Enumerated}"
                """,
                Glob,
                _glob,
                _fileSystem.GetCurrentDirectory(),
                FromDirectory,
                fromDir,
                Enumerated);

        _deque.Clear();                                       // just in case
        _deque.IsStack = DepthFirst;                          // honor the order of traversing
        _deque.Add((fromDir, FirstGlobComponent(), false));   // enqueue the first search and dive-into the enumeration

        var enumerable = EnumerateImpl();

        // only pattern-s with more than one directory recursive wildcards "**" can produce duplicates
        if (Distinct && RecursiveRegex().Matches(_glob).Count > 1)
            enumerable = enumerable.Distinct();

        return enumerable;
    }
    #endregion

    #region Private methods
    Range FirstGlobComponent()
        => 0..(_glob.IndexOf(SepChar) is int nextEnd && nextEnd is >=0 ? nextEnd : _glob.Length);
    // first pattern globComponent always starts at 0 and ends at the first SepChar, or at the end of the pattern

    Range NextGlobComponent(Range range)
        => IsLastGlobComponent(range)
                ? _glob.Length.._glob.Length // no next globComponent
                : (range.End.Value+1)..      // skipping the first '/' to the next '/' or the end of the pattern
                  (_glob.IndexOf(SepChar, range.End.Value+1) is int nextEnd && nextEnd is >=0 ? nextEnd : _glob.Length);
    // the nextStart is after the separator of the current range,
    // the nextEnd is at the next SepChar after this, or at the end of the pattern

    bool IsLastGlobComponent(Range range) => range.End.Value >= _glob.Length;

    IEnumerable<string> EnumerateImpl()
    {
        while (_deque.TryGet(out var p))
        {
            var (dir, globComponentRange, recursively) = p;

            var isLast           = IsLastGlobComponent(globComponentRange);
            var globComponent    = _glob[globComponentRange];
            var (pattern, regex) = GlobToRegex(globComponent);  // globComponent -> pattern (in .NET) and then regex to filter
                                                                // the names of the objects in dir

            if (_logger?.IsEnabled(LogLevel.Debug) is true)
                _logger.LogDebug("""
                    --------------------------------
                    searching in:               "{Directory}" {Recursively}
                    glob component:             "{Component}" {IsLastComponent}
                        pattern:                    "{Pattern}"
                        match regex:                "{Regex}"
                    """,
                    dir,
                    recursively ? "recursively" : "",
                    globComponent,
                    isLast ? "(the last)" : "",
                    pattern,
                    regex);

            var nextGlobComponentRange = NextGlobComponent(globComponentRange);

            // handle special globComponents: ., .., **
            switch (globComponent)
            {
                case CurrentDir:
                    // search again in the current dir
                    _deque.Add((dir, nextGlobComponentRange, false));
                    continue;

                case ParentDir:
                    // searching in the parent dir
                    _deque.Add((_fileSystem.GetFullPath($"{dir}/.."), nextGlobComponentRange, false));
                    continue;

                case RecursiveWildcard:
                    // search again in the current dir but recursively!
                    _deque.Add((dir, nextGlobComponentRange, true));
                    continue;
            }

            if (!isLast)
            {
                // add all sub-directories and go process the next search on the deque
                foreach (var subDir in EnumerateDirectories(dir, pattern, regex, recursively))
                    _deque.Add((subDir, nextGlobComponentRange, false));
                continue;
            }

            // if we are here, then we are at the last globComponent: search for the request objects (files and/or directories)
            // that match the last globComponent in the current dir.
            if (Enumerated.HasFlag(Objects.Directories))
                foreach (var d in EnumerateDirectories(dir, pattern, regex, recursively))
                {
                    if (_logger?.IsEnabled(LogLevel.Debug) is true)
                        _logger.LogDebug("          dir:  {Directory}", d);
                    yield return d;
                }

            if (Enumerated.HasFlag(Objects.Files))
                foreach (var f in EnumerateFiles(dir, pattern, regex, recursively))
                {
                    if (_logger?.IsEnabled(LogLevel.Debug) is true)
                        _logger.LogDebug("          file: {File}", f);
                    yield return f;
                }
        }
    }

    IEnumerable<string> EnumerateDirectories(
        string dir,
        string pattern,
        string regex,
        bool recursively)
    {
        _options.RecurseSubdirectories = recursively;

        // filter on pattern (hopefully it honors _options.MatchCasing)
        var result = _fileSystem.EnumerateDirectories(dir, pattern, _options);

        if (regex is not "" && regex != _fileSystem.NameSequence)
        {
            // compose regex filtering after the file system pattern (we already set the RegexOptions.IgnoreCase)
            var rex = new Regex($"(^|/){regex}(/|$)", _regexOptions);

            result = result.Where(d => rex.IsMatch(LastComponent(d)));
        }

        return result;
    }

    IEnumerable<string> EnumerateFiles(
        string dir,
        string pattern,
        string regex,
        bool recursively)
    {
        _options.RecurseSubdirectories = recursively;

        // filter on pattern (hopefully it honors _options.MatchCasing)
        var result = _fileSystem.EnumerateFiles(dir, pattern, _options);

        if (regex is not "" && regex != _fileSystem.NameSequence)
        {
            // compose regex filtering after the file system pattern (we already set the RegexOptions.IgnoreCase)
            var rex = new Regex($"(^|/){regex}$", _regexOptions);

            result = result.Where(f => rex.IsMatch(LastComponent(f)));
        }

        return result;
    }

    /// <summary>
    /// Gets the last component of a path - the name of the file or directory at the end of the path as they are returned by
    /// EnumerateFiles/EnumerateDirectories.
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
