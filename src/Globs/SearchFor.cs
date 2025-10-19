namespace vm2.DevOps.Globs;

/// <summary>
/// Specifies the type of items to search for in searcher.
/// </summary>
[Flags]
public enum SearchFor
{
    /// <summary>
    /// Search for files only.
    /// </summary>
    Files       = 1 << 0,

    /// <summary>
    /// Search for directories only.
    /// </summary>
    Directories = 1 << 1,

    /// <summary>
    /// Search for both files and directories.
    /// </summary>
    Both        = Files | Directories,
}
