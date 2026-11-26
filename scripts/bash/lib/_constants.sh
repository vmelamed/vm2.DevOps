# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

#===============================================================================================
# This script defines constants for:
#
# Well known vm2 repositories and their locations relative to the parent directory where all
# the vm2 repositories are cloned (e.g. $VM2_REPOS).
#
# Terminal Color and Formatting Constants ANSI escape codes for terminal text formatting and
# colors:
#   Available constants:
#       - Text formatting: BOLD, RESET
#       - Basic colors: RED, GREEN, YELLOW, BLUE
#       - Bold colors: BOLDRED, BOLDGREEN, BOLDYELLOW, BOLDBLUE
#       - NC (No Color) - alias for RESET
#   Note that when stdout is connected to a terminal (tty), color codes are enabled,
#   otherwise they are set to empty strings.
#
# Regular Expression constants.
# A few graphical characters and emojis used for output formatting.
#===============================================================================================

# Circular include guard
(( ${__VM2_LIB_CONSTANTS_SH_LOADED:-0} == 1 )) && return 0
declare -r __VM2_LIB_CONSTANTS_SH_LOADED=1

#-----------------------------------------------------------------------------------------------
# @description A list of the current vm2 projects. The vm2 repositories are expected to be
#   present in the same directory as the repository that contains the scripts and this core
#   library - `vm2.DevOps`, so that the projects can be easily found and referenced by the
#   scripts without needing to search for them.
#   This is useful for scripts that work across all vm2 projects, e.g. `diff-shared.sh`.
#   Each name is both the directory name under $VM2_REPOS and the GitHub repository name, case
#   included -- see CONVENTIONS.md, "Local Workspace".
#-----------------------------------------------------------------------------------------------
declare -xra vm2_repositories=(
    "vm2.DevOps"
    "vm2.TestUtilities"
    "vm2.Templates"
    "vm2.Ulid"
    "vm2.Glob"
    "vm2.SemVer"
    "vm2.Linq.Expressions"
    "vm2.Functional"
    "vm2.Domain"
    "vm2.Abstractions"
    "vm2.Repository"
)

#-----------------------------------------------------------------------------------------------
# @description
#    Array of allowed commit types for semantic versioning and changelog generation.
#    The allowed commit types are based on the Conventional Commits specification and are used
#    to determine the type of version bump (major, minor, patch) and to generate
#    changelog entries.
#
# KEEP IN SYNC WITH:
#    - [vm2.Templates/templates/AddNewPackage/content/.gitmessage](../vm2.Templates/templates/AddNewPackage/content/.gitmessage)
#    - [vm2.Templates/changelog/cliff.prerelease.toml](../vm2.Templates/changelog/cliff.prerelease.toml)
#    - [vm2.Templates/changelog/cliff.release-header.toml](../vm2.Templates/changelog/cliff.release-header.toml)
#-----------------------------------------------------------------------------------------------
declare -xra allowed_commit_types=(
    "feat"              # minor  New feature
    "fix"               # patch  Bug fix
    "perf"              # patch  Performance improvement
    "security"          # patch  Security fix/hardening
    "doc"               # patch  Documentation change. SHOULD not force client rebuild
    "docs"              # patch  Documentation change. SHOULD not force client rebuild
    "deps"              # patch  Dependency updates
    "revert"            # patch  Revert previous commit
    "remove"            # patch  Remove code or files
    "refactor"          # patch  Code refactoring that does not change functionality, API, etc. MUST not force client rebuild
    "style"             # n/a    Code style changes (formatting, linting, etc.) MUST not force client rebuild
    "test"              # n/a    Adding or updating tests
    "tests"             # n/a    Adding or updating tests
    "ci"                # n/a    Continuous integration configuration changes that do not force client rebuild
    "chore"             # n/a    Miscellaneous tasks or maintenance that do not force client rebuild
)
declare -x allowed_commit_types_str
allowed_commit_types_str=$(IFS=,; echo "${allowed_commit_types[*]}")
readonly allowed_commit_types_str

declare -x allowed_commit_types_rex
allowed_commit_types_rex=$(IFS='|'; echo "${allowed_commit_types[*]}")
readonly allowed_commit_types_rex

#-----------------------------------------------------------------------------------------------
# @description Specifies the default path to the parent directory of all vm2 repositories.
#   Usually $VM2_REPOS is set to "$HOME/repos/vm2" but it might be different on other systems
#   or environments (e.g. in CI/CD pipelines, other developers' machines, etc.).
#-----------------------------------------------------------------------------------------------
declare -xr default_vm2_repos_path="$HOME/repos/vm2"

#-----------------------------------------------------------------------------------------------
# @description Specifies the name of the `vm2.DevOps` repository
#-----------------------------------------------------------------------------------------------
declare -xr vm2_devops_repo_name="vm2.DevOps"

#===============================================================================================
# There are many files in the VM2 repositories that are repeated in other projects
#    (repositories) and all, or at least big parts of their content is identical across projects
#    that were created off the same `dotnet add new` template. This shared content may drift and
#    it needs to be kept in sync across repositories. The sources of truth (SOT) for the shared
#    content are the templates in the vm2.Templates repository. E.g. the SOT files for the
#    projects that produce NuGet packages is in the AddNewPackage template and they are located
#    in the "templates/AddNewPackage/content" directory in the vm2.Templates repository. Some of
#    the SoT files are: `.editorconfig`, `.gitignore`, `global.json`, `coverage.settings.xml`,
#    etc. These are files that are almost always 100% shared without changes across repositories
#    created from the same template. Some other files, e.g. `Directory.Build.props` and
#    `Directory.Packages.props`, `.github/CI.yaml` are shared but they often have some minor
#    differences (usually less than 25%) across the repositories (they may have additional NuGet
#    packages, or test projects to be run in CI, etc.).
#    For more information about the shared files and the sources of truth, and how they are kept
#    in sync, see the script `scripts/bash/src/diff-shared*.sh` and the documentation
#    `docs/docs/diff-shared.md` in this repository.
#===============================================================================================

#-----------------------------------------------------------------------------------------------
# @description Specifies the repository that contains the shared, source-of-truth files
#    relative to the parent directory where these repositories are cloned, e.g. `$VM2_REPOS`.
#-----------------------------------------------------------------------------------------------
declare -xr vm2_sot_repo_name="vm2.Templates"

#-----------------------------------------------------------------------------------------------
# @description Specifies the names of the directories in the `$vm2_sot_repo_name` (the
#    vm2.Templates repository, sub-directory "templates/", that contain "dotnet add package"
#    templates for building vm2 projects - sources of truth templates and configuration files.
#-----------------------------------------------------------------------------------------------
declare -xra sources_of_truth=(
    "AddNewPackage"
)
declare -x sources_of_truth_str
sources_of_truth_str=$(IFS=,; echo "${sources_of_truth[*]}")
readonly sources_of_truth_str

declare -x sources_of_truth_rex
sources_of_truth_rex=$(IFS='|'; echo "${sources_of_truth[*]}")
readonly sources_of_truth_rex

#-----------------------------------------------------------------------------------------------
# @description Specifies the default SOT directory to use as a source for comparison and
#    synchronization. The script may allow overriding it by passing the --sot option. The
#    default value is `AddNewPackage`, which is the directory in the `vm2.Templates`
#    repository that contains the source of truth files for the projects created with the
#    `AddNewPackage` template. The script may support other scenarios in the future, and each
#    template may have its own directory in the vm2.Templates repository.
#-----------------------------------------------------------------------------------------------
declare -xr default_sot="AddNewPackage"

#-----------------------------------------------------------------------------------------------
# @description The default repository to which the packages will be pushed.
#-----------------------------------------------------------------------------------------------
declare -xr default_nuget_server="nuget"

#-----------------------------------------------------------------------------------------------
# @description Markers that delimit a "shared" block within an otherwise private/local file --
#    content between them is expected to stay synced with the SoT, while everything outside is
#    left entirely to the target repository. Matched as a plain substring anywhere on a line;
#    any trailing text after the marker on that line (e.g. a human-readable "Beginning of shared
#    content" label) is purely descriptive and ignored by the scanner. The two marker LINES
#    themselves are delimiters and are never considered part of the shared content.
#-----------------------------------------------------------------------------------------------
declare -xr shared_begin_marker='<<<==='
declare -xr shared_end_marker='===>>>'

#-----------------------------------------------------------------------------------------------
# @description Locale independent letters and digits sets
#-----------------------------------------------------------------------------------------------
declare -xr u_letters_set='ABCDEFGHIJKLMNOPQRSTUVWXYZ' # this is locale independent
declare -xr l_letters_set='abcdefghijklmnopqrstuvwxyz' # this is locale independent
declare -xr letters_set="${u_letters_set}${l_letters_set}" # this is locale independent
declare -xr nz_digits_set='123456789'
declare -xr digits_set="0${nz_digits_set}"
declare -xr hex_digits_set="${digits_set}ABCDEFabcdef"

#-----------------------------------------------------------------------------------------------
# @description Discard targets: pass one as an output nameref whose value you do not need, e.g.
#   `resolve_repo_root "$vm2_repos" "$repo" repo_path void`. Writable on purpose (never readonly), and
#   never read. Do not use `_` for this: bash overwrites `$_` after every simple command, so a function
#   that reads its output back sees garbage, an array output is clobbered, and a map output fails.
#-----------------------------------------------------------------------------------------------
# shellcheck disable=SC2034 # never read here: the callers pass these names as output namerefs
{
    declare void=''
    declare -a void_array=()
    declare -A void_map=()
}

# characters
declare -xr secret_str='••••••'
declare -xr secret_placeholder=$secret_str
declare -xr mask_ch='•'
declare -xr check_ch='✓'
declare -xr cross_ch='✗'
declare -xr question_ch='?'
declare -xr fail_ch='✗'
declare -xr error_ch='✗'
declare -xr warning_ch='⚠'
declare -xr info_ch='ℹ'
declare -xr done_ch='✔'
declare -xr equals_ch='='
declare -xr not_eq_ch='≠'
declare -xr left_arrow_ch='←'
declare -xr right_arrow_ch='→'
declare -xr up_arrow_ch='↑'
declare -xr down_arrow_ch='↓'
declare -xr space_ch=$'\xe2\x80\x82' # markdown does not collapse this space (EN SPACE, U+2002 -- \xHH bytes, not \u2002: the \u escape is locale-dependent and breaks under a POSIX/C locale, e.g. under bats or minimal CI images)

# emojis
declare -xr mask_em='🔒'
declare -xr key_em='🔑'
declare -xr edit_em='✏️'
declare -xr check_em='✅'
declare -xr done_em='✔️'
declare -xr fail_em='❌'
declare -xr no_entry_em='⛔'
declare -xr fatal_em='💀'
declare -xr bug_em='🪲'
declare -xr error_em='❌'
declare -xr warn_em='⚠️'
declare -xr info_em='ℹ️'
declare -xr question_em='❓'
declare -xr equals_em='🟰'
declare -xr not_eq_em='❔'
declare -xr ok_em='🆗'
declare -xr left_arrow_em='⬅️'
declare -xr right_arrow_em='➡️'
declare -xr up_arrow_em='⬆️'
declare -xr down_arrow_em='⬇️'
declare -xr trace_em='🐾'

if [[ -t 1 ]]; then
    declare -xr clr_reset=$'\033[0m'
    declare -xr clr_bold=$'\033[1m'
    declare -xr clr_red=$'\033[0;31m'
    declare -xr clr_green=$'\033[0;32m'
    declare -xr clr_yellow=$'\033[1;33m'
    declare -xr clr_blue=$'\033[0;34m'
    declare -xr clr_bold_red=$'\033[1;31m'
    declare -xr clr_bold_green=$'\033[1;32m'
    declare -xr clr_bold_yellow=$'\033[1;33m'
    declare -xr clr_bold_blue=$'\033[1;34m'
else
    declare -xr clr_reset=''
    declare -xr clr_bold=''
    declare -xr clr_red=''
    declare -xr clr_green=''
    declare -xr clr_yellow=''
    declare -xr clr_blue=''
    declare -xr clr_bold_red=''
    declare -xr clr_bold_green=''
    declare -xr clr_bold_yellow=''
    declare -xr clr_bold_blue=''
fi

declare -xra all_colors=(
    "$clr_reset"
    "$clr_bold"
    "$clr_red"
    "$clr_green"
    "$clr_yellow"
    "$clr_blue"
    "$clr_bold_red"
    "$clr_bold_green"
    "$clr_bold_yellow"
    "$clr_bold_blue"
)
