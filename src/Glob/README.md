# vm2.DevOps.Glob - Cross-Platform Glob Pattern Matching Tool

A fast, intuitive CLI tool for finding files and directories using glob patterns.

## Installation

    dotnet tool install -g vm2.DevOps.Glob

## Quick Start

    # Find all C# files recursively
    glob "**/*.cs"

    # Find files in a specific directory
    glob "**/*.txt" -d ~/documents

    # Find only directories
    glob "**" -o directories

    # Case-sensitive search
    glob "[A-Z]*.cs" -c sensitive

    # Remove duplicates from multi-globstar patterns
    glob "**/docs/**/*.md" -x

## Features

- ✅ **[POSIX.2 glob specification](https://www.man7.org/linux/man-pages/man7/glob.7.html)** with Windows extensions
- ✅ **Cross-platform** - Windows, Linux, macOS
- ✅ **Fast** - Optimized enumeration algorithms
- ✅ **Flexible** - Files, directories, or both
- ✅ **Smart** - Environment variable expansion
- ✅ **Clean output** - Full absolute paths

## Glob Pattern Syntax

| Pattern     | Meaning                                            |
|-------------|----------------------------------------------------|
| `*`         | Any sequence of characters (except path separator) |
| `?`         | Any single character                               |
| `[abc]`     | Any character in set (a, b, or c)                  |
| `[a-z]`     | Any character in range                             |
| `[!abc]`    | Any character NOT in set                           |
| `**`        | Zero or more directory levels (globstar)           |
| `[:alpha:]` | Named character class                              |

## Command Line Options

    glob <pattern> [options]

    Arguments:
      glob                Glob pattern (e.g., '**/*.txt')

    Options:
      -d, --start-from       Start directory (default: current directory)
      -o, --search-objects   What to find: files|f, directories|d, both|b (default: both)
      -c, --case             Case sensitivity: sensitive|s, insensitive|i, platform|p (default: platform)
      -x, --distinct         Remove duplicate results (default: false)
      -a, --show-hidden      Include hidden/system files (default: false)
      --help                 Show help and usage information
      --version              Show version information

## Examples

### Basic Usage

    # Find all C# files
    glob "**/*.cs"

    # Find test files
    glob "**/*Tests.cs"

    # Find JSON config files
    glob "*.json"

### Directory Specific

    # Search in a specific directory
    glob "**/*.txt" -d ~/documents

    # Search from home directory
    glob "**/*.log" -d ~

    # Search with absolute path
    glob "**/*.md" -d /usr/share/doc

### Object Type Selection

    # Find only files
    glob "**/*.dll" -o files

    # Find only directories
    glob "**" -o directories

    # Find both (default)
    glob "src/**" -o both

### Case Sensitivity

    # Case-sensitive (exact match required)
    glob "[A-Z]*.cs" -c sensitive

    # Case-insensitive (README.md matches readme.md)
    glob "readme.md" -c insensitive

    # Platform default (insensitive on Windows, sensitive on Unix)
    glob "*.TXT" -c platform

### Advanced Patterns

    # Character classes
    glob "**/*[0-9].log"           # Files ending with digit
    glob "**/[a-z]*.cs"            # Files starting with lowercase
    glob "**/{bin,obj}/**"         # Specific directory names

    # Named character classes
    glob "**/*[[:digit:]].txt"     # Files with digits
    glob "**/*[[:alpha:]]*.cs"     # Files with letters

    # Negation
    glob "**[!.]*.json"            # JSON files not starting with dot

    # Environment variables (expanded before matching)
    glob "$HOME/documents/**/*.pdf"              # Unix
    glob "%USERPROFILE%\documents\**\*.pdf"      # Windows
    glob "~/documents/**/*.pdf"                  # Unix (~ expands to $HOME)

### Deduplication

    # Without distinct (may show duplicates)
    glob "**/docs/**/*.md"

    # With distinct (removes duplicates)
    glob "**/docs/**/*.md" -x

### Including Hidden Files

    # Exclude hidden/system files (default)
    glob "**/*"

    # Include hidden/system files
    glob "**/*" -a

## Real-World Use Cases

### Development Workflows

    # Find all unit test files
    glob "**/test/**/*Tests.cs"

    # Find configuration files
    glob "**/{appsettings,web.config}.json"

    # Find source files excluding tests
    glob "src/**/*.cs"

### CI/CD Integration

#### GitHub Actions

    - name: Find test assemblies
      run: |
        TEST_DLLS=$(glob "**/*Tests.dll" -d ./artifacts/bin)
        dotnet test $TEST_DLLS

#### Azure Pipelines

    - script: |
        FILES=$(glob "**/*.csproj")
        echo "##vso[task.setvariable variable=ProjectFiles]$FILES"

### Code Analysis

    # Find public interfaces
    glob "src/**/I*.cs" | xargs grep "public interface"

    # Find deprecated code
    glob "**/*.cs" | xargs grep -l "Obsolete"

    # Count lines of code
    glob "src/**/*.cs" | xargs wc -l

### Project Maintenance

    # Find package references
    glob "**/*.csproj" | xargs grep PackageReference

    # Find large files
    glob "**/*" | xargs du -h | sort -rh | head -20

    # Find old log files
    glob "**/*.log" -d /var/log

## Output Format

Each matched path is printed on a separate line with:
- Absolute paths (full path from root)
- Directory paths end with `/` separator
- No extra formatting or colors (perfect for piping)

Example output:

    /home/user/projects/MyApp/src/Program.cs
    /home/user/projects/MyApp/src/Models/User.cs
    /home/user/projects/MyApp/test/ProgramTests.cs

## Environment Variable Support

The tool expands environment variables before pattern matching:

### Windows

    glob "%APPDATA%\**\*.json"
    glob "%USERPROFILE%\Documents\**\*.txt"

### Unix/Linux/macOS

    glob "$HOME/documents/**/*.pdf"
    glob "~/projects/**/*.cs"        # ~ expands to $HOME
    glob "$XDG_CONFIG_HOME/**/*.conf"

## Performance Tips

1. **Be specific** - `src/**/*.cs` is faster than `**/*.cs`
2. **Use `-o files`** if you only need files (skips directory enumeration)
3. **Avoid multiple globstars** unless necessary (`**/docs/**` is slower than `docs/**`)
4. **Use `-x` only when needed** (deduplication has memory cost)

## Comparison with Alternatives

| Feature          | `glob`        | `find` (Unix) | `Get-ChildItem` (PS) | `fd`      |
|------------------|---------------|---------------|----------------------|-----------|
| Cross-platform   | ✅            | ❌           | ❌                   | ✅       |
| Glob syntax      | ✅ Native     | ❌ Regex     | ❌ Complex           | ✅       |
| .NET integration | ✅            | ❌           | ⚠️                   | ❌       |
| Install          | `dotnet tool` | Pre-installed | Pre-installed        | Cargo     |
| Environment vars | ✅            | ❌           | ✅                   | ❌       |
| Speed            | Fast          | Very fast     | Slow                 | Very fast |

## Troubleshooting

### Pattern Not Matching

    # Use quotes to prevent shell expansion
    glob "**/*.cs"     # Correct
    glob **/*.cs       # Wrong (shell expands before tool runs)

### Permission Errors

    # Use elevated permissions (Windows)
    glob "C:\Windows\System32\**\*.dll" -a

    # Use sudo (Unix)
    sudo glob "/root/**/*"

### No Results

    # Verify start directory exists
    glob "**/*.cs" -d ~/nonexistent  # Error

    # Check case sensitivity
    glob "README.md" -c sensitive    # Won't match readme.md
    glob "README.md" -c insensitive  # Matches readme.md

## Library Integration

This tool is built on the `vm2.DevOps.Glob.Api` library. For programmatic access in .NET applications:

    dotnet add package vm2.DevOps.Glob.Api

Example usage:

    using vm2.DevOps.Glob.Api;

    var enumerator = new GlobEnumerator();
    enumerator.Glob = "**/*.cs";
    enumerator.FromDirectory = "/path/to/search";

    foreach (var file in enumerator.Enumerate())
    {
        Console.WriteLine(file);
    }

## Documentation

- [GitHub Repository](https://github.com/vmelamed/vm2.DevOps)
- [API Documentation](https://github.com/vmelamed/vm2.DevOps/tree/main/src/Glob.Api)
- [POSIX Glob Specification](https://www.man7.org/linux/man-pages/man7/glob.7.html)

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](../../CONTRIBUTING.md) for details.

## License

MIT License - Copyright © 2025 Val Melamed

See [LICENSE](../../LICENSE) for full text.

## Version History

See [CHANGELOG.md](../../CHANGELOG.md) for version history and release notes.