using vm2.UlidType.Tests.FluentAssertionsExtensions;

[assembly: AssertionEngineInitializer(
    typeof(FluentAssertionsInitializer),
    nameof(FluentAssertionsInitializer.AcknowledgeSoftWarning))]

namespace vm2.UlidType.Tests.FluentAssertionsExtensions;

/// <summary>
/// Provides methods to initialize and configure the assertion engine.
/// </summary>
/// <remarks>This class contains static methods for setting up the assertion engine, including handling
/// license-related warnings. It is intended to be used during the initialization phase of the application.</remarks>
[ExcludeFromCodeCoverage]
public static class FluentAssertionsInitializer
{
    /// <summary>
    /// Acknowledges and accepts the current soft warning related to the license.
    /// </summary>
    public static void AcknowledgeSoftWarning()
    {
        License.Accepted = true;
    }
}