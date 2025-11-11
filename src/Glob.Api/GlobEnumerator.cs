namespace vm2.DevOps.Glob.Api;
/// <summary>
/// Represents a glob pattern searcher.
/// </summary>
public sealed partial class GlobEnumerator
{
    #region fields
    IFileSystem _fileSystem;
    string _pattern             = "";
    RegexOptions _regexOptions  = RegexOptions.IgnorePatternWhitespace
                                | RegexOptions.ExplicitCapture
                                | (OperatingSystem.IsWindows() ? RegexOptions.IgnoreCase : RegexOptions.None);

    EnumerationOptions _options = new() {
        IgnoreInaccessible       = true,
        MatchCasing              = MatchCasing.PlatformDefault,
        MatchType                = OperatingSystem.IsWindows() ? MatchType.Win32 : MatchType.Simple,
        RecurseSubdirectories    = false,
        ReturnSpecialDirectories = true,
    };
    #endregion

    #region Properties
    /// <summary>
    /// Gets a rex that matches if a pattern starts from the root of the file system.
    /// </summary>
    /// <returns>Regex</returns>
    Regex FileSystemRoot { get; init; }

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
            throw new ArgumentException("Pattern cannot end with a recursive wildcard '**' when searching for files.", nameof(pattern));

        string fromDir;
        (_pattern, fromDir) = NormalizePatternAndDir(pattern);

        if (!_fileSystem.Glob().IsMatch(_pattern))
            throw new ArgumentException("Invalid glob-pattern.", nameof(pattern));

        Logger.LogDebug("""
            ================================
            Matching the pattern:       "{Pattern}" ("{NormalizedPattern}")
            Current directory:          "{CurrentFolder}"
            Enumerate from folder:      "{FromFolder}"
            Objects:                    "{Enumerated}"
            """,
            pattern, _pattern, _fileSystem.GetCurrentDirectory(), EnumerateFromFolder, Enumerated);

        // call the actual search
        return EnumerateImpl(fromDir, FirstComponentRange());
    }
    #endregion

    #region Private methods
    /// <summary>
    /// Normalizes the specified pattern by converting separators, removing duplicates, and determining the starting directory.
    /// Also sets the _fromDir field.
    /// </summary>
    /// <param name="pattern"></param>
    /// <returns></returns>
    (string normPattern, string fromDir) NormalizePatternAndDir(string pattern)
    {
        Span<char> patternSpan = stackalloc char[pattern.Length];
        int start;
        var end = pattern.EndsWith(SepChar) ? pattern.Length - 1 : pattern.Length;  // trim a trailing separator
        string fromDir = "";

        pattern.AsSpan().CopyTo(patternSpan);

        var m = FileSystemRoot.Match(pattern);   // if it starts with a root or drive like `C:/` or just `/`
        if (m.Success)
        {
            // then ignore EnumerateFromFolder and the current folder and start from the root of the file system
            fromDir = m.Value;
            start   = m.Length; // skip the root part in the pattern - it is reflected in fromDir
        }
        else
        {
            // get the full path of EnumerateFromFolder relative to the current dir
            fromDir = _fileSystem.GetFullPath(EnumerateFromFolder);
            start   = 0;        // start from the beginning
        }

        char prev = '\0';
        int i = start;

        for (var j = start; j < end; j++)
        {
            var ch = patternSpan[j];
            var c = ch is WinSepChar ? SepChar : ch;    // convert Windows separators to Unix-style

            if (c is SepChar && prev is SepChar)        // Skip duplicate separators
                continue;

            patternSpan[i++] = c;
            prev = ch;
        }

        return (patternSpan[start..i].ToString(), fromDir);
    }

    Range FirstComponentRange()
        => ..(_pattern.IndexOf(SepChar) is int nextEnd && nextEnd is -1 ? _pattern.Length : nextEnd);
    // always starts at 0 and
    // the end is at the first SepChar, or at the end of the pattern


    Range NextComponentRange(Range range)
        => IsLastComponentRange(range)
                ? ..0 // no next component
                : (range.End.Value+1)..(_pattern.IndexOf(SepChar, range.End.Value+1) is int nextEnd &&
                                          nextEnd is -1 ? _pattern.Length : nextEnd);
    // the nextStart is just after the end
    // the nextEnd is at the next SepChar after this, or at the end of the pattern

    bool IsLastComponentRange(Range range)
        => range.End.Value >= _pattern.Length;

    IEnumerable<string> EnumerateImpl(string dir, Range componentRange, bool recursive = false)
    {
        var isLastComponent  = IsLastComponentRange(componentRange);
        var component        = _pattern[componentRange];
        var (pattern, regex) = GlobToRegex(component);

        Logger.LogDebug("""
                --------------------------------
                searching in:               "{Directory}"
                pattern component:          "{Component}" {IsLastComponent}:
                    file pattern:               "{Pattern}"
                    match regex:                "{Regex}"
                """,
                dir, component, isLastComponent ? "(last)" : "", pattern, regex);

        var nextRange = NextComponentRange(componentRange);

        switch (component)
        {
            case RecursiveWildcard:
                // set recursive to true and continue searching in the current dir
                recursive = true;
                goto case CurrentDir;

            case ParentDir:
                // change the dir to the parent
                dir = _fileSystem.GetFullPath($"{dir}/..");
                goto case CurrentDir;

            case CurrentDir:
                if (isLastComponent)
                    break;  // nothing more to do - just list the requested objects in the current dir
                // because there are more components after this one, we need to continue searching in the current dir
                foreach (var e in EnumerateImpl(dir, nextRange, recursive))
                    yield return e;
                yield break;
        }

        if (!isLastComponent)
        {
            // because there are more components after this one, we need to find all *sub-directories*
            // of the current component and continue searching in them

            // find one or more sub-directories that match the current component (if recursive - goes into the sub-trees) and
            // continues searching in all of them
            var subDirs = EnumerateDirectories(dir, pattern, regex, recursive);

            foreach (var subDir in subDirs)
                // recursively go into the sub-tree and enumerate both files and directories as per the next components
                foreach (var e in EnumerateImpl(subDir, nextRange, recursive))
                    yield return e;
            yield break;
        }

        // We are at the last component: search objects (files and/or directories) that match this component in the current "dir"
        // Just list the requested objects to be enumerated in the current directory
        // that match this last component:
        if (Enumerated.HasFlag(Objects.Directories))
        {
            var dirs = EnumerateDirectories(dir, pattern, regex, recursive);

            foreach (var d in dirs)
                yield return d;
        }

        if (Enumerated.HasFlag(Objects.Files))
        {
            var files = EnumerateFiles(dir, pattern, regex, recursive);

            foreach (var f in files)
                yield return f;
        }
    }

    IReadOnlyList<string> EnumerateFiles(
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
                        .Where(f => { var m = rex.Match(f); return m.Success; })
                        ;
        }

        var list = result
                        .ToList()
                        ;

        Logger.LogDebug("""
                --------------------------------
                enumerate files in:         "{Dir}"
                recursively:                {Recursively}
                files:
                  file: {Files}
                """,
                dir, recursively, string.Join("\n        file: ", list));

        return list;
    }

    IReadOnlyList<string> EnumerateDirectories(
        string dir,
        string pattern,
        string regex,
        bool recursively)
    {
        _options.RecurseSubdirectories = recursively;

        var result = _fileSystem
                        .EnumerateFolders(dir, pattern, _options)
                        .Where(d => !(d.EndsWith(CurrentDir) || d.EndsWith(ParentDir)))
                        ;

        if (regex != "" && regex != _fileSystem.SequenceRegex())
        {
            // add filtering on top of the pattern matching in EnumerateFiles
            var rex = new Regex($"(^|/){regex}(/|$)", _regexOptions);

            result = result
                        .Where(d => rex.IsMatch(d))
                        ;
        }

        var list = result
                        .Select(p => p.EndsWith(SepChar) ? p : p + SepChar)
                        .ToList()
                        ;

        Logger.LogDebug("""
            --------------------------------
            enumerate directories in:   "{Dir}"
            recursively:                "{Recursively}"
            directories:
              dir:  {Dirs}
            """,
            dir, recursively, string.Join("\n        dir:  ", list));

        return list;
    }
    #endregion
}
