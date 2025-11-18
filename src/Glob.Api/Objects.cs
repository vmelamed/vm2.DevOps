namespace vm2.DevOps.Glob.Api;

/// <summary>
/// Specifies the type of items to search for in searcher.
/// </summary>
[Flags]
public enum Objects
{
    /// <summary>
    /// Enumerate files only.
    /// </summary>
    Files                 = 1 << 0,

    /// <summary>
    /// Enumerate directories only.
    /// </summary>
    Directories           = 1 << 1,

    /// <summary>
    /// Enumerate both files and directories.
    /// </summary>
    FilesAndDirefctories  = Files | Directories,
}
