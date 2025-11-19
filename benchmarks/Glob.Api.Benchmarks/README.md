# Glob.Api Benchmarks

Performance benchmarks for the Glob.Api library using BenchmarkDotNet.

## Running Benchmarks

### Run all benchmarks

    cd benchmarks/Glob.Api.Benchmarks
    dotnet run -c Release

### Run specific benchmark

    dotnet run -c Release --filter "*GlobEnumerationBenchmarks*"

### Run with memory diagnostics

    dotnet run -c Release -- --memory --runtimes net10.0

## Benchmark Categories

**GlobEnumerationBenchmarks** - Basic glob enumeration performance
**CaseSensitivityBenchmarks** - Case matching mode comparison
**PatternComplexityBenchmarks** - Pattern complexity impact
**BuilderBenchmarks** - Builder pattern overhead
**AllocationBenchmarks** - Memory allocation analysis

## Results Location

Results are saved to: `BenchmarkDotNet.Artifacts/results/`

Formats: HTML, CSV, Markdown

## Performance Goals

- Simple patterns: 1000+ files/sec
- Recursive patterns: 500+ files/sec
- Linear memory scaling
- Case-sensitive faster than case-insensitive

## Best Practices

1. Run in Release mode
2. Close other applications
3. Run multiple iterations
4. Test on multiple platforms
5. Use --memory flag for allocations