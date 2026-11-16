# Bash Library Functions Reference

<!-- TOC tocDepth:2..3 chapterDepth:2..6 -->

- [Bash Library Functions Reference](#bash-library-functions-reference)
  - [\_constants.sh](#_constantssh)
  - [core.sh](#coresh)
    - [on\_exit()](#on_exit)
    - [on\_err()](#on_err)
    - [add\_trap()](#add_trap)
    - [execute()](#execute)
    - [execute\_with\_retry()](#execute_with_retry)
    - [list\_of\_files()](#list_of_files)
    - [find\_files\_by\_precedence()](#find_files_by_precedence)
  - [\_core\_state.sh](#_core_statesh)
    - [is\_verbose()](#is_verbose)
    - [set\_verbose() / unset\_verbose()](#set_verbose--unset_verbose)
    - [is\_quiet()](#is_quiet)
    - [set\_quiet() / unset\_quiet()](#set_quiet--unset_quiet)
    - [is\_dry\_run()](#is_dry_run)
    - [set\_dry\_run() / unset\_dry\_run()](#set_dry_run--unset_dry_run)
    - [show\_ignored\_output()](#show_ignored_output)
    - [hide\_ignored\_output()](#hide_ignored_output)
    - [set\_trace\_enabled()](#set_trace_enabled)
    - [unset\_trace\_enabled()](#unset_trace_enabled)
    - [is\_trace\_enabled()](#is_trace_enabled)
    - [get\_table\_format()](#get_table_format)
    - [set\_table\_format()](#set_table_format)
    - [save\_state()](#save_state)
    - [restore\_state()](#restore_state)
    - [begin\_scope()](#begin_scope)
    - [end\_scope()](#end_scope)
    - [report\_open\_scopes()](#report_open_scopes)
    - [set\_glob\_star()](#set_glob_star)
    - [set\_null\_glob()](#set_null_glob)
  - [\_error\_codes.sh](#_error_codessh)
    - [error\_message()](#error_message)
    - [error\_name()](#error_name)
  - [\_predicates.sh](#_predicatessh)
    - [is\_case\_sensitive()](#is_case_sensitive)
    - [set\_case\_insensitive() / set\_case\_sensitive()](#set_case_insensitive--set_case_sensitive)
    - [is\_variable\_name()](#is_variable_name)
    - [is\_variable()](#is_variable)
    - [is\_indexed\_array() / is\_associative\_array() / is\_array()](#is_indexed_array--is_associative_array--is_array)
    - [is\_empty\_array()](#is_empty_array)
    - [is\_function()](#is_function)
    - [\_\_test\_with\_regex()](#__test_with_regex)
    - [is\_boolean()](#is_boolean)
    - [is\_natural()](#is_natural)
    - [is\_non\_negative()](#is_non_negative)
    - [is\_exit\_code()](#is_exit_code)
    - [is\_positive()](#is_positive)
    - [is\_non\_positive()](#is_non_positive)
    - [is\_negative()](#is_negative)
    - [is\_integer()](#is_integer)
    - [is\_decimal()](#is_decimal)
    - [is\_base64()](#is_base64)
    - [is\_in()](#is_in)
    - [is\_in\_i()](#is_in_i)
    - [is\_windows()](#is_windows)
    - [is\_valid\_filename()](#is_valid_filename)
    - [is\_valid\_path()](#is_valid_path)
    - [is\_valid\_secret\_name()](#is_valid_secret_name)
    - [is\_valid\_secret()](#is_valid_secret)
    - [is\_valid\_dotnet\_version()](#is_valid_dotnet_version)
    - [is\_tool\_present()](#is_tool_present)
    - [is\_valid\_json()](#is_valid_json)
    - [is\_valid\_json\_file()](#is_valid_json_file)
  - [\_diagnostics.sh](#_diagnosticssh)
    - [to\_stdout() / to\_stderr() / to\_output()](#to_stdout--to_stderr--to_output)
    - [has\_errors()](#has_errors)
    - [get\_errors()](#get_errors)
    - [set\_errors()](#set_errors)
    - [reset\_errors()](#reset_errors)
    - [exit\_if\_has\_bugs()](#exit_if_has_bugs)
    - [usage()](#usage)
    - [exit\_if\_has\_errors()](#exit_if_has_errors)
    - [\_\_message()](#__message)
    - [error()](#error)
    - [exit\_with\_error()](#exit_with_error)
    - [with\_error()](#with_error)
    - [bug()](#bug)
    - [exit\_with\_bug()](#exit_with_bug)
    - [fatal\_exit()](#fatal_exit)
    - [warning()](#warning)
    - [info()](#info)
    - [trace()](#trace)
    - [warning\_var()](#warning_var)
    - [show\_stack()](#show_stack)
    - [to\_summary()](#to_summary)
    - [now\_us()](#now_us)
  - [\_core\_args.sh](#_core_argssh)
    - [get\_common\_arg()](#get_common_arg)
    - [usage\_if\_requested()](#usage_if_requested)
    - [usage()](#usage-1)
    - [usage\_text()](#usage_text)
  - [\_semver.sh](#_semversh)
    - [print\_semver\_regexes()](#print_semver_regexes)
    - [validate\_minver\_tag\_components()](#validate_minver_tag_components)
    - [get\_semver\_major() / get\_semver\_minor() / get\_semver\_patch() / get\_semver\_prerelease() / get\_semver\_build()](#get_semver_major--get_semver_minor--get_semver_patch--get_semver_prerelease--get_semver_build)
    - [compare\_semver()](#compare_semver)
    - [semver\_eq() / semver\_gt() / semver\_gte() / semver\_lt() / semver\_lte()](#semver_eq--semver_gt--semver_gte--semver_lt--semver_lte)
    - [is\_semver()](#is_semver)
    - [is\_semver\_tag()](#is_semver_tag)
    - [is\_semver\_prerelease()](#is_semver_prerelease)
    - [is\_semver\_prerelease\_tag()](#is_semver_prerelease_tag)
    - [is\_semver\_release()](#is_semver_release)
    - [is\_semver\_release\_tag()](#is_semver_release_tag)
  - [\_sanitize.sh](#_sanitizesh)
    - [ltrim() / rtrim() / trim()](#ltrim--rtrim--trim)
    - [ltrim\_var() / rtrim\_var() / trim\_var()](#ltrim_var--rtrim_var--trim_var)
    - [is\_safe\_input()](#is_safe_input)
    - [is\_safe\_boolean()](#is_safe_boolean)
    - [is\_safe\_integer()](#is_safe_integer)
    - [is\_safe\_path()](#is_safe_path)
    - [is\_safe\_valid\_path()](#is_safe_valid_path)
    - [is\_safe\_existing\_path()](#is_safe_existing_path)
    - [is\_safe\_existing\_directory() / is\_safe\_existing\_file()](#is_safe_existing_directory--is_safe_existing_file)
    - [validate\_json\_array()](#validate_json_array)
    - [is\_safe\_runner\_os()](#is_safe_runner_os)
    - [is\_safe\_reason()](#is_safe_reason)
    - [is\_valid\_nuget\_server()](#is_valid_nuget_server)
    - [validate\_nuget\_server()](#validate_nuget_server)
    - [is\_valid\_configuration()](#is_valid_configuration)
    - [is\_safe\_configuration()](#is_safe_configuration)
    - [is\_valid\_framework()](#is_valid_framework)
    - [is\_safe\_framework()](#is_safe_framework)
    - [is\_valid\_runtime()](#is_valid_runtime)
    - [is\_safe\_runtime()](#is_safe_runtime)
    - [validate\_runtime()](#validate_runtime)
    - [validate\_preprocessor\_symbols()](#validate_preprocessor_symbols)
    - [is\_safe\_secret()](#is_safe_secret)
    - [is\_valid\_percentage()](#is_valid_percentage)
    - [is\_safe\_min\_coverage\_pct() / is\_safe\_max\_regression\_pct()](#is_safe_min_coverage_pct--is_safe_max_regression_pct)
    - [is\_valid\_minverTagPrefix()](#is_valid_minvertagprefix)
    - [is\_safe\_minverTagPrefix()](#is_safe_minvertagprefix)
    - [is\_valid\_minverPrereleaseId()](#is_valid_minverprereleaseid)
    - [is\_safe\_minverPrereleaseId()](#is_safe_minverprereleaseid)
    - [escape\_ere()](#escape_ere)
    - [validate\_json\_schema()](#validate_json_schema)
  - [\_dump\_vars.sh](#_dump_varssh)
    - [\_write\_title()](#_write_title)
    - [\_write\_line()](#_write_line)
    - [dump\_vars()](#dump_vars)
  - [\_user.sh](#_usersh)
    - [press\_any\_key()](#press_any_key)
    - [confirm()](#confirm)
    - [enter\_value()](#enter_value)
    - [choose()](#choose)
    - [print\_sequence()](#print_sequence)
  - [\_git.sh](#_gitsh)
    - [is\_valid\_branch\_name()](#is_valid_branch_name)
    - [is\_valid\_tag\_name()](#is_valid_tag_name)
    - [is\_valid\_commit\_sha()](#is_valid_commit_sha)
    - [validate\_branch\_name()](#validate_branch_name)
    - [is\_inside\_work\_tree()](#is_inside_work_tree)
    - [root\_working\_tree()](#root_working_tree)
    - [should\_fetch\_for\_latest\_stable\_tag()](#should_fetch_for_latest_stable_tag)
    - [ensure\_fresh\_git\_state()](#ensure_fresh_git_state)
    - [get\_latest\_stable\_tag\_hash()](#get_latest_stable_tag_hash)
    - [is\_after\_latest\_stable\_tag() / is\_on\_or\_after\_latest\_stable\_tag()](#is_after_latest_stable_tag--is_on_or_after_latest_stable_tag)
  - [\_git\_gh.sh](#_git_ghsh)
    - [is\_valid\_gh\_repo\_owner() / is\_valid\_gh\_repo\_name() / is\_valid\_gh\_repo\_full\_name() / is\_valid\_gh\_repo\_description()](#is_valid_gh_repo_owner--is_valid_gh_repo_name--is_valid_gh_repo_full_name--is_valid_gh_repo_description)
    - [validate\_gh\_repo\_owner() / validate\_gh\_repo\_name() / validate\_gh\_repo\_description()](#validate_gh_repo_owner--validate_gh_repo_name--validate_gh_repo_description)
    - [execute\_gh\_with\_retry()](#execute_gh_with_retry)
    - [execute\_gh\_api\_with\_retry()](#execute_gh_api_with_retry)
    - [get\_gh\_repo\_property()](#get_gh_repo_property)
    - [is\_repo\_state\_initialized()](#is_repo_state_initialized)
    - [initialize\_repo\_state()](#initialize_repo_state)
    - [get\_gh\_repo\_state()](#get_gh_repo_state)
    - [get\_repo\_state()](#get_repo_state)
    - [has\_local\_repo() / has\_remote\_repo() / has\_github\_remote()](#has_local_repo--has_remote_repo--has_github_remote)
    - [read\_repo\_state()](#read_repo_state)
    - [print\_repo\_state()](#print_repo_state)
  - [\_git\_vm2.sh](#_git_vm2sh)
    - [get\_devops\_parent()](#get_devops_parent)
    - [\_\_validate\_repo\_root()](#__validate_repo_root)
    - [resolve\_vm2\_repos()](#resolve_vm2_repos)
    - [\_\_search\_repo\_dir()](#__search_repo_dir)
    - [resolve\_repo\_root()](#resolve_repo_root)
    - [get\_vm2\_sot\_path()](#get_vm2_sot_path)
  - [\_xml.sh](#_xmlsh)
    - [get\_xml\_value()](#get_xml_value)
  - [\_dotnet\_constants.sh](#_dotnet_constantssh)
    - [dotnet\_error\_message()](#dotnet_error_message)
  - [\_dotnet\_args.sh](#_dotnet_argssh)
    - [get\_common\_dotnet\_arg()](#get_common_dotnet_arg)
    - [sanitize\_common\_dotnet\_args()](#sanitize_common_dotnet_args)
  - [\_dotnet\_msbuild.sh](#_dotnet_msbuildsh)
    - [get\_msbuild\_property()](#get_msbuild_property)
    - [get\_msbuild\_properties()](#get_msbuild_properties)
    - [get\_target\_path()](#get_target_path)
    - [get\_artifacts\_path()](#get_artifacts_path)
    - [convert\_dotnet\_args\_to\_msbuild\_args()](#convert_dotnet_args_to_msbuild_args)
    - [extract\_dotnet\_build\_info()](#extract_dotnet_build_info)
    - [display\_dotnet\_build\_summary()](#display_dotnet_build_summary)
  - [\_dotnet.sh](#_dotnetsh)
    - [update\_nuget\_sources\_with\_github\_vm2()](#update_nuget_sources_with_github_vm2)
    - [dotnet\_clean()](#dotnet_clean)
    - [dotnet\_restore()](#dotnet_restore)
    - [dotnet\_build()](#dotnet_build)
    - [dotnet\_pack()](#dotnet_pack)
    - [list\_solution\_projects()](#list_solution_projects)
    - [expand\_solution\_projects()](#expand_solution_projects)
  - [gh\_core.sh](#gh_coresh)
    - [to\_stdout() / to\_stderr() (overrides)](#to_stdout--to_stderr-overrides)
    - [to\_output() (override)](#to_output-override)
    - [gh\_escape()](#gh_escape)
    - [args\_to\_github\_output()](#args_to_github_output)
  - [Summary](#summary)
    - [Total Functions: 215](#total-functions-215)
    - [Usage Pattern](#usage-pattern)
    - [Key Design Principles](#key-design-principles)

<!-- /TOC -->

This document provides a quick reference to all functions in the bash library, organized by file in the order they are sourced
by `core.sh`.

For detailed information about parameters, return values, and usage examples, refer to the function documentation (shdoc-style
comment blocks) directly above each function in its source file.

---

## _constants.sh

Defines ANSI escape codes, emojis/glyphs, and vm2-wide constants (vm2 repository list, NuGet server regex, allowed conventional-
commit types, etc.). Contains no functions, only constant declarations.

---

## core.sh

General-purpose functions sourced by every script. Also wires up the `on_exit`/`on_err` traps.

### on_exit()

EXIT trap handler: reports a non-zero, non-explicit exit, restores `$initial_cwd`, and disables trace mode.

### on_err()

ERR trap handler: reports the failing command, its exit code, and a stack trace.

### add_trap()

Appends a command to the current trap of one or more signals, instead of replacing it as a plain `trap` does (e.g.
adds a cleanup step after `on_exit`). The script's exit code is preserved. On EXIT, it inserts the command before
`report_open_scopes`, which stays last.

### execute()

Executes a command, or (in dry-run mode) prints what would have been executed without running it.

### execute_with_retry()

Executes a command, retrying on failure until it succeeds or a maximum attempt count is reached, with a fixed delay between attempts.

### list_of_files()

Expands a glob pattern (with globstar/nullglob enabled) and returns the matching files as a space-separated list.

### find_files_by_precedence()

Searches a directory for the first of several file name patterns that matches anything (e.g. `*.slnx`, then `*.sln`, then
`*.csproj`) and stores the matching files in the caller's array; skips `.git`, `obj`, `bin`, and `templates`.

---

## _core_state.sh

Common state variables (`$ci`, `$debugger`, quiet/verbose/dry-run/trace modes, `$_ignore`, table format) and the functions that
read, set, and save/restore them.

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

Saves quiet/verbose/dry-run/`$_ignore`/table-format/tracing state into an associative array, for later `restore_state`. For the
shell options, use `begin_scope`/`end_scope`.

### restore_state()

Restores global flag state previously saved by `save_state`, validating it was saved in the same shell/subshell.

### begin_scope()

Opens a shell-option scope: saves the shopt options in `$scope_shell_options` on the scope stack, recording the caller's
call depth, name, location, and process.

### end_scope()

Closes the innermost shell-option scope and restores the saved options; bug-exits when the innermost open scope was opened
by another function, at another call depth, or in another process (a missing `end_scope` or `begin_scope`).

### report_open_scopes()

Reports a bug for every scope the current process left open, and exits with the bug's code; core.sh registers it on EXIT,
and `add_trap` keeps it the last EXIT command, so the scripts' cleanups still run.

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

Looks up an error code and prints its symbolic name (e.g. `$err_not_found`). Exits the process directly, for the same reason as
`error_message`.

---

## _predicates.sh

Boolean test (`is_*`) functions for variable existence/type, numeric formats, OS detection, and basic file/JSON validity.

### is_case_sensitive()

Tests whether shell pattern matching is currently case-sensitive.

### set_case_insensitive() / set_case_sensitive()

Sets the shell's `nocasematch` option off/on.

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

### is_in_i()

Tests if the first argument equals one of the following arguments, case-insensitively.

### is_windows()

Detects if the current OS is Windows (Windows_NT, MINGW, or MSYS).

### is_valid_filename()

Tests if a string is a valid, simple filename (non-empty, no slashes, not `.`/`..`).

### is_valid_path()

Tests if a string is a syntactically valid path, via `pathchk`.

### is_valid_secret_name()

Tests if a string is a valid GitHub secret name: letters, digits, and underscores only, not starting with a digit or with
`GITHUB_` (in any case).

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

## _diagnostics.sh

Logging functions (`error`, `warning`, `info`, `trace`, `bug`), the global error/bug counters, and the
`exit_if_has_errors`/`exit_if_has_bugs` gates.

### to_stdout() / to_stderr() / to_output()

Read lines from stdin and echo them to stdout / stderr / stdout, respectively — overridable abstractions (`gh_core.sh` overrides
them to also write to GitHub Actions step summary/output files).

### has_errors()

Tests whether the global error counter has recorded any errors.

### get_errors()

Prints the current value of the global error counter.

### set_errors()

Sets the global error counter to a specific value.

### reset_errors()

Resets the global error counter to zero.

### exit_if_has_bugs()

Exits the script (via `exit_with_error`) if any bugs were recorded by this function's own call depth or deeper; defers to an
ancestor's still-open validation block otherwise.

### usage()

Forward-declaration placeholder for `usage()`, meant to be overridden by sourcing `_core_args.sh`; always bug-exits if not overridden.

### exit_if_has_errors()

Exits the script (via `usage`, or directly) if any errors were recorded.

### __message()

Internal helper that formats and prints one or more message lines with a severity prefix, optional error-code translation, and
an optional stack dump. Used by `error`/`warning`/`info`/`trace`/`bug`.

### error()

Logs an error message to stderr and increments the global error counter.

### exit_with_error()

Logs an error message and exits immediately with the last recorded error code (or `$failure`).

### with_error()

Records a vm2 error code in the caller's variable and reports the failure with `error`, adding the failed command's exit
status; always returns `$success`. Used as `cmd || with_error rc "$err_…" "…"` in a chain of `(( rc != success )) ||`-guarded
steps.

### bug()

Logs a bug message (caller-contract violation) to stderr and increments the global bug counter.

### exit_with_bug()

Logs a bug message (like `bug`) and exits immediately with the recorded error code (or `$err_has_bugs`).

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

Logs one or more lines under a `## Summary` markdown heading, via `$__summary_output` (glow, if available and not in CI;
otherwise `to_stdout`).

### now_us()

Prints the current time in microseconds since the epoch (from `$EPOCHREALTIME`; Bash 5.0+), for measuring elapsed time.

---

## _core_args.sh

Common command-line argument parsing (`--verbose`, `--quiet`, `--trace`, `--dry-run`, `--graphical`, `--markdown`,
`--help`/`-h`/`-?`) and the default `usage`/`usage_text` implementation.

### get_common_arg()

Processes one common command-line argument/switch; returns `$negative` if the argument is not one of the common ones.

### usage_if_requested()

Exits (via `usage`) if a usage request was previously recorded by `get_common_arg`.

### usage()

Displays an optional error message, the usage text, and exits. Overrides the forward-declaration in `_diagnostics.sh`.

### usage_text()

Default placeholder usage text; meant to be overridden by each top-level script.

---

## _semver.sh

Semantic Versioning (SemVer 2.0.0) and MinVer tag regular expressions, comparison, and validation functions.

### print_semver_regexes()

Dumps the SemVer/MinVer regex constants to stdout, grouped by category, via `dump_vars`.

### validate_minver_tag_components()

Validates a MinVer tag prefix and (optionally) a MinVer prerelease identifier template against their regular expressions.

### get_semver_major() / get_semver_minor() / get_semver_patch() / get_semver_prerelease() / get_semver_build()

Output one component of a SemVer 2.0.0 string to stdout. The prerelease and build components come without their leading
`-`/`+` separator, and are empty when the version has none. Return `$err_argument_value` with no output for an invalid
version.

### compare_semver()

Compares two semantic versions per SemVer 2.0.0, returning `$rc_equal`/`$rc_greater_than`/`$rc_less_than`.

### semver_eq() / semver_gt() / semver_gte() / semver_lt() / semver_lte()

Boolean comparison wrappers around `compare_semver`.

### is_semver()

Tests if a string is a valid SemVer 2.0.0 version.

### is_semver_tag()

Tests if a string is a valid semver tag (with the configured MinVer prefix).

### is_semver_prerelease()

Tests if a string is a valid semver prerelease version.

### is_semver_prerelease_tag()

Tests if a string is a valid semver prerelease tag (with the configured MinVer prefix).

### is_semver_release()

Tests if a string is a valid semver release version (no prerelease identifier).

### is_semver_release_tag()

Tests if a string is a valid semver release tag (with the configured MinVer prefix, no prerelease).

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

Validates and normalizes a JSON array of strings (or a single string) into a deduplicated, trimmed JSON array, optionally
validating each item with a caller-supplied function.

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

## _dump_vars.sh

Formats and prints variable names/values as a graphical or markdown table.

### _write_title()

Internal helper: writes a header title line in the current table format.

### _write_line()

Internal helper: writes a "name: value" line, handling scalars, arrays, associative arrays, functions, and unbound/invalid names.

### dump_vars()

If verbose (or `--force`), dumps a table of named variables with optional headers, secrets masking, and blank/dividing lines;
optionally prompts "press any key" afterward.

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

Plain Git: branch, tag, and commit-SHA name validation, the working tree, and latest-stable-tag helpers. Knows nothing
about GitHub (see `_git_gh.sh`).

### is_valid_branch_name()

Tests if a string is a valid Git branch name (with or without `refs/heads/`), via `git check-ref-format`.

### is_valid_tag_name()

Tests if a string is a valid Git tag name (with or without `refs/tags/`), via `git check-ref-format`; also rejects a
leading `-`, which `git tag` refuses.

### is_valid_commit_sha()

Tests that a string has the format of a commit SHA or an abbreviation of one (4 to 64 hexadecimal digits); it does not check
that the commit exists.

### validate_branch_name()

Validates a Git branch name, via `is_valid_branch_name`.

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

## _git_gh.sh

GitHub: repository naming rules, the GitHub remote URL, the repo state, and the `gh` / `gh api` retry wrappers.

### is_valid_gh_repo_owner() / is_valid_gh_repo_name() / is_valid_gh_repo_full_name() / is_valid_gh_repo_description()

Test a GitHub repository owner / name / full name (`<owner>/<name>`) / description against GitHub's rules.

### validate_gh_repo_owner() / validate_gh_repo_name() / validate_gh_repo_description()

Validate a GitHub repository owner / name / description, reporting an error when invalid.

### execute_gh_with_retry()

Executes a `gh` command with retry logic for transient failures (rate limits, timeouts, etc.).

### execute_gh_api_with_retry()

Executes a `gh api` command with retry logic based on the response's HTTP status (or stderr pattern matching as a fallback).

### get_gh_repo_property()

Prints the value of one property of a GitHub repository (e.g. `default_branch`), from the GitHub API.

### is_repo_state_initialized()

Tests if a repo-state associative array contains every predefined key.

### initialize_repo_state()

Initializes a repo-state associative array: every predefined key, with an empty value.

### get_gh_repo_state()

Fills an initialized repo state with a repository's owner, name, full name, ID, and default branch, from the GitHub API.

### get_repo_state()

Retrieves the repository state for a directory: the working-tree root and the `origin` URL from Git, the owner and name
parsed from a GitHub URL, and optionally the GitHub fields, cross-checked against the full name GitHub reports. Starts
from an empty state, so a reused array keeps nothing from a previous call.

### has_local_repo() / has_remote_repo() / has_github_remote()

Test if a repo-state array has a local Git repo / a remote URL / a remote GitHub repo (repo ID) recorded.

### read_repo_state()

Deserializes a repo state from `key=value` lines on stdin.

### print_repo_state()

Prints a repo state to stdout, one line per predefined key.

---

## _git_vm2.sh

vm2-specific repository resolution: locating `$VM2_REPOS` and individual vm2 repositories.

### get_devops_parent()

Returns (and caches) the parent directory of the vm2.DevOps repository.

### __validate_repo_root()

Internal helper: validates that a named/pathed repository exists, is a Git root with CI configuration, is on the expected branch,
and is at or ahead of its latest stable tag.

### resolve_vm2_repos()

Resolves `$VM2_REPOS` (CLI arg > `$VM2_REPOS` env > vm2.DevOps's own parent > hardcoded default), validating vm2.DevOps and
vm2.Templates under it.

### __search_repo_dir()

Internal helper used by `resolve_repo_root`: searches for a directory by name/relative path under a parent, skipping noise
directories (`.git`, `node_modules`, `bin`, `obj`, etc.).

### resolve_repo_root()

Finds the root of a Git repository (or nearest ancestor with CI configuration) by searching under `$vm2_repos`, falling back to
`$HOME`.

### get_vm2_sot_path()

Resolves the path to the Source-of-Truth shared-content directory inside vm2.Templates.

---

## _xml.sh

Generic XML value reading via `yq`'s XML support. Knows nothing about dotnet, MSBuild, or any other specific XML dialect.

### get_xml_value()

Reads a single element or attribute value out of an XML file by yq path expression (e.g. `.Project.PropertyGroup.IncludeSymbols`,
or `.Project.ItemGroup.PackageReference.+@Version` for an attribute). A literal, single-file read -- does not resolve inherited
values (e.g. from a project's `Directory.Build.props`) the way `get_msbuild_property()` does.

---

## _dotnet_constants.sh

The `dotnet` exit codes with their messages and names, and the keys of the build, build-result, version, and package information
arrays.

### dotnet_error_message()

Prints `Dotnet <name> (<code>): <message>` for a `dotnet` process exit code, falling back to the unknown-code message. `error`'s
`--dotnet-error-code`/`-dec` option uses it.

---

## _dotnet_args.sh

Common dotnet-CLI argument variables (`$configuration`, `$framework`, `$runtime`, `$artifacts`, MinVer settings, NuGet
credentials) and their parsing/sanitization.

### get_common_dotnet_arg()

Processes one common dotnet-related command-line option and its value.

### sanitize_common_dotnet_args()

Validates and freezes (via `readonly`) the common dotnet arguments after parsing; resolves `$artifacts` to a concrete path.

---

## _dotnet_msbuild.sh

MSBuild property helpers, conversion of `dotnet` arguments to `dotnet msbuild` arguments, and extraction and display of build information.

### get_msbuild_property()

Gets the value of a single MSBuild property for a project, via `dotnet msbuild -getProperty`, without building.

### get_msbuild_properties()

Gets the values of two or more MSBuild properties in one call (JSON-shaped result).

### get_target_path()

Gets the full path to the assembly that was/would be produced by `dotnet build` (wraps `get_msbuild_property` for `TargetPath`).

### get_artifacts_path()

Gets the full path to the `ArtifactsPath` directory for a project or solution.

### convert_dotnet_args_to_msbuild_args()

Converts `dotnet <command>` arguments (e.g. `--configuration Release`) to the equivalent `dotnet msbuild` arguments/properties.

### extract_dotnet_build_info()

Parses the output of a `dotnet build` command from stdin and populates an associative array with build/version/result information.

### display_dotnet_build_summary()

Displays a formatted summary table (via `dump_vars`) of build information previously extracted by `extract_dotnet_build_info`.

---

## _dotnet.sh

.NET build/restore/pack/clean orchestration and solution helpers.

### update_nuget_sources_with_github_vm2()

Updates the `github.vm2` NuGet source with credentials (CLI args, or `$GH_ACTOR`/`$GH_TOKEN` in CI).

### dotnet_clean()

Cleans a .NET project or solution using the common dotnet arguments.

### dotnet_restore()

Restores a .NET project's dependencies (`--locked-mode`) using the common dotnet arguments.

### dotnet_build()

Builds a .NET project or solution (no restore) and captures build output information.

### dotnet_pack()

Packs an already-built .NET project (`--no-build`), resolving `Configuration` from the project if not pinned, and returns the
produced package/symbols paths.

### list_solution_projects()

Lists the constituent project paths of a solution file, via `dotnet sln list`.

### expand_solution_projects()

Expands any solution-file entries in a JSON array of project/solution paths into their constituent project paths.

---

## gh_core.sh

GitHub Actions environment integration. Sources `core.sh` and overrides its `to_*` functions to also write to the step-summary/
output files.

### to_stdout() / to_stderr() (overrides)

Send input to stdout/stderr, and (in GitHub Actions) also append to `$GITHUB_STEP_SUMMARY`.

### to_output() (override)

Sends input to stdout, and (in GitHub Actions) also appends to `$GITHUB_OUTPUT`.

### gh_escape()

Escapes a value for safe inclusion in a GitHub Actions workflow command (`::notice::`, etc.), per GitHub's own `%`/CR/LF
escaping rules.

### args_to_github_output()

Outputs a `key=value` pair (kebab-case key) for each named variable to `$GITHUB_OUTPUT`, via `to_output`.

---

## Summary

### Total Functions: 215

| File                 | Functions |
|----------------------|----------:|
| core.sh              |         7 |
| _core_state.sh       |        23 |
| _error_codes.sh      |         2 |
| _predicates.sh       |        32 |
| _diagnostics.sh      |        24 |
| _core_args.sh        |         4 |
| _semver.sh           |        19 |
| _sanitize.sh         |        37 |
| _dump_vars.sh        |         3 |
| _user.sh             |         5 |
| _git.sh              |        11 |
| _git_gh.sh           |        19 |
| _git_vm2.sh          |         6 |
| _xml.sh              |         1 |
| _dotnet_constants.sh |         1 |
| _dotnet_args.sh      |         2 |
| _dotnet_msbuild.sh   |         7 |
| _dotnet.sh           |         7 |
| gh_core.sh           |         5 |

Counts include internal (`__`-prefixed) helper functions that are not part of the public library surface but are still documented
in their source files. The `gh_core.sh` overrides of `to_stdout`/`to_stderr`/`to_output` and the `_core_args.sh` override of
`usage` are counted in both files.

### Usage Pattern

1. Source `core.sh` in your scripts to get all base functionality (it sources every other component file in turn).
2. Source `gh_core.sh` instead of `core.sh` when the script runs in GitHub Actions, to get step-summary/output integration.
3. Individual component files (`_predicates.sh`, `_sanitize.sh`, etc.) can be sourced directly if only a narrow slice of
4. functionality is needed.

### Key Design Principles

- Functions read from stdin and write to stdout/stderr where appropriate, for pipeline composition (`to_stdout`, `to_stderr`,
- `to_output`, `to_summary`, `error`, `warning`, `info`, `trace`).
- Global state is saved/restored cooperatively via `save_state`/`restore_state`, never mutated ad hoc.
- Predicate functions (`is_*`, `has_*`) return `$positive`/`$negative` (0/1); they answer a yes/no question, and "no" is a
- legitimate answer, not a failure.
- Validation (`is_safe_*`, `validate_*`) and other action functions return `$success`/`$failure` or a specific named error code
- (`$err_argument_value`, `$err_tool_error`, etc.) on failure.
- Caller-contract violations (`bug`) hard-exit via `exit_if_has_bugs`; runtime/environmental failures (`error`) accumulate and
- are surfaced via `exit_if_has_errors` at the top-level script only.
