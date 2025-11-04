namespace vm2.DevOps.Glob.Api;

using System.Collections.Frozen;
using System.Diagnostics;

/// <summary>
/// Represents a glob pattern searcher.
/// </summary>
public sealed partial class GlobEnumerator
{
    /// <summary>
    /// Represents the character used to separate the drive letter from the dirPath in f system paths.
    /// </summary>
    /// <remarks>Typically used in Windows.</remarks>
    public const char DriveSep = ':';

    /// <summary>
    /// Represents the more popular character used to separate the folders or directories in a dirPath for Windows.
    /// </summary>
    public const char WinSepChar = '\\';    // always converted to '/' - Windows takes both '/' and '\'

    /// <summary>
    /// Represents the character used to separate the folders or directories in a dirPath for both Unix and Windows.
    /// </summary>
    public const char SepChar = '/';

    /// <summary>
    /// Represents the dirPath of the current working directory as a dirPath segment.
    /// </summary>
    public const string CurrentDir = ".";

    /// <summary>
    /// Represents the dirPath of the parent directory of the current working directory as a dirPath segment.
    /// </summary>
    public const string ParentDir = "..";

    /// <summary>
    /// Represents a recursive wildcard pattern that matches all levels of a directory hierarchy from "here" - down.
    /// </summary>
    public const string RecursiveWildcard = "**";

    /// <summary>
    /// Represents the character used to denote an arbitrary sequence in a glob.
    /// </summary>
    public const char SequenceChar        = '*';

    /// <summary>
    /// Represents a string used to denote an arbitrary sequence in a glob.
    /// </summary>
    public const string SequenceWildcard  = "*";

    /// <summary>
    /// Represents a wildcard for any single character in a dirPath.
    /// </summary>
    public const string CharacterWildcard = "?";

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

        if (DebugOutput)
            Console.WriteLine($"""
                Current directory:          {Directory.GetCurrentDirectory()}
                Enumerate from folder:      {EnumerateFromFolder}
                Searching for:              {Enumerated}
                Matching the pattern:       {pattern}
                """);

        var m = StartFromRoot.Match(pattern);  // if it starts with a root or drive like `D:\`, `C:/` or just `/` or `\` then ignore EnumerateFromFolder and start from the root
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
    //    => component.Contains(SequenceWildcard) || component.Contains(CharacterWildcard);

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

    IEnumerable<string> EnumerateFiles(string dir, string pattern, bool recursively)
    {
        if (string.IsNullOrEmpty(pattern))
            throw new ArgumentException("Pattern cannot be null or empty.", nameof(pattern));
        if (pattern == RecursiveWildcard)
            throw new ArgumentException("Recursive wildcard '**' is not valid here.", nameof(pattern));

        _options.RecurseSubdirectories = recursively;

        var (pat, rex) = GlobToRegex(pattern);
        var result = _fileSystem
                        .EnumerateFiles(dir, pat, _options)
                        .Select(OsNormalizeFilePath)
                        ;

        if (!string.IsNullOrWhiteSpace(rex))
        {
            var regex = new Regex($"^{rex}$", _regexOptions);
            result = result.Where(f => regex.IsMatch(f));
        }

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
            foreach (var f in result)
                Console.WriteLine($"f: {f}");
        }

        return result;
    }

    Dictionary<string, Regex> _tempRegexes = [];

    IEnumerable<string> EnumerateDirectories(string dir, string pattern, bool recursively)
    {
        if (string.IsNullOrEmpty(pattern))
            throw new ArgumentException("Pattern cannot be null or empty.", nameof(pattern));
        if (pattern == RecursiveWildcard)
            throw new ArgumentException("Recursive wildcard '**' is not valid here.", nameof(pattern));

        _options.RecurseSubdirectories = recursively;

        var (pat, rex) = GlobToRegex(pattern);
        var result = _fileSystem
                        .EnumerateFolders(dir, pattern, _options)
                        .Where(d => !(d.EndsWith(CurrentDir) || d.EndsWith(ParentDir)))
                        .Select(OsNormalizeDirPath)
                        ;

        var list = result.ToList();

        if (!string.IsNullOrWhiteSpace(rex))
        {
            if (!_tempRegexes.TryGetValue(rex, out var regex))
                _tempRegexes[rex] = regex = new Regex($"(?:^|/){rex}(?:/|$)", _regexOptions | RegexOptions.Compiled);

            list = list.Where(d => regex.IsMatch(d)).ToList();
        }

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
            foreach (var d in list)
                Console.WriteLine($"dir:  {d}");
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

    /// <summary>
    /// Translates a glob pattern to .NET pattern used in EnumerateDirectories and to a regex pattern for final filtering.
    /// </summary>
    /// <param name="glob">The glob to translate.</param>
    /// <returns>A .NET path segment pattern and the corresponding <see cref="Regex"/></returns>
    static (string pattern, string regex) GlobToRegex(string glob)
    {
        Debug.Assert(glob is not RecursiveWildcard, "The recursive wildcard must be processed separately.");

        // shortcut the easy cases
        if (string.IsNullOrWhiteSpace(glob) || glob is SequenceWildcard)
            return (glob, "");
        if (glob is SequenceWildcard)
            return (glob, ".*");
        if (glob is CharacterWildcard)
            return (glob, ".?");

        // find all wildcard matches in the glob
        var matches = PathRegex.ReplaceableWildcard().Matches(glob);

        if (matches.Count == 0)
        {
            var regex = Regex.Escape(glob);
            return (glob, glob!=regex ? regex : ""); // no wildcards
        }

        // the glob can be represented as: (<non-match><match>)*<non-match>, where each element can be empty
        var globSpan = glob.AsSpan();
        var gCur = 0;   // current index in globSpan

        // escape the non-spans and translate the matches to regex equivalents
        Span<char> rexSpan = stackalloc char[4*glob.Length];
        Span<char> patSpan = stackalloc char[4*glob.Length];

        // replace all wildcards with '*'
        foreach (Match match in matches)
        {
            // escape and copy the next non-match
            if (match.Index > gCur)
            {
                var nonMatch = globSpan.Slice(gCur, match.Index);
                var esc = Regex.Escape(nonMatch.ToString());

                esc.CopyTo(rexSpan[rexSpan.Length..]);
                nonMatch.CopyTo(patSpan[patSpan.Length..]);
            }

            // translate the next match in globSpan
            var (pat, rex) = TranslateGlob(match);

            rex.CopyTo(rexSpan[rexSpan.Length..]);
            pat.CopyTo(patSpan[patSpan.Length..]);
        }

        // escape and copy the final non-match
        if (gCur < globSpan.Length)
        {
            var nonMatch = globSpan[gCur..];
            var esc = Regex.Escape(nonMatch.ToString());

            esc.CopyTo(rexSpan[rexSpan.Length..]);
            nonMatch.CopyTo(patSpan[patSpan.Length..]);
        }

        return (patSpan.ToString(), rexSpan.ToString());
    }

    static (string pattern, string regex) TranslateGlob(Match match) => match.Groups[0] switch {
        { Name: PathRegex.SeqWildcardGr } => (SequenceWildcard, ".*"),
        { Name: PathRegex.CharWildcardGr } => (CharacterWildcard, "."),
        { Name: PathRegex.ClassNameGr } nm => (CharacterWildcard, _globClassTranslations[nm.Name]),
        { Name: PathRegex.ClassGr } cl => (CharacterWildcard, TranslateGlobClass(cl.Value)),
        _ => throw new ArgumentException("Invalid glob pattern match.", nameof(match)),
    };

    static readonly FrozenDictionary<string, string> _globClassTranslations =
        FrozenDictionary.ToFrozenDictionary(
            new Dictionary<string, string>()
            {
                ["alnum"]  = @"[\p{L}\p{Nd}\p{Nl}]",
                ["alpha"]  = @"[\p{L}\p{Nl}]",
                ["blank"]  = @"[\p{Zs}\t]",
                ["cntrl"]  = @"\p{Cc}",
                ["digit"]  = @"\d",
                ["graph"]  = @"[\p{L}\p{M}\p{N}\p{P}\p{S}]",
                ["lower"]  = @"[\p{Ll}\p{Lt}\p{Nl}]",
                ["print"]  = @"[\p{S}\p{N}\p{Zs}\p{M}\p{L}\p{P}]",
                ["punct"]  = @"[\p{P}$+<=>^`|~]",
                ["space"]  = @"\s",
                ["upper"]  = @"[\p{Lu}\p{Lt}\p{Nl}]",
                ["xdigit"] = @"[0-9A-Fa-f]",
            });

    static string TranslateGlobClass(string glClass)
    {
        if (glClass[0] is not ('!' or ']'))
            return glClass;

        Span<char> clSpan = stackalloc char[glClass.Length + 1];
        var nG = 0;
        var nC = 0;

        if (glClass[nG] is '!')
        {
            nG++;
            clSpan[nC++] = '^';
        }

        if (glClass[nG] is ']')
        {
            nG++;
            clSpan[nC++] = '\\';
            clSpan[nC++] = ']';
        }

        glClass.AsSpan(nG).CopyTo(clSpan[nC..]);
        return clSpan.ToString();
    }
}