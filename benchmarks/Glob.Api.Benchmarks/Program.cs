// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Val Melamed

var artifactsFolder = "./BenchmarkDotNet.Artifacts/results";

for (var i = 0; i < args.Length; i++)
    if ((args[i] == "--artifacts" || args[i] == "i") && i+1 < args.Length)
        artifactsFolder = args[i+1];

#if DEBUG
// for debugging the benchmarks:
var config = new DebugInProcessConfig()
                    .WithArtifactsPath(artifactsFolder)
                    .WithOptions(ConfigOptions.DisableOptimizationsValidator | ConfigOptions.StopOnFirstError)
                    .WithArtifactsPath(artifactsFolder)
                    .WithSummaryStyle(SummaryStyle.Default.WithRatioStyle(RatioStyle.Trend))
                    ;
#else
var config = ManualConfig
                    .Create(DefaultConfig.Instance)
                    .WithOptions(ConfigOptions.DisableOptimizationsValidator | ConfigOptions.StopOnFirstError)
                    .WithArtifactsPath(artifactsFolder)
                    .WithSummaryStyle(SummaryStyle.Default.WithRatioStyle(RatioStyle.Trend))
                    ;
#endif

BenchmarkSwitcher.FromAssembly(typeof(Program).Assembly).Run(args, config);
