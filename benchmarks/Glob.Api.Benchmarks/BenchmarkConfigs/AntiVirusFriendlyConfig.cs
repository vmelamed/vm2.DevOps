namespace vm2.DevOps.Glob.Api.Benchmarks.BenchmarkConfigs;

/// <summary>
/// Configuration for benchmarks that interact with the real file system.
/// Uses longer warmup times to account for antivirus scanning and disk caching.
/// </summary>
public class AntiVirusFriendlyConfig : ManualConfig
{
    public AntiVirusFriendlyConfig()
    {
        AddJob(Job.Default
            .WithWarmupCount(5)
            .WithIterationCount(10)
            .WithInvocationCount(16)
            .WithUnrollFactor(1));
    }
}