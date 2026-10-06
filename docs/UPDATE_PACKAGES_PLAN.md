# Plan: `update-packages.sh` (local machine, version 1)

The key words **MUST**, **MUST NOT**, **SHOULD**, **SHOULD NOT**, and **MAY** in this document are to be interpreted as
described in [RFC 2119](https://www.rfc-editor.org/rfc/rfc2119).

## Goal

Upgrade the NuGet package versions in `Directory.Packages.props` across the vm2 repositories, from the local machine,
without the cross-repo coupling of `update-dependencies.sh` (which is work in progress and out of scope here).

## Decisions

1. **Stable versions only.** The script MUST NOT select prerelease versions (`-preview`, `-rc`, etc.).
2. **Never downgrade.** A package is upgraded only when the newest stable version found is strictly greater than the
   current version under SemVer precedence. Versions currently referenced as prereleases MUST be left alone.
3. **Shared block first (option A).** The shared block between `begin/end shared content` markers in
   `vm2.Templates` is the single source of truth. Packages in that block are upgraded in the SoT first, then copied to
   the repositories with `diff-shared.sh`.
4. **Repository-specific section second.** Each repository's `Directory.Packages.props` section outside the markers is
   upgraded by the script after the shared block has been copied.
5. **Scope.**
   - No repository list (default): all repositories with a `Directory.Packages.props`. The SoT is processed, then
     `diff-shared.sh` runs, then each repository's own section is processed.
   - A repository list: if `vm2.Templates` is in the list, phase 1 (SoT and `diff-shared.sh`) runs first. Otherwise,
     `diff-shared.sh` MUST NOT run, and only the repository-specific sections of the listed repositories are upgraded.
6. **`diff-shared.sh` runs automatically** when phase 1 runs, scoped to `Directory.Packages.props`:
   - all repositories: `diff-shared.sh --all-repos --file Directory.Packages.props --quiet`;
   - a repository list: the same flags, with the listed repositories as positional arguments.
7. **Working tree safety.** Before changing a repository, the script:
   - stashes any local changes, including untracked files, with a message that names the script;
   - creates a branch `deps/update-packages-<yyyy-mm-dd>` from the current `HEAD` (not `origin/main`; that choice is
     deferred to CI);
   - makes the version changes;
   - commits them on that branch;
   - leaves the stash in place and prints the command to restore it.
8. **Commit on the upgrade branch.** The script commits; it MUST NOT push.
9. **Package IDs are compared case-insensitively.** GitHub Packages returns IDs in lowercase (`vm2.testutilities`).
   The casing already in the file MUST be kept when a version is rewritten.
10. **Summary.** The script ends with a table: repository, package, old version, new version, or the reason for not
    upgrading (already latest, prerelease only, not found in any source, downgrade prevented).

## Version lookup

- Use `dotnet package search <id> --exact-match --format json`, which returns all versions per source. `--take` and
  `--skip` are ignored with `--exact-match`, so they are not used.
- Search all configured sources in the local `NuGet.config` (nuget.org and `github.vm2`). For a package found in more
  than one source, the highest stable version wins.
- Compare versions with SemVer precedence (`scripts/bash/lib/_semver.sh`).

## Structure (three-file convention)

- `scripts/bash/src/update-packages.sh` (entry point)
- `scripts/bash/src/update-packages.args.sh` (arguments: optional repository list, `--dry-run`, common switches)
- `scripts/bash/src/update-packages.usage.sh` (help text)
- Library functions in `scripts/bash/src/update-packages.functions.sh` where they are specific to this script.

## Testing

- Tests in `scripts/bash/tests/src/test_update_packages.bats`.
- A fake `dotnet` returns JSON fixtures for `package search`.
- Test cases SHOULD cover: upgrade, no upgrade when already latest, prerelease-only versions ignored, downgrade
  prevented, case-insensitive matching with the original casing kept, marker-aware editing (the shared block is not
  touched in phase 2), dirty tree handling (stash and branch), and `--dry-run` making no changes.

## Out of scope for version 1

- Prerelease selection (an explicit `--allow-prerelease` flag may come later).
- Running in CI, and any reuse of the `update-dependencies.sh` flow (its force-push is not reused).
- Opening pull requests, scheduling, and the `nuget.config` reusable action for CI.
- Choosing the branch base (`origin/main` for CI, deferred).
- Options for a single `Directory.Packages.props`, or combinations of packages (manual for now).

## Open for later

- Whether a repository list without `vm2.Templates` should refresh the shared block from the SoT first.
- Whether to add a `--sot-only` option.
- CI integration as a scheduled or dispatched workflow, possibly on top of the existing Monday PR flow.
