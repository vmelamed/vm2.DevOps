namespace vm2.DevOps.Glob.Api;

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
        // shortcut the easy cases
        if (glob is "")
            return (glob, "");
        if (glob is SequenceWildcard)
            return (glob, SequenceRegex);
        if (glob is CharacterWildcard)
            return (glob, CharacterRegex);
        if (glob is RecursiveWildcard)
            return ("", "");

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

        //var globSpan = glob.AsSpan();
        //var globCur = 0;   // current index in globSpan
        var roGlobSpan = new SpanReader(glob.AsSpan());

        // escape the non-matches and translate the matches to regex equivalents
        var rexSpan = new SpanWriter(stackalloc char[10*glob.Length]);
        // copy the non-matches and translate the matches to file system pattern equivalents - * and ?
        var patSpan = new SpanWriter(stackalloc char[10*glob.Length]);

        // replace all wildcards with '*'
        foreach (Match match in matches)
        {
            // escape and copy the next non-match
            if (match.Index > roGlobSpan.Length)
            {
                var nonMatch = roGlobSpan.Read(match.Index-roGlobSpan.Length);

                rexSpan.Write(Regex.Escape(nonMatch.ToString()));
                patSpan.Write(nonMatch);
            }

            // translate the following match in globSpan
            var (pat, rex) = TranslateGlob(match);

            roGlobSpan.Read(match.Value.Length);

            rexSpan.Write(rex.AsSpan());
            patSpan.Write(pat.AsSpan());
        }

        // escape and copy the final non-match
        if (!roGlobSpan.IsEmpty)
        {
            var finalNonMatch = roGlobSpan.ReadAll();

            rexSpan.Write(Regex.Escape(finalNonMatch.ToString()));
            patSpan.Write(finalNonMatch);
        }

        return (patSpan.Chars.ToString(), rexSpan.Chars.ToString());
    }

    static (string pattern, string regex) TranslateGlob(Match match)
        => match.Groups.Values.FirstOrDefault(
            g => !string.IsNullOrWhiteSpace(g.Name)
            && char.IsLetter(g.Name[0])
            && !string.IsNullOrWhiteSpace(g.Value)) switch {
                { Name: SeqWildcardGr } asterisk => (SequenceWildcard, SequenceRegex),     // no need to filter the results
                { Name: CharWildcardGr } question => (CharacterWildcard, CharacterRegex),
                { Name: ClassNameGr } className => (CharacterWildcard, $"[{(match.Value[1] is '!' ? "^" : "")}{_namedClassTranslations[className.Value]}]"),
                { Name: ClassGr } chrClass => (CharacterWildcard, $"[{TransformClass(chrClass.Value)}]"),
                _ => throw new ArgumentException("Invalid glob pattern match.", nameof(match)),
            };

    static readonly FrozenDictionary<string, string> _namedClassTranslations =
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

    static ReadOnlySpan<char> TransformClass(string glClass)
    {
        if (glClass[0] is not ('!' or ']'))
            return glClass;

        var clSpan = new SpanWriter(new Memory<char>(new char[glClass.Length + 1]).Span);
        var nG = 0;

        if (glClass[nG] is '!')
        {
            nG++;
            clSpan.Write('^');
        }

        if (glClass[nG] is ']')
        {
            nG++;
            clSpan.Write('\\');
            clSpan.Write(']');
        }

        clSpan.Write(glClass.AsSpan(nG));
        return clSpan.Chars;
    }
}