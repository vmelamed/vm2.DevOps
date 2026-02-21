# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

# shellcheck disable=SC2154 # solution_dir is referenced but not assigned
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
Usage: ${script_name} [<repository-name>] | [--<long option> <value>|-<short option> <value> | --<long switch>|-<short switch> ]*
Compares a pre-defined set of files from the source-of-truth repositories with the corresponding files in the specified project.
This is opinionated tool that requires certain file structure of  the repository and the project directory. See the README.md
file for more details

Arguments:
  <repository-name>             Determines the target directory for the operation. It can be:
                                1) not specified - the current working directory is used
                                2) just the name of the project's repository (assumed under \$GIT_REPOS)
                                3) the full path to the project's directory that is either the root of the working tree or
                                   inside it (useful for dotnet template projects)

Options:
  -r, --git-repos               The parent directory where the .github workflow templates and vm2.DevOps are cloned
                                Initial from the GIT_REPOS environment variable or '~/repos'
  -mp, --minver-tag-prefix      The prefix used for MinVer version tags in the repositories. Used to detect the latest stable
                                version tag of the source repositories 'vm2.DevOps' and '.github'
                                Initial from the \$MINVERTAGPREFIX environment variable or 'v'
  -f, --files                   A comma-separated list of files to compare/copy/merge. Instead of going through all the pre-
                                defined files, only the specified files from the full list are processed. The file names can be
                                regular expressions.
                                Example: -f '.*ya?ml$' or --files 'Dockerfile,Directory.*'

$std_switches
Environment Variables:
  GIT_REPOS                     The parent directory where the .github workflow templates, vm2.DevOps, and project repositories
                                are cloned
  MINVERTAGPREFIX               The prefix used for MinVer version tags in the repositories
$std_vars
Configuration Files:
    The script uses a configuration file 'diff-common.actions.json' located in the project's directory to customize the actions
    taken when differences are found. (See the README.md file for more details.)

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
