# CLAUDE.md

@~/.claude/CLAUDE.md
@~/repos/vm2/CLAUDE.md
@.github/CONVENTIONS.md

Additional references:

@docs/ARCHITECTURE.md
@docs/WORKFLOWS_REFERENCE.md
@docs/GIT_PLAYBOOK.md
@docs/RELEASE_PROCESS.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

<!-- TOC tocDepth:2..6 chapterDepth:2..6 -->

- [CLAUDE.md](#claudemd)
  - [Project Context](#project-context)
  - [What This Repository Is](#what-this-repository-is)
  - [Architecture](#architecture)
  - [Key Directories](#key-directories)
  - [Common Local Commands](#common-local-commands)
  - [Script Base Filenames Convention: `<action>-<target>`](#script-base-filenames-convention-action-target)
  - [Three-File Script Convention](#three-file-script-convention)
  - [Bash Library](#bash-library)
    - [Input parameters](#input-parameters)
    - [Parameter Conventions](#parameter-conventions)
    - [Parameter and Precondition Validation Patterns](#parameter-and-precondition-validation-patterns)
      - [Start Every Function with a **Formal** Parameter Validation Checks](#start-every-function-with-a-formal-parameter-validation-checks)
      - [Follow the Formal Checks with **Runtime** Checks](#follow-the-formal-checks-with-runtime-checks)
    - [Returning Values from Functions](#returning-values-from-functions)
    - [Function Types](#function-types)
      - [Predicates](#predicates)
      - [Validation Functions](#validation-functions)
      - [Functions Forwarding `stdin`](#functions-forwarding-stdin)
      - [Functions Returning Values in `stdout`](#functions-returning-values-in-stdout)
      - [Functions Modifying Variables](#functions-modifying-variables)
  - [Shared File Sync](#shared-file-sync)
  - [Documentation Reference](#documentation-reference)

<!-- /TOC -->

## Project Context

Val is currently the only developer on this project. There is no team. This affects prioritization (correctness still matters; urgency and process overhead do not).

## What This Repository Is

vm2.DevOps is the shared CI/CD automation framework for all vm2 .NET packages. It provides:

- **Reusable GitHub Actions workflows** — consumed by every vm2 package repo
- **Bash script library** — 67 functions in `scripts/bash/lib/`, sourced by CI scripts and local utilities
- **CI/CD action scripts** — in `.github/scripts/`, each following the three-file convention

Consumer repos use workflow templates from `vm2.Templates`. The reusable workflows and the scripts they call live here.

## Architecture

```text
Top-level Workflows      Reusable Workflows                  Bash Scripts                     Bash Library
vm2.*                    vm2.DevOps/.github/workflows        vm2.DevOps/.github/scripts/      vm2.DevOps/scripts/bash/lib/

═══════════════════════► ══════════════════════════════════► ═══════════════════════════════► ════════════════════════════

CI.yaml ───────┬───────► actions/gather-inputs/action.yaml
               └───────► _ci.yaml ─┬───────────────────────► validate-commits.sh ───────────►
                                   ├───────────────────────► validate-inputs.sh ────────────►
                                   ├──► _build.yaml ───────► build.sh ──────────────────────►
                                   ├──► _test.yaml ────────► run-tests.sh ──────────────────►
                                   ├──► _benchmarks.yaml ──► run-benchmarks.sh ─────────────►
                                   └──► _pack.yaml ────────► pack.sh ───────────────────────►

Prerelease.yaml ───────► _prerelease.yaml ───────────────┬─► compute-prerelease-version.sh ─►
                                                         ├─► changelog-and-tag.sh ──────────►
                                                         └─► publish-package.sh ────────────►

Release.yaml ──────────► _release.yaml ──────────────────┬─► compute-release-version.sh ────►
                                                         ├─► changelog-and-tag.sh ──────────►
                                                         └─► publish-package.sh ────────────►

```

See `docs/ARCHITECTURE.md` for the full design and `docs/WORKFLOWS_REFERENCE.md` for workflow inputs/outputs.

## Key Directories

| Path                   | Contents                                                             |
|------------------------|----------------------------------------------------------------------|
| `.github/workflows/`   | Reusable workflows (`_ci.yaml`, `_build.yaml`, `_test.yaml`, etc.)   |
| `.github/scripts/`     | CI/CD action scripts (three-file convention — see below)             |
| `.github/actions/`     | Custom composite actions (`setup-env`, `cache-dependencies`, etc.)   |
| `scripts/bash/lib/`    | Shared bash library (`_diagnostics.sh`, `_git.sh`, `_args.sh`, etc.) |
| `scripts/bash/src/`    | Local dev utility scripts (`diff-shared.sh`, `setup-repo.sh`, etc.)  |
| `docs/`                | Reference documentation (15 `.md` files)                             |

## Common Local Commands

```bash
# Sync shared files from vm2.Templates canonical source
./scripts/bash/src/diff-shared.sh

# Audit and initialize repository configuration
./scripts/bash/src/setup-repo.sh

# Create a PR with vm2 conventions
./scripts/bash/src/create-pr.sh
```

ShellCheck runs live in VSCode via the ShellCheck extension — do not run it from the CLI.

## Script Base Filenames Convention: `<action>-<target>`

The first part of the script (`script`) should follow the convention &lt;action&gt;-&lt;target&gt; (or &lt;verb&gt;-&lt;noun&gt;), where `<action>` is the main action the script performs and `<target>` describes the subject or context of the action. For example, `setup-repo*.sh` for a script that sets up the repository; or `diff-shared*.sh` for the script that compares files with shared content between the canonical source and the local repository.

## Three-File Script Convention

For minimizing the visual clutter and improve maintainability, the top-level, executable scripts SHOULD consist of at least three files:

- `action-target.args.sh`: argument parser — defines the script's calling syntax and maps CLI arguments to script variables.
  Here you implement the logic to:
  - parse the script specific command-line options and arguments
  - parse common CLI options like `--verbose` and `--quiet`
  - parse common CI arguments like `--configuration` and `--artifacts-path`
  - implement `--help` functionality
  - implement input dump functionality for debugging and verification purposes
- `action-target.usage.sh`: here you define:
  - script-specific help text
  - reuse the common help and common CI texts
  - implement usage display functionality, including short and long forms
- `action-target.sh`: the main executable:
  - verifies the environment
  - implements the overriding hierarchy for argument values (CLI > environment > defaults)
  - validates and normalizes arguments
  - implements the business logic and calls script's or library business functions

New scripts should follow the pattern: `*.usage.sh` and `*.args.sh` and SHOULD implement the boilerplate code for input and help text. If scripts will run in CI, as well as standalone, source `gh_core.sh` instead of `core.sh` at the top for GitHub Actions integration.

## Bash Library

All core library files live in `scripts/bash/lib/` and are sourced by scripts that need them:

| File              | Purpose                                                          |
|-------------------|------------------------------------------------------------------|
| `gh_core.sh`      | GitHub Actions environment integration (sources core.sh)         |
| `core.sh`         | Initialization, trap handlers                                    |
| `_constants.sh`   | ANSI color codes and a few other constants                       |
| `_core_state.sh`  | Common state variables (quiet, verbose, dry-run, trace modes)    |
| `_error_codes.sh` | Error code constants                                             |
| `_diagnostics.sh` | Logging (`to_stdout`, `error`, `warning`, `trace`, etc.)         |
| `_args.sh`        | Common argument parsing to initialize core state                 |
| `_predicates.sh`  | Boolean checks (`is_array`, `is_positive`, etc.)                 |
| `_semver.sh`      | Semantic versioning utilities                                    |
| `_sanitize.sh`    | Input validation (`is_safe_path`, `is_safe_configuration`, etc.) |
| `_dump_vars.sh`   | Dumps the values of bash variables in a tabular format           |
| `_user.sh`        | User interface primitives                                        |
| `_git.sh`         | Git operations                                                   |
| `_git_vm2.sh`     | Git operations with focus on vm2 repos                           |
| `_dotnet_args.sh` | Manages the output of `dotnet build` command                     |
| `_dotnet.sh`      | Manages the output of `dotnet build` commands                    |

See `scripts/bash/lib/FUNCTIONS_REFERENCE.md` for the full function inventory.

### Input parameters

Bash has a limited mechanism for passing input parameters to functions. Parameters are passed by position and are accessible within the function using the special variables `$1`, `$2`, ..., `$N` for the first, second, ..., N-th argument, and `$#` for the total number of arguments. This is not enough especially when it comes to sensitive areas like CI/CD pipelines, where more robust and secure handling of input parameters is often required. Also, for a general purpose library like the one provided by vm2.DevOps, it is important to have a consistent and reliable way to handle input parameters across all functions.

### Parameter Conventions

Functions that accept variadic input (variable-length parameter lists) MUST place the variadic input at the end of the
parameter list. It is acceptable the variadic input to include option flags as ordinary arguments, e.g., `"-h"` or
`"--header"`, to signal the presence of a specific behavior, mode, special treatment of the following parameter(s) - turning them into "named arguments", etc.

Nameref **output** parameters SHOULD be placed after all input parameters. If the function accepts variadic input, place the output nameref parameters immediately before the variable-length list. Exceptions would be OK for the sake of readability and maintainability.

Input nameref parameters (for indexed or associative arrays) can be placed anywhere among the input parameters, but they SHOULD precede any output nameref parameters.

Typed optional positional parameters in the middle are acceptable for small, internal Bash APIs when the type boundary is genuinely unambiguous, e.g. optional boolean parameter before integer (all digits) parameter. Use named options when the interface is public, complex, or expected to grow.

### Parameter and Precondition Validation Patterns

For **maintainability**'s sake, Bash functions that validate their own call arguments (`$#`, `$1`, `$2`, etc.) SHOULD follow an
**accumulate-then-exit** shape, not an exit-on-first-failure pattern. This way, as many as possible argument validation errors
are collected and reported together, providing a comprehensive view of all programming issues at once in this part of the
calling script. Validation errors are not considered runtime errors; they indicate problems in the calling code that need to be
fixed, therefore the function should exit after reporting all validation errors. This also separates programming code errors
(bugs) from runtime errors and helps maintain clear boundaries between argument validation and the actual function logic.

```bash
function foo()
{
    (( $# == <N> )) ||
        bug -sd 3 -ec "$err_invalid_arguments" "${FUNCNAME[0]}() requires exactly <N> arguments (provided $#):" \
                                               "  - <arg1 description>" \
                                               "  - <arg2 description>" \
                                               "  - ... "

    # if $1 is missing it is already reported by the argument count check, otherwise we validate its value
    [[ ! -v 1 || $1 =~ <regex> ]] ||
        bug -ec "$err_specific_code_1" -sd 3 "${FUNCNAME[0]}() argument 1 MUST ... (provided ${1:-<none>})"
    # if $1 is missing it is already reported by the argument count check, otherwise we validate its value
    [[ ! -v 2 ]] || is_boolean $2 ||
        bug -ec "$err_specific_code_2" -sd 3 "${FUNCNAME[0]}() argument 2 MUST ... (provided ${2:-<none>})"

    exit_if_has_bugs

    # business logic follows
    local -i _rc="$success"
}
```

#### Start Every Function with a **Formal** Parameter Validation Checks

These types of errors are not recoverable and indicate a programming mistake. Accumulate all validation errors and exit the script immediately with `exit_if_has_bugs`.

- Use the `bug` function to report the calling script programming errors, e.g. the caller passed an invalid number of arguments,
  or invalid argument types (e.g. "not boolean" or "not integer" or "bad syntax")
  - `bug` should be used consistently for all argument validation failures, that clearly indicate violations of the calling
    contract. In other words `bug` MUST indicate that the calling script was written incorrectly
  - Every invocation of `bug` is recorded in a global counter that contributes to the final decision made by
    `exit_if_has_bugs`
- The first validity test MUST be for a valid number of arguments (using `(( $# == <N> ))`)
- Each subsequent test MUST probe the existence of the respective argument with `[[ ! -v N ]] || is_... $<N>`, because
  a positional parameter may not be present and that fact was already reported in the first test (do not compound the
  reporting)
- Perform as many formal tests as possible and finish with `exit_if_has_bugs`: this will report to the caller all script
  errors. Avoid compounding of bugs, e.g. checking for the existence of an argument after already reporting it as missing

#### Follow the Formal Checks with **Runtime** Checks

These types of errors are typically caused by user input or environmental conditions rather than programming mistakes. They may be recoverable or according to the function contract, indicate conditions that need to be handled differently.

- Follow the formal parameter validation block with runtime checks that use `error` to report issues that are not programming
  mistakes but rather user input or environmental problems
- Report and accumulate all runtime errors using the `error` function
- `error` has its own global counter and contributes to the final decision made by `exit_if_has_errors`
- Since some runtime errors can be recovered from or a non-zero error code may not be reporting a failure but a condition that
  should be treated differently, depending on the context. In those cases, use the other global error count functions: `has_errors`, `get_errors`, `set_errors`, and `reset_errors` to control the error handling flow.

Because of the difference in the targeted audience for `bug` and `error` messages, `exit_if_has_bugs` just displays a summary
message, whereas `exit_if_has_errors` displays a summary message *and* a short usage text. The usage text can be suppressed with an optional parameter: `exit_if_has_errors false`

If possible and safe, use the value of the failed argument in the error message for easier debugging, e.g.:

  ```bash
  error -sd 3 -ec "$err_specific_code_2" "${FUNCNAME[0]}() argument <N> MUST <condition description> (provided ${1:-<none>})"
  ```

Functions that interleave positional-argument parsing with validation (`shift`-based, e.g. `execute_with_retry` in
`core.sh`, `enter_value` in `_user.sh`) may need **multiple** accumulate-then-gate blocks in sequence — one per
"phase" of argument consumption — since a later check's meaning can depend on an earlier `shift` having already
happened.

### Returning Values from Functions

Bash functions have **only one** formal return channel: the exit status. They can communicate additional results through:
`stdout`, caller's variables modified through namerefs, or shared global state. These mechanisms have different scoping, buffering, and error-propagation behavior, especially when command substitution and other piping mechanisms are involved.

- **Exit status**: All functions return an integer exit status using explicitly the `return` command or implicitly return the
  status of the last executed command. By convention, `0` indicates success, and any non-zero value indicates an error. This is
  a good choice for:
  - functions that perform an action (have side effects) and need to only signal success or failure to the caller
  - predicate functions that answer yes/no to some question, e.g., `is_integer`, `is_defined_associative_array`, etc. The
    predicates should return `$positive=0` for **"yes"** or `$negative=1` for **"no"**.

- **Output**: A function can print a value to the standard output `stdout`, which can then be captured by the caller using some
  piping mechanism like command substitution, e.g., `output_value="$(my_function)"`. Use this method when your function does
  not have side effects that modify the state of the calling script, like global variables.

  For example, the function `error` in `_diagnostics.sh` increments the global error counter `__errors`, which is tested by
  `exit_if_has_errors`. However, `$(...)` is executed in a subshell, so **no** changes to global variables within the command substitution will affect the caller's environment, e.g., in this case the global counter `__errors` would not be updated at
  all. Therefore, this code will **not** have the desired effect:

  ```bash
  # (( __errors == 0 )) == true
  output_value="$(my_function)"
  # my_function runs in a subshell with environment copied from the parent shell.
  # Suppose my_function fails and reports the failure by calling the function error().
  # error increments the global counter __errors (in the subshell).
  # exit the subshell BUT in the calling shell the global counter __errors remains unchanged:
  # (( __errors == 0 )) == true
  exit_if_has_errors # will never exit
  ```

  Command substitution can preserve two separate results:
  - the function's standard output - `stdout` - can be captured as data, and
  - the exit status can be captured in the calling script

  However, variable mutations made inside the command substitution, including changes to the global error counter, are lost and
  only the exit code is captured: `output_value="$(my_function)" || _rc=$?`. This corrects the previous script example by capturing both the output and the exit status explicitly:

  ```bash
  output_value="$(my_function)" || {
      _command_rc=$?;
      error "'my_function' failed with exit code $_command_rc"
  }
  exit_if_has_errors
  ```

  Pipelines are often preferable for transforming or capturing output from **external** commands because those commands
  communicate only through their streams rather than through shared shell variables. The command substitution still runs in a
  subshell, so shell-variable side effects remain unavailable to the caller. Also, without `set -o pipefail`, the pipeline
  status is normally the status of its last command.

  ```bash
  _remote_stable_tag=$(
      git -C "$_dir" ls-remote --tags --refs origin 2>"$_ignore" |
      awk '{print $2}' |
      sed 's#refs/tags/##' |
      grep -E "$semverTagReleaseRegex" |
      sort -V |
      tail -n1
  ) || _rc=$?

  ```

- **Nameref**(s): A function can use *nameref*s (name references) to indirectly set a variable in the caller's scope. This
  allows the function to effectively return a value by modifying the variable whose name is passed as an argument. Use a
  syntax like this: `declare -n _var="$1"`, or  `local -n _var="$1"`, to create a nameref - an alias for another shell
  variable. This method is preferable over the previous "output via stdout" method, because it:
  - does not hide the side effects
  - avoids the need for command substitution (or other piping mechanisms)
  - is generally more efficient and reliable

  Here is the previous example rewritten to use a nameref, instead of command substitution. The function's contract is to pass
  the name of a variable as the argument. On return from the function, that variable will contain the result:

  ```bash
  my_function() {
      (( $# == 1 )) ||
            bug -ec $err_invalid_nameref "${FUNCTION[0]}() expects exactly 1 argument"
      # properly validate the parameter as a defined variable within a param validation pattern - see above
      [[ ! -v "$1" ]] ||
            is_defined_variable "$1" ||
            bug -ec $err_invalid_nameref "${FUNCTION[0]}() expects argument 1 to be a name of a defined variable"

      exit_if_has_bugs

      local -n _output="$1"

      # perform some operations
      if ! some_command; then
          error "'some_command' failed"
          return $failure
      fi

      _output="result"
  }

  output_value=''
  my_function output_value
  exit_if_has_errors
  ```

- **Global variables**: A function can modify global variables that can be accessed by the caller. This is less preferred due to the implicit side effects and reduced clarity, but it is sometimes used for modifying global script settings (e.g. `set_verbose` or `set_errors`) or for returning complex data structures and/or multiple values.

### Function Types

#### Predicates

Predicate functions return a value that can be considered boolean: 0 - `$positive` or `$success` for boolean **true**, and non-zero - `$negative` (defined as 1), or `$failure`, or any other non-zero value (`$err_*`) for boolean **false** and are
typically named with an `is_`, `is_valid_` or `has_` prefix, e.g., `is_defined_array`, `is_positive`, and `has_errors`.

The predicates may fail for reasons other than the conditions they are checking, e.g. invalid input parameters or unexpected system state. In this case they also will display an appropriate error message.

#### Validation Functions

Validation functions check the correctness of their input parameters. When invalid, or incorrect, or unsafe input is discovered
they typically **display one or more error messages** explaining the validation failure(s), return a non-zero error code or
`$positive` - 0 for **true**, for success. The names of these functions are typically prefixed with `is_safe_` or `validate_`. Examples include `is_safe_reason`, `validate_preprocessor_symbols`, and `is_safe_json_array`. The `validate_*` functions may also normalize their input or transform it into a canonical form.

#### Functions Forwarding `stdin`

These functions are reading input from `stdin` and outputting it to one or more output streams depending on the environment, options, or internal logic. Examples include `to_traceout`, `to_output`, `to_summary`, `to_stdout`, and `to_stderr`. E.g. `to_stdout` reads from `stdin` and writes to the standard output AND to a variable `github_step_summary` which has value equal to `$GITHUB_STEP_SUMMARY` in GitHub Actions, or `/dev/null` on the local machine. `to_output` reads from `stdin` and writes to the standard output AND to a variable `github_output` which has value equal to `$GITHUB_OUTPUT` in GitHub Actions, or `/dev/null` on the local machine, etc. For more information see the [ARCHITECTURE document](docs/ARCHITECTURE.md)

#### Functions Returning Values in `stdout`

These functions return their non-boolean results through `stdout` rather than using the `$positive`/`$negative` convention.
Examples include `trim`, `get_table_format`, `get_directory_build_props`. These functions are typically used when the primary
purpose is to compute and return a value rather than to indicate success or failure. The return value SHOULD be captured by the
caller using command substitution or other `stdout` redirection mechanisms. In these cases **the functions run in a subshell and
any side effects within the function will not affect the calling context.**

#### Functions Modifying Variables

These functions modify the values of input variables passed by name reference. They typically do not return a value through `stdout` and may instead use exit codes to indicate success or failure. Examples include `warning_var`, `trim_var`, and `resolve_repo_root`. The caller should be aware that these functions can have **side effects that persist beyond the function's
scope**. There is no naming convention for such functions but they should be clearly documented to indicate their side effects. In many cases the functions modifying variables are more efficient and reliable than functions that return values through
`stdout`.

## Shared File Sync

Files that are canonical in `vm2.Templates` (`.editorconfig`, `.github/CONVENTIONS.md`, `Directory.Build.props`, etc.) are synced here via `diff-shared.sh`. The mapping is in `scripts/bash/diff-shared.config.json`.

**Do not edit synced files directly** without also updating the canonical source in `vm2.Templates`.

## Documentation Reference

| File                                    | Covers                                           |
|-----------------------------------------|--------------------------------------------------|
| `docs/CONSUMER_GUIDE.md`                | Integrating vm2.DevOps into a consumer repo      |
| `docs/ARCHITECTURE.md`                  | Detailed workflow and script design              |
| `docs/WORKFLOWS_REFERENCE.md`           | All reusable workflows: inputs, outputs, secrets |
| `docs/SCRIPTS_REFERENCE.md`             | CI/CD scripts: args and behavior                 |
| `docs/CONFIGURATION.md`                 | Required repository variables and secrets        |
| `docs/RELEASE_PROCESS.md`               | MinVer versioning, prerelease and stable flows   |
| `docs/DEVELOPER_WORKFLOW.md`            | Conventional Commits, PR process                 |
| `docs/GIT_PLAYBOOK.md`                  | Rebase-first workflow and git operations         |
| `docs/ERROR_RECOVERY.md`                | Failure scenarios and recovery runbooks          |
| `docs/diff-shared.md`                   | Documents the features and file formats of the shared file contents sync mechanism |
| `docs/GITHUB_ACTIONS_CHEATSHEET.md`     | Short reference for GitHub Actions usage and best practices |
| `docs/HARDENING.md`                     | Security hardening guidelines for the repository |
| `docs/TOOLS.md`                         | Reference for tools used in the repository/CI-CD pipelines |
