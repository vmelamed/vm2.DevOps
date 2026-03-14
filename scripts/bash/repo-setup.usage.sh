# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.
# shellcheck disable=SC2154 # variables referenced but not assigned here

function usage_text()
{
    local cmn_switches=""

    if $1; then
        cmn_switches="$common_switches"
    fi

    cat << EOF
Usage: ${script_name} [<repo-directory>] [--<long option> <value>|-<short option> <value> | --<long switch>|-<short switch> ]*

Bootstrap and configure a repository for a vm2 package project. This script assumes that the project has already been created
locally, e.g. using 'dotnet new vm2.NewPkg' and has all the common files, including the edited GitHub Actions workflow *.yaml
files in place. The script will create a Git repo and the corresponding GitHub repository, push the code, and set up CI/CD
workflows and main branch protections.

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
  <repo-directory>              Path to the local project's root directory, e.g. the directory where the solution file is
                                located. The repo name and other settings will be inferred from the name and contents of this
                                directory.
                                Default: the current working directory.
  -gr, --git-repos <path>       The parent directory where the .github workflow templates, vm2.DevOps, and other vm2 project
                                repositories are cloned. Initial from the GIT_REPOS environment variable or '~/repos'
  -o, --owner <owner>           GitHub user or organization that will own the repository
                                From environment variable: ORGANIZATION or default: vmelamed.
                                Used only during repository initialization.
  -n, --name <GH repo name>     Name of the repository to create on GitHub. If not specified, the name will be inferred from the
                                name of the repo directory. Used only during repository initialization.
  --visibility <public|private> Repository visibility. Used only during repository initialization.
                                Default: public
  -b, --branch <branch>         GitHub default branch name. Used only during repository initialization.
                                Default: main
  -d, --description <text>      Short description for the repository (max 350 chars). Ignored if --audit or --configure-only is
                                used. Used only during repository initialization.
  -rs, --ruleset-name <name>    The name of the ruleset for protecting the default branch. Used only during repository
                                configuration.
                                Default: "<GitHub default branch name> protection" - usually 'main protection'

Switches:
  --audit                       Read-only: report current vs expected settings without changes, ignores all other options
  --configure-only              Skip repo creation; configure an existing repo only
  --skip-secrets                Skip setting repository secrets
  --skip-variables              Skip setting repository variables
  --ssh                         Use SSH URL for the remote origin
  --https                       Use HTTPS URL for the remote origin

Note: If multiple '--ssh' and/or '--https' are specified - the last on the command line wins.
$cmn_switches
Examples:
  ${script_name} vm2.Glob --audit
  ${script_name} ~/repos/vm2.Glob --configure-only
  ${script_name} \$GIT_REPOS/vm2.Glob --configure-only --skip-secrets --dry-run
  ${script_name} myorg/vm2.MyPackage --visibility private
EOF
}

function usage()
{
    local long_help=false
    if [[ $# -gt 0 && $1 =~ ^(true|false)$ ]]; then
        long_help=$1
        shift
    fi
    display_usage_msg "$(usage_text "$long_help")" "$@"
}
