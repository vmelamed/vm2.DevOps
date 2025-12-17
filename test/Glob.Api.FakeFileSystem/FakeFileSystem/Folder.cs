// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Val Melamed

namespace vm2.DevOps.Glob.Api.FakeFileSystem;

using System.Linq;

/// <summary>
/// Represents a folder in a fake file system: container for sub-folders and files.
/// </summary>
public partial class Folder
{
    ISet<Folder> _folders = new SortedSet<Folder>(InFolderComparer.Instance);
    ISet<string> _files = new SortedSet<string>(StringComparer.Ordinal);

    [JsonPropertyName("name")]
    public string Name { get; private set; }

    [JsonPropertyName("files")]
    public IEnumerable<string> Files
    {
        get => _files;
        private set => _files = new SortedSet<string>(value, Comparer);
    }

    [JsonPropertyName("folders")]
    public IEnumerable<Folder> Folders
    {
        get => _folders;
        private set => _folders = new SortedSet<Folder>(value, InFolderComparer.Instance);
    }

    private class InFolderComparer : IComparer<Folder>
    {
        public static readonly InFolderComparer Instance = new();

        public int Compare(Folder? x, Folder? y)
        {
            if (x is null && y is null)
                return 0;
            if (x is null)
                return -1;
            if (y is null)
                return 1;
            return x.Comparer.Compare(x.Name, y.Name);
        }
    }

    [JsonIgnore]
    public string Path { get; private set; }

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

            foreach (var folder in Folders)
                folder.Comparer = value;    // propagate to children

            field   = value;
            Folders = Folders;      // rebuild to ensure correct new ordering of children
            Files   = Files;        // Recreate the sets with the new comparer
        }
    } = StringComparer.OrdinalIgnoreCase;

    public bool HasRootName => FileSystemRootRegex().IsMatch(Name);

    public static readonly Folder Default = new();

    [GeneratedRegex(@"^(/ | \\ | [A-Za-z]:[/\\]? )", RegexOptions.IgnorePatternWhitespace | RegexOptions.ExplicitCapture)]
    internal static partial Regex FileSystemRootRegex();

    /// <summary>
    /// Initializes a new instance of the <see cref="Folder"/> class.
    /// </summary>
    /// <param name="name">The name of the new folder</param>
    /// <param name="comparer">
    /// If <paramref name="comparer"/> is null, the default <b>case-sensitive string comparer</b> will be used.
    /// </param>
    /// <remarks>
    /// <para>
    /// If the folder's comparer will change to case-insensitive later, all existing files and sub-folders will be re-evaluated
    /// and re-added to ensure correct behavior. Files and sub-folders with names that differ only by case will cause an
    /// exception to be thrown.
    /// </para>
    /// We use the term "folder" instead of "directory" in classes and method names to avoid confusion with the .NET class
    /// <see cref="Directory"/>.
    /// </remarks>
    public Folder(string name = "", StringComparer? comparer = null)
    {
        Name     = name;
        Path     = name.EndsWith(SepChar) ? name : name + SepChar;
        Comparer = comparer ?? StringComparer.Ordinal;
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
        IEnumerable<string>? files,
        StringComparer? comparer = null) : this(name, comparer)
    {
        if (folders is not null)
            foreach (var f in folders)
                _folders.Add(f);

        if (files is not null)
            foreach (var f in files)
                _files.Add(f);
    }

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

    public override string ToString() => Name;

    public Folder Add(Folder node)
    {
        if (node.HasRootName)
            throw new ArgumentException("Root folder cannot be added as a child.", nameof(node));
        if (!_folders.Add(node))
            throw new ArgumentException($"Folder '{node.Name}' already exists in '{Name}'.", nameof(node));

        node.Parent = this;
        return this;
    }

    public Folder Add(string file)
    {
        if (!_files.Add(file))
            throw new ArgumentException($"File '{file}' already exists in '{Name}'.", nameof(file));

        return this;
    }

    void SetPath()
    {
        var segment = Name.EndsWith(SepChar) ? Name : Name + SepChar;

        Path = Parent is not null
                    ? $"{Parent.Path}{segment}"
                    : segment;
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

    public static Folder LinkChildren(Folder root, StringComparer comparer)
    {
        if (root.Parent is not null)
            throw new ArgumentException("Root node cannot have a parent.", nameof(root));
        if (!root.HasRootName)
            throw new ArgumentException("The name of the folder is not a name of a root.", nameof(root));
        if (!root.Name.EndsWith(SepChar))
            throw new InvalidDataException($"Root node name must end with '{SepChar}'.");

        root.SetPath();

        // Set the parents and the comparer recursively from the root node through the entire tree
        root.Comparer = comparer;
        SetAsParent(root);
        return root;
    }
}

[ExcludeFromCodeCoverage]
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
public partial class FolderSourceGenerationContext : JsonSerializerContext { }
