namespace vm2.DevOps.Glob.Api.Benchmarks.Classes.Options;

/// <summary>
/// Represents configuration options for a benchmark run, including paths for results, test file system structure, and
/// test root directory.
/// </summary>
/// <param name="resultsPath">
/// The file system path where benchmark results will be saved. Must be a valid, writable directory path.
/// </param>
/// <param name="fsJsonModelsDirectory">
/// The path to the file system structure definition used for the benchmark tests. Must refer to an existing JSON file as
/// required by the benchmark.
/// </param>
/// <param name="testsRootPath">
/// The directory containing the test cases to be used during benchmarking. Must be a valid directory path.
/// </param>
public class BmOptions(
    string resultsPath = "BenchmarkDotNet.Artifacts/results",
    string fsJsonModelsDirectory = "./FSModels",
    string testsRootPath = "")
{
    /// <summary>
    /// The path where benchmark results will be saved. Must be a valid, writable directory path.
    /// Default: "./BenchmarkDotNet.Artifacts/results"
    /// </summary>
    public string ResultsPath { get; set; } = resultsPath;

    /// <summary>
    /// Gets or sets the directory path used for storing test file system files used by the FakeFS or to create real file
    /// system sub-tree structure for FileSystem.
    /// </summary>
    public string FsJsonModelsDirectory { get; set; } = fsJsonModelsDirectory;

    /// <summary>
    /// Gets or sets the root directory path where the real file system sub-tree structure for FileSystem is located.
    /// </summary>
    public string TestsRootPath { get; set; } = testsRootPath;
}
