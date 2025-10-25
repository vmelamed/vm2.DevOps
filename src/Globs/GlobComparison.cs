namespace vm2.DevOps.Globs;

/// <summary>
/// Specifies the comparison rules to use when evaluating glob patterns.
/// </summary>
public enum GlobComparison
{
    /// <summary>
    /// The comparison rules are based on the current platform.
    /// </summary>
    Default,

    /// <summary>
    /// Equivalent to <see cref="StringComparison.Ordinal"/>.
    /// </summary>
    Ordinal,

    /// <summary>
    /// Equivalent to <see cref="StringComparison.OrdinalIgnoreCase"/>.
    /// </summary>
    OrdinalIgnoreCase,

    /// <summary>
    /// Equivalent to <see cref="StringComparison.Ordinal"/>.
    /// </summary>
    Unix = Ordinal,

    /// <summary>
    /// Equivalent to <see cref="StringComparison.OrdinalIgnoreCase"/>.
    /// </summary>
    Windows = OrdinalIgnoreCase,
}
