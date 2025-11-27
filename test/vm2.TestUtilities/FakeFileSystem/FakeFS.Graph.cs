// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Val Melamed

namespace vm2.TestUtilities.FakeFileSystem;

public sealed partial class FakeFS
{
    /// <summary>
    /// Serializes the fake file system to a text file in graph format.
    /// </summary>
    /// <param name="fileName">The path to the output graph text file.</param>
    public void ToGraphFile(string fileName)
    {
        ValidateOSPath(fileName);
        File.WriteAllText(fileName, ToGraph(), Encoding.UTF8);
    }

    /// <summary>
    /// Serializes the fake file system to a graph string representation.
    /// </summary>
    /// <returns>A string containing the tree-like representation of the file system.</returns>
    public string ToGraph()
    {
        var sb = new StringBuilder();
        sb.AppendLine(RootFolder.Name);
        WriteGraphNode(sb, RootFolder, "", true);
        return sb.ToString();
    }

    void WriteGraphNode(StringBuilder sb, Folder folder, string indent, bool isRoot)
    {
        var folders = folder.Folders.ToList();
        var files = folder.Files.ToList();
        var totalItems = folders.Count + files.Count;
        var currentItem = 0;

        foreach (var subFolder in folders)
        {
            currentItem++;
            var isLast = currentItem == totalItems;
            var prefix = isRoot ? "" : (isLast ? "└── " : "├── ");
            var childIndent = isRoot ? "" : (isLast ? "    " : "│   ");

            sb.Append(indent).Append(prefix).Append(subFolder.Name).AppendLine("/");
            WriteGraphNode(sb, subFolder, indent + childIndent, false);
        }

        foreach (var file in files)
        {
            currentItem++;
            var isLast = currentItem == totalItems;
            var prefix = isRoot ? "" : (isLast ? "└── " : "├── ");

            sb.Append(indent).Append(prefix).AppendLine(file);
        }
    }
}
