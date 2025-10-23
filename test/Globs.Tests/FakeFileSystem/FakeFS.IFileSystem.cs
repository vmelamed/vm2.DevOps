namespace vm2.DevOps.Globs.Tests.FakeFileSystem;

/// <summary>
/// Fake file system loaded from a JSON representation.
/// </summary>
/// <remarks>
/// We use the term "folder" instead of "directory" in classes and method names to avoid confusion with the .NET class
/// <see cref="Directory"/>.
/// </remarks>
public sealed partial class FakeFS : IFileSystem
{
    Func<string, bool> GetSegmentMatcher(string segment)
    {
        if (segment is RecursiveWildcard || !segment.AsSpan().ContainsAny(Wildcards))
            return a => Comparer.Compare(a, segment) == 0;

        var regex = new Regex(
                            Regex.Escape(segment.ToString()).Replace(@"\*", ".*").Replace(@"\?", "."),  // TODO: add [], {}, etc. advanced patterns
                            RegexOptions.Compiled | (IsWindows ? RegexOptions.IgnoreCase : RegexOptions.None));

        return regex.IsMatch;
    }

    public bool IsWindows { get; private set; }

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

        do
        {
            foreach (var sub in folder.Folders)
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
            foreach (var f in folder.Files)
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
        if (string.IsNullOrEmpty(pattern))
            // the name of no folder matches empty pattern
            return (null, null);

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
        return (GetSegmentMatcher(pattern), folder);
    }
}
