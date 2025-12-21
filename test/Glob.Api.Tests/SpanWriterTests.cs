// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Val Melamed

namespace vm2.DevOps.Glob.Api.Tests;

/// <summary>
/// Unit tests for the SpanWriter ref struct.
/// </summary>
public class SpanWriterTests
{
    #region Constructor Tests

    [Fact]
    public void Constructor_WithEmptySpan_CreatesEmptyWriter()
    {
        // Arrange
        Span<char> buffer = stackalloc char[0];

        // Act
        var writer = new SpanWriter(buffer);

        // Assert
        writer.Position.Should().Be(0);
        writer.Remaining.Should().Be(0);
        writer.IsFull.Should().BeTrue();
        writer.Chars.IsEmpty.Should().BeTrue();
    }

    [Fact]
    public void Constructor_WithNonEmptySpan_InitializesCorrectly()
    {
        // Arrange
        Span<char> buffer = stackalloc char[10];

        // Act
        var writer = new SpanWriter(buffer);

        // Assert
        writer.Position.Should().Be(0);
        writer.Remaining.Should().Be(10);
        writer.IsFull.Should().BeFalse();
        writer.Chars.IsEmpty.Should().BeTrue();
    }

    #endregion

    #region Write(ReadOnlySpan<char>) Tests

    [Fact]
    public void Write_Span_WritesToBuffer()
    {
        // Arrange
        Span<char> buffer = stackalloc char[20];
        var writer = new SpanWriter(buffer);

        // Act
        writer.Write("Hello".AsSpan());

        // Assert
        writer.Position.Should().Be(5);
        writer.Remaining.Should().Be(15);
        writer.Chars.ToString().Should().Be("Hello");
    }

    [Fact]
    public void Write_Span_MultipleWrites_AppendsCorrectly()
    {
        // Arrange
        Span<char> buffer = stackalloc char[20];
        var writer = new SpanWriter(buffer);

        // Act
        writer.Write("Hello".AsSpan());
        writer.Write(" ".AsSpan());
        writer.Write("World".AsSpan());

        // Assert
        writer.Position.Should().Be(11);
        writer.Chars.ToString().Should().Be("Hello World");
    }

    [Fact]
    public void Write_Span_ExactlyFillsBuffer_Succeeds()
    {
        // Arrange
        Span<char> buffer = stackalloc char[5];
        var writer = new SpanWriter(buffer);

        // Act
        writer.Write("Hello".AsSpan());

        // Assert
        writer.Position.Should().Be(5);
        writer.IsFull.Should().BeTrue();
        writer.Chars.ToString().Should().Be("Hello");
    }

    [Fact]
    public void Write_Span_ExceedsBuffer_ThrowsArgumentOutOfRangeException()
    {
        // Arrange
        var write = () => { var writer = new SpanWriter(stackalloc char[5]); writer.Write("Too Long!".AsSpan()); };

        // Act & Assert
        write
            .Should()
            .Throw<ArgumentOutOfRangeException>()
            .WithMessage("Not enough space in the span (Parameter 'text')")
            .And
            .ParamName
            .Should()
            .Be("text")
            ;
    }

    [Fact]
    public void Write_Span_EmptySpan_DoesNothing()
    {
        // Arrange
        Span<char> buffer = stackalloc char[10];
        var writer = new SpanWriter(buffer);
        writer.Write("Test".AsSpan());

        // Act
        writer.Write(ReadOnlySpan<char>.Empty);

        // Assert
        writer.Position.Should().Be(4);
        writer.Chars.ToString().Should().Be("Test");
    }

    [Fact]
    public void Write_Span_AfterFull_ThrowsArgumentOutOfRangeException()
    {
        // Arrange
        var write = () =>
        {
            var writer = new SpanWriter(stackalloc char[3]);
            writer.Write("ABC".AsSpan()); // Fill buffer
            writer.Write("D".AsSpan());   // This should throw
        };

        // Act & Assert
        write
            .Should()
            .Throw<ArgumentOutOfRangeException>()
            .WithMessage("Not enough space in the span (Parameter 'text')")
            .And
            .ParamName
            .Should()
            .Be("text")
            ;
    }

    #endregion

    #region Write(char) Tests

    [Fact]
    public void Write_Char_WritesToBuffer()
    {
        // Arrange
        Span<char> buffer = stackalloc char[10];
        var writer = new SpanWriter(buffer);

        // Act
        writer.Write('A');

        // Assert
        writer.Position.Should().Be(1);
        writer.Remaining.Should().Be(9);
        writer.Chars.ToString().Should().Be("A");
    }

    [Fact]
    public void Write_Char_MultipleWrites_AppendsCorrectly()
    {
        // Arrange
        Span<char> buffer = stackalloc char[10];
        var writer = new SpanWriter(buffer);

        // Act
        writer.Write('A');
        writer.Write('B');
        writer.Write('C');

        // Assert
        writer.Position.Should().Be(3);
        writer.Chars.ToString().Should().Be("ABC");
    }

    [Fact]
    public void Write_Char_FillsBufferExactly_Succeeds()
    {
        // Arrange
        Span<char> buffer = stackalloc char[3];
        var writer = new SpanWriter(buffer);

        // Act
        writer.Write('X');
        writer.Write('Y');
        writer.Write('Z');

        // Assert
        writer.IsFull.Should().BeTrue();
        writer.Chars.ToString().Should().Be("XYZ");
    }

    [Fact]
    public void Write_Char_WhenFull_ThrowsArgumentOutOfRangeException()
    {
        // Arrange
        var write = () =>
        {
            var writer = new SpanWriter(stackalloc char[2]);
            writer.Write('A');
            writer.Write('B'); // Now full
            writer.Write('C');
        };

        // Act & Assert
        write
            .Should()
            .Throw<ArgumentOutOfRangeException>()
            .WithMessage("Not enough space in the span (Parameter 'text')")
            .And
            .ParamName
            .Should()
            .Be("text")
            ;
    }

    [Fact]
    public void Write_Char_SpecialCharacters_WritesCorrectly()
    {
        // Arrange
        Span<char> buffer = stackalloc char[10];
        var writer = new SpanWriter(buffer);

        // Act
        writer.Write('\n');
        writer.Write('\t');
        writer.Write('\r');

        // Assert
        writer.Position.Should().Be(3);
        writer.Chars[0].Should().Be('\n');
        writer.Chars[1].Should().Be('\t');
        writer.Chars[2].Should().Be('\r');
    }

    #endregion

    #region Properties Tests

    [Fact]
    public void Position_UpdatesCorrectlyAfterWrites()
    {
        // Arrange
        Span<char> buffer = stackalloc char[20];
        var writer = new SpanWriter(buffer);

        // Act & Assert
        writer.Position.Should().Be(0);

        writer.Write("ABC".AsSpan());
        writer.Position.Should().Be(3);

        writer.Write('D');
        writer.Position.Should().Be(4);

        writer.Write("EF".AsSpan());
        writer.Position.Should().Be(6);
    }

    [Fact]
    public void Remaining_DecreasesAsWritesOccur()
    {
        // Arrange
        Span<char> buffer = stackalloc char[10];
        var writer = new SpanWriter(buffer);

        // Act & Assert
        writer.Remaining.Should().Be(10);

        writer.Write("Hello".AsSpan());
        writer.Remaining.Should().Be(5);

        writer.Write('!');
        writer.Remaining.Should().Be(4);
    }

    [Fact]
    public void IsFull_ReturnsTrueWhenBufferFull()
    {
        // Arrange
        Span<char> buffer = stackalloc char[3];
        var writer = new SpanWriter(buffer);

        // Act & Assert
        writer.IsFull.Should().BeFalse();

        writer.Write("AB".AsSpan());
        writer.IsFull.Should().BeFalse();

        writer.Write('C');
        writer.IsFull.Should().BeTrue();
    }

    [Fact]
    public void Chars_ReturnsWrittenPortion()
    {
        // Arrange
        Span<char> buffer = stackalloc char[20];
        var writer = new SpanWriter(buffer);

        // Act
        writer.Write("Test".AsSpan());
        var result1 = writer.Chars;

        writer.Write(" ".AsSpan());
        writer.Write("123".AsSpan());
        var result2 = writer.Chars;

        // Assert
        result1.ToString().Should().Be("Test");
        result2.ToString().Should().Be("Test 123");
        writer.Position.Should().Be(8);
    }

    #endregion

    #region Integration Tests

    [Fact]
    public void SpanWriter_MixedWrites_BuildsStringCorrectly()
    {
        // Arrange
        Span<char> buffer = stackalloc char[50];
        var writer = new SpanWriter(buffer);

        // Act
        writer.Write("Hello".AsSpan());
        writer.Write(' ');
        writer.Write("World".AsSpan());
        writer.Write('!');

        // Assert
        writer.Chars.ToString().Should().Be("Hello World!");
        writer.Position.Should().Be(12);
        writer.Remaining.Should().Be(38);
    }

    [Fact]
    public void SpanWriter_BuildComplexString_WorksCorrectly()
    {
        // Arrange
        Span<char> buffer = stackalloc char[100];
        var writer = new SpanWriter(buffer);

        // Act - Simulate building a formatted string
        writer.Write("Name".AsSpan());
        writer.Write(':');
        writer.Write(' ');
        writer.Write("John Doe".AsSpan());
        writer.Write(',');
        writer.Write(' ');
        writer.Write("Age".AsSpan());
        writer.Write(':');
        writer.Write(' ');
        writer.Write("30".AsSpan());

        // Assert
        writer.Chars.ToString().Should().Be("Name: John Doe, Age: 30");
    }

    [Fact]
    public void SpanWriter_ProgressiveBuilding_MaintainsState()
    {
        // Arrange
        Span<char> buffer = stackalloc char[30];
        var writer = new SpanWriter(buffer);

        // Act & Assert - Progressive checks
        writer.Write("Start".AsSpan());
        writer.Chars.ToString().Should().Be("Start");
        writer.Remaining.Should().Be(25);

        writer.Write(" -> ".AsSpan());
        writer.Chars.ToString().Should().Be("Start -> ");

        writer.Write("End".AsSpan());
        writer.Chars.ToString().Should().Be("Start -> End");
    }

    #endregion

    #region Edge Cases

    [Fact]
    public void SpanWriter_SingleCharBuffer_WorksCorrectly()
    {
        // Arrange
        Span<char> buffer = stackalloc char[1];
        var writer = new SpanWriter(buffer);

        // Act
        writer.Write('X');

        // Assert
        writer.Chars.ToString().Should().Be("X");
        writer.IsFull.Should().BeTrue();
    }

    [Fact]
    public void SpanWriter_LargeBuffer_HandlesCorrectly()
    {
        // Arrange
        Span<char> buffer = stackalloc char[1000];
        var writer = new SpanWriter(buffer);

        // Act
        for (var i = 0; i < 100; i++)
        {
            writer.Write('A');
        }

        // Assert
        writer.Position.Should().Be(100);
        writer.Remaining.Should().Be(900);
        writer.Chars.Length.Should().Be(100);
    }

    [Theory]
    [InlineData(0)]
    [InlineData(1)]
    [InlineData(10)]
    [InlineData(100)]
    public void SpanWriter_VariousBufferSizes_WorksCorrectly(int size)
    {
        // Arrange
        Span<char> buffer = stackalloc char[size];
        var writer = new SpanWriter(buffer);

        // Act & Assert
        writer.Remaining.Should().Be(size);
        writer.IsFull.Should().Be(size == 0);

        if (size > 0)
        {
            writer.Write('T');
            writer.Position.Should().Be(1);
            writer.Remaining.Should().Be(size - 1);
        }
    }

    [Fact]
    public void SpanWriter_WriteUnicodeCharacters_HandlesCorrectly()
    {
        // Arrange
        Span<char> buffer = stackalloc char[20];
        var writer = new SpanWriter(buffer);

        // Act
        writer.Write("Hello".AsSpan());
        writer.Write(' ');
        writer.Write("世界".AsSpan()); // "World" in Chinese

        // Assert
        writer.Chars.ToString().Should().Be("Hello 世界");
        writer.Position.Should().Be(8);
    }

    #endregion

    #region Realistic Scenarios

    [Fact]
    public void SpanWriter_PathBuilding_WorksCorrectly()
    {
        // Arrange
        Span<char> buffer = stackalloc char[100];
        var writer = new SpanWriter(buffer);

        // Act - Simulate building a file path
        writer.Write("C:".AsSpan());
        writer.Write('/');
        writer.Write("Users".AsSpan());
        writer.Write('/');
        writer.Write("Documents".AsSpan());
        writer.Write('/');
        writer.Write("file.txt".AsSpan());

        // Assert
        writer.Chars.ToString().Should().Be("C:/Users/Documents/file.txt");
    }

    [Fact]
    public void SpanWriter_RegexBuilding_WorksCorrectly()
    {
        // Arrange
        Span<char> buffer = stackalloc char[50];
        var writer = new SpanWriter(buffer);

        // Act - Simulate building regex pattern
        writer.Write("^".AsSpan());
        writer.Write(".*".AsSpan());
        writer.Write(@"\.".AsSpan());
        writer.Write("txt".AsSpan());
        writer.Write('$');

        // Assert
        writer.Chars.ToString().Should().Be(@"^.*\.txt$");
    }

    #endregion
}