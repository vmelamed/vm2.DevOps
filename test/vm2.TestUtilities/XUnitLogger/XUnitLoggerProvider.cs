namespace vm2.TestUtilities.XUnitLogger;

/// <summary>
/// Provides an ILoggerProvider implementation that writes log messages to xUnit test output.
/// </summary>
/// <remarks>
/// This provider is intended for use in unit tests to capture log output within xUnit test results. Each logger created by this
/// provider writes to the specified ITestOutputHelper instance. Thread safety and output ordering are determined by the
/// behavior of the provided ITestOutputHelper.
/// </remarks>
/// <param name="testOutputHelper">The ITestOutputHelper instance used to write log output to the xUnit test runner.
/// </param>
[ExcludeFromCodeCoverage]
public class XUnitLoggerProvider(ITestOutputHelper? testOutputHelper = null) : ILoggerProvider
{
    ITestOutputHelper? _testOutputHelper = testOutputHelper;

    public ILogger CreateLogger(string categoryName)
        => new XUnitLogger(
            new LoggerExternalScopeProvider(),
            categoryName,
            _testOutputHelper
                ?? throw new InvalidOperationException("The TestOutputHelper was not set in the provider. You can do this in the constructor of the test class."));

    public void Dispose()
        => GC.SuppressFinalize(this);
}
