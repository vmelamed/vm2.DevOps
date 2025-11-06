namespace vm2.DevOps.Glob.Api;

using System.Collections.Frozen;
using System.Diagnostics;

/// <summary>
/// Represents a glob pattern searcher.
/// </summary>
public sealed partial class GlobEnumerator
{
    /// <summary>
    /// Translates a glob pattern to .NET pattern used in EnumerateDirectories and to a regex pattern for final filtering.
    /// </summary>
    /// <param name="glob">The glob to translate.</param>
    /// <returns>A .NET path segment pattern and the corresponding <see cref="Regex"/></returns>
    static (string pattern, string regex) GlobToRegex(string glob)
    {
        Debug.Assert(glob is not RecursiveWildcard, "The recursive wildcard must be processed separately.");

        // shortcut the easy cases
        if (string.IsNullOrWhiteSpace(glob) || glob is SequenceWildcard)
            return (glob, "");
        if (glob is SequenceWildcard)
            return (glob, ".*");
        if (glob is CharacterWildcard)
            return (glob, ".?");

        // find all wildcard matches in the glob
        var matches = ReplaceableWildcard().Matches(glob);

        if (matches.Count == 0)
        {
            var regex = Regex.Escape(glob);
            return (glob, glob!=regex ? regex : ""); // no wildcards
        }

        // now the glob can be thought of as a sequence of non-matching and matching slices:
        // (<non-match><match>)*<non-match>
        // where each non-match element can be empty

        var globSpan = glob.AsSpan();
        var globCur = 0;   // current index in globSpan

        // escape the non-spans and translate the matches to regex equivalents
        Span<char> rexSpan = stackalloc char[10*glob.Length];
        int rexCur = 0;   // current index in rexSpan

        Span<char> patSpan = stackalloc char[10*glob.Length];
        int patCur = 0;   // current index in patSpan

        // replace all wildcards with '*'
        foreach (Match match in matches)
        {
            // escape and copy the next non-match
            if (match.Index > globCur)
            {
                var nonMatch = globSpan[globCur..match.Index];
                globCur = match.Index;

                Concatenate(rexSpan, Regex.Escape(nonMatch.ToString()), ref rexCur);
                Concatenate(patSpan, nonMatch, ref patCur);
            }

            // translate the following match in globSpan
            var (pat, rex) = TranslateGlob(match);
            globCur += match.Length;

            Concatenate(rexSpan, rex.AsSpan(), ref rexCur);
            Concatenate(patSpan, pat.AsSpan(), ref patCur);
        }

        // escape and copy the final non-match
        if (globCur < globSpan.Length)
        {
            var nonMatch = globSpan[globCur..];

            Concatenate(rexSpan, Regex.Escape(nonMatch.ToString()), ref rexCur);
            Concatenate(patSpan, nonMatch, ref patCur);
        }

        return (patSpan[..patCur].ToString(), rexSpan[..rexCur].ToString());
    }

    static Span<char> Concatenate(Span<char> dest, ReadOnlySpan<char> src, ref int fromIndex)
    {
        src.CopyTo(dest[fromIndex..]);
        fromIndex += src.Length;
        return dest;
    }

    static (string pattern, string regex) TranslateGlob(Match match)
        => match.Groups.Values.FirstOrDefault(
            g => !string.IsNullOrWhiteSpace(g.Name)
            && char.IsLetter(g.Name[0])
            && !string.IsNullOrWhiteSpace(g.Value)) switch {
                { Name: SeqWildcardGr } asterisk => (SequenceWildcard, ".*"),
                { Name: CharWildcardGr } question => (CharacterWildcard, "."),
                { Name: ClassNameGr } className => (CharacterWildcard, $"[{(match.Value[1] is '!' ? "^" : "")}{_globClassTranslations[className.Value]}]"),
                { Name: ClassGr } @class => (CharacterWildcard, $"[{TransformClass(@class.Value)}]"),
                _ => throw new ArgumentException("Invalid glob pattern match.", nameof(match)),
            };

    static readonly FrozenDictionary<string, string> _globClassTranslations =
        FrozenDictionary.ToFrozenDictionary(
            new Dictionary<string, string>()
            {
                ["alnum"]  = @"\p{L}\p{Nd}\p{Nl}",
                ["alpha"]  = @"\p{L}\p{Nl}",
                ["blank"]  = @"\p{Zs}\t",
                ["cntrl"]  = @"\p{Cc}",
                ["digit"]  = @"\d",
                ["graph"]  = @"\p{L}\p{M}\p{N}\p{P}\p{S}",
                ["lower"]  = @"\p{Ll}\p{Lt}\p{Nl}",
                ["print"]  = @"\p{S}\p{N}\p{Zs}\p{M}\p{L}\p{P}",
                ["punct"]  = @"\p{P}$+<=>^`|~",
                ["space"]  = @"\s",
                ["upper"]  = @"\p{Lu}\p{Lt}\p{Nl}",
                ["xdigit"] = @"0-9A-Fa-f",
            });

    static string TransformClass(string glClass)
    {
        if (glClass[0] is not ('!' or ']'))
            return glClass;

        Span<char> clSpan = stackalloc char[glClass.Length + 1];
        var nG = 0;
        var nC = 0;

        if (glClass[nG] is '!')
        {
            nG++;
            clSpan[nC++] = '^';
        }

        if (glClass[nG] is ']')
        {
            nG++;
            clSpan[nC++] = '\\';
            clSpan[nC++] = ']';
        }

        glClass.AsSpan(nG).CopyTo(clSpan[nC..]);
        return clSpan.ToString();
    }
}