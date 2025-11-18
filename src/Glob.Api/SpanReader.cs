namespace vm2.DevOps.Glob.Api;

/// <summary>
/// Provides a utility for sequentially reading characters or slices of characters from a <see cref="ReadOnlySpan{T}"/>
/// of type <see cref="char"/>. Works like a forward-only reader or read-only stream.
/// </summary>
/// <remarks>
/// This struct is designed for efficient, read-only traversal of a span of characters. It maintains an internal position to
/// track the current read offset, allowing methods to read or peek at characters without modifying the underlying span. The
/// <see cref="Position"/> property indicates the current position, and the <see cref="IsEmpty"/> property can be used to check if
/// there are any remaining characters to read.</remarks>
[DebuggerDisplay("{Chars}")]
public ref struct SpanReader
{
    /// <summary>
    /// The underlying span of characters to read from.
    /// </summary>
    readonly ReadOnlySpan<char> _chars;

    /// <summary>
    /// Gets the position of the first non-read character.
    /// </summary>
    public int Position { get; private set; } = 0;

    /// <summary>
    /// Gets the length of the remaining characters in the sequence.
    /// </summary>
    public readonly int Remaining => _chars.Length - Position;

    /// <summary>
    /// Gets a value indicating whether there is no more data to read from the span.
    /// </summary>
    public readonly bool IsEmpty => Remaining <= 0;

    /// <summary>
    /// Initializes a new instance of the <see cref="SpanReader"/> class with the specified span of characters.
    /// </summary>
    /// <param name="chars">The read-only span of characters to be used as the source for reading operations.</param>
    public SpanReader(ReadOnlySpan<char> chars) => _chars = chars;

    /// <summary>
    /// Reads a specified number of characters from the current <see cref="Position"/> in the span and advances it by that
    /// number.
    /// </summary>
    /// <param name="size">The number of characters to read.</param>
    /// <returns>A span containing the read characters.</returns>
    /// <exception cref="ArgumentOutOfRangeException">Thrown when there are not enough characters in the span.</exception>
    public ReadOnlySpan<char> Read(int size)
    {
        if (size > Remaining)
            throw new ArgumentOutOfRangeException(nameof(size), "Not enough characters in span");

        var s = _chars[Position..(Position+size)];

        Position += size;
        return s;
    }

    /// <summary>
    /// Reads the next character from the span and advances the <see cref="Position"/> by one.
    /// </summary>
    /// <returns>The next character in the span.</returns>
    /// <exception cref="ArgumentOutOfRangeException">Thrown if there are no more characters available to read in the span.</exception>
    public char Read()
    {
        if (IsEmpty)
            throw new ArgumentOutOfRangeException("", "Not enough characters in span");

        return _chars[Position++];
    }

    /// <summary>
    /// Reads all remaining characters from the current <see cref="Position"/> to the end of the span.
    /// </summary>
    /// <remarks>
    /// After calling this method, the position is advanced to the end of the span, and subsequent Read or Peek calls will throw
    /// an exception. Also subsequent calls to <see cref="IsEmpty"/> will return <see langword="true"/>.
    /// </remarks>
    /// <returns>A read-only span of characters representing the remaining portion of the span.</returns>
    /// <exception cref="ArgumentOutOfRangeException">Thrown if there are no more characters to read from the span.</exception>
    public ReadOnlySpan<char> ReadAll()
    {
        if (IsEmpty)
            throw new ArgumentOutOfRangeException(nameof(Position), "No more characters in span");

        var s = _chars[Position..];

        Position = _chars.Length;
        return s;
    }

    /// <summary>
    /// Peeks at a specified number of characters from the current <see cref="Position"/> in the span without advancing it.
    /// </summary>
    /// <param name="size"></param>
    /// <returns></returns>
    /// <exception cref="ArgumentOutOfRangeException"></exception>
    public readonly ReadOnlySpan<char> Peek(int size)
    {
        if (size > Remaining)
            throw new ArgumentOutOfRangeException(nameof(size), "Not enough characters in span");

        return _chars[Position..(Position+size)];
    }

    /// <summary>
    /// Peeks at the next character in the span without advancing the <see cref="Position"/>.
    /// </summary>
    /// <returns></returns>
    /// <exception cref="ArgumentOutOfRangeException"></exception>
    public readonly char Peek()
    {
        if (IsEmpty)
            throw new ArgumentOutOfRangeException("", "Not enough characters in span");

        return _chars[Position];
    }

    /// <summary>
    /// Retrieves a read-only span of characters starting from the current position to the end of the span without advancing the
    /// <see cref="Position"/>.
    /// </summary>
    /// <remarks>This method does not modify the current position. It provides a view of the remaining
    /// characters in the span.</remarks>
    /// <returns>A <see cref="ReadOnlySpan{T}"/> of characters representing the remaining portion of the span.</returns>
    /// <exception cref="ArgumentOutOfRangeException">Thrown when there are no more characters in the span, i.e., when the span is empty.</exception>
    public readonly ReadOnlySpan<char> PeekAll()
    {
        if (IsEmpty)
            throw new ArgumentOutOfRangeException(nameof(Position), "No more characters in span");

        return _chars[Position..];
    }
}
