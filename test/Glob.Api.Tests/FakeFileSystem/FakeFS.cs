namespace vm2.DevOps.Glob.Api.Tests.FakeFileSystem;

/// <summary>
/// Fake fileName system loaded from a JSON representation.
/// </summary>
/// <remarks>
/// We use the term "folder" instead of "directory" in classes and method names to avoid confusion with the .NET class
/// <see cref="Directory"/>.
/// </remarks>
public sealed partial class FakeFS
{
    #region fields
    const string Wildcards         = "*?";  // TODO: add [], {}, etc. advanced features
    const string RecursiveWildcard = "**";
    const int WinDriveLength       = 2;     // e.g. "C:"
    const int WinRootLength        = 3;     // e.g. "C:/"

    const string EnvVarNameGr      = "envVar";
    const string EnvVarValueGr     = "envVarValue";
    #endregion

    #region Regexes
    [GeneratedRegex(@"^[C-Za-z]:[/\\]")]
    public static partial Regex StartsWithWinRoot();

    [GeneratedRegex($"^(?<{EnvVarNameGr}> [C-Za-z_][0-9A-Za-z_]* ) = (?<{EnvVarValueGr}> .* )$", RegexOptions.IgnorePatternWhitespace | RegexOptions.ExplicitCapture)]
    public static partial Regex EnvVarDefinition();
    #endregion

    #region Properties
    public bool JsonUtf8Bom { get; set; } = false;

    public Folder RootFolder { get; private set; }

    public Folder CurrentFolder { get; private set; }

    public StringComparer Comparer { get; private set; }
    #endregion

    #region Constructors
    public FakeFS(string fileName, DataType fileType = DataType.Default)
    {
        var m = OperatingSystem.IsWindows()
                    ? WindowsPathRegex().Match(fileName)
                    : UnixPathRgex().Match(fileName);

        if (!m.Success)
            throw new ArgumentException($"The path name '{fileName}' format is invalid.", nameof(fileName));
        if (!File.Exists(fileName))
            throw new FileNotFoundException($"HasFile '{fileName}' not found.", fileName);

        if (fileType is DataType.Default)
        {
            var file = m.Groups[FileGr].ValueSpan;
            var si = file.LastIndexOf('.');

            if (si is <0)
                throw new ArgumentException($"Cannot determine the file type from the file extension of '{fileName}'. Please specify the file type explicitly or change the file suffix to .txt or .json.", nameof(fileType));

            var suffix = file[si..];
            Span<char> lowerSuffix = stackalloc char[suffix.Length];

            suffix.ToLower(lowerSuffix, CultureInfo.InvariantCulture);
            fileType = lowerSuffix switch {
                ".json" => DataType.Json,
                ".txt" => DataType.Text,
                _ => throw new ArgumentException($"Cannot determine the file type from the file extension of '{fileName}'. Please specify the file type explicitly or change the file suffix to .txt or .json.", nameof(fileType)),
            };
        }

        RootFolder = fileType switch {
            DataType.Json => FromJsonFile(fileName),
            DataType.Text => FromTextFile(fileName),
            _ => throw new ArgumentOutOfRangeException(nameof(fileType), "Unsupported data file type."),
        };

        Debug.Assert(RootFolder is not null);
        Debug.Assert(Comparer is not null);

        CurrentFolder = RootFolder;
    }

    public FakeFS(byte[] data, DataType dataType)
    {
        RootFolder = dataType switch {
            DataType.Json => FromJson(data),
            DataType.Text => FromText(new StringReader(Encoding.UTF8.GetString(data))),
            _ => throw new ArgumentOutOfRangeException(nameof(dataType), "The data type must be either Json or Text."),
        };

        Debug.Assert(RootFolder is not null);
        Debug.Assert(Comparer is not null);

        CurrentFolder = RootFolder;
    }
    #endregion

    public Folder SetCurrentFolder(string pathName)
    {
        var (folder, fileComp, _) = GetPathFromRoot(pathName);

        if (folder is null)
            throw new ArgumentException($"GlobRegex '{pathName}' not found in the JSON file system.", nameof(pathName));
        if (fileComp)
            throw new ArgumentException($"The current folder '{pathName}' path points to a file name, not a folder.", nameof(pathName));

        return CurrentFolder = folder;
    }

    public record struct PathAndFile(Folder? Folder = null, bool HasFileComponent = false, string FileName = "");

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
                return new PathAndFile(null);    // different drive letter

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

    public void ToJsonFile(string fileName, bool pretty = false)
    {
        ValidateOSPath(fileName);
        File.WriteAllBytes(fileName, ToJson(pretty));
    }

    public string ToJsonString()
        => Encoding.UTF8.GetString(ToJson(false));

    public ReadOnlySpan<byte> ToJson(bool? writeBom = null)
    {
        var buffer = new byte[64 * 1024];   // should be enough for most cases
        using var stream = new MemoryStream(buffer, true);

        writeBom ??= JsonUtf8Bom;

        if (writeBom.Value)
            stream.Write(Encoding.UTF8.Preamble);

        JsonSerializer.Serialize(stream, RootFolder, new FolderSourceGenerationContext().Folder);

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
        var root    = JsonSerializer.Deserialize(json, new FolderSourceGenerationContext().Folder)
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

            if (EnvVarDefinition().Match(line) is Match m && m.Success)
            {
                Environment.SetEnvironmentVariable(m.Groups[EnvVarNameGr].Value, m.Groups[EnvVarValueGr].Value);
                continue;
            }

            // this is a little risky since we may not know the OS yet,
            // but we have to do it here to support Unix env vars in paths,
            // so we're establishing a convention that the first non-comment line should not have syntax ambiguities,
            // e.g. a Windows path that contains '$' or '~' characters; or a Unix path that contains ':' or '%'.
            if (!IsWindows)
            {
                line = line.Replace(UnixShellSpecificHome, UnixHomeEnvironmentVar);
                line = UnixEnvVarRegex().Replace(line, UnixEnvVarReplacement);
            }

            line = Environment.ExpandEnvironmentVariables(line);

            if (root is null)
            {
                root = new Folder(DetectOS(line));
                Folder.LinkChildren(root, Comparer);
                RootFolder    ??= root;
                CurrentFolder ??= root;
            }

            AddPath(root, line);
        }

        if (root is null)
            throw new ArgumentException("The text fileName is empty.", nameof(reader));

        return root;
    }

    string DetectOS(string line)
    {
        var m = StartsWithWinRoot().Match(line);

        if (m.Success)
        {
            if (!WindowsPathRegex().IsMatch(line))
                throw new ArgumentException($"The Windows path format '{line}' is invalid.", nameof(line));
            IsWindows = true;
            Comparer  = StringComparer.OrdinalIgnoreCase;
            return m.Value.ToUpper().Replace(WinSepChar, SepChar);
        }

        if (line.StartsWith(SepChar))
        {
            if (!UnixPathRgex().IsMatch(line))
                throw new ArgumentException($"The Unix path format '{line}' is invalid.", nameof(line));
            IsWindows = false;
            Comparer  = StringComparer.Ordinal;
            return SepChar.ToString();
        }

        throw new ArgumentException(@"Root must be either ""/"" for Unix-like fileName system, or ""<drive ASCII letter>:\"" (e.g. ""C:\"" or ""C:/"") for Windows.");
    }

    void ValidatePath(string path)
    {
        if (!(IsWindows
                ? WindowsPathRegex().IsMatch(path)
                : UnixPathRgex().IsMatch(path)))
            throw new ArgumentException($"The '{path}' is invalid path.", nameof(path));
    }

    static void ValidateOSPath(string path)
    {
        if (!(OperatingSystem.IsWindows()
                ? WindowsPathRegex().IsMatch(path)
                : UnixPathRgex().IsMatch(path)))
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

        var folder = CurrentFolder ?? RootFolder;

        if (IsRootSegment(seg))
        {
            folder = RootFolder;

            // consume it
            if (!enumerator.MoveNext())
                return folder;
            range = enumerator.Current;
            seg = nPath[range];
        }

        do
        {
            var name = seg.ToString();

            // peek at what's next:

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