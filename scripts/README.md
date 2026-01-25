TODO:

    1) the project directory is cloned under the same parent directory as the
       source-of-truth repositories 'vm2.DevOps' and '.github'
    2) for most projects, the target files are located as follows:
       - in the root directory are some common files (e.g. 'LICENSE',
         '.editorconfig', '.gitignore', 'Directory.*.props', etc.)
       - in the '.github/workflows' sub-directory within the project directory
         are the GitHub Actions workflow '*.yaml' files
       - in the 'scripts' sub-directory within the project directory
         are the bash scripts '*.sh' files
       - the 'src' sub-directory in the project directory contains project
         source code files, projects and other related files
       - the 'test' sub-directory in the project directory contains test source
         code files, projects and other related files


        - for dotnet template projects, the target files are located in a
          sub-directory within the project directory (e.g. 'src/MyProject')

    It is not expected that all files will be present in the project directory
    or will be identical. The goal of this tool is to help the user:
    1) identify differences between their project directory and the standard
       templates and
    2) determine whether they need to update their project files to align with
       the latest templates.

    ATTENTION: It is assumed that all repositories are cloned under the same
    parent directory that is specified by the environment variable \$GIT_REPOS
    or by a command line option.



    ${script_name} compares a pre-defined set of files from the
    cloned repositories 'vm2.DevOps' and '.github' with the corresponding files
    in the specified project directory (local repository). If any of the files
    differ, the script can take one of the following *actions* based on the
    standard and custom configurations:
        - "ignore" - ignore the differences for this file.
        - "copy" - copy the source file over the target file
        - "ask to copy" - prompts the user, if they want to copy the source file
          over the target file
        - "merge or copy" - asks the user if they want to:
            - ignore the differences and continue
            - merge the differences using your configured merge tool or VS Code
            - copy the source file over the target file
          and performs the selected action

    In the project repository, a custom configuration file named
    'diff-common.actions.json' can be created to modify the default *actions*.
    The file must contain a single JSON object with
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
