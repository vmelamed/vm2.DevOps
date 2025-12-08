# DevOps Automation Toolkit

This repository packages reusable GitHub Actions workflows and Bash automation that can be plugged into any .NET solution. All shell entry points sit under `scripts/bash/` and are linted during CI with [ShellCheck](https://www.shellcheck.net/) to keep the scripts portable and robust.

## High-level reusable workflows

These top-level workflows are intended to be called directly via `workflow_call` from dependent repositories. They orchestrate the full CI/CD pipeline, and fan out to lower-level building blocks - reusable workflows and bash scripts as needed. The workflows and scripts share a common input surface to make it easy to toggle behavior across the pipeline:

- Common switches for all bash scripts:
  - `help`: If `true`, scripts will display usage information and exit (default: `false`)
  - `debugger`:  Set when the a script is running under a debugger, e.g. 'gdb'. If specified, the script will not set traps for DEBUG and EXIT, and will set the '--quiet' switch. (default: `false`)
  - `dry-run`: If `true`, scripts will simulate actions without making changes (default: `false`)
  - `quiet`: If `true`, scripts will suppress all functions that request input from the user - confirmations - Y/N, choices - 1) 2)..., etc. and will assume some sensible default input. (default: `false`, in CI - `true`)
  - `verbose`: If `true`, scripts will emit tracing and messages from all `trace()` calls, all executed commands, and all variable dumps (default: `false`)
- Switches and options for the CI workflows and bash scripts:
  - `target-os`: Operating systems to run the jobs on (default: `ubuntu-latest`)
  - `dotnet-version`: .NET SDK version to install (default: `10.0.x`)
  - `configuration`: Build configuration (default: `Release`)
  - `preprocessor-symbols`: Optional preprocessor symbols to pass to `dotnet build` (e.g. SHORT_RUN for benchmarks) (default: empty)
  - `test-project`: Relative path to the test project to execute (default: `tests/UnitTests/UnitTests.csproj`)
  - `min-coverage-pct`: Minimum acceptable line coverage percentage (default: `80`)
  - `run-benchmarks`: Whether to run benchmarks as part of the CI (default: `true`)
  - `benchmark-project`: Relative path to the benchmark project to execute (default: `benchmarks/Benchmarks/Benchmarks.csproj`)
  - `force-new-baseline`: Ignore the current baseline and make the current benchmark results the new baseline (default: `false`)
  - `max-regression-pct`: Maximum acceptable regression percentage (default: `10`)

### `.github/workflows/ci.yaml`

- Orchestrates the full pipeline:
  1. Build
  1. Test
  1. Run benchmark tests
- Normalizes all incoming inputs (target OS, .NET SDK, configuration, defined symbols, etc.) through `setup-ci-vars.sh` (see the list of parameters above).
- Fans out to the lower-level reusable workflows (`build.yaml`, `test.yaml`, `benchmarks.yaml`).
- Uploads/Downloads artifacts from/to artifact directories (`TestArtifacts`, `BmArtifacts`) so downstream jobs and scripts stay in sync, compare with previous versions (esp. for benchmarks), track progress of non-functional changes (e.g. test coverage and performance benchmarks), etc. history.

### `.github/workflows/Prerelease.yaml`

- Triggers on pushes to `main` or manual dispatches to `main`.
- Computes semantic prerelease tags (`vX.Y.(Z+1)-<prefix>.<YYYYMMDD>.<run>`) using MinVer conventions,
- Pushes the tag
- Packs with `dotnet pack`, and publishes to NuGet as a prerelease
- Runs the CI workflow again with all default parameters (see above) to ensure the code is in a good state before packing
- Accepts switches for
  - prerelease tag prefix (e.g. `preview`, `beta`, `alpha`)
  - customizing the prerelease label
  - optionally uploading the produced `.nupkg` files as workflow artifacts for later inspection.
  - forcing publication

### `.github/workflows/Release.yaml`

- Ships stable releases off of `v*` tags - `^v[0-9]+(\.[0-9]+)(\.[0-9]+)(\.[0-9]+)$` (e.g. `v2.1.3`) or manual dispatches.
- Runs a `Release` pack
- Pushes packages to NuGet
- Shares the same input surface as the prerelease workflow, making it easy to toggle behavior between prerelease and stable channels.

## Composable workflow building blocks

These workflows are included by the high-level orchestrators, but can also be consumed individually if you only need part of the pipeline. E.g. all scripts are designed to be reusable and callable either from a workflow or directly from the command line. E.g. you can call `run-tests.sh` from your own workflow if you want to run tests with coverage but don't need the full CI.

### `.github/workflows/build.yaml`

- Checks out the repository
- Installs the requested .NET SDK
- Runs `dotnet build` with optional preprocessor symbols
- Makes all scripts under `scripts/bash/` executable (`chmod +x`)
- Runs ShellCheck (`ludeeus/action-shellcheck`) across `scripts/bash/`
- Populates `$GITHUB_STEP_SUMMARY` with build results

### `.github/workflows/test.yaml`

- Provisions the .NET SDK
- Calls `scripts/bash/run-tests.sh` to execute a specified test project with coverage collection
- Publishes the resulting `TestArtifacts` directory (coverage reports, logs) as an artifact for future inspections
- Populates `$GITHUB_STEP_SUMMARY` with coverage results, and fails the job if coverage is below the configured threshold

### `.github/workflows/benchmarks.yaml`

- Restores baseline benchmark summaries (if available) via `download-artifact.sh`
- Executes `scripts/bash/run-benchmarks.sh`
- Analyses the results and compares to the baseline (results from previous runs)
- Enforces regression thresholds
- Always publishes the latest benchmark summaries
- Optionally pushes a refreshed baseline when large improvements are observed
- When large regressions are detected, the job fails and the summary contains guidance on how to proceed, possibly by forcing a new baseline

## Script library (lowest layer)

All scripts live under `scripts/bash/` and follow a three-file convention:

- the main script
- `*.usage.sh` file that defines help text
- `*.utils.sh` helper that encapsulates argument parsing

They all source `_common.sh` for shared behavior and respect common flags (`--verbose`, `--quiet`, `--trace`, `--dry-run`, `--debugger`, see above).

### `setup-ci-vars.*.sh`

- Validates and normalizes workflow inputs, emitting derived values for downstream jobs in `$GITHUB_OUTPUT`
- Ensures consistent environment variable defaults for the pipeline

### `run-tests.*.sh`

- Runs `dotnet test` with configurable build configuration, preprocessor symbols, and coverage thresholds
- Manages artifacts (`TestArtifacts/Results`, coverage summaries)
- Installs/uninstalls the `dotnet-reportgenerator-globaltool` on demand
- Populates `$GITHUB_STEP_SUMMARY` with coverage outcomes and e
- Exits with a non-zero status when coverage falls below the configured threshold

### `run-benchmarks.*.sh`

- Executes BenchmarkDotNet projects via `dotnet run`
- Exports JSON results and compact summaries (rendered using `jq` and the query `summary.jq`)
- Compares current performance against stored baselines
- Sets `FORCE_NEW_BASELINE` when improvements/regressions exceed significantly the configured tolerances. This causes the `benchmarks.yaml` to upload the results as new baselines.

### `download-artifact.*.sh`

- Downloads artifacts from prior workflow runs using the GitHub REST APIs and `gh` CLI semantics.
- Used by `benchmarks.yaml` to hydrate baseline data before running new benchmarks, but is general-purpose for any artifact retrieval task.

### `_common.sh`

- Shared utility library that wires in tracing, verbosity, CI-safe defaults, and interactive prompts.
- Implements helpers for argument parsing (`get_common_arg()`), logging (`trace()`, `dump_vars()`), command execution with dry-run support (`execute()`), user prompts (`choose()`, `confirm()`, `press_any_key()`), and numeric/string validation helpers (`is_integer`, `is_in`, etc.).
- Should be sourced by all new scripts to ensure consistent behavior across the automation surface.

#### `_common.sh` functions and variables

##### Variables

- `debugger`: If `true`, indicates the script is running under a debugger, e.g. 'gdb'. If specified, the script will not set traps for DEBUG and EXIT (see below), and will set the '--quiet' as user input from stdin interferes with the debugger. (default: `false`)
- `verbose`: If `true`, enables the output from the functions `execute()`, `trace()`, and `dump_vars()` (default: `false`)
- `dry_run`: If `true`, simulates actions without making changes (default: `false`)
- `quiet`: If `true`, suppresses all functions that request input from the user - confirmations - Y/N, choices - 1) 2)..., etc. and will assume some sensible default input. (default: `false`, in CI - `true`)
- `ci`: If `true`, indicates the script is running in a CI environment, as always set by GitHub Actions (default: `false`, or `true` in GitHub Actions)
- `_ignore`: The file to redirect unwanted output to (default: `/dev/null`). When the calling script sets the common flag `--trace`, this is set to `/dev/`stdout`` so that the output from all executed commands are visible.
- `common_switches`: A string that contains documentation of all common switches passed to the calling script's function `get_common_arg()`. For reuse by the calling scripts in their help strings.

##### Functions

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

## Additional notes

- All workflows assume .NET 10.0.x SDKs; update the workflow inputs if you need to target a different version.
- Scripts rely on `bash` and standard GNU utilities available on Ubuntu GitHub-hosted runners. Any additional tooling they need (e.g., `jq`, `reportgenerator`) is installed on demand.
- When adding new scripts, follow the existing three-file pattern and keep code ShellCheck-clean so the shared lint step continues to pass.
