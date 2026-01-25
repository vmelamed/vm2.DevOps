#!/usr/bin/env bash

# shellcheck disable=SC2154 # solution_dir is referenced but not assigned
function usage_text()
{
    local std_switches=""

    if [[ $1 == true ]]; then
        std_switches="$common_switches"
    fi

    cat << EOF
Usage: ${script_name} [--<long option> <value>|-<short option> <value> | --<long switch>|-<short switch> ]*
Moves commits from a specified commit SHA onwards to a new branch, resetting the main branch to the commit before the specified
SHA. This will:
  1. Create new branch <new_branch> with all current commits
  2. Reset main to commit BEFORE <commit_sha>
  3. Push the new branch to the origin (GitHub)
  4. Force push main to the origin (GitHub)
  5. If --check-out-new is specified, check out the new branch

Options:
  -c, --commit-sha <commit-sha> The commit SHA from which to move commits to the new branch.
  -b, --branch <new-branch>     The name of the new branch to create and move commits to.

Switches:
  -n, --check-out-new           After moving the commits, check out the new branch.
$std_switches
Examples:
  ${script_name} --commit-sha ff5c2d182c0d3a01c1f1dfd66c9267f0569d9802 --branch feature/my-feature
  ${script_name} -c ff5c2d1 -b feature/my-feature -n
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
