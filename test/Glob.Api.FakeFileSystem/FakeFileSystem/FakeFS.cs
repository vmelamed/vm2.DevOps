// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Val Melamed

namespace vm2.DevOps.Glob.Api.FakeFileSystem;

/// <summary>
/// This class implements the interface <see cref="IFileSystem"/> used by <see cref="GlobEnumerator"/> but instead of real
/// directories and files it has a tree of memory nodes called <see cref="Folder"/>-s. The folders  have sets of strings that
/// represent the names of the files in those folders. This structure can be easily represented, serialized and deserialized to
/// and from JSON files.
/// <para/>
/// The file system structure can be created also from a text files that contain the full paths of all files in a real
/// file system (or subtree thereof). Many files can be created to emulate various structure of file system for testing the
/// <see cref="GlobEnumerator"/> against.
/// </summary>
/// <remarks>
/// We use the term "folder" instead of "directory" in the code of the FakeFS classes to avoid confusion with the .NET class
/// <see cref="Directory"/> and explicit namespace qualifying.
/// </remarks>
public sealed partial class FakeFS
{
    #region constants
    const string Wildcards     = "*?";  // TODO: add [], {}, etc. advanced features
    const string Globstar      = "**";

    const int WinDriveLength   = 2;     // e.g. "C:"
    const int WinRootLength    = 3;     // e.g. "C:/"
    #endregion

    #region Properties
    /// <summary>
    /// The root of the file system tree.
    /// </summary>
    public Folder RootFolder { get; private set; } = Folder.Default;

    /// <summary>
    /// The current working directory (folder) in the file system tree.
    /// </summary>
    public Folder CurrentFolder { get; private set; } = Folder.Default;
    #endregion

    /// <summary>
    /// Initializes a new instance of the <see cref="FakeFS"/> class from a byte array that contains the JSON or text description
    /// of the fake file system.
    /// </summary>
    /// <param name="data">The byte array containing the file data.</param>
    /// <param name="dataType">The type of data contained in the file.</param>
    public FakeFS(string fileName, DataType dataType = DataType.Default)
        => Initialize(fileName, dataType);

    /// <summary>
    /// Initializes the fake file system from a JSON or text file.
    /// </summary>
    /// <param name="fileName">The name of the file to read the fake file system from.</param>
    /// <param name="dataType">The type of data contained in the file.</param>
    /// <returns></returns>
    /// <exception cref="NotSupportedException"></exception>
    public FakeFS Initialize(string fileName, DataType dataType = DataType.Default)
    {
        string text;

        (dataType, text) = GetFileSystemData(fileName, dataType);
        _ = dataType switch {
            DataType.Json => FromJson(text),
            DataType.Text => FromText(text),
            _ => throw new NotSupportedException("The data type must be either Json or Text."),
        };

        Debug.Assert(RootFolder is not null);

        return this;
    }

    /// <summary>
    /// Sets the current folder to the specified path in the fake file system.
    /// </summary>
    /// <param name="pathName"></param>
    /// <returns></returns>
    /// <exception cref="ArgumentException"></exception>
    public Folder SetCurrentFolder(string pathName)
    {
        var pathAndFile = GetPathFromRoot(pathName);

        if (pathAndFile.Folder is null)
            throw new ArgumentException($"GlobRegex '{pathName}' not found in the JSON file system.", nameof(pathName));
        if (pathAndFile.HasFileComponent)
            throw new ArgumentException($"The current folder '{pathName}' path points to a file name, not a folder.", nameof(pathName));

        return CurrentFolder = pathAndFile.Folder;
    }

    /// <summary>
    /// Represents the path from the root folder to a specific folder or file in the fake file system.
    /// </summary>
    /// <param name="Folder">The folder at the end of the path.</param>
    /// <param name="HasFileComponent">Indicates if the path includes a file component.</param>
    /// <param name="FileName">The name of the file, if applicable.</param>
    public record struct PathAndFile(Folder Folder, bool HasFileComponent = false, string FileName = "");

    /// <summary>
    /// Validates and gets the path from the root folder to a specific folder or file in the fake file system.
    /// </summary>
    /// <param name="path">The path to validate and resolve. The path can be relative to the current folder.</param>
    /// <returns></returns>
    /// <exception cref="ArgumentException">
    /// Thrown if a Windows-like path starts with a drive letter different from the root folder's drive letter. A fake Windows
    /// -like file system has a single drive letter for its root folder.
    /// </exception>
    public PathAndFile GetPathFromRoot(string path)
    {
        ValidatePath(path);

        var nPath      = NormalizePath(path).ToString();
        var enumerator = EnumeratePathRanges(nPath).GetEnumerator();
        var folder     = CurrentFolder;

        if (!enumerator.MoveNext())
            return new PathAndFile(folder);

        var range = enumerator.Current;
        var seg = nPath[range];
        if (IsDrive(seg))
        {
            if (seg[0] != RootFolder.Name[0])
                throw new ArgumentException($"The path '{path}' has a different drive letter than the JSON fileName system root.");

            // consume it
            if (!enumerator.MoveNext())
                return new PathAndFile(CurrentFolder);
            range = enumerator.Current;
            seg = nPath[range];
        }


        if (IsRootSegment(seg))
        {
            folder = RootFolder;

            // consume it
            if (!enumerator.MoveNext())
                return new PathAndFile(folder);
            range = enumerator.Current;
            seg = nPath[range];
        }

        do
        {
            if (!IsRootSegment(seg))
            {
                var name = seg.ToString();
                var nextFolder = folder.HasFolder(name);

                if (nextFolder is null)
                {
                    if (enumerator.MoveNext())
                        // there are more segments in the path that are not matched, i.e. it is not found
                        return new PathAndFile();

                    // if it is the last segment, test if it is a fileName in this folder
                    name = folder.HasFile(name) ?? "";
                    return new PathAndFile(folder, true, name);
                }
                folder = nextFolder;
            }

            if (!enumerator.MoveNext())
                break;

            range = enumerator.Current;
            seg = nPath[range];
        }
        while (true);

        return new PathAndFile(folder);
    }

    static (bool isWindows, string root) DetectOS(string line)
    {
        var m = StartsWithWinRoot().Match(line);

        if (m.Success)
        {
            if (!WindowsPathRegex().IsMatch(line))
                throw new ArgumentException($"The Windows path format '{line}' is invalid.", nameof(line));
            return (true, m.Value.ToUpper().Replace(WinSepChar, SepChar));
        }

        if (line.StartsWith(SepChar))
        {
            if (!UnixPathRgex().IsMatch(line))
                throw new ArgumentException($"The Unix path format '{line}' is invalid.", nameof(line));
            return (false, SepChar.ToString());
        }

        throw new ArgumentException(@"Root must be either ""/"" for Unix-like fileName system, or ""<drive ASCII letter>:\"" (e.g. ""C:\"" or ""C:/"") for Windows.");
    }

    void ValidatePath(string path)
    {
        if (!this.PathRegex().IsMatch(path))
            throw new ArgumentException($"The '{path}' is invalid path.", nameof(path));
    }

    static void ValidateOSPath(string path)
    {
        if (!(OperatingSystem.PathRegex().IsMatch(path)))
            throw new ArgumentException($"The '{path}' is invalid path.", nameof(path));
    }
}