namespace vm2.DevOps.Glob.Api.Benchmarks;

public static class Program
{
    public static void Main(string[] args)
    {
        BenchmarkSwitcher
            .FromAssembly(typeof(Program).Assembly)
            .Run(
                args,
#if DEBUG
                        // for debugging the benchmarks only
                        new DebugInProcessConfig()
#else
                        DefaultConfig
                            .Instance
                            .WithArtifactsPath(artifactsFolder)
                            .WithOptions(ConfigOptions.StopOnFirstError)
#endif
            );
    }
}