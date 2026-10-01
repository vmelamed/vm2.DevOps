#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed


declare -xr common_args_usage
declare -xr script_name

function usage_text()
{
    (( $# ==1 ))    || bug "${FUNCNAME[0]}() expects a single boolean argument indicating whether to display the long or short usage text (provided $#)."
    is_boolean "$1" || bug "${FUNCNAME[0]}() requires argument 1 to be a boolean argument indicating whether to display the long or short usage text (provided ${1:-<none>})."
    exit_if_has_bugs

    local _long_text=$1
    local _common_args=''

    $_long_text  &&  _common_args=$common_args_usage || _common_args=''

    cat << EOF
Usage:
  $script_name [--<long option> <value>|-<short option> <value> | --<long switch>|-<short switch> ]*

Tries to find and download the latest artifact created by a previous run of the specified workflow. Every parameter is
optional if the corresponding environment variable is set instead; when a value is given both ways, the command-line
argument takes precedence.

Options:
  -a, --artifact                Specifies the name of the artifact to download.
                                Initial value from \$ARTIFACT_NAME
  -d, --directory               The directory to download the artifact into. Created if it does not exist; if it exists
                                and is not empty, its contents are clobbered without warning.
                                Initial value from \$ARTIFACT_DIR or default './BmArtifacts/baseline'
  -r, --repository              Specifies the GitHub repository, in the form 'owner/repo', where the workflow lives.
                                Initial value from \$REPOSITORY
  -i, --wf-id                   Specifies the ID of the workflow.
                                Initial value from \$WORKFLOW_ID or default ''
  -n, --wf-name                 Specifies the name of the workflow, as shown in the GitHub Actions UI.
                                Initial value from \$WORKFLOW_NAME
  -p, --wf-path                 Specifies the path of the workflow file in the repository, e.g.
                                '.github/workflows/run-benchmarks.yml'.
                                Initial value from \$WORKFLOW_PATH or default ''
Note:
  1) The workflow is identified by precedence: the workflow ID, if known, is used directly; otherwise the workflow
     name is used to look it up; otherwise the workflow path is used. This precedence applies equally whether the
     value came from \$WORKFLOW_ID/\$WORKFLOW_NAME/\$WORKFLOW_PATH or from --wf-id/--wf-name/--wf-path.
  2) If more than one --wf-* option is given, only the last one on the command line is kept -- each --wf-* option
     clears the other two.
  3) Giving any --wf-* option on the command line clears the environment variables for the other two identifiers, so
     only the identifier you specified is used.

Environment Variables:
  ARTIFACT_NAME                 Name of the artifact to download
  ARTIFACT_DIR                  Directory where artifacts will be downloaded
  REPOSITORY                    GitHub repository in the form 'owner/repo'
  WORKFLOW_ID                   ID of the workflow
  WORKFLOW_NAME                 Name of the workflow
  WORKFLOW_PATH                 Path to the workflow file
$_common_args
EOF
}
