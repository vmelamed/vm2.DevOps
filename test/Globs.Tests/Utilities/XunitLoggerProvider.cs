namespace vm2.DevOps.Glob.Api.Tests.Utilities;

public sealed class XunitLoggerProvider : ILoggerProvider
{
#pragma warning disable IL2057 // Unrecognized value passed to the parameter of method. It's not possible to guarantee the availability of the target type.
    public ILogger CreateLogger(string categoryName)
    {
        var loggerType = typeof(XunitLogger<>).MakeGenericType(Type.GetType(categoryName) ?? typeof(object));
        return Activator.CreateInstance(loggerType) as ILogger ?? throw new InvalidOperationException("Could not create a logger.");
    }
#pragma warning restore IL2057 // Unrecognized value passed to the parameter of method. It's not possible to guarantee the availability of the target type.

    public void Dispose() { }
}
