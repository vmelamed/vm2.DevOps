// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Val Melamed

namespace vm2.DevOps.Glob.Api.Tests;

/// <summary>
/// Unit tests for the Deque{T} class.
/// </summary>
public class DequeTests
{
    #region Constructor Tests

    [Fact]
    public void Constructor_Default_CreatesQueueMode()
    {
        // Arrange & Act
        var deque = new Deque<int>();

        // Assert
        deque.IsStack.Should().BeFalse();
        deque.Count.Should().Be(0);
    }

    [Fact]
    public void Constructor_WithStackMode_CreatesStack()
    {
        // Arrange & Act
        var deque = new Deque<int>(isStack: true);

        // Assert
        deque.IsStack.Should().BeTrue();
        deque.Count.Should().Be(0);
    }

    [Theory]
    [InlineData(0)]
    [InlineData(10)]
    [InlineData(100)]
    public void Constructor_WithCapacity_SetsInitialCapacity(int capacity)
    {
        // Arrange & Act
        var deque = new Deque<int>(capacity: capacity);

        // Assert
        deque.Count.Should().Be(0);
        // Capacity doesn't affect external behavior, just performance
    }

    #endregion

    #region Add Tests

    [Fact]
    public void Add_SingleElement_IncreasesCount()
    {
        // Arrange
        var deque = new Deque<int>();

        // Act
        deque.Add(42);

        // Assert
        deque.Count.Should().Be(1);
    }

    [Fact]
    public void Add_MultipleElements_IncreasesCountCorrectly()
    {
        // Arrange
        var deque = new Deque<string>();

        // Act
        deque.Add("first");
        deque.Add("second");
        deque.Add("third");

        // Assert
        deque.Count.Should().Be(3);
    }

    #endregion

    #region TryGet Tests - Queue Mode (FIFO)

    [Fact]
    public void TryGet_QueueMode_EmptyDeque_ReturnsFalse()
    {
        // Arrange
        var deque = new Deque<int>(isStack: false);

        // Act
        var result = deque.TryGet(out var element);

        // Assert
        result.Should().BeFalse();
        element.Should().Be(0); // default for int
    }

    [Fact]
    public void TryGet_QueueMode_SingleElement_ReturnsFirstElement()
    {
        // Arrange
        var deque = new Deque<string>(isStack: false);
        deque.Add("first");

        // Act
        var result = deque.TryGet(out var element);

        // Assert
        result.Should().BeTrue();
        element.Should().Be("first");
        deque.Count.Should().Be(0);
    }

    [Fact]
    public void TryGet_QueueMode_MultipleElements_ReturnsInFIFOOrder()
    {
        // Arrange
        var deque = new Deque<int>(isStack: false);
        deque.Add(1);
        deque.Add(2);
        deque.Add(3);

        // Act & Assert
        deque.TryGet(out var first).Should().BeTrue();
        first.Should().Be(1);

        deque.TryGet(out var second).Should().BeTrue();
        second.Should().Be(2);

        deque.TryGet(out var third).Should().BeTrue();
        third.Should().Be(3);

        deque.Count.Should().Be(0);
    }
    #endregion

    #region Switch modes
    [Fact]
    public void SwitchingToStack_OnNonEmptyDeque_ThrowsInvalidOperationException()
    {
        // Arrange
        var deque = new Deque<int>(isStack: false);
        deque.Add(1);

        // Act
        var act = () => deque.IsStack = true;

        // Assert
        act.Should().Throw<InvalidOperationException>()
            .WithMessage("Cannot change the mode of a non-empty deque.");
    }

    [Fact]
    public void SwitchingToQueue_OnNonEmptyDeque_ThrowsInvalidOperationException()
    {
        // Arrange
        var deque = new Deque<int>(isStack: false);

        var act1 = () => deque.IsStack = true;

        act1.Should().NotThrow();

        deque.Add(1);

        // Act
        var act2 = () => deque.IsStack = false;

        // Assert
        act2
            .Should()
            .Throw<InvalidOperationException>()
            .WithMessage("Cannot change the mode of a non-empty deque.")
            ;
    }
    #endregion

    #region TryGet Tests - Stack Mode (LIFO)
    [Fact]
    public void TryGet_StackMode_EmptyDeque_ReturnsFalse()
    {
        // Arrange
        var deque = new Deque<int>(isStack: true);

        // Act
        var result = deque.TryGet(out var element);

        // Assert
        result.Should().BeFalse();
        element.Should().Be(0);
    }

    [Fact]
    public void TryGet_StackMode_SingleElement_ReturnsLastElement()
    {
        // Arrange
        var deque = new Deque<string>(isStack: true);
        deque.Add("only");

        // Act
        var result = deque.TryGet(out var element);

        // Assert
        result.Should().BeTrue();
        element.Should().Be("only");
        deque.Count.Should().Be(0);
    }

    [Fact]
    public void TryGet_StackMode_MultipleElements_ReturnsInLIFOOrder()
    {
        // Arrange
        var deque = new Deque<int>(isStack: true);
        deque.Add(1);
        deque.Add(2);
        deque.Add(3);

        // Act & Assert
        deque.TryGet(out var first).Should().BeTrue();
        first.Should().Be(3); // Last added

        deque.TryGet(out var second).Should().BeTrue();
        second.Should().Be(2);

        deque.TryGet(out var third).Should().BeTrue();
        third.Should().Be(1); // First added

        deque.Count.Should().Be(0);
    }

    #endregion

    #region Get Tests

    [Fact]
    public void Get_EmptyDeque_ThrowsInvalidOperationException()
    {
        // Arrange
        var deque = new Deque<int>();

        // Act
        var act = () => deque.Get();

        // Assert
        act.Should().Throw<InvalidOperationException>()
            .WithMessage("The dequeue is empty.");
    }

    [Fact]
    public void Get_QueueMode_ReturnsAndRemovesFirstElement()
    {
        // Arrange
        var deque = new Deque<string>(isStack: false);
        deque.Add("first");
        deque.Add("second");

        // Act
        var result = deque.Get();

        // Assert
        result.Should().Be("first");
        deque.Count.Should().Be(1);
    }

    [Fact]
    public void Get_StackMode_ReturnsAndRemovesLastElement()
    {
        // Arrange
        var deque = new Deque<string>(isStack: true);
        deque.Add("first");
        deque.Add("second");

        // Act
        var result = deque.Get();

        // Assert
        result.Should().Be("second");
        deque.Count.Should().Be(1);
    }

    #endregion

    #region GetAll Tests

    [Fact]
    public void GetAll_EmptyDeque_ReturnsEmptySequence()
    {
        // Arrange
        var deque = new Deque<int>();

        // Act
        var results = deque.GetAll().ToList();

        // Assert
        results.Should().BeEmpty();
        deque.Count.Should().Be(0);
    }

    [Fact]
    public void GetAll_QueueMode_ReturnsAllInFIFOOrder()
    {
        // Arrange
        var deque = new Deque<int>(isStack: false);
        deque.Add(1);
        deque.Add(2);
        deque.Add(3);

        // Act
        var results = deque.GetAll().ToList();

        // Assert
        results.Should().Equal(1, 2, 3);
        deque.Count.Should().Be(0);
    }

    [Fact]
    public void GetAll_StackMode_ReturnsAllInLIFOOrder()
    {
        // Arrange
        var deque = new Deque<int>(isStack: true);
        deque.Add(1);
        deque.Add(2);
        deque.Add(3);

        // Act
        var results = deque.GetAll().ToList();

        // Assert
        results.Should().Equal(3, 2, 1);
        deque.Count.Should().Be(0);
    }

    [Fact]
    public void GetAll_DrainsTheDeque()
    {
        // Arrange
        var deque = new Deque<string>();
        deque.Add("a");
        deque.Add("b");
        deque.Add("c");

        // Act
        var results = deque.GetAll().ToList();

        // Assert
        results.Should().HaveCount(3);
        deque.Count.Should().Be(0);
        deque.TryGet(out _).Should().BeFalse();
    }

    #endregion

    #region Clear Tests

    [Fact]
    public void Clear_EmptyDeque_RemainsEmpty()
    {
        // Arrange
        var deque = new Deque<int>();

        // Act
        deque.Clear();

        // Assert
        deque.Count.Should().Be(0);
    }

    [Fact]
    public void Clear_NonEmptyDeque_RemovesAllElements()
    {
        // Arrange
        var deque = new Deque<string>();
        deque.Add("one");
        deque.Add("two");
        deque.Add("three");

        // Act
        deque.Clear();

        // Assert
        deque.Count.Should().Be(0);
        deque.TryGet(out _).Should().BeFalse();
    }

    [Fact]
    public void Clear_AfterClear_CanAddNewElements()
    {
        // Arrange
        var deque = new Deque<int>();
        deque.Add(1);
        deque.Clear();

        // Act
        deque.Add(42);

        // Assert
        deque.Count.Should().Be(1);
        deque.TryGet(out var element).Should().BeTrue();
        element.Should().Be(42);
    }

    #endregion

    #region IEnumerable Tests

    [Fact]
    public void GetEnumerator_QueueMode_EnumeratesInFIFOOrder()
    {
        // Arrange
        var deque = new Deque<int>(isStack: false);
        deque.Add(1);
        deque.Add(2);
        deque.Add(3);

        var getEnumerator = () => deque.GetEnumerator();
        var enumerator = getEnumerator.Should().NotThrow().Which;
        var moveNext = () => enumerator.MoveNext();
        var current = () => enumerator.Current;

        // Act
        var results = new List<int>();

        while (moveNext.Should().NotThrow().Which)
            results.Add(current.Should().NotThrow().Which);

        // Assert
        results.Should().Equal(1, 2, 3);
        deque.Count.Should().Be(3); // Enumeration doesn't remove elements
    }

    [Fact]
    public void Enumerating_QueueMode_EnumeratesInFIFOOrder()
    {
        // Arrange
        var deque = new Deque<int>(isStack: false);
        deque.Add(1);
        deque.Add(2);
        deque.Add(3);

        // Act
        var results = new List<int>();
        foreach (var item in deque)
        {
            results.Add(item);
        }

        // Assert
        results.Should().Equal(1, 2, 3);
        deque.Count.Should().Be(3); // Enumeration doesn't remove elements
    }

    [Fact]
    public void GetEnumerator_QueueMode_EnumeratesInLIFOOrder()
    {
        // Arrange
        var deque = new Deque<int>(isStack: true);
        deque.Add(1);
        deque.Add(2);
        deque.Add(3);

        var getEnumerator = () => deque.GetEnumerator();
        var enumerator = getEnumerator.Should().NotThrow().Which;
        var moveNext = () => enumerator.MoveNext();
        var current = () => enumerator.Current;

        // Act
        var results = new List<int>();

        while (moveNext.Should().NotThrow().Which)
            results.Add(current.Should().NotThrow().Which);

        // Assert
        results.Should().Equal(3, 2, 1);
        deque.Count.Should().Be(3); // Enumeration doesn't remove elements
    }


    [Fact]
    public void Enumerating_StackMode_EnumeratesInLIFOOrder()
    {
        // Arrange
        var deque = new Deque<int>(isStack: true);
        deque.Add(1);
        deque.Add(2);
        deque.Add(3);

        // Act
        var results = new List<int>();
        foreach (var item in deque)
        {
            results.Add(item);
        }

        // Assert
        results.Should().Equal(3, 2, 1);
        deque.Count.Should().Be(3); // Enumeration doesn't remove elements
    }

    [Fact]
    public void GetEnumerator_EmptyDeque_ReturnsNoElements()
    {
        // Arrange
        var deque = new Deque<string>();

        // Act
        var results = deque.ToList();

        // Assert
        results.Should().BeEmpty();
    }

    [Fact]
    public void GetEnumerator_CanEnumerateMultipleTimes()
    {
        // Arrange
        var deque = new Deque<int>();
        deque.Add(1);
        deque.Add(2);

        // Act
        var firstPass = deque.ToList();
        var secondPass = deque.ToList();

        // Assert
        firstPass.Should().Equal(1, 2);
        secondPass.Should().Equal(1, 2);
        deque.Count.Should().Be(2); // Still intact
    }

    #endregion

    #region Integration Tests

    [Fact]
    public void Deque_UsedAsQueue_BehavesCorrectly()
    {
        // Arrange
        var queue = new Deque<string>(isStack: false);

        // Act - Enqueue operations
        queue.Add("A");
        queue.Add("B");
        queue.Add("C");

        // Act - Dequeue operations
        var first = queue.Get();
        var second = queue.Get();

        queue.Add("D"); // Add more

        var third = queue.Get();
        var fourth = queue.Get();

        // Assert
        first.Should().Be("A");
        second.Should().Be("B");
        third.Should().Be("C");
        fourth.Should().Be("D");
        queue.Count.Should().Be(0);
    }

    [Fact]
    public void Deque_UsedAsStack_BehavesCorrectly()
    {
        // Arrange
        var stack = new Deque<int>(isStack: true);

        // Act - Push operations
        stack.Add(1);
        stack.Add(2);
        stack.Add(3);

        // Act - Pop operations
        var first = stack.Get();
        var second = stack.Get();

        stack.Add(4); // Push more

        var third = stack.Get();
        var fourth = stack.Get();

        // Assert
        first.Should().Be(3);
        second.Should().Be(2);
        third.Should().Be(4);
        fourth.Should().Be(1);
        stack.Count.Should().Be(0);
    }

    [Theory]
    [InlineData(0)]
    [InlineData(1)]
    [InlineData(10)]
    [InlineData(100)]
    public void Deque_WithVariousCapacities_WorksCorrectly(int capacity)
    {
        // Arrange
        var deque = new Deque<int>(capacity: capacity);

        // Act - Add more than initial capacity
        for (var i = 0; i < capacity + 10; i++)
        {
            deque.Add(i);
        }

        // Assert
        deque.Count.Should().Be(capacity + 10);

        // Verify all elements can be retrieved
        var results = deque.GetAll().ToList();
        results.Should().HaveCount(capacity + 10);
    }

    #endregion

    #region Edge Cases

    [Fact]
    public void Deque_AlternatingAddAndRemove_MaintainsCorrectState()
    {
        // Arrange
        var deque = new Deque<int>(isStack: false);

        // Act & Assert
        deque.Add(1);
        deque.Get().Should().Be(1);
        deque.Count.Should().Be(0);

        deque.Add(2);
        deque.Add(3);
        deque.Get().Should().Be(2);
        deque.Count.Should().Be(1);

        deque.Add(4);
        deque.Count.Should().Be(2);
    }

    [Fact]
    public void Deque_WithReferenceTypes_HandlesNullCorrectly()
    {
        // Arrange
        var deque = new Deque<string?>();

        // Act
        deque.Add(null!); // T : notnull but we can still pass null

        // Assert
        deque.TryGet(out var element).Should().BeTrue();
        element.Should().BeNull();
    }

    #endregion
}