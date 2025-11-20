namespace vm2.DevOps.Glob.Api;

class Deque<T>
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

    public void Clear() => _sequence.Clear();
}
