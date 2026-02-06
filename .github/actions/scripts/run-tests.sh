#!/usr/bin/env bash
set -euo pipefail

script_name=$(basename "${BASH_SOURCE[0]}")
script_dir=$(realpath -e "$(dirname "${BASH_SOURCE[0]}")")
lib_dir=$(realpath -e "$script_dir/../../../scripts/bash/lib")
declare -r script_name
declare -r script_dir
declare -r lib_dir

# shellcheck disable=SC1091 # Not following: ./gh_core.sh: openBinaryFile: does not exist (No such file or directory)
source "$lib_dir/gh_core.sh"

declare -xr default_configuration="Release"
declare -xr default_minver_tag_prefix='v'
declare -xr default_minver_prerelease_id="preview.0"
declare -xr default_artifacts_dir="./TestResults"
declare -ixr default_min_coverage_pct=80

declare -x test_project=${TEST_PROJECT:-}
declare -x configuration=${CONFIGURATION:="${default_configuration}"}
declare -x preprocessor_symbols=${PREPROCESSOR_SYMBOLS:-}
declare -x minver_tag_prefix=${MINVERTAGPREFIX:-"${default_minver_tag_prefix}"}
declare -x minver_prerelease_id=${MINVERDEFAULTPRERELEASEIDENTIFIERS:-"${default_minver_prerelease_id}"}
declare -x artifacts_dir=${TEST_ARTIFACTS_DIR:-}
declare -ix min_coverage_pct=${MIN_COVERAGE_PCT:-"${default_min_coverage_pct}"}

source "$script_dir/run-tests.usage.sh"
source "$script_dir/run-tests.utils.sh"

get_arguments "$@"
dump_vars --quiet \
    --header "Inputs" \
    dry_run \
    verbose \
    quiet \
    ci \
    lib_dir \
    --blank \
    test_project \
    configuration \
    preprocessor_symbols \
    min_coverage_pct \
    minver_tag_prefix \
    minver_prerelease_id \
    artifacts_dir \
    --header "other:" \
    script_name \
    script_dir \

is_safe_existing_file "$test_project" || true
test_name=$(basename "${test_project%.*}")                                      # the base name of the test project (without the path and file extension)
test_dir=$(dirname "$test_project")                                             # the directory of the test project
is_safe_configuration "$configuration" || true
validate_preprocessor_symbols preprocessor_symbols || true
validate_minverTagPrefix "$minver_tag_prefix" || true
is_safe_minverPrereleaseId "$minver_prerelease_id" || true
is_safe_path "$artifacts_dir" || true
is_safe_min_coverage_pct "$min_coverage_pct" || true

exit_if_has_errors

test_name=$(basename "${test_project%.*}")                                      # the base name of the test project (without the path and file extension)
test_dir=$(realpath -e "$(dirname "$test_project")")                            # the directory of the test project
[[ -z "$artifacts_dir" ]] && artifacts_dir="${default_artifacts_dir}/${test_name}"
artifacts_dir=$(realpath -m "${artifacts_dir}" 2> "$_ignore")                   # the directory for test results and reports (resolved to an absolute path, if it was relative)
renamed_artifacts_dir="$artifacts_dir-$(date -u +"%Y%m%dT%H%M%S")"

# Freeze the variables
declare -xr test_project
declare -xr configuration
declare -xr preprocessor_symbols
declare -xr min_coverage_pct
declare -xr minver_tag_prefix
declare -xr minver_prerelease_id
declare -xr test_name
declare -xr test_dir
declare -xr artifacts_dir
declare -xr renamed_artifacts_dir

if [[ -d "$artifacts_dir" && -n "$(ls -A "$artifacts_dir")" ]]; then
    if [[ -n "${CI:-}" ]]; then
        # Auto-delete in CI
        echo "Deleting existing artifacts directory (running in CI)..."
        execute rm -rf "$artifacts_dir"
    else
        choice=$(choose \
                    "The test results directory '$artifacts_dir' already exists. What do you want to do?" \
                        "Delete the directory and continue" \
                        "Rename the directory to '$renamed_artifacts_dir' and continue" \
                        "Exit the script") || exit $?

        trace "User selected option: $choice"
        case $choice in
            1)  echo "Deleting the directory '$artifacts_dir'..."
                execute rm -rf "$artifacts_dir"
                ;;
            2)  echo "Renaming the directory '$artifacts_dir' to '$renamed_artifacts_dir'..."
                execute mv "$artifacts_dir" "$renamed_artifacts_dir"
                ;;
            3)  echo "Exiting the script."
                exit 0
                ;;
            *)  echo "Invalid option $choice. Exiting."
                exit 2
                ;;
        esac
    fi
fi

# ${artifacts_dir}                                                              # abs.path to test results and reports          ~/repos/vm2.Glob/TestResults
coverage_source_path="${artifacts_dir}/coverage.cobertura.xml"                  # path to the raw coverage file                 ~/repos/vm2.Glob/TestResults/Glob.Api.Tests/coverage.cobertura.xml
coverage_reports_dir="${artifacts_dir}/reports"                                 # directory for coverage reports                ~/repos/vm2.Glob/TestResults/Glob.Api.Tests/reports
coverage_summary_path="${coverage_reports_dir}/Summary.txt"                     # path to text coverage summary file            ~/repos/vm2.Glob/TestResults/Glob.Api.Tests/reports/Summary.txt

declare -r coverage_source_path
declare -r coverage_reports_dir
declare -r coverage_summary_path

dump_all_variables

test_base_dir="${test_dir}/bin/${configuration}/net10.0"
test_exec_path="${test_base_dir}/${test_name}"
os_name="$(uname -s)"
if [[ "$os_name" == "Windows_NT" || "$os_name" == *MINGW* || "$os_name" == *MSYS* ]]; then
    test_exec_path="${test_exec_path}.exe"
fi
declare -r test_base_dir
declare -rx test_exec_path

declare -x _ignore
declare -rx dry_run

# Verify artifacts exist, if not - rebuild the project (mostly for local runs)
if [[ ! -s "${test_exec_path}" && "$dry_run" != "true" ]]; then
    warning "Cached test executable ${test_exec_path} was not found. Rebuilding the test project"
    execute dotnet clean "$test_project" --configuration "$configuration" || true
    if ! execute dotnet build "$test_project" \
                --configuration "$configuration" \
                -p:preprocessor_symbols="$preprocessor_symbols" \
                -p:MinVerTagPrefix="$minver_tag_prefix" \
                -p:MinVerPrereleaseIdentifiers="$minver_prerelease_id"; then
        error "Building $test_project failed."
        exit 2
    fi
fi

trace "Running tests from ${test_project}..."
if ! execute "${test_exec_path}" \
        --results-directory "${artifacts_dir}" \
        --report-trx \
        --coverage \
        --coverage-output-format "cobertura" \
        --coverage-output "coverage.cobertura.xml" \
        --coverage-settings "CodeCoverage.runsettings" \
        ; then
    error "Tests failed in project '$test_project'."
    exit 2
fi

if [[ $dry_run != "true" ]]; then
    if [[ ! -s "$coverage_source_path" ]]; then
        error "Coverage file '$coverage_source_path' not found or is empty."
        exit 2
    fi
fi

trace "Generating coverage reports..."
uninstall_reportgenerator=false
if ! execute dotnet tool list dotnet-reportgenerator-globaltool --global > "$_ignore"; then
    trace "Installing the tool 'reportgenerator'..."
    execute dotnet tool install dotnet-reportgenerator-globaltool --global --version "5.*"
    uninstall_reportgenerator=true
else
    trace "The tool 'reportgenerator' is already installed."
fi

# Execute the tool in this directory so that it can pick up the .netconfig file for filters specific to this project
execute reportgenerator \
    -reports:"$coverage_source_path" \
    -targetdir:"$coverage_reports_dir" \
    -reporttypes:TextSummary \
	-classfilters:"-*.GeneratedCodeAttribute*;-*GeneratedRegexAttribute*;-*.I[A-Z]*" \
    -filefilters:"-*.g.cs;-*.g.i.cs;-*.i.cs;-*.generated.cs;-*Migrations/*;-*obj/*;-*AssemblyInfo.cs;-*Designer.cs;-*.designer.cs;-*.I[A-Z]*.cs;-*.MoveNext;-*.d__*;-*.<>c-*.<>c__DisplayClass*"

trace "$(cat "$coverage_reports_dir/Summary.txt")"

# reportgenerator -reports:~/repos/vm2.Glob/TestResults/CoverageResults/coverage.cobertura.xml -targetdir:~/repos/vm2.Glob/TestResults/CoverageResults/reports \
#     -reporttypes:TextSummary \
#     -classfilters:"-*.GeneratedCodeAttribute*;-*GeneratedRegexAttribute*" \
#     -filefilters:"-*.g.cs;-*.g.i.cs;-*.i.cs;-*.generated.cs;-*Migrations/*;-*obj/*;-*AssemblyInfo.cs;-*Designer.cs;-*.designer.cs"

if [[ "$uninstall_reportgenerator" = "true" ]]; then
    trace "Uninstalling the tool 'reportgenerator'..."
    execute dotnet tool uninstall dotnet-reportgenerator-globaltool --global
fi

if [[ $dry_run != "true" ]]; then
    if [[ ! -s "$coverage_summary_path" ]]; then
        error "Coverage summary not found."
        exit 2
    fi
fi

# Extract the coverage percentage from the summary file
trace "Extracting coverage percentages from '$coverage_summary_path'..."
if [[ $dry_run != "true" ]]; then
    line_pct=$(sed -nE 's/Line coverage: ([0-9]+)(\.[0-9]+)?%.*/\1/p' "$coverage_summary_path" | head -n1 | xargs)
    if [[ -z "$line_pct" ]]; then
        error "Could not parse line coverage percent from \"$coverage_summary_path\""
        exit 2
    fi
    branch_pct=$(sed -nE 's/Branch coverage: ([0-9]+)(\.[0-9]+)?%.*/\1/p' "$coverage_summary_path" | head -n1 | xargs)
    if [[ -z "$branch_pct" ]]; then
        error "Could not parse branch coverage percent from \"$coverage_summary_path\""
        exit 2
    fi
    method_pct=$(sed -nE 's/Method coverage: ([0-9]+)(\.[0-9]+)?%.*/\1/p' "$coverage_summary_path" | head -n1 | xargs)
    if [[ -z "$method_pct" ]]; then
        error "Could not parse method coverage percent from \"$coverage_summary_path\""
        exit 2
    fi

    ln_status="$([[ $line_pct -lt $min_coverage_pct   ]] && echo '❌' || echo '✅')"
    br_status="$([[ $branch_pct -lt $min_coverage_pct ]] && echo '❌' || echo '✅')"
    me_status="$([[ $method_pct -lt $min_coverage_pct ]] && echo '❌' || echo '✅')"

    # # Compare the coverage percentage against the threshold
    # table_format=$(get_table_format)
    # if [[ $table_format == "markdown" ]]; then
    # {
    #     echo "Coverage for project '$test_name'"
    #     echo ""
    #     echo "Coverage | Percentage     | Status"
    #     echo ":--------|---------------:|:------:"
    #     echo "Line     | ${line_pct}%   | $ln_status"
    #     echo "Branch   | ${branch_pct}% | $br_status"
    #     echo "Method   | ${method_pct}% | $me_status"
    #     echo ""
    # } | to_summary
    # else
    # {
    #     echo "Coverage for project '$test_name'"
    #     echo ""
    #     echo "┌──────────┬────────────────┬────────────┬"
    #     echo "│ Coverage │ Percentage     │ Status     │"
    #     echo "├──────────┼────────────────┼────────────┼"
    #     echo "│ Line     │ ${line_pct}%   │ $ln_status │"
    #     echo "│ Branch   │ ${branch_pct}% │ $br_status │"
    #     echo "│ Method   │ ${method_pct}% │ $me_status │"
    #     echo "└──────────┴────────────────┴────────────┴"
    # } | to_summary
    # fi
    {
        echo "Coverage for project '$test_name'"
        echo ""
        echo "Coverage | Percentage     | Status"
        echo ":--------|---------------:|:------:"
        echo "Line     | ${line_pct}%   | $ln_status"
        echo "Branch   | ${branch_pct}% | $br_status"
        echo "Method   | ${method_pct}% | $me_status"
        echo ""
    } | to_summary

    # Export variables to GitHub Actions output
    to_github_output test_name proj-name
    args_to_github_output \
     artifacts_dir \
     coverage_source_path \
     coverage_summary_path \
     line_pct \
     branch_pct \
     method_pct

    if (( line_pct < min_coverage_pct )); then
        exit 2
    fi
fi
