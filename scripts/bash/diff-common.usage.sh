#!/bin/bash

function usage_text()
{
    # shellcheck disable=SC2154 # solution_dir is referenced but not assigned.
    cat << EOF
Usage:

    ${script_name} [<project-repo-path>] |
        [--<long option> <value>|-<short option> <value> |
         --<long switch>|-<short switch> ]*

    Diff-s a pre-defined set of files from the cloned 'vm2.DevOps' and '.github'
    repositories with the corresponding files in the specified project
    repository.

    It is not expected that all files will be present in the project repository
    or will be identical. The goal of this tool is to help the user:
    1) identify differences between their project repository and the standard
       templates and
    2) determine whether they need to update their project files to align with
       the latest templates.

Parameters:
    <project-repo-name>
        The path to the target project repository or if it is under the same
        directory as the .github and vm2.DevOps, just the name of the target
        project repository to diff against the templates.

Switches:$common_switches
Options:
    --repos | -r
        The parent directory where the .github workflow templates and vm2.DevOps
        are cloned.
        Initial from the GIT_REPOS environment variable or '~/repos'.

    --minver-tag-prefix | -t
        The prefix used for MinVer version tags in the repositories.
        Initial from the MinVerTagPrefix environment variable or 'v'.

Environment Variables:

    GIT_REPOS       The parent directory where the .github workflow templates,
                    vm2.DevOps, and project repositories are cloned.

EOF
}

function usage()
{
    display_usage_msg "$(usage_text)" "$@"
}
