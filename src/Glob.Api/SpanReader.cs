namespace vm2.DevOps.Glob.Api;

[DebuggerDisplay("{Chars}")]
ref struct SpanReader
{
    readonly ReadOnlySpan<char> _chars;

    public readonly ReadOnlySpan<char> Chars => _chars[Length..];
    public int Length { get; private set; } = 0;

    public readonly bool IsEmpty => Length >= _chars.Length;

    public SpanReader(ReadOnlySpan<char> chars) => _chars = chars;

    public ReadOnlySpan<char> Read(int size)
    {
        if (Length + size > _chars.Length)
            throw new ArgumentOutOfRangeException(nameof(size), "Not enough characters in span");

        var s = _chars[Length..(Length+size)];

        Length += size;
        return s;
    }

    public char Read()
    {
        if (Length + 1 > _chars.Length)
            throw new ArgumentOutOfRangeException("", "Not enough characters in span");

        return _chars[Length++];
    }

    public ReadOnlySpan<char> ReadAll()
    {
        if (IsEmpty)
            throw new ArgumentOutOfRangeException(nameof(Length), "No more characters in span");

        var s = _chars[Length..];

        Length = _chars.Length;
        return s;
    }
}
