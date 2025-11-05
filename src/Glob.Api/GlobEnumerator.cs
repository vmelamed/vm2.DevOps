namespace vm2.DevOps.Glob.Api;
/// <summary>
/// Represents a glob pattern searcher.
/// </summary>
public sealed partial class GlobEnumerator
{
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
    /// Gets a regex that matches if a pattern starts from the root of the file system.
    /// </summary>
    /// <returns>Regex</returns>
    Regex StartFromRoot { get; init; }

    /// <summary>
    /// Gets or sets what to search for - files, directories, or both.
    /// </summary>
    public Enumerated Enumerated
    {
        get;
        set => field = value is not Enumerated.None
                            ? value
                            : throw new ArgumentException("Enumerated must be set to Files, Directories, or Both.", nameof(value));
    } = Enumerated.Files;

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
    /// Gets or sets a value indicating whether debug output is enabled.
    /// </summary>
    public bool DebugOutput { get; set; } = false;

    /// <summary>
    /// Initializes a new instance of the <see cref="GlobEnumerator"/> class with <see cref="FileSystem"/> as the f system.
    /// </summary>
    public GlobEnumerator(IFileSystem fileSystem)
    {
        _fileSystem = fileSystem ?? throw new ArgumentNullException(nameof(fileSystem));
        if (_fileSystem.IsWindows)
        {
            _regexOptions |= RegexOptions.IgnoreCase;
            _options.MatchCasing = MatchCasing.CaseInsensitive;
            StartFromRoot = PathRegex.WinFromRoot();
        }
        else
        {
            _regexOptions &= ~RegexOptions.IgnoreCase;
            _options.MatchCasing = MatchCasing.CaseSensitive;
            StartFromRoot = PathRegex.UnixFromRoot();
        }
    }

    /// <summary>
    /// Searches for files or directories that match the specified pattern within the configured folder.
    /// </summary>
    public IEnumerable<string> Enumerate(string pattern)
    {
        ArgumentException.ThrowIfNullOrEmpty(pattern, "Pattern cannot be null, or empty");

        if (!_fileSystem.Glob().IsMatch(pattern))
            throw new ArgumentException("Invalid glob-pattern.", nameof(pattern));
        if (Enumerated.HasFlag(Enumerated.Files) && pattern.Last() is '/' or '\\')
            throw new ArgumentException("Pattern cannot end with a '/' or '\\' when searching for files.", nameof(pattern));
        if (Enumerated == Enumerated.Files && PathRegex.RecursiveAtEnd().IsMatch(pattern))
            throw new ArgumentException("Pattern cannot end with a recursive wildcard '**' when searching for files.", nameof(pattern));

        _pattern = NormalizePattern(pattern);

        if (DebugOutput)
            Console.WriteLine($"""
                Current directory:          {Directory.GetCurrentDirectory()}
                Enumerate from folder:      {EnumerateFromFolder}
                Searching for:              {Enumerated}
                Matching the pattern:       {pattern}
                    Normalized:             {_pattern}
                """);

        // call the actual search
        return EnumerateImpl(_fromDir, GetFirstComponentRange());
    }

    string NormalizePattern(string pattern)
    {
        var start = 0;
        var end = pattern.Length;
        Span<char> patternSpan = stackalloc char[end];

        pattern.AsSpan().CopyTo(patternSpan);

        var m = StartFromRoot.Match(pattern);   // if it starts with a root or drive like `C:/` or just `/`
        if (m.Success)
        {
            // then ignore EnumerateFromFolder and start from the root
            _fromDir = m.Value;
            start = m.Length;  // skip the root part in the pattern
        }
        else
            _fromDir = EnumerateFromFolder;

        int i = start;
        char prev = '\0';

        for (var j = start; j < end; j++)
        {
            var ch = patternSpan[j];
            var c = ch is WinSepChar ? SepChar : ch;    // convert Windows separators to Unix-style

            if (c is SepChar && prev is SepChar)        // Skip duplicate separators
                continue;

            patternSpan[i++] = c;
            prev = ch;
        }

        return patternSpan[start..i].ToString();
    }

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

        if (DebugOutput)
            Console.WriteLine($"""
                --------------------------------
                searching in:               {dir}
                pattern component:          {component}
                """);

        if (IsLastComponentRange(componentRange))
        {
            if (DebugOutput)
                Console.WriteLine("(last component)");

            // no more components after this one - just list the requested elements to be enumerated in the current directory
            // that match this last component:

            if (Enumerated.HasFlag(Enumerated.Directories))
            {
                var dirs = EnumerateDirectories(dir, component, recursive);

                foreach (var d in dirs)
                    yield return d;
            }

            if (Enumerated.HasFlag(Enumerated.Files))
            {
                var files = EnumerateFiles(dir, component, recursive);

                foreach (var f in files)
                    yield return f;
            }

            yield break;
        }

        var nextRange = GetNextComponentRange(componentRange);

        if (component is RecursiveWildcard)
        {
            if (DebugOutput)
                Console.WriteLine("(from here down we go recursively!)");

            // in the next call "dir" doesn't change, but the search becomes recursive for the pattern components after the "**".
            foreach (var e in EnumerateImpl(dir, nextRange, true))
                yield return e;

            yield break;
        }

        // else, because there are more components after this one, we need to find all *sub-directories*
        // of the current component and continue searching in them

        // find one or more sub-directories that match the current component (if recursive - goes into the sub-trees) and
        // continues searching in all of them
        var subDirs = EnumerateDirectories(dir, component, recursive);

        foreach (var subDir in subDirs)
        {
            // recursively go into the sub-tree and enumerate both files and directories as per the next components
            foreach (var e in EnumerateImpl(subDir, nextRange, recursive))
                yield return e;
        }
    }

    IReadOnlyList<string> EnumerateFiles(string dir, string pattern, bool recursively)
    {
        if (string.IsNullOrEmpty(pattern))
            throw new ArgumentException("Pattern cannot be null or empty.", nameof(pattern));
        if (pattern == RecursiveWildcard)
            throw new ArgumentException("Recursive wildcard '**' is not valid here.", nameof(pattern));

        _options.RecurseSubdirectories = recursively;

        var (pat, rex) = GlobToRegex(pattern);
        var result = _fileSystem
                        .EnumerateFiles(dir, pat, _options)
                        ;

        if (!string.IsNullOrWhiteSpace(rex))
        {
            var regex = new Regex($"(?:^|/){rex}$", _regexOptions | RegexOptions.Compiled);

            result = result
                        .Where(f => regex.IsMatch(f))
                        ;
        }

        var list = result
                        .Select(OsNormalizeFilePath)
                        .ToList()
                        ;

        if (DebugOutput)
        {
            Console.WriteLine($"""
                --------------------------------
                enumerate files in:         {dir}
                input pattern:              {pattern}
                file pattern:               {pat}
                matching regex:             {rex}
                recursively:                {recursively}
                files:
                """);
            list.ForEach(f => Console.WriteLine($"  file: {f}"));
        }

        return list;
    }

    IReadOnlyList<string> EnumerateDirectories(string dir, string pattern, bool recursively)
    {
        if (string.IsNullOrEmpty(pattern))
            throw new ArgumentException("Pattern cannot be null or empty.", nameof(pattern));
        if (pattern == RecursiveWildcard)
            throw new ArgumentException("Recursive wildcard '**' is not valid here.", nameof(pattern));

        _options.RecurseSubdirectories = recursively;

        var (pat, rex) = GlobToRegex(pattern);
        var result = _fileSystem
                        .EnumerateFolders(dir, pat, _options)
                        .Where(d => !(d.EndsWith(CurrentDir) || d.EndsWith(ParentDir)))
                        ;

        if (!string.IsNullOrWhiteSpace(rex))
        {
            var regex = new Regex($"(?:^|/){rex}(?:/|$)", _regexOptions | RegexOptions.Compiled);
            result = result
                        .Where(d => regex.IsMatch(d))
                        ;
        }

        var list = result
                        .Select(OsNormalizeDirPath)
                        .ToList()
                        ;

        if (DebugOutput)
        {
            Console.WriteLine($"""
                --------------------------------
                enumerate directories in:   {dir}
                input pattern:              {pattern}
                directory pattern:          {pat}
                matching regex:             {rex}
                recursively:                {recursively}
                directories:
                """);
            list.ForEach(d => Console.WriteLine($"  dir:  {d}"));
        }

        return list;
    }

    string OsNormalizeDirPath(string dirPath)
    {
        var endsWithSep = dirPath.EndsWith(SepChar);
        var length = dirPath.Length + (endsWithSep ? 0 : 1);
        Span<char> span = stackalloc char[length];

        dirPath.CopyTo(span);
        if (_fileSystem.IsWindows)
            span.Replace(WinSepChar, SepChar);
        if (!endsWithSep)
            span[dirPath.Length] = SepChar;
        return span.ToString();
    }

    string OsNormalizeFilePath(string filePath)
    {
        Memory<char> mem = new(new char[filePath.Length]);

        filePath.CopyTo(mem.Span);
        if (_fileSystem.IsWindows)
            mem.Span.Replace(WinSepChar, SepChar);
        return mem.ToString();
    }
}