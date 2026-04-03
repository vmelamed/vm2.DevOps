# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -xr common_switches
declare -xr common_vars
declare -xr script_name

function usage_text()
{
    local long_text=$1
    local switches=""
    local vars=""

    if $long_text; then
        switches="$common_switches"
        vars="Environment Variables:$common_vars"
    fi

    cat << EOF
Usage: ${script_name} [<repo-directory>] [--<long option> <value>|-<short option> <value> | --<long switch>|-<short switch> ]*

Bootstrap and configure a repository for a vm2 package project. This script assumes that the project has already been created
locally, e.g. using 'dotnet new vm2.NewPkg' and has all the common files, including the *edited* GitHub Actions workflow *.yaml
files in place. The script will:
  - Initialize a git repository (if it isn't already)
  - Do an initial commit of the current code in it
  - Create the GitHub repository (if it does not exist already)
  - Link the local repository to the GitHub repository
  - Push the initial commit to the GitHub repository
  - Configure repository settings (rebase merge, auto-delete branches, etc.)
  - Configure Actions workflow permissions (uses the token from 'gh auth login', default=read)
  - Set required secrets and variables for use by the CI/CD workflows
  - Create a ruleset for the repository that protects the default branch ("main") with required status checks

Later you can use the --audit switch to perform a read-only audit of the current repository state (settings, vars, etc.) vs the
expected state based on the script's logic and the local and remote repositories contents. This can help identify
misconfigurations or drift without making changes.

The script is idempotent and can be safely re-run to update settings or fix issues.

Parameters:
  <repo-directory-path>         Path to the project's directory. If it is not an absolute path, the script will try to resolve
                                its absolute location from the vm2 repositories (see the option '--vm2-repos' below). The
                                repository directory cannot be the same as the paths to 'vm2.DevOps' or the '.github' workflow
                                templates directories. If not specified, the script will try the current working directory

Options:
  --vm2-repos <path>            The parent directory where the 'vm2.DevOps' and other vm2 repositories exist (cloned). The value
                                comes from:
                                1) the explicit path specified on the command line with this option, or
                                2) the value of the \$VM2_REPOS environment variable, or
                                3) heuristically, by assuming that the directory of this script is within the git working tree
                                   of the 'vm2.DevOps' repository and that all vm2 repositories are cloned in the same parent
                                   directory - the directory that will be used as the value for the '--vm2-repos' option.
                                The value of this option is needed on every run of this script.
  -o, --owner <owner>           GitHub user ID or organization that will own the GitHub repository. If omitted, the value will
                                be taken from the environment variable ORGANIZATION or the default: 'vmelamed'. Used during
                                linking the local repository to GitHub
  -n, --repo-name <name>        Name of the GitHub repository to create. If not specified, the script will ask the user
                                interactively, inferring the default name from the name of the repo directory. Used during
                                linking the local repository to GitHub
  -d, --description <text>      Short description for the GitHub repository (max 350 chars). If not specified, the script will
                                ask the user interactively with a default - the name of the repository. Used during linking the
                                local repository to GitHub
  --visibility [public|private] Repository visibility. Used during linking the local repository to GitHub. Default: 'public'
  -b, --branch <branch>         GitHub default branch name. Used during linking the local repository to GitHub. Default: 'main'
  -rs, --ruleset-name <name>    The name of the ruleset for protecting the default branch (main). Used during linking the local
                                repository to GitHub. Default: "<GitHub default branch name> protection", e.g. 'main protection'

Switches:
  -s, --ssh                     Specifies that SSH will be used by git for communicating with the remote origin - GitHub. Used
                                during linking the local repository to GitHub
  -t, --https                   Specifies that HTTPS will be used by git for communicating with the remote origin - GitHub. Used
                                during linking the local repository to GitHub
                                NOTE: the script does not setup the SSH keys or HTTPS credentials automatically. Only one
                                communication protocol can be used. If multiple '--ssh' and/or '--https' options are specified -
                                the last on the command line wins. If neither is used, the script will ask the user
                                interactively with a default - SSH.
  -iv, --interactive-vars       Prompts the user to enter the values of the repository variables interactively, instead of using
                                the default values. Can be used at anytime
  -is, --interactive-secrets    Prompts the user to enter the values of the repository secrets interactively, instead of
                                creating them automatically with placeholder values. Can be used at anytime anytime
  -slc, --skip-local-config     Skips the local configuration of the repository. Can be used at anytime
  -a, --audit                   Displays a report of current vs expected state of the repository: variables, secrets, settings
                                and policies. Use this option alone when the repository already exists and is linked to a GitHub
                                repository and none of the --interactive-* options are specified. In any other case, the script
                                will run its normal course and will display the audit at the end anyway.
$switches
$vars
Examples:
  ${script_name} ~/repos/vm2.Glob
  ${script_name} \$VM2_REPOS/vm2.Glob --interactive-secrets --verbose
  ${script_name} vmelamed/vm2.MyPackage --visibility private --ssh
  ${script_name} vm2.Glob --audit

Configured local Git settings:
  core.hooksPath                Set to '\$VM2_REPOS/vm2.DevOps/scripts/githooks'
                                Tells Git where to find repository hook scripts (e.g. pre-commit, commit-msg).
  commit.template               Set to '\$VM2_REPOS/vm2.DevOps/scripts/githooks/.gitmessage'
                                Specifies the default commit message template shown when creating commits.
  pull.rebase                   Set to 'true'
                                Makes 'git pull' rebase local commits on top of upstream changes instead of merging.
  fetch.prune                   Set to 'true'
                                Automatically removes stale remote-tracking branches deleted on the remote.
  push.autoSetupRemote          Set to 'true'
                                Auto-sets upstream tracking when pushing a new local branch for the first time.

EOF
}
