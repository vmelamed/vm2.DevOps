# Script library

All scripts live under `scripts/bash/` and follow a three-file convention:

- the main script
- `*.usage.sh` file that defines help text
- `*.utils.sh` helper that encapsulates argument parsing

They all source `github.sh` (ergo _common.sh) for shared behavior and respect common flags (`--verbose`, `--quiet`, `--trace`, `--dry-run`, `--debugger`, see above).

## `validate-vars.*.sh`

- Validates and normalizes workflow inputs, emitting derived values for downstream jobs in `$GITHUB_OUTPUT`
- Ensures consistent environment variable defaults for the pipeline

## `run-tests.*.sh`

- Runs `dotnet test` with configurable build configuration, preprocessor symbols, and coverage thresholds
- Manages artifacts (`TestArtifacts/Results`, coverage summaries)
- Installs/uninstalls the `dotnet-reportgenerator-globaltool` on demand
- Populates `$GITHUB_STEP_SUMMARY` with coverage outcomes and e
- Exits with a non-zero status when coverage falls below the configured threshold

## `run-benchmarks.*.sh`

- Executes BenchmarkDotNet projects via `dotnet run`
- Exports JSON results and compact summaries (rendered using `jq` and the query `summary.jq`)
- Compares current performance against stored baselines
- Sets `FORCE_NEW_BASELINE` when improvements/regressions exceed significantly the configured tolerances. This causes the `benchmarks.yaml` to upload the results as new baselines.

## `download-artifact.*.sh`

- Downloads artifacts from prior workflow runs using the GitHub REST APIs and `gh` CLI semantics.
- Used by `benchmarks.yaml` to hydrate baseline data before running new benchmarks, but is general-purpose for any artifact retrieval task.

## `_common.sh` and `github.sh`

- Shared utility library that wires in tracing, verbosity, CI-safe defaults, and interactive prompts.
- Implements helpers for argument parsing (`get_common_arg()`), logging (`trace()`, `dump_vars()`), command execution with dry-run support (`execute()`), user prompts (`choose()`, `confirm()`, `press_any_key()`), and numeric/string validation helpers (`is_integer`, `is_in`, etc.).
- Should be sourced by all new scripts to ensure consistent behavior across the automation surface.

## `github.sh`

- Shared utility library that extends `_common.sh` with GitHub-specific helpers and behavior.
- Should be sourced by all new scripts to ensure consistent behavior across the automation surface.

### `_common.sh` and `github.sh` functions and variables (**WIP**)

#### Variables

- `debugger`: If `true`, indicates the script is running under a debugger, e.g. 'gdb'. If specified, the script will not set traps for DEBUG and EXIT (see below), and will set the '--quiet' as user input from stdin interferes with the debugger. (default: `false`)
- `verbose`: If `true`, enables the output from the functions `execute()`, `trace()`, and `dump_vars()` (default: `false`)
- `dry_run`: If `true`, simulates actions without making changes (default: `false`)
- `quiet`: If `true`, suppresses all functions that request input from the user - confirmations - Y/N, choices - 1) 2)..., etc. and will assume some sensible default input. (default: `false`, in CI - `true`)
- `ci`: If `true`, indicates the script is running in a CI environment, as always set by GitHub Actions (default: `false`, or `true` in GitHub Actions)
- `_ignore`: The file to redirect unwanted output to (default: `/dev/null`). When the calling script sets the common flag `--trace`, this is set to `/dev/`stdout`` so that the output from all executed commands are visible.
- `common_switches`: A string that contains documentation of all common switches passed to the calling script's function `get_common_arg()`. For reuse by the calling scripts in their help strings.

#### Functions (**WIP**)

- `on_debug()` and `on_exit()`: bash DEBUG and EXIT trap handlers that remember the last invoked bash command in `$last_command`. Used by `on_exit()` to report the last command when the script exits with an error.
- `set-*` functions are invoked when the script is initializing from external environment variables or common arguments are being applied to the calling script (see `get_common_arg()`).
  - `set_ci()`: when the variable `CI` is `true`, sets the following variables as follows:
    - `ci` to `true`
    - `quiet` to `true`
    - `debugger` to `false`
    - `verbose` to `false`
    - `dry_run` to `false`
    - `_ignore` to `/dev/null`
    - `set +x` - disables bash tracing
  - `set_debugger()`: sets (except when `ci` is `true`):
    - `debugger` to `true`
    - `quiet` to `true`
  - `set_trace_enabled()`: when `true`, sets (except when `ci` is `true`):
    - `verbose` to `true`
    - `_ignore` to `/dev/`stdout``
    - `set -x` enables bash tracing
  - `set_dry_run()`: when `true`, sets (except when `ci` is `true`) `dry_run` to `true`
  - `set_quiet()`: when `true`, sets (except when `ci` is `true`) `quiet` to `true`
  - `set_verbose()`: when `true`, sets `verbose` to `true`. Note that verbose is not disabled in CI, as it is useful when debugging workflows or to see trace output from `execute()`, `trace()`, and `dump_vars()` calls.
- `dump_vars()`: dumps the values of all passed variables to `stdout`. Useful for debugging. Pass the name of the variables you want dumped (without the `$`), e.g. `dump_vars var1 var2`. Also you can pass "flags" between the variable names:
  - `-f` or `--force`: dump the variables even if `verbose` is not `true`. Useful when you want to see variable dumps in quiet mode or in CI.
  - `-h` or `--header` followed by a header string: include a header line before or between the variable dumps
  - `-b` or `--blank`: include a blank line between variable dumps
  - `-l` or `--line`: include a line between variable dumps
- `is_defined()`: returns `0` if the passed variable is defined (not null), `1` otherwise. Usage: `is_defined var_name` (without the `$`).
- `write_line()`: for internal use by `dump_vars()`
- `get_common_arg()`: parses common arguments passed to the calling script and invokes the corresponding `set-*` functions. Usage: `get_common_arg "$@"` (pass all script arguments). Recognizes the following arguments:
  - `--debugger`: calls `set_debugger()` (see above)
  - `--quiet`, `-q`: calls `set_quiet()` (see above)
  - `--verbose`, `-v`: calls `set_verbose()` (see above)
  - `--trace`, `-x`: calls `set_trace_enabled()` (see above)
  - `--dry-run`, `-n`: calls `set_dry_run()` (see above)

  Returns `0` if a common argument was found and processed, `1` otherwise.

- `display_usage_msg()`: suppresses temporarily the bash tracing (if enabled) and displays the passed usage message. Usage: `display_usage_msg "$usage_msg"` (pass the usage message as a single string).
- `trace()`: if `verbose` is `true`, prints the passed message to `stdout`. Usage: `trace "message"`.
- `execute()`: depending on the value of `dry_run`, either executes or just displays what would have been executed. Usage: `execute "command"`. E.g.:
  - `execute sudo apt-get update && sudo apt-get install -y gh jq`
  - `execute mkdir -p "$artifacts_dir"`

  Suggestion: use the execute function to run commands that have no side effects, i.e. do not change the system state, e.g. install/uninstall software, create/delete files or directories, etc.

- `to_lower()` and `to_upper()`: converts the passed string to lower or upper case and outputs the result to `stdout`. Usage: `to_lower "STRING"`. E.g. `lower_str=$(to_lower "$str")`
- `is_*` predicates are useful for arguments validation:
  - `is_integer()`: returns `0` if its parameter represents a valid integer number, `1` otherwise
  - `is_non_positive()`: returns `0` if its parameter represents a valid non-positive, integer number: {..., -3, -2, -1, 0}, `1` otherwise
  - `is_positive()`: returns `0` if its parameter represents a valid positive, integer number (aka natural number): {1, 2, 3, ...}, `1` otherwise
  - `is_non_negative()`: returns `0` if its parameter represents a valid non-negative, integer number: {0, 1, 2, 3, ...}, `1` otherwise
  - `is_negative()`: returns `0` if its parameter represents a valid negative: {..., -3, -2, -1}, `1` otherwise
  - `is_integer()`: returns `0` if its parameter represents a valid integer number (..., -2, -1, 0, 1, 2, ...), `1` otherwise
  - `is_decimal()`: returns `0` if its parameter represents a valid decimal number, `1` otherwise
  - `is_in()`: returns `0` if the first parameter is found in the list of subsequent parameters, `1` otherwise. Usage: `is_in "value" "list_item1" "list_item2" ...`
- `compare_semver()`: compares two semver compliant version strings and returns `0` if the first is equal to the second, `1` if the first is greater, and `255` if the first is smaller. Usage: `compare_semver "1.2.3" "1.2.4"`
- `list_of_files()`: given a file pattern, lists all files as a bash list that match the pattern to `stdout`. Usage: `list_of_files "pattern"`. E.g. `files=$(list_of_files "*.json")`
- User interaction functions:
  - `press_any_key()`: prompts the user to press any key to continue. Usage: `press_any_key "Prompt message"`. If `quiet` is `true`, does nothing and returns   immediately.
  - `confirm()`: prompts the user with a Y/N question and returns `0` if the answer is yes, `1` otherwise. Usage: `if confirm "Are you sure?"; then ...;  fi`.   If `quiet` is `true`, assumes the default answer is yes.
  - `choose()`: prompts the user to choose one of the passed options and returns the selected option to `stdout`. Usage: `choose "Prompt message" "Option 1" "Option 2" ...`. The function automatically displays the options in a numbered list and outputs the user's choice to `stdout`. E.g.:

    ```bash
    choice=$(choose \
                "The benchmark results directory '$artifacts_dir' already exists. What do you want to do?" \
                    "Clobber the directory '$artifacts_dir' with the new contents" \
                    "Move the contents of the directory to '$renamed_artifacts_dir', and continue" \
                    "Delete the contents of the directory, and continue" \
                    "Exit the script") || exit $?
    ```

    If `quiet` is `true`, assumes the first option is selected.

  - `get_credentials()`: prompts the user to enter a username and password, and returns them via predefined variables `username` and `password`. Usage: `get_credentials "Prompt message"`.

    ```bash
    credentials=$(get_credentials "Enter your user ID: " "Enter your password: " "Are these correct?") || exit $?
    username=${credentials%%:*}
    password=${credentials#*:}
    ```

    If `quiet` is `true`, returns ":".

- `scp_retry()`: attempts to SSH copy a file via `scp` up to a specified number of times with a delay between attempts. Usage: `scp_retry "source" "destination" max_attempts delay_seconds`. E.g. `scp_retry "file.txt" "user@host:/path/" 5 10` tries to copy `file.txt` to `user@host:/path/` up to 5 times, waiting 10 seconds between attempts.

- Test functions for building test harnesses:
  - `fail()`: prints the passed message to `stderr` and exits with status `1`. Usage: `fail "Error message"`. E.g. `if ! is_integer "$var"; then fail "The variable 'var' must be an integer"; fi`
  - `assert_eq()`: compares two values and exits with status `1` if they are not equal. Usage: `assert_eq "value1" "value2" "Error message"`. E.g. `assert_eq "$expected" "$actual" "The actual value does not match the expected value"`
  - `assert_true()`: checks if the passed expression is true and exits with status `1` if it is not. Usage: `assert_true "expression" "Error message"`. E.g. `assert_true "$var" "The variable 'var' must be true"; fi`
  - `assert_false()`: checks if the passed expression is false and exits with status `1` if it is not. Usage: `assert_false "expression" "Error message"`. E.g. `assert_false "$var" "The variable 'var' must be false"; fi`
