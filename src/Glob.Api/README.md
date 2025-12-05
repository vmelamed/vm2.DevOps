# vm2.DevOps.Glob.Api - Cross-Platform Glob Pattern Matching Library

A high-performance, cross-platform glob pattern matching library for .NET applications. Implements the
[POSIX.2 glob specification](https://www.man7.org/linux/man-pages/man7/glob.7.html) with extensions for Windows and Unix-like
systems.

## Installation

    dotnet add package vm2.DevOps.Glob.Api

## Quick Start

    using vm2.DevOps.Glob.Api;

    // Basic usage
    var enumerator = new GlobEnumerator();
    enumerator.Glob = "**/*.cs";
    enumerator.FromDirectory = "./src";

    foreach (var file in enumerator.Enumerate())
    {
        Console.WriteLine(file);
    }

## Features

- ✅ **[POSIX.2 glob specification](https://www.man7.org/linux/man-pages/man7/glob.7.html)** compliant with Windows extensions
- ✅ **Cross-platform** - Identical behavior on Windows, Linux, macOS, and BSD
- ✅ **High performance** - Optimized enumeration with minimal allocations
- ✅ **Flexible API** - Fluent builder pattern for easy configuration
- ✅ **Lazy evaluation** - IEnumerable-based streaming of results
- ✅ **Testable** - `IFileSystem` abstraction for unit testing
- ✅ **Environment variables** - Automatic expansion of path variables
- ✅ **Multiple traversal modes** - Depth-first or breadth-first
- ✅ **Deduplication** - Optional removal of duplicate results

## Glob Pattern Syntax

| Pattern     | Meaning                                                  | Example                           |
|-------------|----------------------------------------------------------|-----------------------------------|
| `*`         | Any sequence of characters (except path separator)       | `*.txt` matches `file.txt`        |
| `?`         | Any single character                                     | `file?.txt` matches `file1.txt`   |
| `[abc]`     | Any character in set                                     | `[abc].txt` matches `a.txt`       |
| `[a-z]`     | Any character in range                                   | `[0-9].txt` matches `5.txt`       |
| `[!abc]`    | Any character NOT in set                                 | `[!.]*.txt` excludes hidden files |
| `**`        | Zero or more directory levels (globstar)                 | `**/test/**/*.cs` recursive       |
| `[:class:]` | Named character class (alpha, digit, lower, upper, etc.) | `[[:digit:]]*.log`                |

## Usage

### Basic Enumeration

    var enumerator = new GlobEnumerator
    {
        Glob = "**/*.cs",
        FromDirectory = "./src"
    };

    foreach (var file in enumerator.Enumerate())
    {
        Console.WriteLine(file);
    }

### Using Fluent Builder

    var results = new GlobEnumeratorBuilder()
        .WithGlob("**/*Tests.cs")
        .FromDirectory("./test")
        .SelectFiles()
        .CaseSensitive()
        .Build()
        .Configure(new GlobEnumerator())
        .Enumerate()
        .ToList();

### Dependency Injection

    // In Startup.cs or Program.cs
    services.AddGlobEnumerator();

    // In your service
    public class FileService
    {
        private readonly GlobEnumerator _globEnumerator;

        public FileService(GlobEnumerator globEnumerator)
        {
            _globEnumerator = globEnumerator;
        }

        public IEnumerable<string> FindFiles(string pattern)
        {
            _globEnumerator.Glob = pattern;
            return _globEnumerator.Enumerate();
        }
    }

### Advanced Configuration

    var enumerator = new GlobEnumeratorBuilder()
        .WithGlob("**/docs/**/*.md")
        .FromDirectory("/usr/share")
        .Select(Objects.Files)                    // Files only
        .WithCaseSensitivity(MatchCasing.CaseInsensitive)
        .TraverseDepthFirst(true)                 // Depth-first traversal
        .Distinct()                               // Remove duplicates
        .Build()
        .Configure(new GlobEnumerator());

    foreach (var file in enumerator.Enumerate())
    {
        ProcessFile(file);
    }

### File System Access Control

#### Include Hidden and System Files

Also, useful on UNIX-like systems to include dotfiles (e.g., `.gitignore`).

    var enumerator = new GlobEnumerator
    {
        Glob = "**/*",
        FromDirectory = "./src",
        AttributesToSkip = FileAttributes.None  // Include all files
    };

    foreach (var file in enumerator.Enumerate())
    {
        Console.WriteLine(file);
    }

#### Skip Only Specific Attributes

    // Skip only temporary files
    enumerator.AttributesToSkip = FileAttributes.Temporary;

    // Skip multiple attributes
    enumerator.AttributesToSkip = FileAttributes.Hidden
                                | FileAttributes.System
                                | FileAttributes.Temporary;

#### Handle Access Denied Scenarios

    // Throw exceptions for inaccessible files (strict mode)
    enumerator.IgnoreInaccessible = false;

    try
    {
        foreach (var file in enumerator.Enumerate())
        {
            ProcessFile(file);
        }
    }
    catch (UnauthorizedAccessException ex)
    {
        Console.WriteLine($"Access denied: {ex.Message}");
    }

    // Skip inaccessible files silently (default, permissive mode)
    enumerator.IgnoreInaccessible = true;

    foreach (var file in enumerator.Enumerate())
    {
        // Will skip files/directories that can't be accessed
        ProcessFile(file);
    }

#### Include Special Directory Entries

    // Include "." and ".." in directory enumeration
    var enumerator = new GlobEnumerator
    {
        Glob = "*",
        FromDirectory = "./src",
        Enumerated = Objects.Directories,
        ReturnSpecialDirectories = true
    };

    foreach (var dir in enumerator.Enumerate())
    {
        // Will include ".", "..", and other directories
        Console.WriteLine(dir);
    }

**Note:** `ReturnSpecialDirectories` is rarely needed and defaults to `false` for cleaner results.

## Configuration Options

### Object Type Selection

    // Find only files (default)
    enumerator.Enumerated = Objects.Files;

    // Find only directories
    enumerator.Enumerated = Objects.Directories;

    // Find both files and directories
    enumerator.Enumerated = Objects.FilesAndDirectories;

### Case Sensitivity

    // Platform default (case-insensitive on Windows, sensitive on Unix)
    enumerator.MatchCasing = MatchCasing.PlatformDefault;

    // Always case-sensitive
    enumerator.MatchCasing = MatchCasing.CaseSensitive;

    // Always case-insensitive
    enumerator.MatchCasing = MatchCasing.CaseInsensitive;

### Traversal Order

    // Breadth-first (default) - process all items at current level before descending
    enumerator.DepthFirst = false;

    // Depth-first - fully explore each subdirectory before siblings
    enumerator.DepthFirst = true;

### Deduplication

    // Allow duplicate results (default, faster)
    enumerator.Distinct = false;

    // Remove duplicate results (uses more memory)
    enumerator.Distinct = true;

**Note:** Deduplication is only necessary for patterns with multiple globstars (e.g., `**/docs/**/*.md`).

## Real-World Examples

### Build Tool - Find Source Files

    public IEnumerable<string> GetSourceFiles(string projectPath)
    {
        var enumerator = new GlobEnumeratorBuilder()
            .WithGlob("**/*.cs")
            .FromDirectory(projectPath)
            .SelectFiles()
            .Build()
            .Configure(new GlobEnumerator());

        return enumerator.Enumerate()
            .Where(f => !f.Contains("/obj/") && !f.Contains("/bin/"));
    }

### Test Runner - Find Test Assemblies

    public IEnumerable<string> FindTestAssemblies(string artifactsPath)
    {
        var enumerator = new GlobEnumerator
        {
            Glob = "**/*Tests.dll",
            FromDirectory = artifactsPath,
            Enumerated = Objects.Files
        };

        return enumerator.Enumerate();
    }

### File Cleanup - Find Old Log Files

    public void CleanupLogs(string logDirectory, int daysOld)
    {
        var enumerator = new GlobEnumerator
        {
            Glob = "**/*.log",
            FromDirectory = logDirectory
        };

        var cutoffDate = DateTime.Now.AddDays(-daysOld);

        foreach (var logFile in enumerator.Enumerate())
        {
            if (File.GetLastWriteTime(logFile) < cutoffDate)
            {
                File.Delete(logFile);
            }
        }
    }

### Configuration Loader - Find Config Files

    public Dictionary<string, string> LoadConfigurations(string configPath)
    {
        var enumerator = new GlobEnumeratorBuilder()
            .WithGlob("**/{appsettings,config}.json")
            .FromDirectory(configPath)
            .SelectFiles()
            .CaseInsensitive()
            .Build()
            .Configure(new GlobEnumerator());

        return enumerator.Enumerate()
            .ToDictionary(
                f => Path.GetFileName(f),
                f => File.ReadAllText(f)
            );
    }

### ASP.NET Core - Static File Discovery

    public void ConfigureStaticFiles(IApplicationBuilder app)
    {
        var wwwroot = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot");
        var enumerator = new GlobEnumerator
        {
            Glob = "**/*.{js,css,html}",
            FromDirectory = wwwroot,
            Enumerated = Objects.Files
        };

        foreach (var staticFile in enumerator.Enumerate())
        {
            // Process static files
            Console.WriteLine($"Found: {staticFile}");
        }
    }

## Testing with IFileSystem

The library provides `IFileSystem` abstraction for unit testing without file system access:

### Custom Test Implementation

    public class InMemoryFileSystem : IFileSystem
    {
        private readonly Dictionary<string, List<string>> _structure;

        public bool IsWindows => false;

        public IEnumerable<string> EnumerateFiles(string path, string pattern, EnumerationOptions options)
        {
            return _structure.TryGetValue(path, out var files)
                ? files.Where(f => MatchesPattern(f, pattern))
                : Enumerable.Empty<string>();
        }

        // Implement other methods...
    }

    // In tests
    [Fact]
    public void GlobEnumerator_FindsExpectedFiles()
    {
        var fakeFs = new InMemoryFileSystem();
        fakeFs.AddFile("/src/Program.cs");
        fakeFs.AddFile("/src/Models/User.cs");

        var enumerator = new GlobEnumerator(fakeFs)
        {
            Glob = "**/*.cs",
            FromDirectory = "/src"
        };

        var results = enumerator.Enumerate().ToList();

        results.Should().HaveCount(2);
    }

## Performance Considerations

### Best Practices

1. **Be specific with patterns** - `src/**/*.cs` is faster than `**/*.cs`
2. **Use appropriate object type** - `Objects.Files` skips directory enumeration overhead
3. **Avoid excessive globstars** - Each `**` increases traversal depth
4. **Use deduplication sparingly** - Only enable for multi-globstar patterns
5. **Prefer breadth-first for wide trees** - Better memory locality
6. **Prefer depth-first for deep trees** - Faster for deep hierarchies
7. **Prefer breadth-first for wide trees** - Faster for wide hierarchies or when the sought match is likely near the top and you
   intend to stop as early as possible.

### Memory Usage

- **Lazy enumeration** - Results streamed, not materialized
- **Minimal allocations** - Uses `Span<T>` and `stackalloc` internally
- **Deduplication cost** - `HashSet<string>` for tracking seen paths

### Benchmarks

Typical performance on standard hardware:

| Operation                   | Files | Time   | Allocations |
|-----------------------------|-------|-------:|-------------|
| Simple pattern (`*.cs`)     |   100 | ~1ms   | <1KB        |
| Recursive (`**/*.cs`)       | 1,000 | ~50ms  | ~50KB       |
| Complex (`**/test/**/*.cs`) | 1,000 | ~80ms  | ~80KB       |
| With distinct               | 1,000 | ~100ms | ~150KB      |

## API Reference

### GlobEnumerator Class

#### Properties

##### Pattern and Directory:
- `string Glob` - The glob pattern to match (default: `""` which is treated as `"*"`)
- `string FromDirectory` - Starting directory for enumeration (default: `"."` - current directory)

##### Object Selection:
- `Objects Enumerated` - Type of objects to find: `Files`, `Directories`, or `FilesAndDirectories` (default: `Files`)

##### Matching Behavior:
- `MatchCasing MatchCasing` - Case sensitivity mode: `PlatformDefault`, `CaseSensitive`, or `CaseInsensitive` (default: `PlatformDefault`)
- `bool DepthFirst` - Traversal order: `true` = depth-first, `false` = breadth-first (default: `false`)
- `bool Distinct` - Enable deduplication of results (default: `false`)

##### File System Behavior:
- `bool ReturnSpecialDirectories` - Include special directory entries `"."` and `".."` in results (default: `false`)
- `bool IgnoreInaccessible` - Skip files/directories when access is denied (e.g., `UnauthorizedAccessException`, `SecurityException`) (default: `true`)
- `FileAttributes AttributesToSkip` - Skip files/directories with specified attributes (default: `FileAttributes.Hidden | FileAttributes.System`)

#### Methods

- `IEnumerable<string> Enumerate()` - Execute the glob pattern and return matching paths

#### Constructor

- `GlobEnumerator(IFileSystem? fileSystem = null, ILogger<GlobEnumerator>? logger = null)` - Create a new instance with optional custom file system and logger

### GlobEnumeratorBuilder Class

#### Methods

##### Pattern Configuration:
- `WithGlob(string pattern)` - Set the glob pattern

##### Directory Configuration:
- `FromDirectory(string path)` - Set starting directory

##### Object Type Selection:
- `SelectFiles()` - Find only files
- `SelectDirectories()` - Find only directories
- `SelectDirectoriesAndFiles()` - Find both files and directories
- `Select(Objects type)` - Set object type explicitly

##### Case Sensitivity:
- `CaseSensitive()` - Enable case-sensitive matching
- `CaseInsensitive()` - Enable case-insensitive matching
- `PlatformSensitive()` - Use platform default case sensitivity
- `WithCaseSensitivity(MatchCasing casing)` - Set case sensitivity explicitly

##### Traversal Order:
- `DepthFirst()` - Enable depth-first traversal
- `BreadthFirst()` - Enable breadth-first traversal (default)
- `TraverseDepthFirst(bool depthFirst)` - Set traversal order explicitly

##### Result Filtering:
- `Distinct()` - Enable deduplication
- `WithDistinct(bool distinct)` - Set deduplication explicitly

##### File System Behavior:
- `IncludeSpecialDirectories(bool include = true)` - Include `"."` and `".."` entries
- `SkipInaccessible(bool skip = true)` - Skip files/directories with access errors
- `SkipObjectsWithAttributes(FileAttributes attributes)` - Skip objects with specified attributes (e.g., `FileAttributes.Hidden`)

##### Builder Methods:
- `Build()` - Build and return the builder (for method chaining)
- `Configure(GlobEnumerator enumerator)` - Apply configuration to an enumerator instance

### Extension Methods

#### Dependency Injection:

    // Register with default FileSystem
    IServiceCollection.AddGlobEnumerator()

    // Register with custom FileSystem implementation
    IServiceCollection.AddGlobEnumerator<TFileSystem>()

    // Register with specific FileSystem instance
    IServiceCollection.AddGlobEnumerator(IFileSystem fileSystem)

#### Service Provider:

    // Get configured enumerator from DI container
    IServiceProvider.GetGlobEnumerator(
        Func<GlobEnumeratorBuilder, GlobEnumeratorBuilder> configure)

## Command Line Tool

For quick file searches from the terminal, try our CLI tool:

    dotnet tool install -g vm2.DevOps.Glob

Then use anywhere:

    glob "**/*.cs"

Perfect for shell scripts, CI/CD pipelines, and developer workflows.

See [vm2.DevOps.Glob](https://www.nuget.org/packages/vm2.DevOps.Glob) for more details.

## Documentation

- [GitHub Repository](https://github.com/vmelamed/vm2.DevOps)
- [CLI Tool Documentation](https://github.com/vmelamed/vm2.DevOps/tree/main/src/Glob)
- [POSIX Glob Specification](https://www.man7.org/linux/man-pages/man7/glob.7.html) - The Linux man-pages project

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](../../CONTRIBUTING.md) for details.

### Development Setup

    # Clone repository
    git clone https://github.com/vmelamed/vm2.DevOps.git
    cd vm2.DevOps

    # Build
    dotnet build

    # Run tests
    dotnet test

    # Run benchmarks
    dotnet run -c Release --project benchmarks/Glob.Api.Benchmarks

## License

MIT License - Copyright © 2025 Val Melamed

See [LICENSE](../../LICENSE) for full text.

## Version History

See [CHANGELOG.md](../../CHANGELOG.md) for version history and release notes.

## References

- [POSIX.2 Glob Specification](https://www.man7.org/linux/man-pages/man7/glob.7.html) - The Linux man-pages project
- [Glob (programming) - Wikipedia](https://en.wikipedia.org/wiki/Glob_(programming))
- [CommonMark Specification](https://spec.commonmark.org/) - Used for this documentation