namespace vm2.DevOps.Glob.Api;

/// <summary>
/// Provides a utility for writing characters to a <see cref="Span{T}"/> of type <see cref="char"/>. Works like a write-only
/// stream.
/// </summary>
[DebuggerDisplay("{Chars}")]
public ref struct SpanWriter
{
    /// <summary>
    /// The underlying span of characters to write to.
    /// </summary>
    readonly Span<char> _chars;

    /// <summary>
    /// Gets the current position within the sequence.
    /// </summary>
    public int Position { get; private set; } = 0;

    /// <summary>
    /// Gets the length of the remaining characters in the sequence.
    /// </summary>
    public readonly int Remaining => _chars.Length - Position;

    /// <summary>
    /// Gets the written characters as a read-only span.
    /// </summary>
    public readonly ReadOnlySpan<char> Chars => _chars[..Position];

    /// <summary>
    /// Gets a value indicating whether the current position has reached or exceeded the length of the character buffer.
    /// </summary>
    public readonly bool IsFull => Remaining <= 0;

    /// <summary>
    /// Initializes a new instance of the <see cref="SpanWriter"/> class with the specified character span.
    /// </summary>
    /// <param name="chars">
    /// The span of characters to be used by the writer. This span provides the buffer for writing operations.
    /// </param>
    public SpanWriter(Span<char> chars) => _chars = chars;

    /// <summary>
    /// Writes the specified text to the current position within the buffer.
    /// </summary>
    /// <remarks>After writing, the position within the buffer is advanced by the length of the written
    /// text.</remarks>
    /// <param name="text">
    /// The span of characters to write. The length of the span must not exceed the available space in the buffer.
    /// </param>
    /// <exception cref="ArgumentOutOfRangeException">
    /// Thrown if the length of <paramref name="text"/> exceeds the available space in the buffer.
    /// </exception>
    public void Write(ReadOnlySpan<char> text)
    {
        if (text.Length > Remaining)
            throw new ArgumentOutOfRangeException(nameof(text), "Not enough space in the span");

        text.CopyTo(_chars[Position..]);
        Position += text.Length;
    }

    /// <summary>
    /// Writes a single character to the current position in the buffer and advances the position.
    /// </summary>
    /// <param name="text">The character to write to the buffer.</param>
    /// <exception cref="ArgumentOutOfRangeException">
    /// Thrown if there is not enough space in the buffer to write the character.
    /// </exception>
    public void Write(char text)
    {
        if (IsFull)
            throw new ArgumentOutOfRangeException(nameof(text), "Not enough space in the span");

        _chars[Position++] = text;
    }
}
