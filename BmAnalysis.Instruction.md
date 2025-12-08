# BmAnalysis Instructions

BmAnalysis must be a command line utility that takes the reports (two sets of JSON files) from two different runs of benchmark tests that are built by BenchmarkDotnet based performance tests.

The first set of files is the base line and the second - is the the one to be compared against the baseline.

As an example of set of files produced by a single run are the files in "C:\Users\valme\Downloads\benchmark-summaries-ubuntu-latest".

The important information is in the JSON files "C:\Users\valme\Downloads\benchmark-summaries-ubuntu-latest\results\*-report.json".

So, the program BmAnalysis will be called like this:

```
BmAnalysis <path to baseline JSON files> <path to current JSON files>
```
The output will be a Markdown file (that is also displayed on the `Console`), and a JSON file with the comparison results by method.
The comparison results are the regression percentages for the following metrics:
- Mean
- Median
- StdDev Median
- Memory Allocated
- Gen 0 Collections
- Gen 1 Collections
- Gen 2 Collections

A markdown table should look something like this:

| Method | Mean | Median | Memory Allocated | Gen 0 Collections | Gen 1 Collections | Gen 2 Collections |
|:--|---:|-----:|-----:|------:|--------:|-------:|
| MethodA (base) | 350 ns | 357.4 ns | 256 Bytes | 1024 Bytes | 0 | 0 |
| MethodA (curr) | 360 ns | 368 ns   | 256 Bytes | 1024 Bytes | 0 | 0 |
| Regression     | 2.85%  | 2.96%    |   0.00%   | 0.00% | 0.00% | 0.00% |
|---|---|---|---|---|---|---|
| MethodB (base) | 350 ns | 357.4 ns | 256 Bytes | 1024 Bytes | 0 | 0 |
| MethodB (curr) | 360 ns | 368 ns   | 256 Bytes | 1024 Bytes | 0 | 0 |
| Regression     | 2.85%  | 2.96%    |   0.00%   | 0.00% | 0.00% | 0.00% |
|---|---|---|---|---|---|---|

The resulting JSON file should look something like this:
```json
{
    "Title": "vm2.UlidType.Benchmarks.NewUlid-20251008-151705",
    "Methods": [
        {
            "DisplayInfo": "NewUlid.Factory.NewUlid: DefaultJob [RandomProviderType=CryptoRandom]",
            "Namespace": "vm2.UlidType.Benchmarks",
            "Type": "NewUlid",
            "Method": "Factory_NewUlid",
            "MethodTitle": "Factory.NewUlid",
            "Parameters": "RandomProviderType=CryptoRandom",
            "FullName": "vm2.UlidType.Benchmarks.NewUlid.Factory_NewUlid(RandomProviderType: \"CryptoRandom\")",
            "HardwareIntrinsics": "AVX2+BMI1+BMI2+F16C+FMA+LZCNT+MOVBE,AVX,SSE3+SSSE3+SSE4.1+SSE4.2+POPCNT,X86Base+SSE+SSE2,AES+PCLMUL VectorSize=256",
            "Statistics-baseline": {
                "Min": { "value": 5.000, "unit": "us" },
                "Mean": { "value": 5.123, "unit": "us" },
                "Median": { "value": 5.100, "unit": "us" },
                "Max": { "value": 5.300, "unit": "us" },
                "StandardError": { "value": 0.04357183084674108, "unit": "us" },
                "Variance": { "value": 0.028477566650055262, "unit": "us^2" },
                "StandardDeviation": { "value": 0.16875297523319482, "unit": "us" },
                "Memory": {
                    "Gen0Collections": 20,
                    "Gen1Collections": 0,
                    "Gen2Collections": 0,
                    "TotalOperations": 8388608,
                    "BytesAllocatedPerOperation": 40
                }
            },
            "Statistics-current": {
                "Min": { "value": 5.000, "unit": "us" },
                "Mean": { "value": 5.123, "unit": "us" },
                "Median": { "value": 5.100, "unit": "us" },
                "Max": { "value": 5.300, "unit": "us" },
                "StandardError": { "value": 0.045, "unit": "us" },
                "Variance": { "value": 0.040, "unit": "us^2" },
                "StandardDeviation": { "value": 0.000, "unit": "us" },
                "Memory": {
                    "Gen0Collections": 20,
                    "Gen1Collections": 0,
                    "Gen2Collections": 0,
                    "TotalOperations": 8388608,
                    "BytesAllocatedPerOperation": 80
                }
            },
            "Regression": {
                "Mean": { "value": 3, "unit": "%" }
                "Memory": {
                    "Gen0Collections": { "value": 0, "unit": "%" }
                    "Gen1Collections": { "value": 0, "unit": "%" }
                    "Gen2Collections": { "value": 0, "unit": "%" }
                    "TotalOperations": { "value": 0, "unit": "%" }
                    "BytesAllocatedPerOperation": { "value": 100, "unit": "%" }
                }
            }
        },
        {
            "DisplayInfo": "NewUlid.Factory.NewUlid: DefaultJob [RandomProviderType=PseudoRandom]",
            "Namespace": "vm2.UlidType.Benchmarks",
            "Type": "NewUlid",
            "Method": "Factory_NewUlid",
            "MethodTitle": "Factory.NewUlid",
            "Parameters": "RandomProviderType=PseudoRandom",
            "FullName": "vm2.UlidType.Benchmarks.NewUlid.Factory_NewUlid(RandomProviderType: \"PseudoRandom\")",
            // etc...
        }
    ]
}
```

If there are other important for the analysis metrics, please include them as well, of course based on the available data in the JSON files.

Suggest a methodology to assess the statistical significance of the observed regressions, considering factors such as sample size, variance, and confidence intervals.

Although the benchmark results are split in several JSON files, the output should be a single Markdown file and a single JSON file.

For the Markdown file, you can use the `Markdig` library to help with formatting.

For JSON parsing and serialization, you can use preferably `System.Text.Json` + JsonPath.Net, but if you find that it will be more efficient and maintainable to use `Newtonsoft.Json` + `JsonPath`,  feel free to do so.

For command line parsing, you can use `System.CommandLine`.