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

    #region IFileSystem Members
    public bool IsWindows { get; private set; }

    public bool FolderExists(string path)
    {
        var (folder, file) = FromPath(path);

        return folder is not null && file is null;
    }

    public bool FileExists(string path)
    {
        if (path.EndsWith(SepChar))
            return false;   // A path to a file cannot end with a separator

        var (_, file) = FromPath(path);

        return file is not null;
    }

    public string GetFullPath(string path)
    {
        ValidatePath(path);

        var nPath = NormalizePath(path);

        if (IsRoot(nPath))
            return RootFolder.Name;

        var (folder, fileName) = FromPath(path);

        if (folder is null)
            throw new ArgumentException("Path not found in the JSON file system.", nameof(path));

        if (fileName is not null)
            return folder.Path + fileName;

        return folder.Path;
    }

    public IEnumerable<string> EnumerateFolders(
        string path,
        string pattern,
        EnumerationOptions options)
    {
        if (string.IsNullOrEmpty(pattern))
            // the name of no folder matches empty pattern
            yield break;

        // normalize the pattern and split into path and pattern
        pattern = (IsWindows ? pattern.Replace(WinSepChar, SepChar) : pattern);
        var i = pattern.LastIndexOf(SepChar);

        if (i >= 0)
        {
            // append the pattern path to the given path
            path = path + (path is "" ? "" : SepChar) + pattern[..i];   // it is possible to get more than 1 separators in path but FromPath(path) will normalize it
            pattern = pattern[(i + 1)..];                               // pattern is the last segment
        }

        var (folder, _) = FromPath(path);

        if (folder is null)
            // path - no such folder
            yield break;

        // enumerate the folders from this folder's sub-tree
        Queue<Folder> unprocessedNodes = new([folder]);
        var matchesPattern = GetSegmentMatcher(pattern);

        while (unprocessedNodes.Count > 0)
        {
            // remove the next unprocessed folder from the queue
            folder = unprocessedNodes.Dequeue();
            foreach (var dir in folder.Folders)
            {
                if (options.RecurseSubdirectories)
                    // add its sub-folders to the queue of unprocessed unprocessedNodes
                    foreach (var d in dir.Folders)
                        unprocessedNodes.Enqueue(d);

                if (matchesPattern(dir.Name))
                    yield return dir.Path;
            }
        }
    }

    public IEnumerable<string> EnumerateFiles(
        string path,
        string pattern,
        EnumerationOptions options)
    {
        if (string.IsNullOrEmpty(pattern))
            // the name of no file matches empty pattern
            yield break;

        // normalize the pattern and split into path and pattern
        pattern = (IsWindows ? pattern.Replace(WinSepChar, SepChar) : pattern);
        var i = pattern.LastIndexOf(SepChar);

        if (i >= 0)
        {
            path = path + (path is "" ? "" : SepChar) + pattern[..i];   // it is possible to get more than 1 separators in path but FromPath(path) will normalize it
            pattern = pattern[(i + 1)..];                               // pattern is the last segment
        }

        var (folder, _) = FromPath(path);

        if (folder is null)
            // path - no such folder
            yield break;

        Queue<Folder> unprocessedNodes = new([folder]);
        var matchesPattern = GetSegmentMatcher(pattern);

        while (unprocessedNodes.Count > 0)
        {
            folder = unprocessedNodes.Dequeue();
            foreach (var dir in folder.Folders)
            {
                if (options.RecurseSubdirectories)
                    foreach (var d in dir.Folders)
                        unprocessedNodes.Enqueue(d);

                foreach (var f in dir.Files)
                    if (matchesPattern(f))
                        yield return dir.Path;
            }
        }
    }
    #endregion
}
