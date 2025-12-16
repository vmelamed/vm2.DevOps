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

source "$script_dir/run-tests.usage.sh"
source "$script_dir/run-tests.utils.sh"

get_arguments "$@"

if [[ ! -s "$test_project" ]]; then
    usage "The specified test project file '$test_project' does not exist." >&2
    exit 2
fi

base_name=$(basename "${test_project%.*}")                                      # the base name of the test project without the path and file extension

declare -r test_project
declare -r configuration
declare -r preprocessor_symbols
declare -r min_coverage_pct
declare -r base_name
declare -r cached_dependencies
declare -r cached_artifacts

solution_dir="$(realpath -e "$(dirname "$test_project")/../..")" # assuming <solution-root>/test/<test-project>/test-project.csproj
artifacts_dir=$(realpath -m "${artifacts_dir:-"$solution_dir/TestArtifacts"}")  # ensure it's an absolute path

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

coverage_results_dir="$artifacts_dir/CoverageResults"                           # the directory for the coverage results. We do
declare -r coverage_results_dir                                                 # it here again in case the user changed the test
                                                                                # results directory.

test_results_dir="$artifacts_dir/Results"                                       # the directory for the log files from the test run

coverage_source_dir="$coverage_results_dir/coverage"                            # the directory for the raw coverage files
coverage_source_fileName="coverage.cobertura.xml"                               # the name of the raw coverage file
coverage_source_path="$coverage_source_dir/$coverage_source_fileName"           # the path to the raw coverage file

coverage_reports_dir="$coverage_results_dir/coverage_reports"                   # the directory for the coverage reports
coverage_reports_path="$coverage_reports_dir/Summary.txt"                       # the path to the coverage summary file


coverage_summary_dir="$artifacts_dir/coverage/text"                             # the directory for the text coverage summary artifacts
coverage_summary_path="$coverage_summary_dir/$base_name-TextSummary.txt"        # the path to the coverage summary artifact file
coverage_summary_html_dir="$artifacts_dir/coverage/html"                        # the directory for the coverage html artifacts

declare -r test_results_dir

declare -r coverage_source_dir
declare -r coverage_source_fileName
declare -r coverage_source_path

declare -r coverage_reports_dir
declare -r coverage_reports_path

declare -r coverage_summary_dir
declare -r coverage_summary_path
declare -r coverage_summary_html_dir

dump_all_variables

trace "Creating directories..."
execute mkdir -p "$test_results_dir"
execute mkdir -p "$coverage_source_dir"
execute mkdir -p "$coverage_reports_dir"
execute mkdir -p "$coverage_summary_dir"

declare test_base_path
declare test_dll_path
declare test_exe_path

test_base_path="$(dirname "$test_project")/bin/${configuration}/net10.0/$(basename "${test_project%.*}")"
test_dll_path="${test_base_path}.dll"
os_name="$(uname -s)"
if [[ "$os_name" == "Windows_NT" || "$os_name" == *MINGW* || "$os_name" == *MSYS* ]]; then
    test_exe_path="${test_base_path}.exe"
else
    test_exe_path="${test_base_path}"
fi
declare -r test_base_path
declare -r test_dll_path
declare -rx test_exe_path

if [[ $cached_dependencies != "true" ]]; then
    trace "Restore dependencies if not cached"
    # we are not getting the dependencies from a cache - do the slow full restore
    execute dotnet restore
fi

# shellcheck disable=SC2154
if [[ $cached_artifacts != "true" ]]; then
    trace "Build the artifacts if not cached"
    # we are not getting the build artifacts from a cache - do the slow full build
    execute dotnet build  \
        --project "$test_project" \
        --configuration "$configuration" \
        --no-restore \
        /p:DefineConstants="$preprocessor_symbols"
fi

# shellcheck disable=SC2154
if [[ ! -f "${test_dll_path}" && "$dry_run" != "true" ]]; then
    echo "❌ Test executable not found at: ${test_dll_path}" | tee >> "$GITHUB_STEP_SUMMARY" >&2
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
if ! dotnet tool list dotnet-reportgenerator-globaltool --global > "$_ignore"; then
    echo "Installing the tool 'reportgenerator'..."; sync
    execute dotnet tool install dotnet-reportgenerator-globaltool --global --version 5.*
    uninstall_reportgenerator=true
else
    echo "The tool 'reportgenerator' is already installed." >&2
fi

execute reportgenerator \
    -reports:"$coverage_source_path" \
    -targetdir:"$coverage_reports_dir" \
    -reporttypes:TextSummary,html \
	-assemblyfilters:"-Test.Utilities*" \
	-classfilters:"-*.ExcludeFromCodeCoverage*;-*.GeneratedCode*;-*GeneratedRegex*;-*SourceGenerationContext*"
    # -assemblyfilters:"-Test.Utilities*" \   # -*.Tests; ???

if [[ "$uninstall_reportgenerator" = "true" ]]; then
    echo "Uninstalling the tool 'reportgenerator'..."; sync
    execute dotnet tool uninstall dotnet-reportgenerator-globaltool --global
fi

if [[ $dry_run != "true" ]]; then
    if [[ ! -s "$coverage_reports_path" ]]; then
        echo "❌ Coverage summary not found." | tee >> """$GITHUB_STEP_SUMMARY""" >&2
        exit 2
    fi
fi

# Copy the coverage report summary to the artifact directory
trace "Copying coverage summary to '$coverage_summary_path'..."
execute mv """$coverage_reports_path""" """$coverage_summary_path"""
execute mv """$coverage_reports_dir"""  """$coverage_summary_html_dir"""

# Extract the coverage percentage from the summary file
trace "Extracting coverage percentage from '$coverage_summary_path'..."
if [[ $dry_run != "true" ]]; then
    pct=$(sed -nE 's/Method coverage: ([0-9]+)(\.[0-9]+)?%.*/\1/p' "$coverage_summary_path" | head -n1)
    if [[ -z "$pct" ]]; then
        echo "❌ Could not parse coverage percent from \"$coverage_summary_path\"" | tee >> "$GITHUB_STEP_SUMMARY" >&2
        sync
        exit 2
    fi

    proj_name="$(basename "${test_project%.*}")"
    echo "proj-name=$proj_name" >> "$GITHUB_OUTPUT"

    # Compare the coverage percentage against the threshold
    if (( pct < min_coverage_pct )); then
        echo "❌ Coverage of $pct% is below the threshold of ${min_coverage_pct}%" | tee >> "$GITHUB_STEP_SUMMARY" >&2
    else
        echo "✔️ Coverage of $pct% meets the threshold of ${min_coverage_pct}%" >> "$GITHUB_STEP_SUMMARY"
    fi

    # Output coverage percentage for use in workflow
    if [[ -n "$GITHUB_OUTPUT" ]]; then
        echo "coverage-pct=${pct}" >> "$GITHUB_OUTPUT"
    fi
    sync

    if (( pct < min_coverage_pct )); then
        exit 2
    fi
fi
