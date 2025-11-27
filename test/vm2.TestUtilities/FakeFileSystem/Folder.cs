// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Val Melamed

namespace vm2.TestUtilities.FakeFileSystem;

/// <summary>
/// Represents a folder in the file system: container for subfolders and files.
/// </summary>
/// <param name="name"></param>
/// <remarks>
/// We use the term "folder" instead of "directory" in classes and method names to avoid confusion with the .NET class
/// <see cref="Directory"/>.
/// </remarks>
[ExcludeFromCodeCoverage]
public class Folder(string name = "") : IEquatable<Folder>, IComparable<Folder>
{
    public static readonly Folder Default = new();

    [JsonPropertyName("name")]
    public string Name { get; private set; } = name;

    ISet<Folder> _folders = new SortedSet<Folder>();
    ISet<string> _files = new SortedSet<string>(StringComparer.Ordinal);

    [JsonPropertyName("folders")]
    public IEnumerable<Folder> Folders
    {
        get => _folders;
        private set => _folders = new SortedSet<Folder>(value);
    }

    [JsonPropertyName("files")]
    public IEnumerable<string> Files
    {
        get => _files;
        private set => _files = new SortedSet<string>(value, StringComparer.Ordinal);
    }

    /// <summary>
    /// Initializes a new instance of the <see cref="Folder"/> class. Used for deserialization from JSON.
    /// </summary>
    /// <param name="name"></param>
    /// <param name="folders"></param>
    /// <param name="files"></param>
    [JsonConstructor]
    public Folder(
        string name,
        IEnumerable<Folder>? folders,
        IEnumerable<string>? files) : this(name)
    {
        Folders = folders is null ? [] : [.. folders];
        Files   = files is null ? [] : [.. files];
    }

    [JsonIgnore]
    public string Path { get; private set; } = "";

    [JsonIgnore]
    public Folder? Parent
    {
        get;
        private set
        {
            if (field == value) // the same parent? - do nothing
                return;

            field = value;

            if (value is not null)
                Comparer = value.Comparer;
            SetPath();
        }
    }

    [JsonIgnore]
    public StringComparer Comparer
    {
        get;
        private set
        {
            if (field == value) // the same comparer? - do nothing
                return;

            field       = value;
            Files       = new SortedSet<string>(Files, value);  // Recreate the sets with the new comparer
            Folders     = new SortedSet<Folder>(Folders);       // rebuild to ensure correct new ordering of children
            foreach (var folder in Folders)
                folder.Comparer = value; // propagate to children
        }
    } = StringComparer.Ordinal;

    public string? HasFile(string fileName)
        => Files.FirstOrDefault(f => Comparer.Compare(f, fileName) == 0);

    public Folder? HasFolder(string subDirName)
    {
        if (subDirName is CurrentDir)
            return this;
        if (subDirName is ParentDir)
            return Parent;

        return Folders.FirstOrDefault(d => Comparer.Compare(d.Name, subDirName) == 0);
    }

    public bool Equals(Folder? other) => CompareTo(other) == 0;

    public int CompareTo(Folder? other)
    {
        if (other is null)
            return 1;
        if (ReferenceEquals(this, other))
            return 0;
        return Parent == other.Parent
            || string.IsNullOrWhiteSpace(Path)
            || string.IsNullOrWhiteSpace(other.Path)
                    ? Comparer.Compare(Name, other.Name)
                    : Comparer.Compare(Path, other.Path);   // so that we can compare unlinked nodes
    }

    public override bool Equals(object? other) => Equals(other as Folder);

    public override int GetHashCode() => Name.GetHashCode();

    public override string ToString() => Name;

    public Folder Add(Folder node)
    {
        if (Folders.Contains(node))
            throw new ArgumentException($"Folder '{node.Name}' already exists in '{Name}'.", nameof(node));

        node.Parent = this;
        _folders.Add(node);
        return this;
    }

    public Folder Add(string file)
    {
        if (Files.Contains(file))
            throw new ArgumentException($"HasFile '{file}' already exists in '{Name}'.", nameof(file));

        _files.Add(file);
        return this;
    }

    public static Folder LinkChildren(Folder root, StringComparer comparer)
    {
        if (root.Parent is not null)
            throw new ArgumentException("Root node cannot have a folder.", nameof(root));
        if (!root.Name.EndsWith(SepChar))
            throw new InvalidDataException($"Root node name must end with '{SepChar}'.");

        root.SetPath();

        // Set the parents and the comparer recursively from the root node through the entire tree
        root.Comparer = comparer;
        SetAsParent(root);
        return root;
    }

    void SetPath()
    {
        var segment = Name.EndsWith(SepChar) ? Name : Name + SepChar;
        Path = Parent is not null
                    ? $"{Parent?.Path}{segment}"
                    : $"{segment}";
    }

    static void SetAsParent(Folder folder)
    {
        foreach (var child in folder.Folders)
        {
            child.Parent   = folder;
            child.Comparer = folder.Comparer;
            SetAsParent(child);
        }
    }
}

[JsonSerializable(typeof(Folder))]
[JsonSourceGenerationOptions(
    AllowTrailingCommas = true,
    PropertyNameCaseInsensitive = true,
    PropertyNamingPolicy = JsonKnownNamingPolicy.CamelCase,
    ReadCommentHandling = JsonCommentHandling.Skip,
    WriteIndented = true,
    IndentSize = 4,
    IndentCharacter = ' ',
    NewLine = "\r\n")]
internal partial class FolderSourceGenerationContext : JsonSerializerContext { }
