# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

# shellcheck disable=SC2154 # solution_dir is referenced but not assigned
function usage_text()
{
    local switches=""
    local vars=""

    if [[ $1 == true ]]; then
        vars="Environment Variables:
  VM2_REPOS                     The parent directory where the .github workflow templates, vm2.DevOps, and other vm2.* project
                                repositories are cloned
  MINVERTAGPREFIX               The prefix used for MinVer version tags in the repositories
$common_vars"

        switches="
Switches:
$common_switches"
    fi

    cat << EOF
Usage: ${script_name} [<repo-directory>] [--<long option> <value>|-<short option> <value> | --<long switch>|-<short switch> ]*

Compares a pre-defined set of common files (e.g. .editorconfig, .gitignore, etc.) from the specified <repo-directory> with the
corresponding set of files from source-of-truth repositories (.github and vm2.DevOps). Note that the <repo-directory> doesn't
need to be the root of the repository working tree but deeper. This may be useful for multi-solution repository or repository
that contains a dotnet template project.

The root directories of the source-of-truth repositories are expected to be found under the same parent directory, specified
either by the environment variable \$VM2_REPOS or the --vm2-repos option.

The <repo-directory> will be determined in the following order:
  - If not specified, the current working directory is used as the target directory and then
  - The target directory is sought in the current working directory, otherwise
  - It is sought under the directory specified by the \$VM2_REPOS environment variable or the --vm2-repos option.

See the README.md file for more details.

Arguments:
  <repo-directory>              Determines the target directory for the operation. It can be:
                                1) not specified - the current working directory is used
                                2) just the name of the project's repository (assumed under \$VM2_REPOS)
                                3) the full path to the project's directory that is either the root of the working tree or
                                   inside it (useful for dotnet template projects)

Options:
  -r, --vm2-repos               The parent directory where the .github workflow templates and vm2.DevOps are cloned
                                Initial from the VM2_REPOS environment variable or '~/repos'
  -mp, --minver-tag-prefix      The prefix used for MinVer version tags in the repositories. Used to detect the latest stable
                                version tag of the source repositories 'vm2.DevOps' and '.github'
                                Initial from the \$MINVERTAGPREFIX environment variable or 'v'
  -f, --files                   A comma-separated list of files to compare/copy/merge. Instead of going through all the pre-
                                defined files, only the specified files from the full list are processed. The file names can be
                                regular expressions.
                                Example: -f '.*ya?ml$' or --files 'Dockerfile,Directory.*'
$switches
$vars
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
