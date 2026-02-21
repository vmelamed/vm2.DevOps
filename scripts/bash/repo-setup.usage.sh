# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

# shellcheck disable=SC2154 # variables referenced but not assigned here
function usage_text()
{
    local std_switches=""

    if [[ $1 == true ]]; then
        std_switches="$common_switches"
    fi

    cat << EOF
Usage: ${script_name} [--repo <repoName>] [options]

Bootstrap and configure a repository for a vm2 project. This script assumes that the project has already been created locally,
e.g. using 'dotnet new vm2.NewPkg' and has all the conventianal files, including GitHub Actions worflow *.yaml files. The script
will create a Git repo and the corresponding GitHub repository, push the code, and set up CI/CD workflows and branch protection.

The script is idempotent and can be safely re-run to update settings or fix issues. The --configure-only switch allows skipping
the repo creation step, which is useful for configuring an existing repository or when the local repo is already initialized and
linked to GitHub. The --skip-secrets and --skip-variables switches allow skipping the setting of secrets and variables, which
can be useful for read-only audits or when those are managed separately.

Use the --audit switch to perform a read-only audit of the current repository settings vs expected settings based on the
script's logic and the local repository contents. This can help identify misconfigurations or drift without making changes.

This script will:
  - Initialize git, commit, and create the GitHub repository (unless --configure-only)
  - Set required secrets and variables for CI/CD workflows (unless --skip-secrets and/or --skip-variables)
  - Configure repository settings (squash merge, auto-delete branches, etc.)
  - Configure Actions workflow permissions (GITHUB_TOKEN default=read)
  - Set up default branch ("main") protection with required status checks

Options:
  --path <path>                 Path to the local project's root directory, e.g. the directory where the solution file is
                                located. The repo name and other settings will be inferred from the name and contents of this
                                directory.
                                Default: the current working directory.
  --owner <owner>               GitHub user or organization that will own the repository
                                From environment variable: ORGANIZATION or default: vmelamed
  --visibility <public|private> Repository visibility
                                Default: public
  --branch <branch>             Branch to protect
                                Default: main

Switches:
  --configure-only              Skip repo creation; configure an existing repo only
  --skip-secrets                Skip setting repository secrets
  --skip-variables              Skip setting repository variables
  --audit                       Read-only: report current vs expected settings without changes
$std_switches
Examples:
  ${script_name} --repo vmelamed/vm2.Glob
  ${script_name} --repo vmelamed/vm2.Glob --configure-only
  ${script_name} --repo vmelamed/vm2.Glob --configure-only --skip-secrets --dry-run
  ${script_name} --repo myorg/vm2.MyPackage --visibility private
EOF
}

function usage()
{
    local long_help=false
    if [[ $# -gt 0 && ($1 == true || $1 == false) ]]; then
        long_help=$1
        shift
    fi
    display_usage_msg "$(usage_text "$long_help")" "$@"
}
