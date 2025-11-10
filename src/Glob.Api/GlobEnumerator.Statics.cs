namespace vm2.DevOps.Glob.Api;

/// <summary>
/// Represents a glob pattern searcher.
/// </summary>
public sealed partial class GlobEnumerator
{
    /// <summary>
    /// Escapes a span of characters for use in a regular expression pattern.
    /// </summary>
    /// <remarks>
    /// Basically a rewrite of <see cref="Regex.Escape"/> for spans.<para/>
    /// <b>Note</b> that if no character was escaped, the method will return the original span, saving one allocation.
    /// </remarks>
    /// <param name="span">The span of characters to escape.</param>
    public static ReadOnlySpan<char> RegexEscape(ReadOnlySpan<char> span)
    {
        var writer = new SpanWriter(stackalloc char[2*span.Length]);

        foreach (var ch in span)
        {
            if (RegexEscapable.Contains(ch))
                writer.Write('\\');
            writer.Write(ch);
        }

        return writer.Position == span.Length ? span : writer.Chars.ToString().AsSpan();
    }

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
        var matches = GlobExpression().Matches(glob);

        if (matches.Count == 0)
        {
            var regex = RegexEscape(glob);
            return (glob, glob.Length!=regex.Length ? regex.ToString() : ""); // no wildcards
        }

        // now the glob can be thought of as a sequence of non-matching and matching slices:
        // (<non-match><match>)*<non-match>
        // where each non-match element can be empty

        // span to go through the glob
        var globReader = new SpanReader(glob.AsSpan());
        // escape the non-matches and translate the matches to regex equivalents
        var rexWriter = new SpanWriter(stackalloc char[10*glob.Length]);
        // copy the non-matches and translate the matches to file system pattern equivalents - * and ?
        var patWriter = new SpanWriter(stackalloc char[10*glob.Length]);

        // replace all wildcards with '*'
        foreach (Match match in matches)
        {
            // the non-match is from the current position to the start of the match - escape and copy the next non-match
            if (match.Index > globReader.Position)
            {
                var nonMatch = globReader.Read(match.Index-globReader.Position);

                rexWriter.Write(RegexEscape(nonMatch));
                patWriter.Write(nonMatch);
            }

            _ = globReader.Read(match.Length);  // consume the match

            // translate the match
            var (pat, rex) = TranslateGlobExpression(match);

            // TranslateGlobExpression(match); already processed this part, so just advance the reader
            rexWriter.Write(rex.AsSpan());
            patWriter.Write(pat.AsSpan());
        }

        // escape and copy the final non-match
        if (!globReader.IsEmpty)
        {
            var finalNonMatch = globReader.ReadAll();

            rexWriter.Write(RegexEscape(finalNonMatch));
            patWriter.Write(finalNonMatch);
        }

        return (patWriter.Chars.ToString(), rexWriter.Chars.ToString());
    }

    static (string pattern, string regex) TranslateGlobExpression(Match match)
        // At this point, we know that match is one of the glob expression elements: *, ?, [class], [!class], where a class is a
        // sequence of letters (e.g. 'abc..'), letter ranges (e.g. '0-9'), and named classes (e.g. [:alnum:]. We need to
        // identify and replace the match its respective regex equivalents:
        // * => .*
        // * => .
        // [class] => [class] (in each class we have to find and replace the named classes with their regex equivalent)
        // [!class] => [^class]
        // Therefore, we need a function that transforms each class into a .net regex - TransformClass
        => match.Groups.Values.FirstOrDefault(
            g => !string.IsNullOrWhiteSpace(g.Name)
              && !char.IsDigit(g.Name[0])
              && !string.IsNullOrWhiteSpace(g.Value)) switch {
                { Name: SeqWildcardGr } asterisk => (SequenceWildcard, SequenceRegex),     // no need to filter the results
                { Name: CharWildcardGr } question => (CharacterWildcard, CharacterRegex),
                { Name: ClassGr } chrClass => (CharacterWildcard, $"[{TransformClass(chrClass.Value)}]"),
                  _ => throw new ArgumentException("Invalid glob pattern match.", nameof(match)),
              };

    static ReadOnlySpan<char> TransformClass(string globClass)
    {
        var globReader = new SpanReader(globClass);
        var globWriter = new SpanWriter(new Memory<char>(new char[10*globClass.Length]).Span);

        // the first char(s) can be '!' or ']' or '!]' that need special handling
        if (globReader.Peek() is '!')
        {
            _ = globReader.Read();  // consume it
            globWriter.Write(globReader.Remaining is > 1 ? '^' : '!'); // deal with the case of [!] vs [!class]
        }

        if (globReader.IsEmpty)
            return globWriter.Chars;

        if (globReader.Peek() is ']')
        {
            _ = globReader.Read();  // consume it
            globWriter.Write(']');
        }

        if (globReader.IsEmpty)
            return globWriter.Chars;

        var matches = NamedClass().Matches(globClass);

        // replace all wildcards with '*'
        foreach (Match match in matches)
        {
            // the non-match is from the current position to the start of the match - escape and copy the next non-match
            if (match.Index > globReader.Position)
                globWriter.Write(RegexEscape(globReader.Read(match.Index-globReader.Position)));

            _ = globReader.Read(match.Length);  // consume the match

            Debug.Assert(_namedClassTranslations.ContainsKey(match.Groups[ClassNameGr].Value), "We know this class name can be translated.");

            // get the class name, translate it and write it to the writer
            globWriter.Write(_namedClassTranslations[match.Groups[ClassNameGr].Value]);
        }

        // escape and copy the final non-match
        if (!globReader.IsEmpty)
            globWriter.Write(RegexEscape(globReader.ReadAll()));

        return globWriter.Chars;
    }

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
}