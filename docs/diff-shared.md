# Command Line Tool: `diff-shared.sh`

<!-- TOC tocDepth:2..3 chapterDepth:2..6 -->

- [Command Line Tool: `diff-shared.sh`](#command-line-tool-diff-sharedsh)
  - [What is it?](#what-is-it)
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

## What is it?

The Bash script `diff-shared.sh` is an interactive, command-line tool that helps keep files with shared content across one or more repositories in sync with the corresponding source-of-truth (SoT) repository.

Early on, when we were planning the set of **vm2** repositories and creating their initial content, we relied heavily on copy-pasting from one repository to another, especially for files required for CI workflows (e.g. GitHub Actions workflow YAML files) and for GitHub repository configuration, dev conventions and rules, etc. To name a few such files: `.editorconfig`, `.gitignore`, `.github/dependabot.yml`, `.github/workflows/CI.yaml` etc. This was a quick and efficient way to bootstrap the initial content, but it created the problem of keeping that *shared content* in sync. There are many files in the vm2 repositories that are identical or nearly identical to files, usually with the same names, in other vm2 projects (repositories) that were created from the same template by issuing a command like `dotnet new <template-name>`. Much of their content is simply copied over and stays that way, so we say that *these files have **shared** content*.

The ***sources of truth*** (*SoT*) for the ***shared content*** are the corresponding files in a `vm2.Templates` template repository. E.g., the SoT files for projects that produce NuGet packages are in the subdirectory `templates/AddNewPackage/content`, or in the full path `$VM2_REPOS/vm2.Templates/templates/AddNewPackage/content`. We call the template directory `AddNewPackage` the ***source of truth*** (*SoT*) for NuGet package projects.

 > [!NOTE]
 > `diff-shared.sh` **compares, one by one, a set of *files with shared content* (a.k.a. ***target files***) with the corresponding *source-of-truth (SoT) files***, and when a target file is missing or differs from its SoT counterpart, it takes a configurable action for that file.

For example, the actions can be:

- ask the user if they want to
  - ignore the differences
  - merge
  - copy the SoT file over the target file
- ask the user if they want to copy the SoT file over the target file without merging
- open a merge tool without asking to merge the differences
- copy without asking
- etc.

The action for each file is specified in:

1. A global configuration file (`diff-shared.config.json`) located in the **SoT directory** (e.g. `$VM2_REPOS/vm2.Templates/templates/AddNewPackage/content`) defines the default action for each file and the diff/merge tools to use. This file is mandatory and must be present in the SoT directory.
1. A repository-specific file (`diff-shared.custom.json`) in the root of the **target repository** (e.g. `$VM2_REPOS/vm2.TestUtilities`), which may override the global configuration for that repository for specific files
1. CLI parameters, which override both configuration files for the duration of the current run of the script

## Assumptions

1. The script is intended to be run interactively from a Linux, macOS, or Git Bash terminal in a **`Bash` shell**. It is interactive because the user may be prompted to confirm or choose an action for some of the files that are missing or different.
1. **All *vm2* repositories** (or at least `vm2.DevOps` and `vm2.Templates`) **are cloned under the same *parent directory*** that can be specified with:
   - the environment variable **`$VM2_REPOS`**
   - command line option **`--vm2-repos <parent-directory>`**
   - defaults to the parent directory of the **root of the working tree of the `diff-shared.sh` script's Git repository**. E.g. if the path of the script is `$HOME/repos/vm2/vm2.DevOps/scripts/bash/diff-shared.sh`, and `$VM2_REPOS` and `--vm2-repos` are not defined or specified, then the default *vm2* parent is `$HOME/repos/vm2/` and the expected structure of the repositories under it is expected to be as follows:

     ```text
     $HOME/repos/vm2/                         <------- the vm2 PARENT DIRECTORY of all vm2 repositories
                 │                                    (defined by $VM2_REPOS or --vm2-repos or default)
                 │
                 ├── vm2.DevOps/                <---- the Git repository containing `diff-shared.sh`
                 │   └─ scripts/
                 │      └─ bash/
                 │         ├── diff-shared.sh      <- the diff-shared.sh script
                 │         ├── repo-setup.sh
                 │         ├── ...
                 │
                 ├── vm2.Templates/
                 │   └─ templates/
                 │      └─ AddNewPackage/
                 │         └─ content/           <--- the SOT FILES
                 |            ├─ diff-shared.config.json  <- global config per (SOT) template (mandatory!)
                 │            ├─ .github/
                 │            │  ├─ workflows/
                 │            │  │  ├─ CI.yaml
                 │            │  │  ├─ ...
                 │            │  ├─ ...
                 │            ├─ .editorconfig
                 │            ├─ .gitignore
                 │            ├─ ...
                 │
                 ├── vm2.Ulid/                   <--- the TARGET FILES
                 |   ├─ diff-shared.custom.json    <- per repo custom configuration (optional)
                 │   ├─ .editorconfig
                 │   ├─ .gitignore
                 │   ├─ .github/
                 │   │  ├─ workflows/
                 │   │  │  ├─ CI.yaml
                 ├── ...
     ```

   > [!NOTE]
   > The **parent directory** is also referred to as *the vm2 parent* throughout this document.

1. The target repository contains a solution created with the `dotnet new <template-short-name>` template.
1. The target directory either **is** or **will become** a **git repository** with CI workflows configured (GitHub Actions workflow templates) in `.github/workflows/`. This is automatically true for repositories created with the `dotnet new vm2pkg` template.

    > [!NOTE]
    > Immediately after creating a new NuGet package project, consider running the script `repo-setup.sh` (adjacent to `diff-shared.sh` in the `vm2.DevOps` repo) to create and set up its GitHub repository with the correct structure and content, including the CI workflow templates, variables, secrets, rules and protections.

1. The SoT files are located in the *vm2.Templates* repository, already cloned under the vm2 parent, e.g. in `$VM2_REPOS/vm2.Templates/templates/<sot>/content/`. The vm2.Templates repository **must** be in sync with its Git remote.
1. Both the target files and their SoT counterparts are **predefined**. The files are specified as relative paths in both locations. The predefined set is in `diff-shared.config.json` in the SoT directory; its actions can be overridden by `diff-shared.custom.json` in the target repository or by CLI parameters.

    > [!NOTE]
    > The set of files cannot be changed by `diff-shared.custom.json` or the CLI parameters — only the action for each file can be overridden. For example, `diff-shared.config.json` may specify that `Directory.Build.props` should be copied from the SoT when it differs, but `diff-shared.custom.json` can override that to `merge-or-copy`.

## Diff and Merge Tools

To determine the action, the script must first **compare** the target file with its SoT counterpart. For that, it uses the standard `diff` utility in quiet mode, which is fast and is usually available on all platforms. Then, if the files differ, and depending on the configuration, the script may need to just **show** the differences to the user and then **ask them what they want to do** about them. Displaying the differences can be done in the terminal CLI or in a graphical UI diff tool, depending on the configuration. We recommend configuring and using a user-friendly CLI diff tool such as [delta](https://github.com/dandavison/delta); we found that visual tools like `Visual Studio Code` or `meld` work but are not very convenient for **just** displaying the differences.

After comparing the files and showing the differences, the script may need to open a tool to **merge** the SoT file changes into the target file. This can also be done in a terminal CLI or in a graphical UI merge tool, depending on the configuration. However, for merging we do recommend a good UI tool like `Visual Studio Code` or [`Meld`](https://meldmerge.org/).

If not configured explicitly in `diff-shared.config.json` or `diff-shared.custom.json`, the script uses the diff and merge utilities configured in `Git` for displaying and merging. If Git is not configured, it falls back to the good old `diff` and Visual Studio Code, respectively.

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
- `-y`, `--dry-run`: suppresses execution of commands wrapped in `execute` and displays what would have been run. Initial value from `$DRY_RUN` or `false`
- `-q`, `--quiet`: suppresses all user prompts, assuming default answers. Initial value from `$QUIET` or `false`
- `--help`: displays the full usage text, including all common flags
- `-h`, `-?`: displays a shorter usage text without the common flags. If both `--help` and `-h`/`-?` are present, the last one wins

### Positional Arguments

The script accepts one or more target repository paths as positional arguments:

```text
<target-repo-dir1> <target-repo-dir2> ... <target-repo-dirN>
```

1. If no positional arguments are provided, the script compares the files in the current directory with the SoT.
1. Each argument can be a repository name (looked up under the vm2 parent) or an absolute or relative path to a directory that is the working tree root or inside it.

### Named Arguments

- `--vm2-repos <directory>` (`-r`) — the vm2 parent directory. Overrides `$VM2_REPOS`
- `--source-of-truth <sot>` (`-s`) — the SoT template. Must be one of the pre-defined templates under `$VM2_REPOS/vm2.Templates/templates/`
- `--file <file-selector>` (`-f`) — the file selector can be a file name or a **quoted** glob pattern. Can be specified multiple times to select multiple files. Only files matching the selector are processed and only if they are listed in the configuration. The argument can be specified multiple times to select multiple files. For example,
  - `diff-shared.sh --file Directory.Build.props --file Directory.Packages.props` is equivalent to
  - `diff-shared.sh --file "Directory.*Build*.props"`.

  > [!WARNING]
  > If you do not quote the glob pattern, the shell will expand it before passing it to the script, and the script will receive the list of matched files instead of the pattern. This leads to unexpected results: the first file will be accepted as a parameter value, but the rest will be treated as positional arguments (target repositories), which is not the intended use.

- The action for the selected file(s) is determined by the configuration, unless overridden by the following variants of the option `--file`:

  - `--file-ignore <file-selector>` — overrides the configured action to `ignore`
  - `--file-merge-or-copy <file-selector>` — overrides the configured action to `merge or copy`
  - `--file-ask-to-merge <file-selector>` — overrides the configured action to `ask to merge`
  - `--file-merge <file-selector>` — overrides the configured action to `merge`
  - `--file-ask-to-copy <file-selector>` — overrides the configured action to `ask to copy`
  - `--file-copy <file-selector>` — overrides the configured action to `copy`
- `--summary <file>` — write the script run summary to `<file>` in Markdown format. If not specified, a temporary file is created, displayed at the end of the run with `glow`, and then deleted.

### Switches

- `--all-repos` (`-a`) — compare all pre-defined vm2 repositories under the vm2 parent with the SoT, one by one. The set is defined in `lib/core.sh`.

    > [!WARNING]
    > For this to work, every time you add a new repository to the vm2 parent, you must add it to `vm2_repositories` array in `$VM2_HOME/vm2.DevOps/scripts/bash/lib/core.sh`.

- `--diff` (`-d`) — compare files and display differences and equalities without taking any action. Can be combined with `--all-repos`.

### Usage Examples

Assuming `diff-shared.sh` is on `$PATH` and the current directory is inside any of the vm2 repositories, here are some example usages:

1. Compare all predefined files in the **current** directory with the SoT, applying the configured action for each difference:

    ```bash
    diff-shared.sh # the current directory is the target repository, and the SoT is determined by the configuration
    ```

2. Compare all predefined files in a specific repository (e.g. `vm2.Ulid`):

    ```bash
    diff-shared.sh vm2.Ulid # the script will try to resolve the target repo from the vm2 parent, e.g. $VM2_REPOS/vm2.Ulid
    ```

3. Compare files in two repositories one after the other:

    ```bash
    diff-shared.sh vm2.Ulid vm2.SemVer # the script will process both targets one after the other
    ```

4. Compare files in all pre-defined vm2 repositories:

    ```bash
    diff-shared.sh --all-repos # the script will process all targets one after the other
    ```

5. Compare only `Directory.Build.props` in the current repository, using the configured action:

    ```bash
    diff-shared.sh --file Directory.Build.props # the script will only process the file Directory.Build.props, the action is determined by the configuration
    ```

6. Compare two specific files:

    ```bash
    diff-shared.sh --file-merge-or-copy "*.props" # the script will process all files matching the glob pattern *.props, and for each difference, it will ask the user whether to ignore, merge or copy the SoT file over the target file
    ```

7. Compare `Directory.Build.props` and `Directory.Packages.props` and, if different, ask the user whether to merge:

    ```bash
    diff-shared.sh --file-ask-to-merge "Directory.Build.props" --file-ask-to-merge "Directory.Packages.props"
    ```

8. Copy `.editorconfig` from the SoT without prompting:

    ```bash
    diff-shared.sh --file-copy ".editorconfig" # the script will copy .editorconfig from the SoT to the target repository without asking, if it is different or missing in the target repository
    ```

9. Apply `--file-copy` to all `*.toml` files in a specific repository:

    ```bash
    diff-shared.sh vm2.SemVer --file-copy "*.toml" # the script will copy all .toml files from the SoT to the target repository without asking, if they are different or missing in the target repository
    ```

10. Merge all `*.yaml` files across all repositories without prompting:

    ```bash
    diff-shared.sh --all-repos --file-merge "*.yaml"
    ```

11. Display equalities and differences of the files from the current repo only, without taking any action:

    ```bash
    diff-shared.sh --diff
    ```
