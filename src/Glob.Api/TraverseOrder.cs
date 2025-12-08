namespace vm2.DevOps.Glob.Api;

/// <summary>
/// Specifies the order in which directories are traversed during glob enumeration.
/// </summary>
public enum TraverseOrder
{
    /// <summary>
    /// Specifies breadth-first traversal, where all entries at the current level are visited before descending into their children.
    /// </summary>
    BreadthFirst,
    /// <summary>
    /// Specifies depth-first traversal, where directories are fully explored before moving on to sibling directories.
    /// </summary>
    DepthFirst
};
