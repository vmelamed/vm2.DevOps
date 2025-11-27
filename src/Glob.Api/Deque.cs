namespace vm2.DevOps.Glob.Api;

class Deque<T> : IEnumerable<T> where T : notnull
{
    List<T> _sequence;

    public Deque(bool isStack = false, int capacity = 0)
    {
        IsStack = isStack;
        _sequence = capacity is >0 ? new(capacity) : new();
    }

    public int Count => _sequence.Count;

    public bool IsStack { get; set; }

    public void Add(T element) => _sequence.Add(element);

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

    public T Get()
    {
        if (_sequence.Count is 0)
            throw new InvalidOperationException("The line is empty.");

        TryGet(out var element);
        return element;
    }

    public IEnumerable<T> GetAll()
    {
        while (TryGet(out var element))
            yield return element;
    }

    public void Clear() => _sequence.Clear();

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

        object IEnumerator.Current => Current;

        public bool MoveNext()
            => _deque.IsStack
                    ? --_index >= 0
                    : ++_index < _deque.Count;

        public void Reset()
        {
            _index = _deque.IsStack ? _deque.Count + 1 : -1;
        }

        public void Dispose() { }
    }
}
