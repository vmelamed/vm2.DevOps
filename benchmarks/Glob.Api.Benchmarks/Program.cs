BenchmarkSwitcher
    .FromAssembly(typeof(Program).Assembly)
    .Run(
        args,
#if DEBUG
        // only for debugging the benchmarks
        new DebugInProcessConfig()
#else
        DefaultConfig
            .Instance
            .WithArtifactsPath(artifactsFolder)
            .WithOptions(ConfigOptions.StopOnFirstError)
#endif
    );
