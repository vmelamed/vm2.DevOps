// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Val Melamed

namespace vm2.DevOps.Glob.Api.Tests;

/// <summary>
/// Unit tests for the SpanReader ref struct.
/// </summary>
public class SpanReaderTests
{
    #region Constructor Tests

    [Fact]
    public void Constructor_WithEmptySpan_CreatesEmptyReader()
    {
        // Arrange & Act
        var reader = new SpanReader(ReadOnlySpan<char>.Empty);

        // Assert
        reader.Position.Should().Be(0);
        reader.Remaining.Should().Be(0);
        reader.IsEmpty.Should().BeTrue();
    }

    [Fact]
    public void Constructor_WithNonEmptySpan_InitializesCorrectly()
    {
        // Arrange
        var text = "Hello World".AsSpan();

        // Act
        var reader = new SpanReader(text);

        // Assert
        reader.Position.Should().Be(0);
        reader.Remaining.Should().Be(11);
        reader.IsEmpty.Should().BeFalse();
    }

    #endregion

    #region Read(int) Tests

    [Fact]
    public void Read_WithValidSize_ReturnsCorrectSpan()
    {
        // Arrange
        var reader = new SpanReader("Hello World".AsSpan());

        // Act
        var result = reader.Read(5);

        // Assert
        result.ToString().Should().Be("Hello");
        reader.Position.Should().Be(5);
        reader.Remaining.Should().Be(6);
    }

    [Fact]
    public void Read_MultipleReads_AdvancesPositionCorrectly()
    {
        // Arrange
        var reader = new SpanReader("ABCDEFGH".AsSpan());

        // Act
        var first = reader.Read(3);
        var second = reader.Read(2);
        var third = reader.Read(3);

        // Assert
        first.ToString().Should().Be("ABC");
        second.ToString().Should().Be("DE");
        third.ToString().Should().Be("FGH");
        reader.Position.Should().Be(8);
        reader.IsEmpty.Should().BeTrue();
    }

    [Fact]
    public void Read_ExactlyAllCharacters_Succeeds()
    {
        // Arrange
        var reader = new SpanReader("Test".AsSpan());

        // Act
        var result = reader.Read(4);

        // Assert
        result.ToString().Should().Be("Test");
        reader.IsEmpty.Should().BeTrue();
    }

    [Fact]
    public void Read_MoreThanRemaining_ThrowsArgumentOutOfRangeException()
    {
        // Arrange
        var reader = new SpanReader("ABC".AsSpan());

        // Act & Assert
        try
        {
            reader.Read(5);
            Assert.Fail("Expected ArgumentOutOfRangeException was not thrown");
        }
        catch (ArgumentOutOfRangeException ex)
        {
            ex.ParamName.Should().Be("size");
            ex.Message.Should().Contain("Not enough characters in span");
        }
    }

    [Fact]
    public void Read_ZeroSize_ReturnsEmptySpan()
    {
        // Arrange
        var reader = new SpanReader("Hello".AsSpan());

        // Act
        var result = reader.Read(0);

        // Assert
        result.IsEmpty.Should().BeTrue();
        reader.Position.Should().Be(0);
    }

    #endregion

    #region Read() Single Character Tests

    [Fact]
    public void Read_SingleChar_ReturnsFirstCharacter()
    {
        // Arrange
        var reader = new SpanReader("ABC".AsSpan());

        // Act
        var result = reader.Read();

        // Assert
        result.Should().Be('A');
        reader.Position.Should().Be(1);
        reader.Remaining.Should().Be(2);
    }

    [Fact]
    public void Read_SingleChar_MultipleReads_ReturnsSequentially()
    {
        // Arrange
        var reader = new SpanReader("XYZ".AsSpan());

        // Act & Assert
        reader.Read().Should().Be('X');
        reader.Read().Should().Be('Y');
        reader.Read().Should().Be('Z');
        reader.IsEmpty.Should().BeTrue();
    }

    [Fact]
    public void Read_SingleChar_OnEmptyReader_ThrowsArgumentOutOfRangeException()
    {
        // Arrange
        var reader = new SpanReader(ReadOnlySpan<char>.Empty);

        // Act & Assert
        try
        {
            reader.Read();
            Assert.Fail("Expected ArgumentOutOfRangeException was not thrown");
        }
        catch (ArgumentOutOfRangeException ex)
        {
            ex.Message.Should().Contain("Not enough characters in span");
        }
    }

    [Fact]
    public void Read_SingleChar_AfterFullyRead_ThrowsArgumentOutOfRangeException()
    {
        // Arrange
        var reader = new SpanReader("A".AsSpan());
        reader.Read(); // Consume the only character

        // Act & Assert
        try
        {
            reader.Read();
            Assert.Fail("Expected ArgumentOutOfRangeException was not thrown");
        }
        catch (ArgumentOutOfRangeException)
        {
            // Expected
        }
    }

    #endregion

    #region ReadAll Tests

    [Fact]
    public void ReadAll_FromBeginning_ReturnsEntireSpan()
    {
        // Arrange
        var reader = new SpanReader("Hello World".AsSpan());

        // Act
        var result = reader.ReadAll();

        // Assert
        result.ToString().Should().Be("Hello World");
        reader.Position.Should().Be(11);
        reader.IsEmpty.Should().BeTrue();
    }

    [Fact]
    public void ReadAll_AfterPartialRead_ReturnsRemainingSpan()
    {
        // Arrange
        var reader = new SpanReader("ABCDEFGH".AsSpan());
        reader.Read(3); // Read "ABC"

        // Act
        var result = reader.ReadAll();

        // Assert
        result.ToString().Should().Be("DEFGH");
        reader.IsEmpty.Should().BeTrue();
    }

    [Fact]
    public void ReadAll_OnEmptyReader_ThrowsArgumentOutOfRangeException()
    {
        // Arrange
        var reader = new SpanReader(ReadOnlySpan<char>.Empty);

        // Act & Assert
        try
        {
            reader.ReadAll();
            Assert.Fail("Expected ArgumentOutOfRangeException was not thrown");
        }
        catch (ArgumentOutOfRangeException ex)
        {
            ex.ParamName.Should().Be("Position");
            ex.Message.Should().Contain("No more characters in span");
        }
    }

    [Fact]
    public void ReadAll_CalledTwice_ThrowsOnSecondCall()
    {
        // Arrange
        var reader = new SpanReader("Test".AsSpan());
        reader.ReadAll(); // First call

        // Act & Assert
        try
        {
            reader.ReadAll();
            Assert.Fail("Expected ArgumentOutOfRangeException was not thrown");
        }
        catch (ArgumentOutOfRangeException)
        {
            // Expected
        }
    }

    #endregion

    #region Peek(int) Tests

    [Fact]
    public void Peek_ValidSize_ReturnsWithoutAdvancing()
    {
        // Arrange
        var reader = new SpanReader("Hello".AsSpan());

        // Act
        var result = reader.Peek(3);

        // Assert
        result.ToString().Should().Be("Hel");
        reader.Position.Should().Be(0); // Position unchanged
        reader.Remaining.Should().Be(5);
    }

    [Fact]
    public void Peek_MultipleTimes_ReturnsSameResult()
    {
        // Arrange
        var reader = new SpanReader("ABC".AsSpan());

        // Act
        var first = reader.Peek(2);
        var second = reader.Peek(2);

        // Assert
        first.ToString().Should().Be("AB");
        second.ToString().Should().Be("AB");
        reader.Position.Should().Be(0);
    }

    [Fact]
    public void Peek_AfterRead_PeeksFromCurrentPosition()
    {
        // Arrange
        var reader = new SpanReader("ABCDEF".AsSpan());
        reader.Read(2); // Read "AB", position now at 2

        // Act
        var result = reader.Peek(3);

        // Assert
        result.ToString().Should().Be("CDE");
        reader.Position.Should().Be(2); // Still at 2
    }

    [Fact]
    public void Peek_MoreThanRemaining_ThrowsArgumentOutOfRangeException()
    {
        // Arrange
        var reader = new SpanReader("Hi".AsSpan());

        // Act & Assert
        try
        {
            reader.Peek(5);
            Assert.Fail("Expected ArgumentOutOfRangeException was not thrown");
        }
        catch (ArgumentOutOfRangeException ex)
        {
            ex.ParamName.Should().Be("size");
            ex.Message.Should().Contain("Not enough characters in span");
        }
    }

    [Fact]
    public void Peek_ZeroSize_ReturnsEmptySpan()
    {
        // Arrange
        var reader = new SpanReader("Test".AsSpan());

        // Act
        var result = reader.Peek(0);

        // Assert
        result.IsEmpty.Should().BeTrue();
        reader.Position.Should().Be(0);
    }

    #endregion

    #region Peek() Single Character Tests

    [Fact]
    public void Peek_SingleChar_ReturnsWithoutAdvancing()
    {
        // Arrange
        var reader = new SpanReader("ABC".AsSpan());

        // Act
        var result = reader.Peek();

        // Assert
        result.Should().Be('A');
        reader.Position.Should().Be(0);
    }

    [Fact]
    public void Peek_SingleChar_MultipleTimes_ReturnsSameCharacter()
    {
        // Arrange
        var reader = new SpanReader("XYZ".AsSpan());

        // Act
        var first = reader.Peek();
        var second = reader.Peek();
        var third = reader.Peek();

        // Assert
        first.Should().Be('X');
        second.Should().Be('X');
        third.Should().Be('X');
        reader.Position.Should().Be(0);
    }

    [Fact]
    public void Peek_SingleChar_AfterRead_PeeksNextCharacter()
    {
        // Arrange
        var reader = new SpanReader("123".AsSpan());
        reader.Read(); // Read '1'

        // Act
        var result = reader.Peek();

        // Assert
        result.Should().Be('2');
        reader.Position.Should().Be(1);
    }

    [Fact]
    public void Peek_SingleChar_OnEmptyReader_ThrowsArgumentOutOfRangeException()
    {
        // Arrange
        var reader = new SpanReader(ReadOnlySpan<char>.Empty);

        // Act & Assert
        try
        {
            reader.Peek();
            Assert.Fail("Expected ArgumentOutOfRangeException was not thrown");
        }
        catch (ArgumentOutOfRangeException ex)
        {
            ex.Message.Should().Contain("Not enough characters in span");
        }
    }

    #endregion

    #region PeekAll Tests

    [Fact]
    public void PeekAll_FromBeginning_ReturnsEntireSpanWithoutAdvancing()
    {
        // Arrange
        var reader = new SpanReader("Hello World".AsSpan());

        // Act
        var result = reader.PeekAll();

        // Assert
        result.ToString().Should().Be("Hello World");
        reader.Position.Should().Be(0);
        reader.Remaining.Should().Be(11);
    }

    [Fact]
    public void PeekAll_AfterPartialRead_ReturnsRemainingWithoutAdvancing()
    {
        // Arrange
        var reader = new SpanReader("ABCDEFGH".AsSpan());
        reader.Read(3); // Read "ABC"

        // Act
        var result = reader.PeekAll();

        // Assert
        result.ToString().Should().Be("DEFGH");
        reader.Position.Should().Be(3); // Unchanged
    }

    [Fact]
    public void PeekAll_MultipleTimes_ReturnsSameResult()
    {
        // Arrange
        var reader = new SpanReader("Test".AsSpan());

        // Act
        var first = reader.PeekAll();
        var second = reader.PeekAll();

        // Assert
        first.ToString().Should().Be("Test");
        second.ToString().Should().Be("Test");
        reader.Position.Should().Be(0);
    }

    [Fact]
    public void PeekAll_OnEmptyReader_ThrowsArgumentOutOfRangeException()
    {
        // Arrange
        var reader = new SpanReader(ReadOnlySpan<char>.Empty);

        // Act & Assert
        try
        {
            reader.PeekAll();
            Assert.Fail("Expected ArgumentOutOfRangeException was not thrown");
        }
        catch (ArgumentOutOfRangeException ex)
        {
            ex.ParamName.Should().Be("Position");
            ex.Message.Should().Contain("No more characters in span");
        }
    }

    #endregion

    #region Integration Tests

    [Fact]
    public void SpanReader_MixedReadAndPeek_BehavesCorrectly()
    {
        // Arrange
        var reader = new SpanReader("ABCDEFGH".AsSpan());

        // Act & Assert
        reader.Peek().Should().Be('A');
        reader.Position.Should().Be(0);

        var read1 = reader.Read(2);
        read1.ToString().Should().Be("AB");
        reader.Position.Should().Be(2);

        reader.Peek(3).ToString().Should().Be("CDE");
        reader.Position.Should().Be(2); // Still at 2

        var read2 = reader.Read();
        read2.Should().Be('C');
        reader.Position.Should().Be(3);

        reader.PeekAll().ToString().Should().Be("DEFGH");
        reader.Position.Should().Be(3); // Still at 3

        var readAll = reader.ReadAll();
        readAll.ToString().Should().Be("DEFGH");
        reader.IsEmpty.Should().BeTrue();
    }

    [Fact]
    public void SpanReader_ParseScenario_WorksCorrectly()
    {
        // Arrange - Simulate parsing "key=value"
        var reader = new SpanReader("name=John".AsSpan());

        // Act - Read until '='
        var key = reader.Read(4); // "name"
        var equals = reader.Read(); // '='
        var value = reader.ReadAll(); // "John"

        // Assert
        key.ToString().Should().Be("name");
        equals.Should().Be('=');
        value.ToString().Should().Be("John");
        reader.IsEmpty.Should().BeTrue();
    }

    [Fact]
    public void SpanReader_LookAheadScenario_WorksCorrectly()
    {
        // Arrange
        var reader = new SpanReader("  trimmed".AsSpan());

        // Act - Peek to check for whitespace without consuming
        while (!reader.IsEmpty && reader.Peek() == ' ')
        {
            reader.Read(); // Consume whitespace
        }

        var result = reader.ReadAll();

        // Assert
        result.ToString().Should().Be("trimmed");
    }

    #endregion

    #region Edge Cases

    [Fact]
    public void SpanReader_SingleCharacterSpan_WorksCorrectly()
    {
        // Arrange
        var reader = new SpanReader("X".AsSpan());

        // Act & Assert
        reader.Peek().Should().Be('X');
        reader.Read().Should().Be('X');
        reader.IsEmpty.Should().BeTrue();
    }

    [Fact]
    public void SpanReader_WithSpecialCharacters_HandlesCorrectly()
    {
        // Arrange
        var reader = new SpanReader("Hello\nWorld\t!".AsSpan());

        // Act
        var line1 = reader.Read(5);
        var newline = reader.Read();
        var line2 = reader.Read(5);
        var tab = reader.Read();
        var exclamation = reader.Read();

        // Assert
        line1.ToString().Should().Be("Hello");
        newline.Should().Be('\n');
        line2.ToString().Should().Be("World");
        tab.Should().Be('\t');
        exclamation.Should().Be('!');
    }

    [Theory]
    [InlineData("")]
    [InlineData("A")]
    [InlineData("Hello World")]
    [InlineData("1234567890")]
    public void SpanReader_VariousLengths_HandlesCorrectly(string input)
    {
        // Arrange
        var reader = new SpanReader(input.AsSpan());

        // Act & Assert
        reader.Remaining.Should().Be(input.Length);
        reader.IsEmpty.Should().Be(input.Length == 0);

        if (input.Length > 0)
        {
            var all = reader.ReadAll();
            all.ToString().Should().Be(input);
            reader.IsEmpty.Should().BeTrue();
        }
    }

    #endregion
}