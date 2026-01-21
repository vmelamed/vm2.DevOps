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

    ATTENTION: It is assumed that all repositories are under the same parent
    directory that is specified on the command line or in the environment
    variable \$GIT_REPOS.

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
        The prefix used for MinVer version tags in the repositories. Used to
        detect the latest stable version tag of the source repositories
        'vm2.DevOps' and '.github'.
        Initial from the MINVERTAGPREFIX environment variable or 'v'.

Environment Variables:

    GIT_REPOS       The parent directory where the .github workflow templates,
                    vm2.DevOps, and project repositories are cloned.

    When ${script_name} is run, it compares a pre-defined set of files from the
    cloned 'vm2.DevOps' and '.github' repositories with the corresponding files
    in the specified project repository. If any of the files differ, the script
    can take one of the following *actions* based on the standard and custom
    configurations:
        - "copy" - copy the source file over the target file
        - "ask to copy" - prompts the user, if they want to copy the source file
          over the target file
        - "merge or copy" - asks the user if they want to:
            - ignore the differences
            - merge the differences using 'Visual Studio Code' (if installed)
            - copy the source file over the target file
          and performs the selected action
        - "ignore" - ignore the differences for this file.

    In the project repository, a custom configuration file named
    'diff-common.actions.json' can be created to modify the default *actions*.
    The file must contain a JSON object with
        - properties names - the relative paths of the target files for which
          you want the *action* modified
        - property values - the *action* that the ${script_name} should do when
          differences are found for the specified target file. The action must
          be one of the listed above.

    An example of a custom configuration file 'diff-common.actions.json':

    {
      "codecov.yml": "ignore",
      "test.runsettings": "ignore"
    }

EOF
}

function usage()
{
    text="$(usage_text)"
    display_usage_msg  "$text" "$@"
}
