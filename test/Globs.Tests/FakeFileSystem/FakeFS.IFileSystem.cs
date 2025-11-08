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
    Func<string, bool> GetSegmentMatcher(string segment, Folder folder)
    {
        if (segment is RecursiveWildcard)
            throw new ArgumentException($"The segment '{RecursiveWildcard}' is not allowed here.", nameof(segment));
        if (segment is "" or CurrentDir)
            return _ => true;
        if (segment is ParentDir)
            return _ => folder.Parent is not null;
        if (!segment.AsSpan().ContainsAny(Wildcards))
            return a => Comparer.Compare(a, segment) == 0;

        var regex = new Regex(
                            Regex.Escape(segment.ToString()).Replace(@"\*", ".*").Replace(@"\?", "."),  // TODO: add [], {}, etc. advanced patterns
                            RegexOptions.Compiled | (IsWindows ? RegexOptions.IgnoreCase : RegexOptions.None));

        return regex.IsMatch;
    }

    public bool IsWindows { get; private set; }

    public string GetFullPath(string path)
    {
        if (string.IsNullOrEmpty(path))
            throw new ArgumentException("Path cannot be null or empty.", nameof(path));

        var nPath = NormalizePath(path).ToString();
        var enumerator = EnumeratePathRanges(nPath).GetEnumerator();

        var moved = enumerator.MoveNext();
        Debug.Assert(moved, "Normalized path is not empty.");

        // the current range and segment
        var range = enumerator.Current;
        ReadOnlySpan<char> seg = nPath[range];

        // this buffer will hold the resulting full path
        Span<char> buffer = stackalloc char[CurrentFolder.Path.Length + path.Length + 1];
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

        Stack<int> separatorIndices = new();    // used to go back when we see ParentDir segments

        if (IsRootSegment(seg))
        {
            // root path - just copy it
            seg.CopyTo(buffer[bufPos..]);
            bufPos += seg.Length;
            moved = enumerator.MoveNext();

            if (!moved)
                // done
                return new string(buffer[..bufPos]);
        }
        else
        {
            // prepend with current directory path
            CurrentFolder.Path.AsSpan().CopyTo(buffer);

            // initialize the separator indices stack from the current path, skipping the terminating path separator
            for (bufPos = 0; bufPos < CurrentFolder.Path.Length-1; bufPos++)
                if (buffer[bufPos] is SepChar)
                    separatorIndices.Push(bufPos);

            bufPos++;   // move past the terminating separator
        }

        do
        {
            range = enumerator.Current;
            seg = nPath[range];

            if (seg is CurrentDir)
                continue;

            if (seg is ParentDir)
            {
                // go back to the previous folder
                if (!separatorIndices.TryPop(out bufPos))
                    throw new ArgumentException("Path goes above the root folder.", nameof(path));

                bufPos++;   // move past the separator
                continue;
            }

            // append the segment
            seg.CopyTo(buffer[bufPos..]);
            bufPos += seg.Length;

            // append separator if not the last segment
            if (range.End.Value < nPath.Length)
            {
                buffer[bufPos++] = SepChar;
                separatorIndices.Push(bufPos);
            }
        }
        while (enumerator.MoveNext());

        return new string(buffer[..bufPos]);
    }

    public string GetCurrentDirectory() => CurrentFolder.Path;

    public bool FolderExists(string path)
    {
        var (folder, fileComp, file) = GetPathFromRoot(path);

        return folder is not null && !fileComp && file is "";
    }

    public bool FileExists(string path)
    {
        if (path.EndsWith(SepChar))
            return false;   // A path to a file cannot end with a separator

        var (folder, _, file) = GetPathFromRoot(path);

        return folder is not null && file is not "";
    }

    public IEnumerable<string> EnumerateFolders(
        string path,
        string pattern,
        EnumerationOptions options)
    {
        var (matchesPattern, folder) = PrepareToEnumerate(path, pattern);

        if (matchesPattern is null || folder is null)
            yield break;

        Queue<Folder>? unprocessedNodes = options.RecurseSubdirectories ? new() : null;

        // return current and parent directories if they match the pattern
        if (matchesPattern(CurrentDir))
            yield return CurrentDir;
        if (folder.Parent is not null &&
            matchesPattern(ParentDir))
            yield return ParentDir;

        do
        {
            var folders = folder.Folders; // snapshot of the current folders

            foreach (var sub in folders)
            {
                if (options.RecurseSubdirectories)
                    // add its sub-folders to the queue of unprocessed unprocessedNodes
                    foreach (var d in sub.Folders)
                        unprocessedNodes!.Enqueue(d);

                if (matchesPattern(sub.Name))
                    yield return sub.Path;
            }

            if ((unprocessedNodes?.Count ?? 0) > 0)
            {
                folder = unprocessedNodes!.Dequeue();
                if (matchesPattern(folder.Name))
                    yield return folder.Path;
            }
            else
                break;
        }
        // try to remove the next unprocessed folder from the queue, if any
        while (true);
    }

    public IEnumerable<string> EnumerateFiles(
        string path,
        string pattern,
        EnumerationOptions options)
    {
        var (matchesPattern, folder) = PrepareToEnumerate(path, pattern);

        if (matchesPattern is null || folder is null)
            yield break;

        Queue<Folder>? unprocessedNodes = options.RecurseSubdirectories ? new() : null;

        do
        {
            var files = folder.Files.ToList(); // snapshot of the current files

            foreach (var f in files)
                if (matchesPattern(f))
                    yield return folder.Path+f;

            if (options.RecurseSubdirectories)
                foreach (var sub in folder.Folders)
                    // add its sub-folders to the queue of unprocessed unprocessedNodes
                    unprocessedNodes!.Enqueue(sub);

            if ((unprocessedNodes?.Count ?? 0) > 0)
                folder = unprocessedNodes!.Dequeue();
            else
                break;
        }
        // try to remove the next unprocessed folder from the queue, if any
        while (true);
    }

    (Func<string, bool>? matches, Folder? folder) PrepareToEnumerate(
        string path,
        string pattern)
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
        return (GetSegmentMatcher(pattern, folder), folder);
    }
}
