# Bash Library Functions Reference

This document provides a quick reference to all functions in the bash library, organized by file in the order they are sourced by `core.sh`.

For detailed information about parameters, return values, and usage examples, refer to the function documentation in each source file.

---

## _constants.sh

Defines ANSI escape codes for terminal text formatting and colors. Contains no functions, only constant declarations.

---

## _diagnostics.sh

### to_stdout()

Logs messages to stdout, allowing override in other scripts for alternate destinations.

### to_trace_out()

Logs trace messages to stdout, allowing override in other scripts for alternate destinations.

### to_stderr()

Logs messages to stderr, allowing override in other scripts for alternate destinations.

### error()

Logs error messages to stderr and increments the global error counter.

### warning()

Logs warning messages to stderr.

### warning_var()

Logs a warning about a variable's value and sets it to a default value.

### info()

Logs informational messages to stdout.

### trace()

Logs trace messages to stdout when verbose mode is enabled.

### on_debug()

DEBUG trap handler that tracks the last executed command for error reporting.

### on_exit()

EXIT trap handler that displays failed commands, restores directory, and disables tracing.

### show_stack()

Displays the current call stack when verbose mode is enabled.

---

## _args.sh

### set_quiet()

Sets the script to quiet mode, suppressing user prompts.

### set_verbose()

Sets the script to verbose mode, enabling detailed output.

### set_dry_run()

Sets the script to dry-run mode, simulating commands without execution.

### set_trace_enabled()

Enables trace mode for debugging by setting verbose, redirecting output, and enabling bash tracing.

### set_table_format()

Sets the table format for variable dumps to either graphical or markdown.

### get_table_format()

Returns the current table format setting.

### get_common_arg()

Processes common command-line arguments like --quiet, --verbose, --trace, --dry-run.

### display_usage_msg()

Displays a usage message and optionally additional error messages, exiting with code 2 if errors are present.

### usage()

Displays the usage message; MUST be overridden in calling scripts for custom usage information.

### exit_if_has_errors()

Tests the global error counter and exits if errors were encountered.

---

## _predicates.sh

### is_defined_variable()

Tests if a variable is defined.

### is_positive()

Tests if the parameter represents a valid positive integer number (natural number: 1, 2, 3, ...).

### is_non_negative()

Tests if the parameter represents a valid non-negative integer (0, 1, 2, 3, ...).

### is_non_positive()

Tests if the parameter represents a valid non-positive integer (0, -1, -2, -3, ...).

### is_negative()

Tests if the parameter represents a valid negative integer (-1, -2, -3, ...).

### is_integer()

Tests if the parameter represents a valid integer (..., -2, -1, 0, 1, 2, ...).

### is_decimal()

Tests if the parameter represents a valid decimal number (including integers and floating-point).

### is_in()

Tests if the first parameter equals one of the following parameters.

### is_inside_work_tree()

Tests if the specified directory is a Git repository (inside a work tree).

### is_latest_stable_tag()

Tests if the current commit in the specified directory is on the latest stable tag.

### is_after_latest_stable_tag()

Tests if the current commit in the specified directory is after the latest stable tag.

### is_on_or_after_latest_stable_tag()

Tests if the current commit in the specified directory is on or after the latest stable tag.

---

## _dump_vars.sh

### push_state()

Saves current state of global flags to be restored later by pop_state.

### pop_state()

Restores state of global flags previously saved by push_state.

### dump_vars()

Displays a formatted table of variable names and values with optional headers and formatting.

### _write_title()

Internal function to write a header title in the variable dump table.

### _write_line()

Internal function to write a variable name and value line in the dump table.

---

## _semver.sh

### validate_minverTagPrefix()

Validates MinVer tag prefix and creates tag validation regular expressions.

### compare_semver()

Compares two semantic versions according to semver 2.0.0 specification.

### is_semver()

Tests if the parameter is a valid semantic version (semver 2.0.0 format).

### is_semverTag()

Tests if the parameter is a valid semver tag (with configured prefix).

### is_semverPrerelease()

Tests if the parameter is a valid semver prerelease version.

### is_semverPrereleaseTag()

Tests if the parameter is a valid semver prerelease tag (with configured prefix).

### is_semverRelease()

Tests if the parameter is a valid semver release version (without prerelease identifier).

### is_semverReleaseTag()

Tests if the parameter is a valid semver release tag (with configured prefix, without prerelease).

---

## _user.sh

### press_any_key()

Displays a prompt and waits for user to press any key before continuing.

### confirm()

Asks the user to respond yes or no to a prompt.

### choose()

Displays a prompt and list of options, asks user to choose one.

### print_sequence()

Prints a sequence of quoted values with customizable quote, separator, and parentheses.

---

## core.sh

### execute()

Depending on the value of $dry_run, either executes or displays what would have been executed.

### list_of_files()

Tests if parameter is a valid file pattern and returns matching files, recursing into subdirectories.

---

## gh_core.sh

GitHub Actions-specific extensions that override and extend core library functions.

### to_stdout() (override)

Sends input to stdout and, if in GitHub Actions, also appends to the GitHub step summary.

### to_trace_out() (override)

Sends trace output to stdout and optionally to GitHub step summary.

### to_stderr() (override)

Sends input to stderr and, if in GitHub Actions, also appends to the GitHub step summary.

### to_summary()

Logs a summary message with markdown heading to stdout and GitHub step summary.

### to_output()

Sends input to stdout and, if in GitHub Actions, also appends to the GitHub output file.

### to_github_output()

Outputs a variable to GitHub Actions output, converting underscores to hyphens in the key name.

### args_to_github_output()

Outputs multiple variables to GitHub Actions output, converting underscores to hyphens in key names.

---

## _sanitize.sh

Input validation and sanitization functions for security.

### is_safe_input()

Tests if user input is safe by checking for potentially dangerous characters.

### is_safe_path()

Validates file paths to prevent directory traversal and dangerous patterns.

### is_safe_existing_path()

Validates that a path is safe and exists.

### is_safe_existing_directory()

Validates that a path is safe, exists, and is a directory.

### is_safe_existing_file()

Validates that a path is safe, exists, and is a non-empty file.

### is_safe_json_array()

Validates a JSON array of strings and checks each item's safety using provided validator function.

### is_safe_runner_os()

Validates that a runner OS name is in the allowed list of GitHub Actions runners.

### is_safe_reason()

Validates a "reason" text input for safety and length constraints.

### is_safe_nuget_server()

Validates NuGet server URL or known server name.

### validate_nuget_server()

Validates NuGet server variable and sets to default if empty.

### is_safe_configuration()

Validates that a configuration name is a valid identifier.

### validate_preprocessor_symbol()

Validates preprocessor symbols and formats them for MSBuild with DefineConstants preservation.

### is_safe_minverPrereleaseId()

Validates MinVer prerelease identifier format.

### is_safe_dotnet_version()

Validates .NET version input format.

---

## _dotnet.sh

.NET build tooling support.

### summarizeDotnetBuild()

Summarizes the output of a 'dotnet build -v d' command, extracting version info and results.

---

## Summary

**Total Functions: 67**

- _diagnostics.sh: 11 functions
- _args.sh: 10 functions
- _predicates.sh: 12 functions
- _dump_vars.sh: 5 functions
- _semver.sh: 8 functions
- _user.sh: 4 functions
- core.sh: 4 functions
- gh_core.sh: 7 functions
- _sanitize.sh: 14 functions (13 validators + 1 formatter)
- _dotnet.sh: 1 function

**Usage Pattern:**

1. Source `core.sh` in your scripts to get all base functionality
2. Source `gh_core.sh` for GitHub Actions-specific features
3. Individual component files can be sourced directly if needed

**Key Design Principles:**

- Functions read from stdin and write to stdout where appropriate for pipeline composition
- Global state modifications are minimized (e.g., `dump_vars` uses push_state/pop_state)
- Validation functions return exit codes: 0 (success), 1 (validation failed), 2 (invalid arguments)
- Diagnostic functions support both argument-based and stdin-based input for flexibility
