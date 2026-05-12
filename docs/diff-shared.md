# Command Line Tool: `diff-shared.sh`

<!-- TOC tocDepth:2..3 chapterDepth:2..6 -->

- [Command Line Tool: `diff-shared.sh`](#command-line-tool-diff-sharedsh)
  - [Source of Truth (SoT)](#source-of-truth-sot)
  - [Assumptions](#assumptions)
  - [Diff and Merge Tools](#diff-and-merge-tools)
  - [Actions](#actions)
    - [Configuring Actions in the Global Configuration File `diff-shared.config.json`](#configuring-actions-in-the-global-configuration-file-diff-sharedconfigjson)
    - [Customizing Actions with the Repository-Specific Configuration File `diff-shared.custom.json`](#customizing-actions-with-the-repository-specific-configuration-file-diff-sharedcustomjson)
  - [CLI Parameters](#cli-parameters)
    - [Common CLI Parameters](#common-cli-parameters)
    - [Positional Arguments](#positional-arguments)
    - [Named Arguments](#named-arguments)
    - [Switches](#switches)
    - [Usage Examples](#usage-examples)

<!-- /TOC -->

## Source of Truth (SoT)

There are many files in the VM2 repositories that are identical or almost identical to files with the same names in other VM2 projects (repositories) created from the same `dotnet new <template-short-name>` template. All or at least big parts of their content is copied and they stay that way - we say that *they have **shared** content*. This shared content may drift with time (due to bug fixes, extensions, etc.) and it must be kept in sync across repositories. The ***sources of truth* (SoT)** for the shared content are the corresponding files in the in the `vm2.Templates` repository. E.g., the SoT files for the projects that produce NuGet packages is in the `AddNewPackage` template and they are located in the `$VM2_REPOS/vm2.Templates/templates/AddNewPackage/content` directory. We call `AddNewPackage` the ***source of truth***. It uniquely identifies the ***source of truth directory*** `$VM2_REPOS/vm2.Templates/templates/AddNewPackage/content` that contains ***source of truth files***.

> [!IMPORTANT]
> ***The Bash script `diff-shared.sh` is an interactive command-line tool that helps keep the files with shared content from one or more repositories in sync with the corresponding Source of Truth***.

It **compares one by one a set of *target files* with the corresponding *source-of-truth (SoT) files*** and when a target file is missing or differs from its SoT counterpart it takes certain, configured actions (e.g. ask the user if they want to ignore the differences, merge or copy the SoT file to the target file, etc.). The action for each file is specified in:

1. A global configuration file (`diff-shared.config.json`) located in the SoT directory (e.g. `$VM2_REPOS/vm2.Templates/templates/AddNewPackage/content`)
2. A repository-specific file (`diff-shared.custom.json`) in the root of the target repository (e.g. `$VM2_REPOS/vm2.TestUtilities`), which overrides the global configuration for that repository only
1. CLI parameters, which override both configuration file for the duration of the current script run

## Assumptions

1. The script is intended to be run interactively from a Linux, macOS, or Git Bash terminals in a **`Bash` shell**. It is interactive because the user may be prompted to confirm or to choose an action for some of the files that are missing or different.
1. **All *vm2* repositories** (or at least `vm2.DevOps` and `vm2.Templates`) **are cloned under the same <u>*parent directory*</u>** that can be specified with:
   - the environment variable `$VM2_REPOS`
   - command line option `--vm2-repos <parent-directory>`
   - default to the parent directory of the root of the working tree of the `diff-shared.sh` script's Git repository, e.g. if the path of the script is `$HOME/repos/vm2/vm2.DevOps/scripts/bash/diff-shared.sh`, then the default *vm2* parent is `$HOME/repos/vm2/` and the expected structure of the repositories under it is:

     ```text
     $HOME$/repos/vm2/ (= $VM2_REPOS)            <-- the vm2 parent directory of all vm2 repositories
                  ├── vm2.DevOps/                    <-- the root of the Git repository containing `diff-shared.sh`
                  │   └── scripts/
                  │       └── bash/
                  │           ├── diff-shared.sh         <--- the diff-shared.sh script
                  │           ├── repo-setup.sh
                  │           ├── ...
                  ├── vm2.Templates/
                  ├── vm2.Ulid/
                  ├── ...
     ```

   This **parent directory** is also referred to as *the vm2 parent* throughout this document
1. The target repository contains a solution created with the `dotnet new <template-short-name>` template.
1. The target directory either **is** or **will become** a **git repository** with CI workflows configured (GitHub Actions workflow templates) in `.github/workflows/`. This is automatically true for repositories created with the `dotnet new vm2pkg` template.

    > [!NOTE]
    > Immediately after creating a new NuGet package project, consider running the script `repo-setup.sh` (adjacent to `diff-shared.sh` in the `vm2.DevOps` repo) to create and set up its GitHub repository with the correct structure and content, including the CI workflow templates, variables, secrets, rules and protections.

1. The SoT files are located in the *vm2.Templates* repository, already cloned under the vm2 parent, e.g. in `$VM2_REPOS/vm2.Templates/templates/<sot>/content/`. The vm2.Templates repository **must** be in sync with its Git remote.
1. Both the target files and their SoT counterparts are **predefined**. The files are specified as relative paths in both locations. The predefined set is in `diff-shared.config.json` in the SoT directory; its actions can be overridden by `diff-shared.custom.json` in the target repository or by CLI parameters.

    > [!NOTE]
    > The set of files cannot be changed by `diff-shared.custom.json` or the CLI parameters — only the action for each file can be overridden. For example, `diff-shared.config.json` may specify that `Directory.Build.props` should be copied from the SoT when it differs, but `diff-shared.custom.json` can override that to `merge-or-copy`.

## Diff and Merge Tools

To determine the action, the script must first **compare** the target file with its SoT counterpart. For that it uses the standard `diff` utility in a quiet mode, which is fast and is usually available on all platforms. Then, if the files differ, and depending on the configuration the script may need to just **show** the differences to the user, and then **ask them what they want to do** about the displayed differences. Displaying the differences can be done on the terminal CLI or in a graphical UI diff tool, depending on the configuration. We recommend configuring and using a user-friendly CLI diff tool such as [delta](https://github.com/dandavison/delta) - we found, that visual tools like `Visual Studio Code` or `meld` work but are not very convenient for **just** displaying the differences.

After comparing the files and showing the differences, the script may need to open a tool to **merge** the the SoT file changes into the the target file. This can be done again in a terminal CLI or in a graphical UI merge tool, as well, also depending on the configuration. However, for merge we do recommend a good UI tool like `Visual Studio Code` or  [`Meld`](https://meldmerge.org/).

If not configured explicitly in `diff-shared.config.json` or `diff-shared.custom.sh` the script uses the diff and merge utilities configured in `Git` for displaying and merging. If Git is not configured, it falls back to the good old `diff` and Visual Studio Code, respectively.

The tools can be customized in the `diff` and `merge` sections of `diff-shared.config.json` and overridden in `diff-shared.custom.json` using the `diff.tool` and `merge.tool` properties, respectively. The command to run the tool can be customized with the `diff.command` and `merge.command` properties. The `*.command` properties **must** use the placeholders `$LOCAL` and `$REMOTE`, which the script replaces at runtime with the paths of the target file and its SoT counterpart, respectively. For example:

```json
{
    "diff": {
        "tool": "delta",
        "command": "delta --side-by-side --line-numbers --paging never \"$LOCAL\" \"$REMOTE\""
    },
    "merge": {
        "tool": "code",
        "command": "code --new-window --wait --diff \"$REMOTE\" \"$LOCAL\" \"$REMOTE\" \"$LOCAL\""
    }
    // ...
}
```

## Actions

There are 6 actions that can be taken when a file is missing or differs from the SoT:

- `ignore` — do nothing; just list the difference in the summary
- `merge or copy` — display a menu and ask the user what to do:
  1. do nothing (ignore the difference)
  1. open the configured merge tool to merge the SoT file changes into the target file
  1. copy the SoT file over the target file
- `ask to merge` — ask the user whether to open the merge tool (yes/no)
- `ask to copy` — ask the user whether to copy the SoT file over the target file (yes/no)
- `merge` — open the merge tool, without prompting
- `copy` — copy the SoT file over the target file, without prompting

### Configuring Actions in the Global Configuration File `diff-shared.config.json`

This file is mandatory and must be located in the SoT directory. It defines the set of files to compare, the default action for each, and the diff/merge tools to use. For example:

```json
{
    "diff": {
        "tool": "delta",
        "command": "delta --side-by-side --line-numbers --paging never \"$LOCAL\" \"$REMOTE\""
    },
    "merge": {
        "tool": "code",
        "command": "code --new-window --wait --diff \"$REMOTE\" \"$LOCAL\" \"$REMOTE\" \"$LOCAL\""
    },
    "files": [
        {
            "sourceFile": "${vm2_repos}/$vm2_sot_shared/.github/workflows/Release.yaml",
            "targetFile": "${target_path}/.github/workflows/Release.yaml",
            "action": "ask to merge"
        },
        {
            "sourceFile": "${vm2_repos}/$vm2_sot_shared/.github/workflows/ClearCache.yaml",
            "targetFile": "${target_path}/.github/workflows/ClearCache.yaml",
            "action": "copy"
        },
        {
            "sourceFile": "${vm2_repos}/$vm2_sot_shared/.editorconfig",
            "targetFile": "${target_path}/.editorconfig",
            "action": "ask to copy"
        },
        {
            "sourceFile": "${vm2_repos}/$vm2_sot_shared/.gitignore",
            "targetFile": "${target_path}/.gitignore",
            "action": "copy"
        },
        ...
    ]
}
```

File paths may contain variables that the script resolves at runtime:

- `${vm2_repos}` — the vm2 parent directory, e.g. `/home/user/repos/vm2`
- `${vm2_sot_shared}` — path to the SoT files relative to the vm2 parent, e.g. `vm2.Templates/templates/AddNewPackage/content`
- `${target_path}` — path to the target repository

The example above configures:

1. `delta` as the diff tool and Visual Studio Code as the merge tool
2. A custom merge command that opens a new VS Code window and waits for the user to close it before proceeding (the default `code --diff` does not wait and reuses an existing window, which can be confusing)
3. Ask the user whether to merge `Release.yaml` when it differs from the SoT
4. Copy `ClearCache.yaml` from the SoT automatically, without asking
5. Ask the user whether to copy `.editorconfig` when it differs
6. Copy `.gitignore` from the SoT automatically, without asking

See the full [`diff-shared.config.json`](https://github.com/vmelamed/vm2.DevOps/blob/main/scripts/bash/diff-shared.config.json) for the actual default configuration used by the script.

### Customizing Actions with the Repository-Specific Configuration File `diff-shared.custom.json`

This file is optional and if present, it must be placed in the root of the target repository. It can override the diff/merge tools and the action for specific files. It cannot add or remove files from the predefined set. For example:

```json
{
    "diff": {
        "tool": "diff"
    },
    "merge": {
        "tool": "code",
        "command": "code --new-window --wait --diff \"$REMOTE\" \"$LOCAL\" \"$REMOTE\" \"$LOCAL\""
    },
    "action_overrides": {
        "codecov.yaml": "ignore",
        "coverage.settings.xml": "ignore",
        "testconfig.json": "ignore"
    }
}
```

In this example, the diff tool is overridden to plain `diff`, and three files are set to `ignore` regardless of the global configuration. File names in `action_overrides` are matched by name only, not by full path.

## CLI Parameters

### Common CLI Parameters

The script supports the standard set of common CLI switches:

- `-v`, `--verbose`: enables verbose output. Initial value from `$VERBOSE` or `false`
- `-x`, `--trace`:
  1. Sets `--verbose`
  2. Redirects suppressed output from `/dev/null` to `/dev/stderr`
  3. Enables the Bash trace option `set -x`
- `-y`, `--dry-run`: suppress execution of commands wrapped in `execute` and display what would have been run. Initial value from `$DRY_RUN` or `false`
- `-q`, `--quiet`: suppresses all user prompts, assuming default answers. Initial value from `$QUIET` or `false`
- `--help`: displays the full usage text, including all common flags
- `-h`, `-?`: displays a shorter usage text without the common flags. If both `--help` and `-h`/`-?` are present, the last one wins

### Positional Arguments

The script accepts one or more target repository paths as positional arguments:

```text
<target-repo-dir1> <target-repo-dir2> ... <target-repo-dirN>
```

1. If no positional arguments are provided, the script compares the files in the current directory with the SoT.
2. Each argument should be an existing or future repository name (looked up under the vm2 parent) or an absolute or relative path.

### Named Arguments

- `--vm2-repos <directory>` (`-r`) — the vm2 parent directory. Overrides `$VM2_REPOS`
- `--source-of-truth <sot>` (`-s`) — the SoT template. Must be one of the pre-defined templates under `$VM2_REPOS/vm2.Templates/templates/`
- `--summary <file>` — write the run summary to `<file>` in Markdown format. If not specified, a temporary file is created, displayed at the end of the run, and then deleted
- `--file <pattern>` (`-f`) — a comma-separated list of glob patterns. Only files matching the patterns are processed and only if they are listed in the configuration
- `--file-ignore <pattern>` — same as `--file` but overrides the action to `ignore`
- `--file-merge-or-copy <pattern>` — same as `--file` but overrides the action to `merge or copy`
- `--file-ask-to-merge <pattern>` — same as `--file` but overrides the action to `ask to merge`
- `--file-merge <pattern>` — same as `--file` but overrides the action to `merge`
- `--file-ask-to-copy <pattern>` — same as `--file` but overrides the action to `ask to copy`
- `--file-copy <pattern>` — same as `--file` but overrides the action to `copy`

### Switches

- `--all-repos` (`-a`) — compare all pre-defined vm2 repositories under the vm2 parent with the SoT, one by one. The set is defined in `lib/core.sh`.

    > [!WARNING]
    > Every time you add a new repository to the vm2 parent, you must add it to `vm2_repositories` in `lib/core.sh`.

- `--diff` — compare files using `diff` only, and display the differences and equalities without taking any action. Can be combined with `--all-repos`.

### Usage Examples

Assuming `diff-shared.sh` is on `$PATH`:

1. Compare all predefined files in the **current** directory with the SoT, applying the configured action for each difference:

    ```bash
    diff-shared.sh
    ```

2. Compare all predefined files in a specific repository (e.g. `vm2.Ulid`):

    ```bash
    diff-shared.sh vm2.Ulid
    ```

3. Compare files in two repositories one after the other:

    ```bash
    diff-shared.sh vm2.Ulid vm2.SemVer
    ```

4. Compare files in all pre-defined vm2 repositories:

    ```bash
    diff-shared.sh --all-repos
    ```

5. Compare only `Directory.Build.props` in the current repository, using the configured action:

    ```bash
    diff-shared.sh --file "Directory.Build.props"
    ```

6. Compare two specific files:

    ```bash
    diff-shared.sh --file "Directory.Build.props,Directory.Packages.props"
    ```

    > [!NOTE]
    > Multiple files are specified as a **comma-separated** list without spaces. The argument accepts **glob patterns**, so `Directory.*.props` matches all props files starting with `Directory.`.

7. Compare `Directory.Build.props` and, if different, ask the user whether to merge:

    ```bash
    diff-shared.sh --file-ask-to-merge "Directory.Build.props"
    ```

8. Copy `Directory.Build.props` from the SoT without prompting:

    ```bash
    diff-shared.sh --file-copy "Directory.Build.props"
    ```

9. Apply `--file-copy` to all `*.toml` files in a specific repository:

    ```bash
    diff-shared.sh vm2.SemVer --file-copy "*.toml"
    ```

10. Merge all `*.yaml` files across all repositories without prompting:

    ```bash
    diff-shared.sh --all-repos --file-merge "*.yaml"
    ```

11. Display differences only, without taking any action:

    ```bash
    diff-shared.sh --diff
    ```
