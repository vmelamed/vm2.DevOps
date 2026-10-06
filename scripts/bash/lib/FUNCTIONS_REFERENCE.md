# Bash Library Functions Reference

This document provides a quick reference to all functions in the bash library, organized by file in the order they are sourced by `core.sh`.

For detailed information about parameters, return values, and usage examples, refer to the function documentation (shdoc-style comment blocks) directly above each function in its source file.

---

## _constants.sh

Defines ANSI escape codes, emojis/glyphs, and vm2-wide constants (vm2 repository list, NuGet server regex, allowed conventional-commit types, etc.). Contains no functions, only constant declarations.

---

## core.sh

General-purpose functions sourced by every script. Also wires up the `on_exit`/`on_err` traps.

### on_exit()

EXIT trap handler: reports a non-zero, non-explicit exit, restores `$initial_cwd`, and disables trace mode.

### on_err()

ERR trap handler: reports the failing command, its exit code, and a stack trace.

### remove_traps()

Removes the ERR and EXIT traps set by `core.sh` (via `trap '' SIGNAL`, not `trap - SIGNAL`).

### execute()

Executes a command, or (in dry-run mode) prints what would have been executed without running it.

### execute_with_retry()

Executes a command, retrying on failure until it succeeds or a maximum attempt count is reached, with a fixed delay between attempts.

### list_of_files()

Expands a glob pattern (with globstar/nullglob enabled) and returns the matching files as a space-separated list.

---

## _core_state.sh

Common state variables (`$ci`, `$debugger`, quiet/verbose/dry-run/trace modes, `$_ignore`, table format) and the functions that read, set, and save/restore them.

### is_verbose()

Tests whether the script is in verbose mode.

### set_verbose() / unset_verbose()

Enables / disables verbose mode.

### is_quiet()

Tests whether the script is in quiet mode.

### set_quiet() / unset_quiet()

Enables / disables quiet mode (suppresses user prompts).

### is_dry_run()

Tests whether the script is in dry-run mode.

### set_dry_run() / unset_dry_run()

Enables / disables dry-run mode.

### show_ignored_output()

Redirects `$_ignore` (normally `/dev/null`) to a given file, default `/dev/stderr`, for debugging.

### hide_ignored_output()

Restores `$_ignore` to `/dev/null`.

### set_trace_enabled()

Enables trace mode: turns on verbose mode, redirects `$_ignore` to stderr, and enables `set -x`.

### unset_trace_enabled()

Disables trace mode: the inverse of `set_trace_enabled`.

### is_trace_enabled()

Tests whether trace mode (verbose + `$_ignore` redirected + `set -x`) is currently enabled.

### get_table_format()

Returns (via nameref) the current `dump_vars` table format ("graphical" or "markdown").

### set_table_format()

Sets the `dump_vars` table format to "graphical" or "markdown".

### save_state()

Saves quiet/verbose/dry-run/`$_ignore`/table-format/tracing/shell-option state into an associative array, for later `restore_state`.

### restore_state()

Restores global flag state previously saved by `save_state`, validating it was saved in the same shell/subshell.

### set_glob_star()

Enables or disables the `globstar` shell option.

### set_null_glob()

Enables or disables the `nullglob` shell option.

---

## _error_codes.sh

Standard error code constants (`$success`, `$err_invalid_arguments`, `$err_tool_error`, etc.) and lookup functions.

### error_message()

Looks up an error code and prints `"<code>: <message>"`. Exits the process directly (not via `bug`) to avoid recursion.

### error_name()

Looks up an error code and prints its symbolic name (e.g. `$err_not_found`). Exits the process directly, for the same reason as `error_message`.

---

## _diagnostics.sh

Logging functions (`error`, `warning`, `info`, `trace`, `bug`), the global error/bug counters, and the `exit_if_has_errors`/`exit_if_has_bugs` gates.

### to_stdout() / to_stderr() / to_output()

Read lines from stdin and echo them to stdout / stderr / stdout, respectively — overridable abstractions (`gh_core.sh` overrides them to also write to GitHub Actions step summary/output files).

### has_errors()

Tests whether the global error counter has recorded any errors.

### get_errors()

Prints the current value of the global error counter.

### set_errors()

Sets the global error counter to a specific value.

### reset_errors()

Resets the global error counter to zero.

### exit_if_has_bugs()

Exits the script (via `exit_with_error`) if any bugs were recorded by this function's own call depth or deeper; defers to an ancestor's still-open validation block otherwise.

### usage()

Forward-declaration placeholder for `usage()`, meant to be overridden by sourcing `_core_args.sh`; always bug-exits if not overridden.

### exit_if_has_errors()

Exits the script (via `usage`, or directly) if any errors were recorded.

### __message()

Internal helper that formats and prints one or more message lines with a severity prefix, optional error-code translation, and an optional stack dump. Used by `error`/`warning`/`info`/`trace`/`bug`.

### error()

Logs an error message to stderr and increments the global error counter.

### exit_with_error()

Logs an error message and exits immediately with the last recorded error code (or `$failure`).

### bug()

Logs a bug message (caller-contract violation) to stderr and increments the global bug counter.

### fatal_exit()

Logs a message with a fatal prefix and exits immediately with a specified (or default) error code.

### warning()

Logs a warning message to stderr.

### info()

Logs an informational message to stdout.

### trace()

Logs a trace message to stderr, only when verbose mode is enabled.

### warning_var()

Displays a warning about a variable's value and sets that variable to a given default.

### show_stack()

Prints the current call stack, one line per frame.

### to_summary()

Logs one or more lines under a `## Summary` markdown heading, via `$__summary_output` (glow, if available and not in CI; otherwise `to_stdout`).

---

## _core_args.sh

Common command-line argument parsing (`--verbose`, `--quiet`, `--trace`, `--dry-run`, `--graphical`, `--markdown`, `--help`/`-h`/`-?`) and the default `usage`/`usage_text` implementation.

### get_common_arg()

Processes one common command-line argument/switch; returns `$negative` if the argument is not one of the common ones.

### usage_if_requested()

Exits (via `usage`) if a usage request was previously recorded by `get_common_arg`.

### usage()

Displays an optional error message, the usage text, and exits. Overrides the forward-declaration in `_diagnostics.sh`.

### usage_text()

Default placeholder usage text; meant to be overridden by each top-level script.

---

## _predicates.sh

Boolean test (`is_*`) functions for variable existence/type, numeric formats, OS detection, and basic file/JSON validity.

### is_case_sensitive()

Tests whether shell pattern matching is currently case-sensitive.

### set_case_insensitive() / set_case_sensitive()

Sets the shell's `nocasematch` option off/on.

### set_case_sensitivity()

Sets the shell's case-sensitivity to a given state, returning the previous state.

### is_variable_name()

Tests if a string is a syntactically valid variable name.

### is_variable()

Tests if a variable is defined.

### is_indexed_array() / is_associative_array() / is_array()

Test if a variable is defined and is an indexed array / an associative array / either kind of array.

### is_empty_array()

Tests if an array (indexed or associative) has zero elements.

### is_function()

Tests if a function is defined.

### __test_with_regex()

Internal helper: tests if a string matches a given regular expression.

### is_boolean()

Tests if a string is `true` or `false`.

### is_natural()

Tests if a string is a natural number (1, 2, 3, ...).

### is_non_negative()

Tests if a string is a non-negative integer (0, 1, 2, ...).

### is_exit_code()

Tests if a string is a valid exit code (0-255).

### is_positive()

Tests if a string is a positive integer, optional leading `+`.

### is_non_positive()

Tests if a string is a non-positive integer (0, -1, -2, ...).

### is_negative()

Tests if a string is a negative integer.

### is_integer()

Tests if a string is an integer, optional leading sign.

### is_decimal()

Tests if a string is a decimal number (integer or floating-point).

### is_base64()

Tests if a string is validly Base64-encoded.

### is_in()

Tests if the first argument equals any of the subsequent arguments.

### is_windows()

Detects if the current OS is Windows (Windows_NT, MINGW, or MSYS).

### is_valid_filename()

Tests if a string is a valid, simple filename (non-empty, no slashes, not `.`/`..`).

### is_valid_path()

Tests if a string is a syntactically valid path, via `pathchk`.

### is_valid_secret()

Tests if a string is non-empty and free of control characters.

### is_valid_dotnet_version()

Tests if a string is a valid .NET SDK version specifier (full version, major.minor with optional feature band, bare major, or `latest`).

### is_tool_present()

Tests if a named tool is available on `$PATH`.

### is_valid_json()

Tests if a string is valid JSON, via `jq`.

### is_valid_json_file()

Tests if the file at a given path contains valid JSON.

---

## _sanitize.sh

Input trimming and safety/validation functions (`is_safe_*`, `validate_*`) for GitHub Actions and script argument sanitization.

### ltrim() / rtrim() / trim()

Trim leading / trailing / both leading-and-trailing whitespace from a string, printed to stdout.

### ltrim_var() / rtrim_var() / trim_var()

In-place variants of the above, operating on a referenced variable.

### is_safe_input()

Tests that a string contains no shell-metacharacters that could enable command injection.

### is_safe_boolean()

Validates that a string is `true` or `false`.

### is_safe_integer()

Validates that a string is an integer.

### is_safe_path()

Validates that a relative path contains no traversal sequences, leading `/`, or dangerous characters.

### is_safe_valid_path()

Combines `is_safe_path` with `is_valid_path` (syntactic validity via `pathchk`).

### is_safe_existing_path()

Combines `is_safe_valid_path` with an existence check.

### is_safe_existing_directory() / is_safe_existing_file()

Combine `is_safe_existing_path` with a directory / non-empty-file type check.

### validate_json_array()

Validates and normalizes a JSON array of strings (or a single string) into a deduplicated, trimmed JSON array, optionally validating each item with a caller-supplied function.

### is_safe_runner_os()

Validates that a string is one of the allowed GitHub Actions runner OS monikers.

### is_safe_reason()

Validates a free-text "reason" input for length and shell-safety.

### is_valid_nuget_server()

Tests if a string is `nuget`, `github`, or a valid http(s) URL.

### validate_nuget_server()

Validates a NuGet server moniker and resolves it into a display name and server URL.

### is_valid_configuration()

Tests if a string is a syntactically valid build-configuration identifier.

### is_safe_configuration()

Validates a build configuration name, warning (not failing) if it's not one of the known configurations.

### is_valid_framework()

Tests if a string is a syntactically valid Target Framework Moniker (TFM).

### is_safe_framework()

Validates a TFM, warning (not failing) if it's not one of the known frameworks.

### is_valid_runtime()

Tests if a string is a syntactically valid Runtime Identifier (RID).

### is_safe_runtime()

Validates a RID, warning (not failing) if it's not one of the known runtimes.

### validate_runtime()

Lowercases a referenced RID in place and validates it via `is_safe_runtime`.

### validate_preprocessor_symbols()

Validates and reformats a space/comma/colon/semicolon-separated preprocessor-symbol list into a semicolon-separated list, in place.

### is_safe_secret()

Validates that a candidate secret value is non-empty and free of control characters.

### is_valid_percentage()

Tests if a string is an integer between 0 and 100.

### is_safe_min_coverage_pct() / is_safe_max_regression_pct()

Validate a minimum-coverage / maximum-regression percentage input.

### is_valid_minverTagPrefix()

Tests if a string is a valid MinVer Git tag prefix.

### is_safe_minverTagPrefix()

Validates a MinVer Git tag prefix, via `is_valid_minverTagPrefix`.

### is_valid_minverPrereleaseId()

Tests if a string is a valid MinVer prerelease identifier.

### is_safe_minverPrereleaseId()

Validates a MinVer prerelease identifier, via `is_valid_minverPrereleaseId`.

### escape_ere()

Escapes a string's special characters for safe use in an extended regular expression (ERE).

### validate_json_schema()

Validates a JSON file against a JSON Schema file via `check-jsonschema`, if installed (warns and skips otherwise).

---

## _semver.sh

Semantic Versioning (SemVer 2.0.0) and MinVer tag regular expressions, comparison, and validation functions.

### print_semver_regexes()

Dumps the SemVer/MinVer regex constants to stdout, grouped by category, via `dump_vars`.

### validate_semverTagComponents()

Validates a MinVer tag prefix and (optionally) a MinVer prerelease identifier template against their regular expressions.

### compare_semver()

Compares two semantic versions per SemVer 2.0.0, returning `$rc_equal`/`$rc_greater_than`/`$rc_less_than`.

### semver_equal() / semver_greaterThan() / semver_greaterThanOrEqual() / semver_lessThan() / semver_lessThanOrEqual()

Boolean comparison wrappers around `compare_semver`.

### is_semver()

Tests if a string is a valid SemVer 2.0.0 version.

### is_semverTag()

Tests if a string is a valid semver tag (with the configured MinVer prefix).

### is_semverPrerelease()

Tests if a string is a valid semver prerelease version.

### is_semverPrereleaseTag()

Tests if a string is a valid semver prerelease tag (with the configured MinVer prefix).

### is_semverRelease()

Tests if a string is a valid semver release version (no prerelease identifier).

### is_semverReleaseTag()

Tests if a string is a valid semver release tag (with the configured MinVer prefix, no prerelease).

---

## _dump_vars.sh

Formats and prints variable names/values as a graphical or markdown table.

### _write_title()

Internal helper: writes a header title line in the current table format.

### _write_line()

Internal helper: writes a "name: value" line, handling scalars, arrays, associative arrays, functions, and unbound/invalid names.

### dump_vars()

If verbose (or `--force`), dumps a table of named variables with optional headers, secrets masking, and blank/dividing lines; optionally prompts "press any key" afterward.

---

## _user.sh

User interaction primitives: prompts, confirmations, and choices.

### press_any_key()

Displays a prompt and waits for a keypress, unless in quiet mode.

### confirm()

Asks the user a yes/no question, defaulting (and skipping the prompt) in quiet mode.

### enter_value()

Prompts the user to enter a value, with support for a default, secret masking, and a validation function.

### choose()

Displays a numbered list of options and asks the user to pick one, defaulting to the first in quiet mode.

### print_sequence()

Prints a sequence of values with a customizable quote character, separator, and enclosing parentheses.

---

## _git.sh

Git/GitHub repository validation, state retrieval, and latest-stable-tag helpers.

### validate_gh_repo_owner() / validate_gh_repo_name() / validate_gh_repo_description()

Validate a GitHub repository owner / name / description against GitHub's naming rules.

### is_valid_branch_name()

Tests if a string is a valid Git branch name, via `git check-ref-format`.

### validate_branch_name()

Validates a Git branch name, via `is_valid_branch_name`.

### execute_gh_with_retry()

Executes a `gh` command with retry logic for transient failures (rate limits, timeouts, etc.).

### execute_gh_api_with_retry()

Executes a `gh api` command with retry logic based on the response's HTTP status (or stderr pattern matching as a fallback).

### initialize_repo_state()

Initializes a repo-state associative array to all predefined keys with empty values.

### get_repo_state()

Retrieves the Git/GitHub repository state for a directory (local Git-derived fields, optionally cross-checked against the GitHub API).

### has_local_repo() / has_remote_repo() / has_github_remote()

Test if a repo-state array has a local Git repo / a remote URL / a remote GitHub repo (repo ID) recorded.

### read_repo_state()

Deserializes a repo state from `key=value` lines on stdin.

### print_repo_state()

Prints a repo state to stdout, one line per predefined key.

### is_inside_work_tree()

Tests if a directory is inside a Git working tree.

### root_working_tree()

Resolves the root directory of the Git working tree containing a given directory.

### should_fetch_for_latest_stable_tag()

Tests whether local Git metadata looks stale enough to justify a fetch before evaluating latest-stable-tag predicates.

### ensure_fresh_git_state()

Fetches from the remote if `should_fetch_for_latest_stable_tag` recommends it.

### get_latest_stable_tag_hash()

Gets the commit hash of the latest stable tag in a repository.

### is_after_latest_stable_tag() / is_on_or_after_latest_stable_tag()

Test if the current commit is strictly after / on-or-after the latest stable tag.

---

## _git_vm2.sh

vm2-specific repository resolution: locating `$VM2_REPOS` and individual vm2 repositories.

### get_devops_parent()

Returns (and caches) the parent directory of the vm2.DevOps repository.

### __validate_repo_root()

Internal helper: validates that a named/pathed repository exists, is a Git root with CI configuration, is on the expected branch, and is at or ahead of its latest stable tag.

### resolve_vm2_repos()

Resolves `$VM2_REPOS` (CLI arg > `$VM2_REPOS` env > vm2.DevOps's own parent > hardcoded default), validating vm2.DevOps and vm2.Templates under it.

### __search_repo_dir()

Internal helper used by `resolve_repo_root`: searches for a directory by name/relative path under a parent, skipping noise directories (`.git`, `node_modules`, `bin`, `obj`, etc.).

### resolve_repo_root()

Finds the root of a Git repository (or nearest ancestor with CI configuration) by searching under `$vm2_repos`, falling back to `$HOME`.

### get_vm2_sot_path()

Resolves the path to the Source-of-Truth shared-content directory inside vm2.Templates.

---

## _xml.sh

Generic XML value reading via `yq`'s XML support. Knows nothing about dotnet, MSBuild, or any other specific XML dialect.

### get_xml_value()

Reads a single element or attribute value out of an XML file by yq path expression (e.g. `.Project.PropertyGroup.IncludeSymbols`, or `.Project.ItemGroup.PackageReference.+@Version` for an attribute). A literal, single-file read -- does not resolve inherited values (e.g. from a project's `Directory.Build.props`) the way `get_msbuild_property()` does.

---

## _dotnet_args.sh

Common dotnet-CLI argument variables (`$configuration`, `$framework`, `$runtime`, `$artifacts`, MinVer settings, NuGet credentials) and their parsing/sanitization.

### get_common_dotnet_arg()

Processes one common dotnet-related command-line option and its value.

### sanitize_common_dotnet_args()

Validates and freezes (via `readonly`) the common dotnet arguments after parsing; resolves `$artifacts` to a concrete path.

---

## _dotnet.sh

.NET build/restore/pack/clean orchestration and MSBuild property/metadata helpers.

### get_dotnet_error_message()

Looks up the human-readable message for a known `dotnet` process exit code.

### update_nuget_sources_with_github_vm2()

Updates the `github.vm2` NuGet source with credentials (CLI args, or `$GH_ACTOR`/`$GH_TOKEN` in CI).

### convert_dotnet_args_to_msbuild_args()

Converts `dotnet <command>` arguments (e.g. `--configuration Release`) to the equivalent `dotnet msbuild` arguments/properties.

### extract_dotnet_build_info()

Parses the output of a `dotnet build` command from stdin and populates an associative array with build/version/result information.

### display_dotnet_build_summary()

Displays a formatted summary table (via `dump_vars`) of build information previously extracted by `extract_dotnet_build_info`.

### dotnet_clean()

Cleans a .NET project or solution using the common dotnet arguments.

### dotnet_restore()

Restores a .NET project's dependencies (`--locked-mode`) using the common dotnet arguments.

### dotnet_build()

Builds a .NET project or solution (no restore) and captures build output information.

### dotnet_pack()

Packs an already-built .NET project (`--no-build`), resolving `Configuration` from the project if not pinned, and returns the produced package/symbols paths.

### get_msbuild_property()

Gets the value of a single MSBuild property for a project, via `dotnet msbuild -getProperty`, without building.

### get_msbuild_properties()

Gets the values of two or more MSBuild properties in one call (JSON-shaped result).

### get_target_path()

Gets the full path to the assembly that was/would be produced by `dotnet build` (wraps `get_msbuild_property` for `TargetPath`).

### get_artifacts_path()

Gets the full path to the `ArtifactsPath` directory for a project or solution.

### list_solution_projects()

Lists the constituent project paths of a solution file, via `dotnet sln list`.

### expand_solution_projects()

Expands any solution-file entries in a JSON array of project/solution paths into their constituent project paths.

---

## gh_core.sh

GitHub Actions environment integration. Sources `core.sh` and overrides its `to_*` functions to also write to the step-summary/output files.

### to_stdout() / to_stderr() (overrides)

Send input to stdout/stderr, and (in GitHub Actions) also append to `$GITHUB_STEP_SUMMARY`.

### to_output() (override)

Sends input to stdout, and (in GitHub Actions) also appends to `$GITHUB_OUTPUT`.

### gh_escape()

Escapes a value for safe inclusion in a GitHub Actions workflow command (`::notice::`, etc.), per GitHub's own `%`/CR/LF escaping rules.

### args_to_github_output()

Outputs a `key=value` pair (kebab-case key) for each named variable to `$GITHUB_OUTPUT`, via `to_output`.

---

## Summary

### Total Functions: 192

| File               | Functions |
|--------------------|----------:|
| core.sh            |         6 |
| _core_state.sh     |        20 |
| _error_codes.sh    |         2 |
| _diagnostics.sh    |        21 |
| _core_args.sh           |         4 |
| _predicates.sh     |        31 |
| _sanitize.sh       |        36 |
| _semver.sh         |        14 |
| _dump_vars.sh      |         3 |
| _user.sh           |         5 |
| _git.sh            |        21 |
| _git_vm2.sh        |         6 |
| _xml.sh            |         1 |
| _dotnet_args.sh    |         2 |
| _dotnet.sh         |        15 |
| gh_core.sh         |         5 |

Counts include internal (`__`-prefixed) helper functions that are not part of the public library surface but are still documented in their source files.

### Usage Pattern

1. Source `core.sh` in your scripts to get all base functionality (it sources every other component file in turn).
2. Source `gh_core.sh` instead of `core.sh` when the script runs in GitHub Actions, to get step-summary/output integration.
3. Individual component files (`_predicates.sh`, `_sanitize.sh`, etc.) can be sourced directly if only a narrow slice of functionality is needed.

### Key Design Principles

- Functions read from stdin and write to stdout/stderr where appropriate, for pipeline composition (`to_stdout`, `to_stderr`, `to_output`, `to_summary`, `error`, `warning`, `info`, `trace`).
- Global state is saved/restored cooperatively via `save_state`/`restore_state`, never mutated ad hoc.
- Predicate functions (`is_*`, `has_*`) return `$positive`/`$negative` (0/1); they answer a yes/no question, and "no" is a legitimate answer, not a failure.
- Validation (`is_safe_*`, `validate_*`) and other action functions return `$success`/`$failure` or a specific named error code (`$err_argument_value`, `$err_tool_error`, etc.) on failure.
- Caller-contract violations (`bug`) hard-exit via `exit_if_has_bugs`; runtime/environmental failures (`error`) accumulate and are surfaced via `exit_if_has_errors` at the top-level script only.
