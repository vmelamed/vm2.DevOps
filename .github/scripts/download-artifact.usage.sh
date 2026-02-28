#!/usr/bin/env bash

# shellcheck disable=SC2154 # variable is referenced but not assigned
function usage_text()
{
    local std_switches=""
    local std_vars=""

    if [[ $1 == true ]]; then
        std_switches="
Switches:
$common_switches"
        std_vars=$common_vars
    fi

    cat << EOF
Usage: ${script_name} [--<long option> <value>|-<short option> <value> | --<long switch>|-<short switch> ]*
Tries to find and download the latest artifact created by previous runs of the specified workflow. All parameters are optional
if the corresponding environment variables are set. If both are specified, the command line arguments take precedence

Options:
  -a, --artifact                Specifies the name of the artifact to download
                                Initial value from \$ARTIFACT_NAME
  -d, --directory               The path to the artifact directory where to download the artifacts. If the directory does not
                                exist, it will be created. If it exists and it is not empty, its contents will be clobbered
                                without warning
                                Initial value from \$ARTIFACT_DIR or default './BmArtifacts/baseline'
  -r, --repository              Specifies the GitHub repository in the form 'owner/repo' where to find the workflow
                                Initial value from \$REPOSITORY
  -i, --wf-id                   Specifies the ID of the workflow
                                Initial value from \$WORKFLOW_ID or default ''
  -n, --wf-name                 Specifies the name of the workflow as shown in the GitHub Actions UI
                                Initial value from \$WORKFLOW_NAME
  -p, --wf-path                 Specifies the path of the workflow file in the repository, e.g
                                '.github/workflows/run-benchmarks.yml'
                                Initial value from \$WORKFLOW_PATH or default ''
Note:
    1) If none of the --wf-* options are specified, the script will try to find the workflow by the first non-empty environment
       variable WORKFLOW_NAME, WORKFLOW_PATH, and WORKFLOW_ID in that order
    2) If more than one --wf-* options are specified, only the last one is considered
    3) If one of the --wf-* options is specified, the environment variables will be ignored
$std_switches
Environment Variables:
  ARTIFACT_NAME                 Name of the artifact to download
  ARTIFACT_DIR                  Directory where artifacts will be downloaded
  REPOSITORY                    GitHub repository in the form 'owner/repo'
  WORKFLOW_ID                   ID of the workflow
  WORKFLOW_NAME                 Name of the workflow
  WORKFLOW_PATH                 Path to the workflow file
$std_vars
EOF
}

function usage()
{
    local long_help=true
    if [[ $# -gt 0 && ($1 == true || $1 == false) ]]; then
        long_help=$1
        shift
    fi
    display_usage_msg "$(usage_text "$long_help")" "$@"
}
