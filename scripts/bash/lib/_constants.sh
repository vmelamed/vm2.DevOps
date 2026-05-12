# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

#-------------------------------------------------------------------------------
# This script defines constants for:
#
# Well known vm2 repositories and their locations relative to the parent directory where all the vm2 repositories are cloned
# (e.g. $VM2_REPOS).
#
# Terminal Color and Formatting Constants ANSI escape codes for terminal text formatting and colors:
#   Available constants:
#       - Text formatting: BOLD, RESET
#       - Basic colors: RED, GREEN, YELLOW, BLUE
#       - Bold colors: BOLDRED, BOLDGREEN, BOLDYELLOW, BOLDBLUE
#       - NC (No Color) - alias for RESET
#   Note that when stdout is connected to a terminal (tty), color codes are enabled, otherwise they are set to empty strings.
#
# Regular Expression constants.
# A few graphical characters and emojis used for output formatting.
#-------------------------------------------------------------------------------

# Circular include guard
(( ${__VM2_LIB_CONSTANTS_SH_LOADED:-0} == 1 )) && return 0
declare -xr __VM2_LIB_CONSTANTS_SH_LOADED=1

# Add below all projects that are considered part of the vm2 family and are expected to be present in the same repository as the
# scripts using this core library, so that they can be easily referenced by the scripts without needing to detect them
# dynamically. This is useful for scripts that do work across all vm2 projects, e.g. diff-shared and change-ver-string.sh.
# vm2.DevOps is intentionally not included in this list, to avoid accidentally introducing dependencies on it from the other
# projects.
declare -rxa vm2_repositories=(
    "vm2.Templates"
    "vm2.TestUtilities"
    "vm2.Glob"
    "vm2.SemVer"
    "vm2.Ulid"
    "vm2.Linq.Expressions")

#-------------------------------------------------------------------------------
# Constant: specifies the expected location of the vm2.DevOps repository relative to the parent directory where all the vm2
#           repositories are cloned (e.g. $VM2_REPOS). The vm2 DevOps repository contains scripts and callable GitHub Actions
#           workflow templates that are used by the other vm2 repositories.
#-------------------------------------------------------------------------------
declare -rx vm2_devops_repo_name="vm2.DevOps"

#-------------------------------------------------------------------------------
# There are many files in the VM2 repositories that are repeated in other projects (repositories) and all or at least big parts
# of their content is identical across projects that were created off the same `dotnet add new` template. This shared content
# may drift and it needs to be kept in sync across repositories. The sources of truth (SoT) for the shared content are the
# templates in the vm2.Templates repository. E.g. the SoT files for the projects that produce NuGet packages is in the
# AddNewPackage template and they are located in the "templates/AddNewPackage/content" directory in the vm2.Templates
# repository. Some of the SoT files are: .editorconfig, .gitignore, global.json, coverage.settings.xml, etc. These are files
# that are almost always shared without changes across repositories created off the same template. Some other files, e.g.
# Directory.Build.props and Directory.Build.targets, .github/CI.yaml are shared but they often have some differences across
# repositories (additional NuGet packages, or test projects to be run in CI, etc.).

#-------------------------------------------------------------------------------
# Constant: specifies the repository that contains the shared, source-of-truth files relative to the parent directory where
#           these repositories are cloned (e.g. $VM2_REPOS).
#-------------------------------------------------------------------------------
declare -rx vm2_sot_repo_name="vm2.Templates"

#-------------------------------------------------------------------------------
# Constant: specifies the names of the directories in the vm2.Templates repository (sub-directory "templates/") that contain
#           "dotnet add package" templates for building vm2 projects.
#           projects sources of truth templates and
#           and configuration files therein.
declare -rxa sources_of_truth=(
    "AddNewPackage")

#-------------------------------------------------------------------------------
# Constant: specifies the which SoT directory to use as a source for comparison and synchronization. The script may allow
#           overriding it by passing the --sot option.
#           The default value is AddNewPackage, which is the directory in the vm2.Templates repository that contains the source
#           of truth files for the AddNewPackage template. The script may support other scenarios in the future, and each
#           template may have its own directory in the vm2.Templates repository.
declare -rx default_sot="AddNewPackage"

declare -rx varNameRegex="^[A-Za-z_][A-Za-z0-9_]*$"
declare -rx nugetServersRegex="^(nuget|github|https?://[-a-zA-Z0-9._/]+)$";

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
