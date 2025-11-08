namespace vm2.DevOps.Glob.Api;

[DebuggerDisplay("{Chars}")]
ref struct SpanWriter
{
    readonly Span<char> _chars;

    public readonly ReadOnlySpan<char> Chars => _chars[..Length];

    public int Length { get; private set; } = 0;

    public readonly bool IsFull => Length >= _chars.Length;

    public SpanWriter(Span<char> chars) => _chars = chars;

    public void Write(ReadOnlySpan<char> text)
    {
        if (text.Length + Length > _chars.Length)
            throw new ArgumentOutOfRangeException(nameof(text), "Not enough space in span");

        text.CopyTo(_chars[Length..]);
        Length += text.Length;
    }

    public void Write(char text) => _chars[Length++] = text;
}
