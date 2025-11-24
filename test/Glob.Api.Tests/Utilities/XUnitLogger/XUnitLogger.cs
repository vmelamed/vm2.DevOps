namespace vm2.DevOps.Glob.Api.Tests.Utilities.XUnitLogger;

/// <summary>
/// ILogger implementation that writes log messages to an xUnit <see cref="ITestOutputHelper"/>.
/// </summary>
/// <param name="scopeProvider"></param>
/// <param name="categoryName"></param>
/// <param name="testOutputHelper"></param>
/// <remarks>
/// Thanks, Gérald Barré (aka.Meziantou), for the original implementation idea:
/// https://www.meziantou.net/how-to-get-asp-net-core-logs-in-the-output-of-xunit-tests.htm
/// </remarks>
public class XUnitLogger(
    LoggerExternalScopeProvider scopeProvider,
    string categoryName,
    ITestOutputHelper testOutputHelper) : ILogger
{
    /// <summary>
    /// Creates a new <see cref="XUnitLogger"/> instance.
    /// </summary>
    /// <param name="testOutputHelper"></param>
    /// <returns></returns>
    public static ILogger CreateLogger(ITestOutputHelper testOutputHelper)
        => new XUnitLogger(new LoggerExternalScopeProvider(), "", testOutputHelper);

    /// <summary>
    /// Creates a new <see cref="XUnitLogger{T}"/> instance.
    /// </summary>
    /// <param name="testOutputHelper"></param>
    /// <returns></returns>
    public static ILogger<T> CreateLogger<T>(ITestOutputHelper testOutputHelper)
        => new XUnitLogger<T>(new LoggerExternalScopeProvider(), testOutputHelper);

    #region ILogger
    public IDisposable? BeginScope<TState>(TState state) where TState : notnull => scopeProvider.Push(state);

    public bool IsEnabled(LogLevel logLevel) => logLevel != LogLevel.None;

    public void Log<TState>(
        LogLevel logLevel,
        EventId eventId,
        TState state,
        Exception? exception,
        Func<TState, Exception?, string> formatter)
    {
        if (!IsEnabled(logLevel) || testOutputHelper is null)
            return;

        using var writer = new StringWriter();

        writer.Write(GetLogLevelPrefix(logLevel));
        writer.Write(" [");
        writer.Write(categoryName);
        writer.Write("] ");
        writer.Write(formatter(state, exception));

        if (exception != null)
        {
            writer.WriteLine('\n');
            writer.Write(exception);
        }

        // Append scopes
        scopeProvider.ForEachScope(
            (scope, wr) =>
            {
                wr.Write("\n => ");
                wr.Write(scope);
            },
            writer);

        testOutputHelper.WriteLine(writer.ToString());
    }

    private string GetLogLevelPrefix(LogLevel logLevel)
        => logLevel switch {
            LogLevel.Trace => "trce",
            LogLevel.Debug => "dbug",
            LogLevel.Information => "info",
            LogLevel.Warning => "warn",
            LogLevel.Error => "fail",
            LogLevel.Critical => "crit",
            _ => throw new ArgumentOutOfRangeException(nameof(logLevel))
        };
    #endregion
}

public sealed class XUnitLogger<T>(
    LoggerExternalScopeProvider scopeProvider,
    ITestOutputHelper testOutputHelper)
    : XUnitLogger(
        scopeProvider,
        typeof(T).FullName ?? "",
        testOutputHelper), ILogger<T>
{
}