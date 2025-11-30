// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Val Melamed

namespace vm2.DevOps.Glob.Api;

/// <summary>
/// A double-ended queue (deque) that can operate as a stack (LIFO) or a queue (FIFO).
/// </summary>
/// <typeparam name="T"></typeparam>
public class Deque<T> : IEnumerable<T>
{
    List<T> _sequence;

    /// <summary>
    /// Initializes a new instance of the <see cref="Deque{T}"/> class. By default it operates as a queue (FIFO).
    /// </summary>
    /// <param name="isStack"></param>
    /// <param name="capacity"></param>
    public Deque(bool isStack = false, int capacity = 0)
    {
        _sequence = capacity is >0 ? new(capacity) : new();
        IsStack = isStack;
    }

    /// <summary>
    /// Gets the number of elements contained in the deque.
    /// </summary>
    public int Count => _sequence.Count;

    /// <summary>
    /// Gets or sets a value indicating whether the deque operates as a stack (LIFO) or a queue (FIFO). Note that if the dequeue
    /// is not empty, changing this property will throw an <see cref="InvalidOperationException"/> exception.
    /// </summary>
    public bool IsStack
    {
        get;
        set
        {
            if (Count > 0)
                throw new InvalidOperationException("Cannot change the mode of a non-empty deque.");
            field = value;
        }
    }

    /// <summary>
    /// Adds the specified element to the end of the sequence.
    /// </summary>
    /// <param name="element">The element to add to the sequence. Cannot be null if the sequence does not accept null values.</param>
    public void Add(T element) => _sequence.Add(element);

    /// <summary>
    /// Attempts to remove and return the next element from the collection.
    /// </summary>
    /// <remarks>
    /// The order in which elements are removed depends on whether the collection is operating in stack or queue mode. If the
    /// collection is empty, the method returns false and the out parameter is set to the default value for the type.
    /// </remarks>
    /// <param name="element">
    /// When this method returns, contains the element removed from the collection, if the operation succeeded;
    /// otherwise, the default value for the type of the element parameter.
    /// </param>
    /// <returns>true if an element was successfully removed and returned; otherwise, false.</returns>
    public bool TryGet(out T element)
    {
        if (_sequence.Count is 0)
        {
            element = default!;
            return false;
        }

        var index = IsStack ? _sequence.Count-1 : 0;

        element = _sequence[index];
        _sequence.RemoveAt(index);
        return true;
    }

    /// <summary>
    /// Removes and returns the next element from the collection.
    /// </summary>
    /// <returns></returns>
    /// <exception cref="InvalidOperationException"></exception>
    public T Get()
    {
        if (_sequence.Count is 0)
            throw new InvalidOperationException("The dequeue is empty.");

        TryGet(out var element);
        return element;
    }

    /// <summary>
    /// Returns an enumerable collection containing all available elements of type T.
    /// </summary>
    /// <returns>An <see cref="IEnumerable{T}"/> that contains all elements retrieved from the source. The collection will be
    /// empty if no elements are available.</returns>
    public IEnumerable<T> GetAll()
    {
        while (TryGet(out var element))
            yield return element;
    }

    /// <summary>
    /// Removes all elements from the deque.
    /// </summary>
    public void Clear() => _sequence.Clear();

    /// <summary>
    /// Returns an enumerator that iterates through the deque in the order they would be removed but without removing the elements.
    /// </summary>
    /// <returns></returns>
    public IEnumerator<T> GetEnumerator() => new DequeEnumerator(this);

    IEnumerator IEnumerable.GetEnumerator() => GetEnumerator();

    class DequeEnumerator : IEnumerator<T>
    {
        readonly Deque<T> _deque;
        int _index;

        public DequeEnumerator(Deque<T> deque)
        {
            _deque = deque;
            Reset();
        }

        public T Current => _deque._sequence[_index];

        object? IEnumerator.Current => Current;

        public bool MoveNext() => _deque.IsStack
                                            ? --_index >= 0
                                            : ++_index < _deque.Count;

        public void Reset() => _index = _deque.IsStack ? _deque.Count : -1;

        public void Dispose() { }
    }
}
