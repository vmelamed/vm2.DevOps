// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Val Melamed

namespace vm2.DevOps.Glob.Api.FakeFileSystem;

public sealed partial class FakeFS
{
    #region Regexes
    [GeneratedRegex(@"^[C-Za-z]:[/\\]")]
    private static partial Regex StartsWithWinRoot();

    const string EnvVarNameGr  = "envVar";
    const string EnvVarValueGr = "envVarValue";

    [GeneratedRegex($"^(?<{EnvVarNameGr}> [C-Za-z_][0-9A-Za-z_]* ) = (?<{EnvVarValueGr}> .* )$", RegexOptions.IgnorePatternWhitespace | RegexOptions.ExplicitCapture)]
    private static partial Regex EnvVarDefinition();
    #endregion

    public FakeFS FromText(string text)
    {
        using var reader = new StringReader(text);
        Folder? root = null;
        bool? isWindows = null;
        string? rootPath = null;

        while (true)
        {
            var line = reader.ReadLine();

            if (line is null)   // EOF
                break;

            line = line.Trim();

            if (string.IsNullOrWhiteSpace(line)
             || line.StartsWith('#')
             || line.StartsWith("//")) // skip empty lines and comments
                continue;

            // add the env. vars to the environment so that they can be used by Environment.ExpandEnvironmentVariables
            if (EnvVarDefinition().Match(line) is Match m && m.Success)
            {
                Environment.SetEnvironmentVariable(m.Groups[EnvVarNameGr].Value, m.Groups[EnvVarValueGr].Value);
                continue;
            }

            line = line.Replace(UnixShellSpecificHome, UnixHomeEnvironmentVar);
            line = UnixEnvVarRegex().Replace(line, UnixEnvVarReplacement);
            line = Environment.ExpandEnvironmentVariables(line);
            if (isWindows is null)
            {
                (isWindows, rootPath) = DetectOS(line);

                Debug.Assert(isWindows is not null);
                Debug.Assert(rootPath is not null);

                IsWindows  = isWindows.Value;
                RootFolder = CurrentFolder = root = new Folder(rootPath);
                Folder.LinkChildren(RootFolder, this.Comparer);
            }

            Debug.Assert(root is not null);

            AddPath(root, line);
        }

        if (root is null)
            throw new ArgumentException("The text in the file is empty or consists of comments and blank lines only.", nameof(text));

        return this;
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
