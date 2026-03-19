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

Parameters:
  <repo-directory>              Path to the project's local repository root directory, e.g. the directory where the solution
                                file is located. If not specified, the script will try the current working directory. If it is
                                not an absolute path, the script will try to resolve it relative to the vm2 repositories (see
                                below '--vm2-repos') and finally relative to the current working directory. The repository
                                directory cannot be the same as the vm2.DevOps or the .github workflow templates directories.

Options:
  --vm2-repos <path>            The parent directory where the '.github' workflow templates, 'vm2.DevOps', and other vm2
                                repositories are cloned
                                Initial from the \$VM2_REPOS environment variable or '\$HOME/repos/vm2'
  -o, --owner <owner>           GitHub user or organization that will own the repository
                                From environment variable: ORGANIZATION or default: vmelamed.
                                Used only during repository creation
  -n, --repo-name <name>        Name of the GitHub repository to create. If not specified, the name will be inferred from the
                                name of the repo directory. Used only during repository creation
  --visibility [public|private] Repository visibility. Used only during repository creation
                                Default: public
  -b, --branch <branch>         GitHub default branch name. Used only during repository creation
                                Default: main
  -d, --description <text>      Short description for the GitHub repository (max 350 chars). Used only during repository
                                creation
  -rs, --ruleset-name <name>    The name of the ruleset for protecting the default branch (main). Used only during repository
                                creation
                                Default: "<GitHub default branch name> protection" - usually 'main protection'

Switches:
  -a, --audit                   Read-only: report current vs expected settings and values without any changes, ignores all other
                                options
  -s, --ssh                     Use SSH URL for the remote origin. Used only during repository creation
  -t, --https                   Use HTTPS URL for the remote origin. Used only during repository creation
  -iv, --interactive-vars       Prompts the user to enter the values of the repository variables interactively.
  -is, --interactive-secrets    Prompts the user to enter the values of the repository secrets interactively.

Note: If multiple '--ssh' and/or '--https' are specified - the last on the command line wins.
$cmn_switches
Examples:
  ${script_name} vm2.Glob --audit
  ${script_name} ~/repos/vm2.Glob
  ${script_name} \$VM2_REPOS/vm2.Glob --interactive-secrets --verbose
  ${script_name} vmelamed/vm2.MyPackage --visibility private
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
