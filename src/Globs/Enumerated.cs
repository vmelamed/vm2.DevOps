namespace vm2.DevOps.Globs;

/// <summary>
/// Specifies the type of items to search for in searcher.
/// </summary>
[Flags]
public enum Enumerated
{
    /// <summary>
    /// EnumerateImpl for files only.
    /// </summary>
    Files       = 1 << 0,

    /// <summary>
    /// EnumerateImpl for directories only.
    /// </summary>
    Directories = 1 << 1,

    /// <summary>
    /// EnumerateImpl for both files and directories.
    /// </summary>
    Both        = Files | Directories,
}
