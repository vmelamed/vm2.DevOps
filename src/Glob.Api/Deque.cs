namespace vm2.DevOps.Glob.Api;

class Deque<T>
{
    List<T> _line;

    public Deque(bool isStack = false, int capacity = 0)
    {
        IsStack = isStack;
        _line = capacity is >0 ? new(capacity) : new();
    }

    public int Count => _line.Count;

    public bool IsStack { get; set; }

    public void Add(T element) => _line.Add(element);

    public bool TryGet(out T element)
    {
        if (_line.Count is 0)
        {
            element = default!;
            return false;
        }

        var index = IsStack ? _line.Count-1 : 0;

        element = _line[index];
        _line.RemoveAt(index);
        return true;
    }

    public T Get()
    {
        if (_line.Count is 0)
            throw new InvalidOperationException("The line is empty.");

        var index = IsStack ? _line.Count-1 : 0;
        T element = _line[index];

        _line.RemoveAt(index);
        return element;
    }

    public void Clear() => _line.Clear();
}
