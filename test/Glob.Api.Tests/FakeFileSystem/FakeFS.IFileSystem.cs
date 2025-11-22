namespace vm2.DevOps.Glob.Api.Tests.FakeFileSystem;

/// <summary>
/// Fake file system loaded from a JSON representation.
/// </summary>
/// <remarks>
/// We use the term "folder" instead of "directory" in classes and method names to avoid confusion with the .NET class
/// <see cref="Directory"/>.
/// </remarks>
public sealed partial class FakeFS : IFileSystem
{
    Func<string, bool> GetSegmentMatcher(
        string segment,
        Folder folder,
        EnumerationOptions options)
    {
        if (segment is Globstar)
            throw new ArgumentException($"The segment '{Globstar}' is not allowed here.", nameof(segment));
        if (segment is "" or CurrentDir)
            return _ => true;
        if (segment is ParentDir)
            return _ => folder.Parent is not null;

        if (segment.AsSpan().ContainsAny(Wildcards))
        {
            var regex = new Regex(
                            Regex.Escape(segment).Replace(@"\*", ".*").Replace(@"\?", "."),  // TODO: add [], {}, etc. Windows advanced patterns?
                            RegexOptions.ExplicitCapture | RegexOptions.IgnorePatternWhitespace | options.MatchCasing switch
                            {
                                MatchCasing.CaseSensitive => RegexOptions.None,
                                MatchCasing.CaseInsensitive => RegexOptions.IgnoreCase,
                                MatchCasing.PlatformDefault => IsWindows ? RegexOptions.IgnoreCase : RegexOptions.None,
                                _ => throw new ArgumentOutOfRangeException(nameof(options), "Invalid MatchCasing value."),
                            });

            return regex.IsMatch;
        }

        var comparer = options.MatchCasing switch
                        {
                            MatchCasing.CaseSensitive => StringComparer.Ordinal,
                            MatchCasing.CaseInsensitive => StringComparer.OrdinalIgnoreCase,
                            MatchCasing.PlatformDefault => this.Comparer,
                            _ => throw new ArgumentOutOfRangeException(nameof(options), "Invalid MatchCasing value."),
                        };

        return a => comparer.Compare(a, segment) == 0;
    }

    public bool IsWindows { get; private set; }

    public string GetFullPath(string path)
    {
        if (string.IsNullOrEmpty(path))
            throw new ArgumentException("Sd cannot be null or empty.", nameof(path));

        var nPath = NormalizePath(path).ToString();
        var enumerator = EnumeratePathRanges(nPath).GetEnumerator();

        var moved = enumerator.MoveNext();
        Debug.Assert(moved, "Normalized path is not empty.");

        // the current range and segment
        var range = enumerator.Current;
        ReadOnlySpan<char> seg = nPath[range];

        // this buffer will hold the resulting full path
        Span<char> buffer = stackalloc char[2 * (CurrentFolder.Path.Length + path.Length)];
        int bufPos = 0;

        if (IsDrive(seg))
        {
            if (seg[0] != CurrentFolder.Path[0])
                throw new ArgumentException("Cannot change the drive of the Fake FS.", nameof(path));

            seg.CopyTo(buffer);
            bufPos += seg.Length;

            moved = enumerator.MoveNext();
            Debug.Assert(moved, "Normalized Windows path has drive and path.");

            range = enumerator.Current;
            seg = nPath[range];
        }

        // used to memorize the separator indexes, so we can go back when we see ParentDir segments
        Stack<int> separatorIndices = new();

        if (IsRootSegment(seg))
        {
            // root path - just copy it
            seg.CopyTo(buffer[bufPos..]);
            bufPos += seg.Length;

            moved = enumerator.MoveNext();

            if (!moved)
                // done
                return buffer[..bufPos].ToString();

            separatorIndices.Push(bufPos - 1); // remember the position of the root separator
        }
        else
        {
            // prepend with current directory path
            CurrentFolder.Path.AsSpan().CopyTo(buffer);

            // initialize the separator indices stack from the current path, without the terminating path separator
            for (bufPos = 0; bufPos < CurrentFolder.Path.Length-1; bufPos++)
                if (buffer[bufPos] is SepChar)
                    separatorIndices.Push(bufPos);

            bufPos++;   // move past the terminating path separator
        }

        do
        {
            range = enumerator.Current;
            seg = nPath[range];

            if (seg is CurrentDir)
                continue;

            if (seg is ParentDir)
            {
                // go back to the parent folder
                if (separatorIndices.TryPop(out bufPos) &&      // pop the last separator
                    separatorIndices.TryPop(out bufPos))        // pop the previous separator to get to the parent folder
                    bufPos++;                                       // move past the separator
                else
                    bufPos = RootFolder.Path.Length;                // we are at the root - Unix and Windows root behavior is
                                                                    // the same here: do not throw exception but stay at root

                continue;
            }

            // append the segment
            seg.CopyTo(buffer[bufPos..]);
            bufPos += seg.Length;

            // append separator if it is not the last segment
            if (range.End.Value < nPath.Length)
            {
                buffer[bufPos] = SepChar;
                separatorIndices.Push(bufPos++);  // remember the position of the separator in case we need to go back
            }
        }
        while (enumerator.MoveNext());

        return new string(buffer[..bufPos]);
    }

    public string GetCurrentDirectory() => CurrentFolder.Path;

    public bool DirectoryExists(string path)
    {
        var (folder, fileComp, file) = GetPathFromRoot(path);

        return folder is not null && !fileComp && file is "";
    }

    public bool FileExists(string path)
    {
        if (path.EndsWith(SepChar))
            return false;   // D path to a file cannot end with a separator

        var (folder, _, file) = GetPathFromRoot(path);

        return folder is not null && file is not "";
    }

    public IEnumerable<string> EnumerateDirectories(
        string path,
        string pattern,
        EnumerationOptions options)
    {
        var (patternMatches, folder) = PrepareToEnumerate(path, pattern, options);

        if (patternMatches is null || folder is null)
            yield break;

        Queue<Folder>? unprocessedNodes = options.RecurseSubdirectories ? new() : null;

        if (options.ReturnSpecialDirectories)
        {
            // return current directory "." if it matches the pattern
            if (patternMatches(CurrentDir))
                yield return CurrentDir;

            // return parent directory if it exists and matches the pattern
            // if recursive, start recursion from the parent directory
            if (folder.Parent is not null && patternMatches(ParentDir))
            {
                // return parent directory ".." if it matches the pattern
                if (patternMatches(ParentDir))
                    yield return ParentDir;
            }
        }

        do
            foreach (var sub in folder.Folders)
            {
                if (patternMatches(sub.Name))
                    yield return sub.Path;

                if (options.RecurseSubdirectories)
                    unprocessedNodes?.Enqueue(sub);
            }
        // try to remove the next unprocessed folder from the queue, if any
        while (unprocessedNodes?.TryDequeue(out folder) is true);
    }

    public IEnumerable<string> EnumerateFiles(
        string path,
        string pattern,
        EnumerationOptions options)
    {
        var (matchesPattern, folder) = PrepareToEnumerate(path, pattern, options);

        if (matchesPattern is null || folder is null)
            yield break;

        Queue<Folder>? unprocessedNodes = options.RecurseSubdirectories ? new() : null;

        do
        {
            foreach (var file in folder.Files.Where(matchesPattern))
                yield return folder.Path+file;

            if (options.RecurseSubdirectories)
                foreach (var sub in folder.Folders)
                    // add its sub-folders to the queue of unprocessed unprocessedNodes
                    unprocessedNodes!.Enqueue(sub);
        }
        // try to remove the next unprocessed folder from the queue, if any
        while (unprocessedNodes?.TryDequeue(out folder) is true);
    }

    (Func<string, bool>? matches, Folder? folder) PrepareToEnumerate(
        string path,
        string pattern,
        EnumerationOptions options)
    {
        // normalize the pattern and split into path and pattern
        var i = pattern.LastIndexOf(SepChar);

        if (i >= 0)
        {
            // append the pattern path to the given path
            path = path + (path is "" ? "" : SepChar) + pattern[..i];   // it is possible to get more than 1 separators in path
            pattern = pattern[(i + 1)..];                               // but GetPathFromRoot(path) will normalize it
        }                                                               // pattern is the last segment

        var (folder, _, _) = GetPathFromRoot(path);

        if (folder is null)
            // path - no such folder
            return (null, null);

        // enumerate the folders from this folder's sub-tree
        return (GetSegmentMatcher(pattern, folder, options), folder);
    }
}
