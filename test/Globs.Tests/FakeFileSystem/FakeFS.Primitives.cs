namespace vm2.DevOps.Glob.Api.Tests.FakeFileSystem;
/// <summary>
/// Fake file system loaded from a JSON representation.
/// </summary>
/// <remarks>
/// We use the term "folder" instead of "directory" in classes and method names to avoid confusion with the .NET class
/// <see cref="Directory"/>.
/// </remarks>
public sealed partial class FakeFS
{
    bool IsDrive(ReadOnlySpan<char> segment)
        => IsWindows && segment.Length == WinDriveLength && char.IsAsciiLetter(segment[0]) && segment[1] == DriveSep;

    bool StartsWithDrive(ReadOnlySpan<char> segment)
        => IsWindows && segment.Length >= WinDriveLength && char.IsAsciiLetter(segment[0]) && segment[1] == DriveSep;

    bool IsRoot(ReadOnlySpan<char> segment)
        => IsWindows
                ? segment.Length == WinRootLength && char.IsAsciiLetter(segment[0]) && segment[1] == DriveSep && segment[2] == SepChar
                : segment.Length == 1 && segment[0] == SepChar;

    bool StartsWithRoot(ReadOnlySpan<char> path)
        => IsWindows
                ? path.Length >= WinRootLength && char.IsAsciiLetter(path[0]) && path[1] == DriveSep && path[2] == SepChar
                : path.Length >= 1 && path[0] == SepChar;

    static bool IsRootSegment(ReadOnlySpan<char> segment)
        => segment.Length == 1 && segment[0] == SepChar;

    /// <summary>
    /// Normalizes the given segment:
    /// <list type="bullet">
    ///     <item>converts backslashes to slashes</item>
    ///     <item>removes duplicate separators</item>
    ///     <item>for Windows, converts drive letter to uppercase</item>
    ///     <item>for Windows, prepends segment with current drive letter from the current path and colon if missing</item>
    /// </list>
    /// </summary>
    /// <param name="path"></param>
    /// <returns>Span of bytes with normalized segment separators</returns>
    ReadOnlySpan<char> NormalizePath(string path)
    {
        if (path.Length == 0)
            return [];

        if (path is CurrentDir)
            return CurrentFolder.Path;
        if (path is ParentDir)
            return CurrentFolder.Parent?.Path
                        ?? throw new ArgumentException("Pattern does not exist.", nameof(path));

        Span<char> buffer = new Memory<char>(new char[path.Length+WinDriveLength]).Span;
        int start = 2;  // leave space for drive letter and colon if needed
        int i = start;
        char prev = '\0';

        foreach (var ch in path)
        {
            var c = ch is WinSepChar ? SepChar : ch;
            if (c == prev && c == SepChar)
                continue;   // Skip duplicate separators
            buffer[i++] = c;
            prev = ch;
        }

        var pathBuf = buffer[start..i];

        if (!IsWindows)
            return pathBuf; // Unix segment: abc/def or /abc/def

        if (StartsWithDrive(pathBuf))
        {
            // "c:/abc/def" or "c:abc/def" => "C:/abc/def" or "C:abc/def"
            pathBuf[0] = char.ToUpperInvariant(pathBuf[0]);
            return pathBuf;
        }

        // "/abc/def" => "C:/abc/def"
        // "abc/def"  => "C:abc/def"
        buffer[0] = (CurrentFolder ?? RootFolder).Path[0];
        buffer[1] = DriveSep;
        return buffer[..i];
    }

    /// <summary>
    /// Enumerates the ranges of segments (the segment tokens) in the given NORMALIZED segment span.
    /// </summary>
    /// <param name="path">The segment to enumerate.</param>
    /// <returns>The ranges of segments in the segment.</returns>
    IEnumerable<Range> EnumeratePathRanges(string path)
    {
        var i = 0;

        if (StartsWithDrive(path))
        {
            i = 2;
            yield return new Range(0, i);               // "C:" if Windows
        }

        if (path.Length > i && path[i] is SepChar)
            yield return new Range(i, ++i);             // the first "/" - root

        var j = i;

        for (; j < path.Length; j++)
            if (path[j] is SepChar)
            {
                yield return new Range(i, j);           // "abc", "def", etc.
                i = j+1 < path.Length ? j+1 : j;
            }

        if (i < j)
            yield return new Range(i, j);               // the last segment "xyz", or the trailing "/"
    }
}
