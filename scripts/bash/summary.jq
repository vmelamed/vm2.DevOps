{
    HostEnvironmentInfo: .HostEnvironmentInfo,
    Totals: {
        Mean:   ([.Benchmarks[].Statistics.Mean]   | map(. // 0) | add | floor),
        Median: ([.Benchmarks[].Statistics.Median] | map(. // 0) | add | floor),
        Memory: {
            Gen0Collections: ([.Benchmarks[].Memory.Gen0Collections]            | map(. // 0) | add),
            Gen1Collections: ([.Benchmarks[].Memory.Gen1Collections]            | map(. // 0) | add),
            Gen2Collections: ([.Benchmarks[].Memory.Gen2Collections]            | map(. // 0) | add),
            AllocatedPerOp:  ([.Benchmarks[].Memory.BytesAllocatedPerOperation] | map(. // 0) | add)
        }
    },
    Benchmarks: [
        .Benchmarks[] | {
            DisplayInfo: .DisplayInfo,
            MethodTitle: .MethodTitle,
            Parameters:  .Parameters,
            Statistics: {
                Min:        .Statistics.Min    | floor,
                Mean:       .Statistics.Mean   | floor,
                Median:     .Statistics.Median | floor,
                Max:        .Statistics.Max    | floor
            },
            Memory: .Memory
        }
    ]
}
