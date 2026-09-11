# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

#=============================================================================================
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
#=============================================================================================

# Circular include guard
(( ${__VM2_LIB_CONSTANTS_SH_LOADED:-0} == 1 )) && return 0
declare -xr __VM2_LIB_CONSTANTS_SH_LOADED=1

#---------------------------------------------------------------------------------------------
# @description A list of the current vm2 projects. The vm2 repositories are expected to be
#   present in the same directory as the repository that contains the scripts and this core
#   library - `vm2.DevOps`, so that the projects can be easily found and referenced by the
#   scripts without needing to search for them.
#   This is useful for scripts that work across all vm2 projects, e.g. `diff-shared.sh`.
#   `vm2.DevOps` is intentionally not included in this list, to avoid accidentally introducing
#   dependencies on it from the other projects.
#---------------------------------------------------------------------------------------------
declare -xra vm2_repositories=(
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

#---------------------------------------------------------------------------------------------
# @description Specifies the name of the `vm2.DevOps` repository
#---------------------------------------------------------------------------------------------
declare -xr vm2_devops_repo_name="vm2.DevOps"

#---------------------------------------------------------------------------------------------
# There are many files in the VM2 repositories that are repeated in other projects
# (repositories) and all, or at least big parts of their content is identical across projects
# that were created off the same `dotnet add new` template. This shared content may drift and
# it needs to be kept in sync across repositories. The sources of truth (SOT) for the shared
# content are the templates in the vm2.Templates repository. E.g. the SOT files for the
# projects that produce NuGet packages is in the AddNewPackage template and they are located
# in the "templates/AddNewPackage/content" directory in the vm2.Templates repository. Some of
# the SoT files are: `.editorconfig`, `.gitignore`, `global.json`, `coverage.settings.xml`,
# etc. These are files that are almost always 100% shared without changes across repositories
# created from the same template. Some other files, e.g. `Directory.Build.props` and
# `Directory.Packages.props`, `.github/CI.yaml` are shared but they often have some minor
# differences (usually less than 25%) across the repositories (they may have additional NuGet
# packages, or test projects to be run in CI, etc.).
# For more information about the shared files and the sources of truth, and how they are kept
# in sync, see the `docs/diff-shared.md` and the script itself `scripts/bash/diff-shared*.sh`
# in this repository.
#---------------------------------------------------------------------------------------------

#---------------------------------------------------------------------------------------------
# @description Specifies the repository that contains the shared, source-of-truth files
#    relative to the parent directory where these repositories are cloned, e.g. `$VM2_REPOS`.
#---------------------------------------------------------------------------------------------
declare -xr vm2_sot_repo_name="vm2.Templates"

#---------------------------------------------------------------------------------------------
# @description Specifies the names of the directories in the `$vm2_sot_repo_name` (the
#    vm2.Templates repository, sub-directory "templates/", that contain "dotnet add package"
#    templates for building vm2 projects - sources of truth templates and configuration files.
#---------------------------------------------------------------------------------------------
declare -xra sources_of_truth=(
    "AddNewPackage"
)

#---------------------------------------------------------------------------------------------
# @description Specifies the default SOT directory to use as a source for comparison and
#    synchronization. The script may allow overriding it by passing the --sot option. The
#    default value is `AddNewPackage`, which is the directory in the `vm2.Templates`
#    repository that contains the source of truth files for the projects created with the
#    `AddNewPackage` template. The script may support other scenarios in the future, and each
#    template may have its own directory in the vm2.Templates repository.
#---------------------------------------------------------------------------------------------
declare -xr default_sot="AddNewPackage"

#---------------------------------------------------------------------------------------------
# @description Regular expression for validating NuGet server names or URLs.
#    A valid NuGet server name must be either "nuget", "github", or a valid URL starting with
#    "http://" or "https://" schema. This regex is used to validate NuGet server names or URLs
#    passed as arguments to functions that expect a valid NuGet server name or URL.
#---------------------------------------------------------------------------------------------
declare -xr nugetServersRegex="^(nuget|github|https?://[-a-zA-Z0-9._/]+)$";

#---------------------------------------------------------------------------------------------
# @description The default repository to which the packages will be pushed.
#---------------------------------------------------------------------------------------------
declare -xr default_nuget_server="nuget"

#---------------------------------------------------------------------------------------------
# @description Array of allowed commit types for semantic versioning and changelog generation.
#    The allowed commit types are based on the Conventional Commits specification and are used
#    to determine the type of version bump (major, minor, patch) and to generate
#    changelog entries.
#
# KEEP IN SYNC WITH:
#    - [vm2.Templates/templates/AddNewPackage/content/.gitmessage](../vm2.Templates/templates/AddNewPackage/content/.gitmessage)
#    - [vm2.Templates/changelog/cliff.prerelease.toml](../vm2.Templates/changelog/cliff.prerelease.toml)
#    - [vm2.Templates/changelog/cliff.release-header.toml](../vm2.Templates/changelog/cliff.release-header.toml)
#---------------------------------------------------------------------------------------------
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

# characters
declare -xr secret_str='••••••'
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
# emojis
declare -xr mask_em='🔒'
declare -xr key_em='🔑'
declare -xr check_em='✅'
declare -xr done_em='✔️'
declare -xr fail_em='❌'
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

if [[ -t 1 ]]; then
    declare -xr bold='\033[1m'
    declare -xr reset='\033[0m'

    declare -xr red='\033[0;31m'
    declare -xr green='\033[0;32m'
    declare -xr yellow='\033[1;33m'
    declare -xr blue='\033[0;34m'
    declare -xr bold_red='\033[1;31m'
    declare -xr bold_green='\033[1;32m'
    declare -xr bold_yellow='\033[1;33m'
    declare -xr bold_blue='\033[1;34m'
    declare -xr nc='\033[0m' # no color (reset)
else
    declare -xr bold=''
    declare -xr reset=''
    declare -xr red=''
    declare -xr green=''
    declare -xr yellow=''
    declare -xr blue=''
    declare -xr bold_red=''
    declare -xr bold_green=''
    declare -xr bold_yellow=''
    declare -xr bold_blue=''
    declare -xr nc='' # no color (reset)
fi
