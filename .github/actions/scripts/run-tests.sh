#!/bin/bash
set -euo pipefail

declare -xr this_script=${BASH_SOURCE[0]}

script_name="$(basename "${this_script%.*}")"
declare -xr script_name

script_dir="$(dirname "$(realpath -e "$this_script")")"
declare -xr script_dir

source "$script_dir/_common.sh"

declare -x test_project=${TEST_PROJECT:-}
declare -x configuration=${CONFIGURATION:="Release"}
declare -x preprocessor_symbols=${PREPROCESSOR_SYMBOLS:-" "}
declare -ix min_coverage_pct=${MIN_COVERAGE_PCT:-80}
declare -x artifacts_dir=${ARTIFACTS_DIR:-}
declare -x cached_dependencies=${CACHED_DEPENDENCIES:-false}
declare -x cached_artifacts=${CACHED_ARTIFACTS:-false}

declare -x github_output=${GITHUB_OUTPUT:-/dev/stdout}
declare -x github_step_summary=${GITHUB_STEP_SUMMARY:-/dev/stdout}

source "$script_dir/run-tests.usage.sh"
source "$script_dir/run-tests.utils.sh"

get_arguments "$@"

if [[ ! -s "$test_project" ]]; then
    usage "The specified test project file '$test_project' does not exist." >&2
    exit 2
fi

test_name=$(basename "${test_project%.*}")                                      # the base name of the test project without the path and file extension
test_dir=$(dirname "$test_project")                                             # the directory of the test project


declare -r test_project
declare -r configuration
declare -r preprocessor_symbols
declare -r min_coverage_pct
declare -r test_name
declare -r test_dir
declare -r cached_dependencies
declare -r cached_artifacts

solution_dir="$(realpath -e "${test_dir}/../..")" # assuming <solution-root>/test/<test-project>/test-project.csproj
artifacts_dir=$(realpath -m "${artifacts_dir:-"$solution_dir/TestArtifacts/$test_name"}")  # ensure it's an absolute path per test project

declare -r solution_dir
declare -r artifacts_dir

renamed_artifacts_dir="$artifacts_dir-$(date -u +"%Y%m%dT%H%M%S")"
declare -r renamed_artifacts_dir

if [[ -d "$artifacts_dir" && -n "$(ls -A "$artifacts_dir")" ]]; then
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

test_results_dir="$artifacts_dir/TestResults"                                   # the directory for the log files from the test run

coverage_results_dir="$artifacts_dir/CoverageResults"                           # the directory for the coverage results. We do
declare -r coverage_results_dir                                                 # it here again in case the user changed the test
                                                                                # results directory.

coverage_source_dir="$coverage_results_dir/coverage"                            # the directory for the raw coverage files
coverage_source_fileName="coverage.cobertura.xml"                               # the name of the raw coverage file
coverage_source_path="$coverage_source_dir/$coverage_source_fileName"           # the path to the raw coverage file

coverage_reports_dir="$coverage_results_dir/coverage_reports"                   # the directory for the coverage reports
coverage_reports_path="$coverage_reports_dir/Summary.txt"                       # the path to the coverage summary file

coverage_summary_dir="$artifacts_dir/coverage"                                  # the directory for the coverage html artifacts
coverage_summary_html_dir="$artifacts_dir/coverage/html"                        # the directory for the coverage html artifacts
coverage_summary_text_dir="$artifacts_dir/coverage/text"                        # the directory for the text coverage summary artifacts
coverage_summary_text_path="$coverage_summary_text_dir/$test_name-Summary.txt"  # the path to the coverage summary artifact file

declare -r test_results_dir

declare -r coverage_source_dir
declare -r coverage_source_fileName
declare -r coverage_source_path

declare -r coverage_reports_dir
declare -r coverage_reports_path

declare -r coverage_summary_dir
declare -r coverage_summary_text_dir
declare -r coverage_summary_html_dir
declare -r coverage_summary_text_path

dump_all_variables

trace "Creating directories..."
execute mkdir -p "$test_results_dir"
execute mkdir -p "$coverage_source_dir"
execute mkdir -p "$coverage_reports_dir"
execute mkdir -p "$coverage_summary_text_dir"

declare test_base_path
declare test_dll_path
declare test_exec_path

test_base_path="${test_dir}/bin/${configuration}/net10.0/${test_name}"
test_dll_path="${test_base_path}.dll"
os_name="$(uname -s)"
if [[ "$os_name" == "Windows_NT" || "$os_name" == *MINGW* || "$os_name" == *MSYS* ]]; then
    test_exec_path="${test_base_path}.exe"
else
    test_exec_path="${test_base_path}"
fi
declare -r test_base_path
declare -r test_dll_path
declare -rx test_exec_path

trace "Restore dependencies if not cached"
if [[ $cached_dependencies != "true" ]]; then
    execute dotnet restore --locked-mode
else
    trace "Skipping restore (using cached dependencies)"
fi

# shellcheck disable=SC2154
trace "Build the artifacts if not cached"
if [[ $cached_artifacts == "true" ]]; then
    # Verify artifacts exist
    if [[ ! -f "${test_exec_path}" || ! -f "${test_dll_path}" ]]; then
        echo "❌ Cached artifacts missing, cannot proceed" >&2
        exit 2
    fi
else
    execute dotnet build  \
        "$test_project" \
        --configuration "$configuration" \
        --no-restore \
        /p:DefineConstants="$preprocessor_symbols"
fi

# shellcheck disable=SC2154
if [[ (! -f "${test_exec_path}" || ! -f "${test_dll_path}") && "$dry_run" != "true" ]]; then
    echo "❌ Test executables ${test_exec_path} or ${test_dll_path} were not found." | tee >> "$GITHUB_STEP_SUMMARY" >&2
    exit 2
fi

trace "Running tests in project ${test_project} with build configuration ${configuration}..."
execute dotnet run \
    --project "$test_project" \
    --configuration "$configuration" \
    --no-build \
    --results-directory "$test_results_dir" \
    --report-trx \
    --coverage \
    --coverage-output-format cobertura \
    --coverage-output "$coverage_source_path"

# shellcheck disable=SC2154
if [[ $dry_run != "true" ]]; then
    if [[ ! -s "$coverage_source_path" ]]; then
        echo "❌ Coverage file not found or is empty." | tee >> "$GITHUB_STEP_SUMMARY" >&2
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

pushd "$test_dir"

# Execute the tool in this directory so that it can pick up the .netconfig file for filters specific to this project
execute reportgenerator \
    -reports:"$coverage_source_path" \
    -targetdir:"$coverage_reports_dir" \
    -reporttypes:TextSummary,html \
	-classfilters:"-*.ExcludeFromCodeCoverage*;-*.GeneratedCode*;-*GeneratedRegex*;-*SourceGenerationContext*" \
    -filefilters:"-*.g.cs;-*.g.i.cs;-*.i.cs;-*.generated.cs;-*Migrations/*;-*obj/*;-*AssemblyInfo.cs;-*Designer.cs;-*.designer.cs"

popd

if [[ "$uninstall_reportgenerator" = "true" ]]; then
    trace "Uninstalling the tool 'reportgenerator'..."
    execute dotnet tool uninstall dotnet-reportgenerator-globaltool --global
fi

if [[ $dry_run != "true" ]]; then
    if [[ ! -s "$coverage_reports_path" ]]; then
        echo "❌ Coverage summary not found." | tee >> "$github_step_summary" >&2
        exit 2
    fi
fi

# Copy the coverage report summary to the artifact directory
trace "Copying coverage summary to '$coverage_summary_text_path'..."
execute mv """$coverage_reports_path""" """$coverage_summary_text_path"""
execute mv """$coverage_reports_dir"""  """$coverage_summary_html_dir"""

# Extract the coverage percentage from the summary file
trace "Extracting coverage percentages from '$coverage_summary_text_path'..."
if [[ $dry_run != "true" ]]; then
    line_pct=$(sed -nE 's/Line coverage: ([0-9]+)(\.[0-9]+)?%.*/\1/p' "$coverage_summary_text_path" | head -n1 | xargs)
    if [[ -z "$line_pct" ]]; then
        echo "❌ Could not parse line coverage percent from \"$coverage_summary_text_path\"" | tee >> "$github_step_summary" >&2
        sync
        exit 2
    fi
    branch_pct=$(sed -nE 's/Branch coverage: ([0-9]+)(\.[0-9]+)?%.*/\1/p' "$coverage_summary_text_path" | head -n1 | xargs)
    if [[ -z "$branch_pct" ]]; then
        echo "❌ Could not parse branch coverage percent from \"$coverage_summary_text_path\"" | tee >> "$github_step_summary" >&2
        sync
        exit 2
    fi
    method_pct=$(sed -nE 's/Method coverage: ([0-9]+)(\.[0-9]+)?%.*/\1/p' "$coverage_summary_text_path" | head -n1 | xargs)
    if [[ -z "$method_pct" ]]; then
        echo "❌ Could not parse method coverage percent from \"$coverage_summary_text_path\"" | tee >> "$github_step_summary" >&2
        sync
        exit 2
    fi

    # Compare the coverage percentage against the threshold
    {
        echo "## Coverage Summary for project '$test_name'"
        echo "Coverage | Percentage | Status"
        echo ":--------|-----------:|:------:"
        status="$([[ $line_pct -lt $min_coverage_pct ]] && echo '❌' || echo '✔️')"
        echo "Line     | ${line_pct}% | $status"
        status="$([[ $branch_pct -lt $min_coverage_pct ]] && echo '❌' || echo '✔️')"
        echo "Branch   | ${branch_pct}% | $status"
        status="$([[ $method_pct -lt $min_coverage_pct ]] && echo '❌' || echo '✔️')"
        echo "Method   | ${method_pct}% | $status"
        echo ""
    } >> "$github_step_summary"

    # Export variables to GitHub Actions output
    {
        echo "proj-name=$test_name"
        echo "artifacts-dir=$artifacts_dir"
        echo "coverage_results_dir=$coverage_results_dir"
        echo "coverage_source_path=$coverage_source_path"
        echo "coverage_summary_dir=$coverage_summary_dir"
        echo "coverage_summary_text_dir=$coverage_summary_text_dir"
        echo "coverage_summary_html_dir=$coverage_summary_html_dir"
        echo "coverage_summary_text_path=$coverage_summary_text_path"
        echo "line_pct=${line_pct}"
        echo "branch_pct=${branch_pct}"
        echo "method_pct=${method_pct}"
    } >> "$github_output"

    if (( line_pct < min_coverage_pct )); then
        exit 2
    fi
fi
