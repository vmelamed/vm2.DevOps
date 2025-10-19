namespace vm2.DevOps.Globs.Tests.FakeFileSystem;
using System.Globalization;

using System.Text;

/// <summary>
/// Fake fileName system loaded from a JSON representation.
/// </summary>
/// <remarks>
/// We use the term "folder" instead of "directory" in classes and method names to avoid confusion with the .NET class
/// <see cref="Directory"/>.
/// </remarks>
public sealed partial class FakeFS : IFileSystem
{
    public const char DriveSep = ':';
    public const char WinSepChar = '\\';    // always converted to '/' - Windows takes both '/' and '\'
    public const char SepChar = '/';
    public const string SepString = "/";
    const string Wildcards = "*?"; // TODO: add [], {}, etc. advanced
    const string RecursiveWildcard = "**";
    const int WinDriveLength = 2; // e.g. "C:"
    const int WinRootLength = 3; // e.g. "C:/"

    /// <summary>
    /// Indicates whether the file system was read from JSON with UTF-8 BOM, also used when writing back to file.
    /// </summary>
    public bool JsonUtf8Bom { get; set; } = false;

    [GeneratedRegex(@"^([A-Z]:/|[A-Z]:\\|/|\\)", RegexOptions.IgnoreCase)]
    public static partial Regex StartsWithWinRootRegex();

    public Folder RootFolder { get; private set; }

    public Folder CurrentFolder { get; private set; }

    public StringComparer Comparer { get; private set; }

    public FakeFS(byte[] json)
    {
        FromJson(json);

        Debug.Assert(RootFolder is not null);
        Debug.Assert(Comparer is not null);

        CurrentFolder = RootFolder;
    }

    public FakeFS(string text)
    {
        using var reader = new StringReader(text);
        FromText(reader);

        Debug.Assert(RootFolder is not null);
        Debug.Assert(Comparer is not null);

        CurrentFolder = RootFolder;
    }

    public FakeFS(string fileName, DataFileType fileType)
    {
        var m = OperatingSystem.IsWindows()
                    ? PathRegex.WindowsPath().Match(fileName)
                    : PathRegex.UnixPath().Match(fileName);

        if (!m.Success)
            throw new ArgumentException($"The path name '{fileName}' format is invalid.", nameof(fileName));
        if (!File.Exists(fileName))
            throw new FileNotFoundException($"HasFile '{fileName}' not found.", fileName);

        if (fileType is DataFileType.Default)
        {
            var file = m.Groups[PathRegex.FileGr].ValueSpan;
            var si = file.LastIndexOf('.');

            if (si is <0)
                throw new ArgumentException($"Cannot determine the file type from the file extension of '{fileName}'. Please specify the file type explicitly or change the file suffix to .txt or .json.", nameof(fileType));

            var suffix = file[si..];
            Span<char> lowerSuffix = stackalloc char[suffix.Length];

            suffix.ToLower(lowerSuffix, CultureInfo.InvariantCulture);
            fileType = lowerSuffix switch {
                ".json" => DataFileType.Json,
                ".txt" => DataFileType.Text,
                _ => throw new ArgumentException($"Cannot determine the file type from the file extension of '{fileName}'. Please specify the file type explicitly or change the file suffix to .txt or .json.", nameof(fileType)),
            };
        }

        RootFolder = fileType switch {
            DataFileType.Json => FromJsonFile(fileName),
            DataFileType.Text => FromTextFile(fileName),
            _ => throw new ArgumentOutOfRangeException(nameof(fileType), "Unsupported data file type."),
        };

        Debug.Assert(Comparer is not null);

        CurrentFolder = RootFolder;
    }

    public Folder SetCurrentFolder(string pathName)
    {
        var (folder, fileName) = FromPath(pathName);

        if (folder is null)
            throw new ArgumentException($"Path '{pathName}' not found in the JSON file system.", nameof(pathName));
        if (fileName is not null)
            throw new ArgumentException($"The current folder '{pathName}' path points to a file name, not a folder.", nameof(pathName));

        return CurrentFolder = folder;
    }

    public (Folder? folder, string? fileName) FromPath(string path)
    {
        ValidatePath(path);

        var nPath      = NormalizePath(path).ToString();
        var folder     = CurrentFolder;
        var enumerator = EnumeratePathRanges(nPath).GetEnumerator();

        if (!enumerator.MoveNext())
            return (folder, null);

        var range = enumerator.Current;
        var seg = nPath[range];
        if (IsDrive(seg))
        {
            if (seg[0] != RootFolder.Name[0])
                return (null, null);    // different drive letter

            // consume it
            if (!enumerator.MoveNext())
                return (null, null);
            range = enumerator.Current;
            seg = nPath[range];
        }

        if (IsRootSegment(seg))
        {
            folder = RootFolder;

            // consume it
            if (!enumerator.MoveNext())
                return (folder, null);
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
                        return (null, null);

                    // if it is the last segment, test if it is a fileName in this folder
                    name = folder.HasFile(name);
                    return (folder, name);

                }
                folder = nextFolder;
            }

            if (!enumerator.MoveNext())
                break;

            range = enumerator.Current;
            seg = nPath[range];
        }
        while (true);

        return (folder, null);
    }

    public void ToJsonFile(string fileName, JsonSerializerOptions? options = null)
    {
        ValidateOSPath(fileName);
        File.WriteAllBytes(fileName, ToJson(options));
    }

    public string ToJsonString(JsonSerializerOptions? options = null)
        => Encoding.UTF8.GetString(ToJson(options, false));

    public ReadOnlySpan<byte> ToJson(JsonSerializerOptions? options = null, bool? writeBom = null)
    {
        var buffer = new byte[64 * 1024];   // should be enough for most cases
        using var stream = new MemoryStream(buffer, true);

        writeBom ??= JsonUtf8Bom;

        if (writeBom.Value)
            stream.Write(Encoding.UTF8.Preamble);

        if (options is null)
            JsonSerializer.Serialize(stream, RootFolder, new FolderSourceGenerationContext().Folder);
        else
            JsonSerializer.Serialize(stream, RootFolder, new FolderSourceGenerationContext(options).Folder);

        return buffer.AsSpan(0, (int)stream.Position);
    }

    Folder FromJsonFile(string fileName)
        => FromJson(File.ReadAllBytes(fileName));

    Folder FromTextFile(string fileName)
    {
        using var reader = new StreamReader(fileName);
        return FromText(reader);
    }

    Folder FromJson(ReadOnlySpan<byte> json)
    {
        JsonUtf8Bom = json.StartsWith(Encoding.UTF8.Preamble);

        if (JsonUtf8Bom)
            json = json[Encoding.UTF8.Preamble.Length..];

        // Use source-generated metadata to avoid IL2026 (trim warning).
        var context = new FolderSourceGenerationContext();
        var root    = JsonSerializer.Deserialize(json, context.Folder)
                            ?? throw new ArgumentException("JSON is null, empty, or invalid.", nameof(json));

        Debug.Assert(root.Name is not null, "Root DTO name is null.");

        DetectOS(root.Name);
        RootFolder ??= Folder.LinkChildren(root, Comparer);
        return root;
    }

    Folder FromText(TextReader reader)
    {
        Folder? root = null;

        while (true)
        {
            var line = reader.ReadLine()?.Trim();

            if (line is null)
                break;
            if (string.IsNullOrWhiteSpace(line) || line.StartsWith('#') || line.StartsWith("//")) // skip empty lines or comments
                continue;

            line = Environment.ExpandEnvironmentVariables(line);

            if (root is null)
            {
                root = new Folder(DetectOS(line));
                Folder.LinkChildren(root, Comparer);
                RootFolder ??= root;
            }

            AddPath(root, line);
        }

        if (root is null)
            throw new ArgumentException("The text fileName is empty.", nameof(reader));

        return root;
    }

    string DetectOS(string line)
    {
        var m = StartsWithWinRootRegex().Match(line);

        if (m.Success)
        {
            if (!PathRegex.WindowsPath().IsMatch(line))
                throw new ArgumentException($"The Windows path format '{line}' is invalid.", nameof(line));
            IsWindows = true;
            Comparer  = StringComparer.OrdinalIgnoreCase;
            return m.Value.ToUpper().Replace(WinSepChar, SepChar);
        }

        if (line.StartsWith(SepChar))
        {
            if (!PathRegex.UnixPath().IsMatch(line))
                throw new ArgumentException($"The Unix path format '{line}' is invalid.", nameof(line));
            IsWindows = false;
            Comparer  = StringComparer.Ordinal;
            return SepString;
        }

        throw new ArgumentException(@"Root must be either ""/"" for Unix-like fileName system, or ""<drive ASCII letter>:\"" (e.g. ""C:\"" or ""C:/"") for Windows.");
    }

    void ValidatePath(string path)
    {
        if (!(IsWindows
                ? PathRegex.WindowsPath().IsMatch(path)
                : PathRegex.UnixPath().IsMatch(path)))
            throw new ArgumentException($"The '{path}' is invalid path.", nameof(path));
    }

    static void ValidateOSPath(string path)
    {
        if (!(OperatingSystem.IsWindows()
                ? PathRegex.WindowsPath().IsMatch(path)
                : PathRegex.UnixPath().IsMatch(path)))
            throw new ArgumentException($"The '{path}' is invalid path.", nameof(path));
    }

    Folder? AddPath(Folder root, string path)
    {
        ValidatePath(path);

        var nPath      = NormalizePath(path).ToString();
        var enumerator = EnumeratePathRanges(nPath).GetEnumerator();

        if (!enumerator.MoveNext())
            throw new ArgumentException($"The path '{path}' has no root.");

        var range = enumerator.Current;
        var seg = nPath[range];

        if (IsDrive(seg))
        {
            if (seg[0] != root.Name[0])
                throw new ArgumentException($"The path '{path}' has a different drive letter than the JSON fileName system root.");

            // consume it
            if (!enumerator.MoveNext())
                return root;

            range = enumerator.Current;
            seg = nPath[range];
        }

        if (!IsRootSegment(seg))
            throw new ArgumentException($"The path '{path}' must start at the root.", nameof(path));

        // consume it
        if (!enumerator.MoveNext())
            return root;

        range = enumerator.Current;
        seg = nPath[range];

        var folder = root;

        do
        {
            var name = seg.ToString();

            // peek what's next:

            if (!enumerator.MoveNext())
            {
                // we are at the end of the path - it must be a file, add it, if not exists and return
                if (folder.HasFile(name) is null)
                    folder.Add(name);
                return folder;
            }

            // not at the end of the path - it must be a folder, add it, if not exists
            var nextFolder = folder.HasFolder(name);

            if (nextFolder is null)
            {
                nextFolder = new Folder(name);
                folder.Add(nextFolder);
            }

            folder = nextFolder;

            range = enumerator.Current;
            seg = nPath[range];
        }
        while (!IsRootSegment(seg));

        return root;
    }
}