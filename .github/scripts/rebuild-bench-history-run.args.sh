# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -x script_name

# vm2 core lib exit codes
declare -x success
declare -x err_argument_value
declare -x err_missing_argument
declare -x err_too_many_arguments
declare -x err_unknown_argument
declare -x err_logic_error
declare -x err_tool_not_found

# vm2 core lib constants

# vm2 core lib defaults
declare -x default_minver_tag_prefix

# vm2 core lib variables
declare -x ci
declare -x dump_common_dotnet_args
declare -x u_letters_set
declare -x l_letters_set
declare -x letters_set
declare -x nz_digits_set
declare -x digits_set

# vm2 core lib variables - dotnet
declare -x preprocessor_symbols=${PREPROCESSOR_SYMBOLS:-}
declare -x minver_tag_prefix=${MINVERTAGPREFIX:-"$default_minver_tag_prefix"}
declare -x minver_prerelease_id=${MINVERDEFAULTPRERELEASEIDENTIFIERS:-}
declare -x artifacts

# this scripts constants
declare -xri default_repeat=10
declare -xr default_bencher_branch="main"
declare -xr default_bencher_adapter="c_sharp_dot_net"

# this scripts arguments
declare -x repeat=${REPEAT:-$default_repeat}
declare -x bencher_project=${BENCHER_PROJECT:-}
declare -x bencher_testbed=${BENCHER_TESTBED:-}
declare -x bencher_branch=${BENCHER_BRANCH:-$default_bencher_branch}
declare -x bencher_adapter=${BENCHER_ADAPTER:-$default_bencher_adapter}
declare -xa benchmark_projects=()

declare benchmark_project=${BENCHMARK_PROJECT:-}

function get_arguments()
{
    parse_arguments "$@"
    usage_if_requested
    verify_environment
    resolve_arguments
    exit_if_has_errors
    dump_args
}

function parse_arguments()
{
    local _option
    local _positional_arg_set=false

    while (( $# > 0 )); do
        _option="$1"; shift
        get_common_arg "$_option" && continue

        case "${_option,,}" in
            --repeat|-n )
                (( $# >= 1 ))                                                   || usage "$err_missing_argument" "Missing value for ${_option,,}"
                repeat="$1"; shift
                ;;

            --define|-d )
                (( $# >= 1 ))                                                   || usage "$err_missing_argument" "Missing value for ${_option,,}"
                preprocessor_symbols="$1"; shift
                ;;

            --minver-tag-prefix|-mp )
                (( $# >= 1 ))                                                   || usage "$err_missing_argument" "Missing value for ${_option,,}"
                minver_tag_prefix="$1"; shift
                ;;

            --minver-prerelease-id|-mi )
                (( $# >= 1 ))                                                   || usage "$err_missing_argument" "Missing value for ${_option,,}"
                minver_prerelease_id="$1"; shift
                ;;

            --bencher-project|-bp )
                (( $# >= 1 ))                                                   || usage "$err_missing_argument" "Missing value for ${_option,,}"
                bencher_project="$1"; shift
                ;;

            --bencher-testbed|-tb )
                (( $# >= 1 ))                                                   || usage "$err_missing_argument" "Missing value for ${_option,,}"
                bencher_testbed="$1"; shift
                ;;

            --bencher-branch|-br )
                (( $# >= 1 ))                                                   || usage "$err_missing_argument" "Missing value for ${_option,,}"
                bencher_branch="$1"; shift
                ;;

            --bencher-adapter|-ad )
                (( $# >= 1 ))                                                   || usage "$err_missing_argument" "Missing value for ${_option,,}"
                bencher_adapter="$1"; shift
                ;;

            # reserved: the options get_common_arg consumes before this case. This arm never runs: it lets ShellCheck
            # (SC2221/SC2222) flag any script-specific arm that reuses one of them, and it bugs out if the lists drift apart.
            -h|-\?|-v|-q|-x|-y|-gr|-md|--help|--verbose|--quiet|--trace|--dry-run|--graphical|--markdown )
                exit_with_bug "'$_option' should have been consumed by get_common_arg." "'$_option' should have been consumed by get_common_arg."
                ;;

            -*) usage "$err_unknown_argument" "Unknown argument: $_option"
                ;;

            *)  ! $_positional_arg_set                                          || usage "$err_too_many_arguments" "Multiple benchmark projects specified: $_option"
                benchmark_project="$_option"
                _positional_arg_set=true
                ;;
        esac
    done

    return "$success"
}

function verify_environment()
{
    is_tool_present bencher                                                     || error "'bencher' is not installed." "Install it from <https://bencher.dev/docs/how-to/install-cli/>." -ec "$err_tool_not_found"
    [[ -n "${BENCHER_API_TOKEN:-}" ]]                                           || error "$err_missing_argument" "The BENCHER_API_TOKEN environment variable is required."

    return "$success"
}

declare -x __bencher_symbol_regex="^[${letters_set}_][${letters_set}${digits_set}_.-]*$"

function resolve_arguments()
{
    is_positive "$repeat"                                                       || error "$err_argument_value" "repeat must be a positive integer (got '$repeat')."
    validate_preprocessor_symbols preprocessor_symbols                          || true
    is_valid_minver_settings "$minver_tag_prefix" "$minver_prerelease_id"       || true

    [[ -n $bencher_project ]]                                                   || error "The Bencher project is not set." "Use '--bencher-project <project>'." -ec "$err_argument_value"
    [[ -z $bencher_project || $bencher_project =~ $__bencher_symbol_regex ]]    || error "$err_argument_value" "The Bencher project '$bencher_project' is not a valid project name (slug)."

    [[ -n $bencher_testbed ]]                                                   || error "The Bencher testbed is not set." "Use '--bencher-testbed <testbed>'." -ec "$err_argument_value"
    [[ -z $bencher_testbed || $bencher_testbed =~ $__bencher_symbol_regex ]]    || error "$err_argument_value" "The Bencher testbed '$bencher_testbed' is not a valid testbed name."

    is_valid_branch_name "$bencher_branch"                                      || true
    is_variable_name "$bencher_adapter"                                         || error "$err_argument_value" "The Bencher adapter '$bencher_adapter' is not a valid adapter name."

    # Determine the benchmark projects: the explicit one if given, otherwise discover every *.csproj under benchmarks/
    # recursively, pruning generated bin/obj/BenchmarkDotNet.Artifacts so BenchmarkDotNet's autogenerated projects are ignored.
    if [[ -n "$benchmark_project" ]]; then
        is_safe_existing_path "$benchmark_project"                              || true
        benchmark_projects+=("$benchmark_project")
    elif [[ -d 'benchmarks' ]]; then
        readarray -t benchmark_projects < <(
            find benchmarks \
                -type d \( -name bin -o -name obj -o -name .git -o -name BenchmarkDotNet.Artifacts \) -prune \
                -o -name '*.csproj' -print | sort)
        trace "Auto-detected benchmark projects: ${benchmark_projects[*]}"
    fi

    if (( ${#benchmark_projects[@]} == 0 )); then                                  error "$err_argument_value" "No benchmark projects found under 'benchmarks/' and none specified."
    else
        get_artifacts_path "${benchmark_projects[0]}" artifacts                 || true
    fi

    readonly preprocessor_symbols
    readonly minver_tag_prefix
    readonly minver_prerelease_id
    readonly artifacts

    readonly benchmark_projects
    readonly bencher_project
    readonly bencher_testbed
    readonly bencher_branch
    readonly bencher_adapter
    readonly repeat

    return "$success"
}

# shellcheck disable=SC2120 # dump_args references arguments, but none are ever passed.
function dump_args()
{
    ! $ci && ! is_verbose && return "$success"

    local -a _args=(
        --force
        --quiet
        --header "Arguments for $script_name:"

        bencher_project
        bencher_testbed
        bencher_branch
        bencher_adapter
        benchmark_project
        benchmark_projects
        repeat

        "${dump_common_dotnet_args[@]}"
        --header "Core State:"
        --core-state
    )

    dump_vars "${_args[@]}" "$@"
}
