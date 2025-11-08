namespace vm2.DevOps.Glob.Api.Tests.Utilities;

public sealed class XunitLogger<T> : ILogger<T>, IDisposable
{
    int _indent = 0;

    public ITestOutputHelper Output { get; set; } = TestContext.Current.TestOutputHelper
                                                        ?? throw new InvalidOperationException("Could not get TestContext.Current.TestOutputHelper.");

    int Indent() => ++_indent;

    int Outdent() => _indent > 0 ? --_indent : 0;

    public void Log<TState>(
        LogLevel logLevel,
        EventId eventId,
        TState state,
        Exception? exception,
        Func<TState, Exception?, string> formatter)
    {
        if (_indent > 0)
            Output.Write(new string(' ', _indent * 2));

        Output.WriteLine(formatter(state, exception));
    }

    public bool IsEnabled(LogLevel logLevel) => true;

    class Scope<TState> : IDisposable
    {
        XunitLogger<T> _logger;

        public Scope(XunitLogger<T> logger)
        {
            _logger = logger;
            _logger.Indent();
        }

        public void Dispose() => _logger.Outdent();
    }

    public IDisposable BeginScope<TState>(TState _) where TState : notnull => new Scope<TState>(this);

    public void Dispose() { }
}
