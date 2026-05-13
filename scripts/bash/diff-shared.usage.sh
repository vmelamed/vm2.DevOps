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

    cat << EOF
Usage: ${script_name} [<repo-directory>...] [--<long option> <value>|-<short option> <value> | --<long switch>|-<short switch>]*

Compares a pre-defined set of files with shared content in one or more target repositories against the corresponding
source-of-truth (SoT) files listed in ${script_name%.sh}.config.json in the SoT directory, for the scenario specified
by --source-of-truth. Note that <repo-directory> does not need to be the root of the repository working tree — a deeper
path works too. This is useful for multi-solution repositories or for repositories that contain a dotnet template project.

The root directories of all vm2 repositories are expected under the same parent directory, specified either by the
environment variable \$VM2_REPOS or the --vm2-repos option.

Arguments:
  <repo-directory>              The target repository for the operation. Can be:
                                1) omitted — the current working directory is used
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
  -d, --diff                    Compare files and display differences and equalities without taking any
                                action. Can be combined with --all-repos.
  -f, --file <pattern>          A file name or a quoted glob pattern (quote glob patterns to prevent shell
                                expansion). Only matching files are processed; the action is taken from
                                the configuration. Can be specified multiple times to select multiple files.
                                Example: --file 'Directory.*.props' or -f '*.yaml'
  -fi, --file-ignore <pattern>  Same as --file but overrides the action to 'ignore'.
  -fmc, --file-merge-or-copy <pattern>
                                Same as --file but overrides the action to 'merge or copy' (asks the user).
  -fam, --file-ask-to-merge <pattern>
                                Same as --file but overrides the action to 'ask to merge'.
  -fm, --file-merge <pattern>   Same as --file but overrides the action to 'merge' (no prompt).
  -fac, --file-ask-to-copy <pattern>
                                Same as --file but overrides the action to 'ask to copy'.
  -fc, --file-copy <pattern>    Same as --file but overrides the action to 'copy' (no prompt).
  --summary <file>              Write the run summary to <file> in Markdown format. If not specified,
                                a temporary file is created, displayed at the end, and then deleted.
$switches
Environment Variables:
  VM2_REPOS                     The parent directory where all vm2 repositories are cloned.
$vars
Configuration Files:
  diff-shared.config.json       Located in the SoT directory. Defines the set of files with shared content,
                                the default action for each, and the diff/merge tools to use.
  diff-shared.custom.json       Optional. Located in the root of the target repository. Overrides actions
                                and diff/merge tools for that repository only.

Examples:

  diff-shared.sh                The current directory is the target repository, and the SoT is determined by the configuration
  diff-shared.sh vm2.Ulid       The script will try to resolve the target repo from the vm2 parent, e.g. $VM2_REPOS/vm2.Ulid
  diff-shared.sh vm2.Ulid vm2.SemVer
                                The script will process both targets one after the other
  diff-shared.sh --all-repos    The script will process all known vm2 target repositories one after the other
  diff-shared.sh --file Directory.Build.props
                                The script will only process the file Directory.Build.props, the action is determined by the
                                configuration
  diff-shared.sh --file-ask-to-merge "Directory.Build.props" --file-ask-to-merge "Directory.Packages.props"
                                  The script will only process the files Directory.Build.props and Directory.Packages.props, and
                                  for each difference, it will ask the user whether to ignore, merge or copy the SoT file over
                                  the target file
  diff-shared.sh --file-merge-or-copy "*.props"
                                The script will process all files matching the glob pattern *.props, and for each difference,
                                it will ask the user whether to ignore, merge or copy the SoT file over the target file
  diff-shared.sh --file-copy ".editorconfig" --all-repos
                                The script will copy .editorconfig from the SoT to all known target vm2 repositories without asking,
                                if it is different or missing in the target repository
  diff-shared.sh vm2.SemVer --file-copy "*.toml"
                                The script will copy all .toml files from the SoT to the target repository without asking, if
                                they are different or missing in the target repository
  diff-shared.sh --all-repos --file-merge "*.yaml"
                                The script will process all .yaml files in all known target vm2 repositories, and for each
                                difference, it will launch the merge tool to merge the SoT file with the target file without
                                asking
  diff-shared.sh --diff --all-repos
                                The script will compare the files in all known target vm2 repositories with the SoT and display
                                the differences and equalities without taking any actions

For more information see 'docs/diff-shared.md'.

EOF
}
