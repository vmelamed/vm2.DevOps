// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Val Melamed

#if DEBUG
// for debugging the benchmarks:
var config = new DebugInProcessConfig()
#else
var config = ManualConfig
                .Create(DefaultConfig.Instance)
#endif
                .WithOptions(ConfigOptions.DisableOptimizationsValidator | ConfigOptions.StopOnFirstError)
                .WithArtifactsPath(BmConfiguration.Options.ResultsPath)
                .WithSummaryStyle(SummaryStyle.Default.WithRatioStyle(RatioStyle.Trend))
;

BenchmarkSwitcher.FromAssembly(typeof(Program).Assembly).Run(args, config);
