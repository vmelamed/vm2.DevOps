# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.
# shellcheck disable=SC2154 # variables sourced from diff-shared.sh

declare -xr common_switches
declare -xr common_vars
declare -xr script_name

function usage_text()
{
    local long_text=$1
    local switches=""
    local vars=""

    if $long_text; then
        switches="Switches:"$'\n'"$common_switches"
        vars="$common_vars"
    fi

    local sot_dir
    sot_dir=${VM2_REPOS:-$(get_devops_parent)}

    cat << EOF
Usage: ${script_name} [<repo-directory>...] [--<long option> <value>|-<short option> <value> | --<long switch>|-<short switch>]*

Compares a pre-defined set of files with shared contents across repositories from one or more target repositories with the
corresponding source-of-truth (SoT) files listed in ${scrip-name}.config.json from the SoT scenario specified by the
--source-of-truth parameter. Note that <repo-directory> does not need to be the root of the repository working tree — a deeper
path works too. This is useful for multi-solution repositories or repositories that contain a dotnet template project.

The root directories of all vm2 repositories are expected under the same parent directory, specified either by the
environment variable \$VM2_REPOS or the --vm2-repos option.

Each <repo-directory> is resolved in the following order:
  - If not specified, the current working directory is used, otherwise
  - The name is looked up under the directory specified by \$VM2_REPOS or --vm2-repos.

Arguments:
  <repo-directory>              The target repository for the operation. Can be:
                                1) omitted - the current working directory is used
                                2) a repository name (looked up under \$VM2_REPOS)
                                3) an absolute or relative path to a directory that is the root of the
                                   working tree or inside it
                                Multiple repositories can be specified as positional arguments.

Options:
  -r, --vm2-repos <dir>         The parent directory where all vm2 repositories are cloned.
                                Initial value from \$VM2_REPOS or '\$HOME/repos/vm2'.
  -s, --source-of-truth <sot>   The source-of-truth scenario to use. Must be one of the pre-defined
                                scenarios in '\$VM2_REPOS/vm2.Templates/templates/'.
  -a, --all-repos               Compare all pre-defined vm2 repositories under \$VM2_REPOS with the SoT,
                                one by one. The set is defined in 'lib/core.sh'.
  -f, --file <pattern>          A comma-separated list of glob patterns. Only files matching the patterns
                                are processed; the action is taken from the configuration.
                                Example: --file 'Directory.*.props' or -f '*.yaml,*.toml'
  --file-ignore <pattern>       Same as --file but overrides the action to 'ignore'.
  --file-merge-or-copy <pattern>
                                Same as --file but overrides the action to 'merge or copy' (asks the user).
  --file-ask-to-merge <pattern> Same as --file but overrides the action to 'ask to merge'.
  --file-merge <pattern>        Same as --file but overrides the action to 'merge' (no prompt).
  --file-ask-to-copy <pattern>  Same as --file but overrides the action to 'ask to copy'.
  --file-copy <pattern>         Same as --file but overrides the action to 'copy' (no prompt).
  --summary <file>              Write the run summary to <file> in Markdown format. If not specified,
                                a temporary file is created, displayed at the end, and then deleted.
$switches
Environment Variables:
  VM2_REPOS                     The parent directory where all vm2 repositories are cloned.
$vars
Configuration Files:
  diff-shared.config.json       Located in the SoT directory. Defines the set of files with shared contents,
                                the default action for each, and the diff/merge tools to use.
  diff-shared.custom.json       Optional. Located in the root of the target repository. Overrides actions
                                and diff/merge tools for that repository only.

For more information see 'docs/diff-shared.md'.

EOF
}
