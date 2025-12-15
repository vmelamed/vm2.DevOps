// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Val Melamed

namespace vm2.DevOps.Glob.Api.FakeFileSystem;

public sealed partial class FakeFS
{
    /// <summary>
    /// Serializes the fake file system to a JSON file.
    /// </summary>
    /// <param name="fileName"></param>
    /// <param name="pretty"></param>
    public void ToJsonFile(string fileName, bool pretty = false)
    {
        ValidateOSPath(fileName);
        File.WriteAllBytes(fileName, ToJson());
    }

    /// <summary>
    /// Serializes the fake file system to a JSON string.
    /// </summary>
    /// <returns></returns>
    public string ToJsonString()
        => Encoding.UTF8.GetString(ToJson());

    /// <summary>
    /// Serializes the root folder to a UTF-8 encoded JSON sequence of bytes - <see cref="Span{char}"/>.
    /// </summary>
    /// <remarks>
    /// The returned span references a buffer that is only valid for the lifetime of the containing object. Callers should copy
    /// the data if it needs to be preserved beyond the immediate scope.
    /// </remarks>
    /// <returns>
    /// A read-only span of bytes containing the JSON-encoded representation of the root folder, including the UTF-8 BOM if
    /// specified.
    /// </returns>
    public ReadOnlySpan<byte> ToJson()
    {
        var buffer = new byte[64 * 1024];
        using var stream = new MemoryStream(buffer);

        JsonSerializer.Serialize(stream, RootFolder, new FolderSourceGenerationContext().Folder);
        stream.Flush();

        return buffer.AsSpan(0, (int)stream.Position);
    }

    public FakeFS FromJson(string json)
    {
        // Use source-generated metadata to avoid IL2026 (trim warning).
        RootFolder = CurrentFolder = JsonSerializer.Deserialize(json, new FolderSourceGenerationContext().Folder)
                                        ?? throw new ArgumentException("JSON is null, empty, or invalid.", nameof(json));

        Debug.Assert(RootFolder.Name is not null, "Root DTO name is null.");

        (IsWindows, _) = DetectOS(RootFolder.Name);

        Folder.LinkChildren(RootFolder, this.Comparer);

        return this;
    }
}
