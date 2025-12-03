// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Val Melamed

BenchmarksConfiguration.Bind();

#if DEBUG
// for debugging the benchmarks:
var config = new DebugInProcessConfig()
#else
var config = ManualConfig
                    .Create(DefaultConfig.Instance)
#endif
                    .WithOptions(ConfigOptions.DisableOptimizationsValidator | ConfigOptions.StopOnFirstError)
                    .WithArtifactsPath(BenchmarksConfiguration.Options.ResultsPath)
                    .WithSummaryStyle(SummaryStyle.Default.WithRatioStyle(RatioStyle.Trend))
                    ;

BenchmarkSwitcher.FromAssembly(typeof(Program).Assembly).Run(args, config);

if (BenchmarksConfiguration.Options.TestFSFilesDirectory.StartsWith(Path.GetTempPath(), StringComparison.OrdinalIgnoreCase))
    try
    {
        Directory.Delete(BenchmarksConfiguration.Options.TestFSFilesDirectory, recursive: true);
    }
    catch
    {
        // Best effort cleanup
    }
