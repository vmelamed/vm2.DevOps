#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Characterization tests for scripts/bash/src/diff-shared.functions.sh and
# diff-shared.args.sh, as they behave TODAY.
#
# These two files are designed to be 'source'd from diff-shared.sh, after core.sh has already
# established script_name/script_dir/lib_dir as readonly globals. They are exercised the same
# way as the scripts/bash/lib/*.sh characterization tests: each test spawns a fresh, ambient-
# environment-free ('env -i HOME="$HOME" PATH=...') bash subshell that sources core.sh and then
# the file(s) under test, so every test starts from a pristine, deterministic state.
#
# diff-shared.sh proper (the top-level orchestrator) is not exercised end-to-end here -- it is
# an interactive tool that shells out to real diff/merge tools and prompts the user via
# 'confirm'/'choose'. Its logic lives almost entirely in the functions tested below; the
# top-level script itself is a thin driver loop over them.

bats_require_minimum_version 1.5.0

load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../helpers/setup'

_src_dir="$(cd "$lib_dir/../src" && pwd)"

# Sources core.sh then diff-shared.functions.sh (and, when _WITH_ARGS is set by the caller,
# also diff-shared.args.sh + diff-shared.usage.sh) inside a fresh env -i subshell, then runs
# the caller-supplied bash snippet.
_ds() {
    local _extra=""
    if [[ "${1:-}" == "--with-args" ]]; then
        shift
        _extra="source '$_src_dir/diff-shared.functions.sh'
                 source '$_src_dir/diff-shared.args.sh'
                 source '$_src_dir/diff-shared.usage.sh'"
    else
        _extra="source '$_src_dir/diff-shared.functions.sh'"
    fi
    env -i HOME="$HOME" PATH="/usr/local/bin:/usr/bin:/bin" bash -c "
        source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1
        $_extra
        $1
    "
}

_make_ci_repo() {
    local _dir="$1"
    mkdir -p "$_dir/.github/workflows"
    git -C "$_dir" init --quiet --initial-branch=main
    git -C "$_dir" config user.email "test@test.local"
    git -C "$_dir" config user.name "test"
    echo "name: CI" > "$_dir/.github/workflows/ci.yaml"
    git -C "$_dir" add -A
    git -C "$_dir" commit --quiet -m "chore: init"
}

# =====================================================================================
# configure()
# =====================================================================================

@test "configure: bug-exits with the wrong argument count" {
    run _ds 'declare -a source_files=() target_files=() file_actions=(); configure "/tmp"'
    assert_failure 254
}

@test "configure: bug-exits when the SoT directory does not exist" {
    run _ds 'declare -a source_files=() target_files=() file_actions=(); configure "/definitely/not/a/real/path" "$BATS_TEST_TMPDIR"'
    assert_failure 254
}

@test "configure: fails when the config file is missing or empty" {
    mkdir -p "$BATS_TEST_TMPDIR/sot" "$BATS_TEST_TMPDIR/target"
    run _ds "declare -a source_files=() target_files=() file_actions=(); configure '$BATS_TEST_TMPDIR/sot' '$BATS_TEST_TMPDIR/target'"
    assert_failure 1
    assert_output --partial "was not found or is empty"
}

@test "configure: fails on invalid JSON in the config file" {
    mkdir -p "$BATS_TEST_TMPDIR/sot" "$BATS_TEST_TMPDIR/target"
    echo "not json" > "$BATS_TEST_TMPDIR/sot/diff-shared.config.json"
    run _ds "declare -a source_files=() target_files=() file_actions=(); configure '$BATS_TEST_TMPDIR/sot' '$BATS_TEST_TMPDIR/target'"
    assert_failure 1
    assert_output --partial "contains invalid JSON"
}

@test "configure: fails on an invalid action for a file entry" {
    mkdir -p "$BATS_TEST_TMPDIR/sot" "$BATS_TEST_TMPDIR/target"
    echo "x" > "$BATS_TEST_TMPDIR/sot/x.txt"
    cat > "$BATS_TEST_TMPDIR/sot/diff-shared.config.json" <<EOF
{"diff":{},"merge":{},"files":[{"sourceFile":"\$1/x.txt","targetFile":"\$2/x.txt","action":"bogus"}]}
EOF
    run _ds "declare -a source_files=() target_files=() file_actions=(); configure '$BATS_TEST_TMPDIR/sot' '$BATS_TEST_TMPDIR/target'"
    assert_failure 1
    assert_output --partial "'bogus' is not a valid action"
}

@test "configure: fails when a listed source file does not exist" {
    mkdir -p "$BATS_TEST_TMPDIR/sot" "$BATS_TEST_TMPDIR/target"
    cat > "$BATS_TEST_TMPDIR/sot/diff-shared.config.json" <<EOF
{"diff":{},"merge":{},"files":[{"sourceFile":"\$1/missing.txt","targetFile":"\$2/x.txt","action":"copy"}]}
EOF
    run _ds "declare -a source_files=() target_files=() file_actions=(); configure '$BATS_TEST_TMPDIR/sot' '$BATS_TEST_TMPDIR/target'"
    assert_failure 1
    assert_output --partial "does not exist or is empty"
}

@test "configure: succeeds with an empty 'files' array" {
    mkdir -p "$BATS_TEST_TMPDIR/sot" "$BATS_TEST_TMPDIR/target"
    echo '{"diff":{},"merge":{},"files":[]}' > "$BATS_TEST_TMPDIR/sot/diff-shared.config.json"
    run _ds "declare -a source_files=() target_files=() file_actions=(); configure '$BATS_TEST_TMPDIR/sot' '$BATS_TEST_TMPDIR/target'"
    assert_success
}

@test "configure: populates the model arrays, expanding \$1/\$2 as macros for the SoT and target dirs" {
    mkdir -p "$BATS_TEST_TMPDIR/sot" "$BATS_TEST_TMPDIR/target"
    echo "hello" > "$BATS_TEST_TMPDIR/sot/a.txt"
    cat > "$BATS_TEST_TMPDIR/sot/diff-shared.config.json" <<EOF
{"diff":{"tool":"","command":""},
 "merge":{"tool":"","command":""},
 "files":[{"sourceFile":"\$1/a.txt","targetFile":"\$2/a.txt","action":"copy"}]}
EOF
    run _ds "declare -a source_files=() target_files=() file_actions=(); configure '$BATS_TEST_TMPDIR/sot' '$BATS_TEST_TMPDIR/target'; declare -p source_files target_files file_actions"
    assert_success
    assert_output --partial "source_files=([0]=\"$BATS_TEST_TMPDIR/sot/a.txt\")"
    assert_output --partial "target_files=([0]=\"$BATS_TEST_TMPDIR/target/a.txt\")"
    assert_output --partial "file_actions=([0]=\"copy\")"
}

@test "configure: expands the real \${vm2_repos}/\${vm2_sot_shared}/\${target_file_path} macros used in the production config (regression)" {
    # Was previously broken: 'vm2_sot_shared' and 'target_file_path' were never 'local'-declared
    # inside configure(), so the eval-based macro expansion of a real diff-shared.config.json
    # entry (which uses exactly these three macro names, not the '$1'/'$2' shorthand the test
    # above uses) silently expanded to empty strings under 'set -u', or picked up a stale value
    # left over from a previous configure() call in the same process.
    mkdir -p "$BATS_TEST_TMPDIR/sot_config" \
             "$BATS_TEST_TMPDIR/vm2_repos/vm2.Templates/templates/AddNewPackage/content" \
             "$BATS_TEST_TMPDIR/target"
    echo "hello" > "$BATS_TEST_TMPDIR/vm2_repos/vm2.Templates/templates/AddNewPackage/content/a.txt"
    cat > "$BATS_TEST_TMPDIR/sot_config/diff-shared.config.json" <<'JSON'
{"diff":{"tool":"","command":""},
 "merge":{"tool":"","command":""},
 "files":[{"sourceFile":"${vm2_repos}/${vm2_sot_shared}/a.txt","targetFile":"${target_file_path}/a.txt","action":"copy"}]}
JSON
    run _ds "declare vm2_repos='$BATS_TEST_TMPDIR/vm2_repos'; declare sot='AddNewPackage'; declare -a source_files=() target_files=() file_actions=(); configure '$BATS_TEST_TMPDIR/sot_config' '$BATS_TEST_TMPDIR/target'; declare -p source_files target_files file_actions"
    assert_success
    assert_output --partial "source_files=([0]=\"$BATS_TEST_TMPDIR/vm2_repos/vm2.Templates/templates/AddNewPackage/content/a.txt\")"
    assert_output --partial "target_files=([0]=\"$BATS_TEST_TMPDIR/target/a.txt\")"
    assert_output --partial "file_actions=([0]=\"copy\")"
}

# =====================================================================================
# get_tools()
# =====================================================================================

@test "get_tools: bug-exits with the wrong argument count" {
    run _ds 'get_tools'
    assert_failure 254
}

@test "get_tools: bug-exits when the config/customization file does not exist or is empty" {
    run _ds "get_tools '$BATS_TEST_TMPDIR/nope.json'"
    assert_failure 254
}

@test "get_tools: uses the configured tool and command when the tool is available on PATH" {
    cat > "$BATS_TEST_TMPDIR/cfg.json" <<'EOF'
{"diff":{"tool":"diff","command":"diff -q \"$LOCAL\" \"$REMOTE\""},"merge":{"tool":"","command":""}}
EOF
    run _ds "get_tools '$BATS_TEST_TMPDIR/cfg.json' 2>/dev/null"
    assert_success
    assert_line --index 0 "diff"
    assert_line --index 1 'diff -q "$LOCAL" "$REMOTE"'
}

@test "get_tools: warns and returns an empty merge tool/command when nothing is configured or available" {
    # diff.tool/command are given explicitly (and found on PATH) so this test is not sensitive
    # to which diff tools happen to be installed in the environment; only the merge tool
    # ('code', which is not on the minimal PATH used here) is left unresolvable.
    cat > "$BATS_TEST_TMPDIR/cfg.json" <<'EOF'
{"diff":{"tool":"diff","command":"diff -q \"$LOCAL\" \"$REMOTE\""},"merge":{"tool":"","command":""}}
EOF
    run _ds "get_tools '$BATS_TEST_TMPDIR/cfg.json'"
    assert_success
    assert_output --partial "No merge tool was configured or none is available"
    run _ds "get_tools '$BATS_TEST_TMPDIR/cfg.json' 2>/dev/null"
    assert_line --index 2 ""
    assert_line --index 3 ""
}

# =====================================================================================
# are_different()
# =====================================================================================

@test "are_different: bug-exits with the wrong argument count" {
    run _ds "are_different '$BATS_TEST_TMPDIR/a'"
    assert_failure 254
}

@test "are_different: bug-exits when either file does not exist" {
    touch "$BATS_TEST_TMPDIR/a.txt"
    run _ds "are_different '$BATS_TEST_TMPDIR/a.txt' '$BATS_TEST_TMPDIR/missing.txt' false"
    assert_failure 254
}

@test "are_different: returns failure (negative) and counts 'identical' for two identical files" {
    echo "same" > "$BATS_TEST_TMPDIR/a.txt"
    echo "same" > "$BATS_TEST_TMPDIR/b.txt"
    run _ds "declare -i summary_identical_count=0 summary_diff_count=0
             are_different '$BATS_TEST_TMPDIR/a.txt' '$BATS_TEST_TMPDIR/b.txt' false
             echo \"RC=\$?\"
             declare -p summary_identical_count summary_diff_count"
    assert_success
    assert_output --partial "RC=1"
    assert_output --partial 'summary_identical_count="1"'
    assert_output --partial 'summary_diff_count="0"'
}

@test "are_different: returns success (positive) and counts 'diff' for two different files" {
    echo "one" > "$BATS_TEST_TMPDIR/a.txt"
    echo "two" > "$BATS_TEST_TMPDIR/b.txt"
    run _ds "declare -i summary_identical_count=0 summary_diff_count=0
             are_different '$BATS_TEST_TMPDIR/a.txt' '$BATS_TEST_TMPDIR/b.txt' false
             echo \"RC=\$?\"
             declare -p summary_identical_count summary_diff_count"
    assert_success
    assert_output --partial "RC=0"
    assert_output --partial 'summary_diff_count="1"'
    assert_output --partial 'summary_identical_count="0"'
}

# =====================================================================================
# merge()
# =====================================================================================

@test "merge: bug-exits with the wrong argument count" {
    run _ds "merge '$BATS_TEST_TMPDIR/a.txt'"
    assert_failure 254
}

@test "merge: returns success and counts 'merged' when the merge command changes the target file" {
    echo "sot content" > "$BATS_TEST_TMPDIR/sot.txt"
    echo "target content" > "$BATS_TEST_TMPDIR/target.txt"
    run _ds "declare -i summary_merged_count=0 summary_not_merged_count=0
             merge_command='cp \"\$REMOTE\" \"\$MERGED\"'
             merge '$BATS_TEST_TMPDIR/sot.txt' '$BATS_TEST_TMPDIR/target.txt'
             echo \"RC=\$?\"
             declare -p summary_merged_count summary_not_merged_count
             cat '$BATS_TEST_TMPDIR/target.txt'"
    assert_success
    assert_output --partial "RC=0"
    assert_output --partial 'summary_merged_count="1"'
    assert_output --partial "sot content"
}

@test "merge: returns failure and counts 'not merged' when the target file is unchanged" {
    echo "sot content" > "$BATS_TEST_TMPDIR/sot.txt"
    echo "target content" > "$BATS_TEST_TMPDIR/target.txt"
    run _ds "declare -i summary_merged_count=0 summary_not_merged_count=0
             merge_command='true'
             merge '$BATS_TEST_TMPDIR/sot.txt' '$BATS_TEST_TMPDIR/target.txt'
             echo \"RC=\$?\"
             declare -p summary_not_merged_count"
    assert_success
    assert_output --partial "RC=1"
    assert_output --partial 'summary_not_merged_count="1"'
}

# =====================================================================================
# copy_file()
# =====================================================================================

@test "copy_file: bug-exits with the wrong argument count" {
    run _ds "copy_file '$BATS_TEST_TMPDIR/a.txt'"
    assert_failure 254
}

@test "copy_file: bug-exits when the source file does not exist" {
    run _ds "copy_file '$BATS_TEST_TMPDIR/missing.txt' '$BATS_TEST_TMPDIR/dest.txt'"
    assert_failure 254
}

@test "copy_file: creates the destination directory and copies the file, counting the copy" {
    echo "content" > "$BATS_TEST_TMPDIR/src.txt"
    run _ds "declare -i summary_copied_count=0
             copy_file '$BATS_TEST_TMPDIR/src.txt' '$BATS_TEST_TMPDIR/newdir/dest.txt'
             declare -p summary_copied_count
             cat '$BATS_TEST_TMPDIR/newdir/dest.txt'"
    assert_success
    assert_output --partial 'summary_copied_count="1"'
    assert_output --partial "content"
}

@test "copy_file: in dry-run mode, prints what it would do and does not touch the filesystem" {
    echo "content" > "$BATS_TEST_TMPDIR/src.txt"
    run _ds "set_dry_run
             copy_file '$BATS_TEST_TMPDIR/src.txt' '$BATS_TEST_TMPDIR/dryrundir/dest.txt'
             [[ -e '$BATS_TEST_TMPDIR/dryrundir' ]] && echo EXISTS || echo NOT-CREATED"
    assert_success
    assert_output --partial "dry-run\$ mkdir -p"
    assert_output --partial "dry-run\$ cp"
    assert_output --partial "NOT-CREATED"
}

# =====================================================================================
# customize()
# =====================================================================================

@test "customize: bug-exits with the wrong argument count" {
    run _ds "customize"
    assert_failure 254
}

@test "customize: bug-exits when the target directory does not exist" {
    run _ds "customize '/definitely/not/a/real/path'"
    assert_failure 254
}

@test "customize: bug-exits on a non-boolean tools-only flag" {
    run _ds "customize '$BATS_TEST_TMPDIR' maybe"
    assert_failure 254
}

@test "customize: is a no-op when no custom config file exists" {
    run _ds "customize '$BATS_TEST_TMPDIR'"
    assert_success
}

@test "customize: fails on invalid JSON in the custom config file" {
    echo "not json" > "$BATS_TEST_TMPDIR/diff-shared.custom.json"
    run _ds "customize '$BATS_TEST_TMPDIR'"
    assert_failure 1
    assert_output --partial "contains invalid JSON"
}

@test "customize: overrides the diff/merge tools and per-file actions from the custom config" {
    mkdir -p "$BATS_TEST_TMPDIR/target"
    cat > "$BATS_TEST_TMPDIR/target/diff-shared.custom.json" <<'EOF'
{
  "diff": {"tool": "diff", "command": "diff -q \"$LOCAL\" \"$REMOTE\""},
  "merge": {"tool": "", "command": ""},
  "action_overrides": {"a.txt": "ignore", "unknown/path.txt": "copy"}
}
EOF
    run _ds "config_diff_tool='olddiff'; config_diff_command='old --cmd'
             config_merge_tool='oldmerge'; config_merge_command='old --merge'
             declare -a target_files=('$BATS_TEST_TMPDIR/target/a.txt' '$BATS_TEST_TMPDIR/target/b.txt')
             declare -a file_actions=('merge' 'merge')
             diff_only=false
             customize '$BATS_TEST_TMPDIR/target'
             echo \"RC=\$?\"
             declare -p diff_tool diff_command merge_tool merge_command file_actions"
    assert_success
    assert_output --partial "RC=0"
    assert_output --partial 'diff_tool="diff"'
    assert_output --partial 'merge_tool="oldmerge"'
    assert_output --partial 'file_actions=([0]="ignore" [1]="merge")'
    assert_output --partial "does not match any known target relative path"
}

@test "customize: with the tools-only flag, does not touch file_actions" {
    mkdir -p "$BATS_TEST_TMPDIR/target"
    cat > "$BATS_TEST_TMPDIR/target/diff-shared.custom.json" <<'EOF'
{
  "diff": {"tool": "diff", "command": "diff -q \"$LOCAL\" \"$REMOTE\""},
  "merge": {"tool": "", "command": ""},
  "action_overrides": {"a.txt": "ignore"}
}
EOF
    run _ds "config_diff_tool='olddiff'; config_diff_command='old --cmd'
             config_merge_tool='oldmerge'; config_merge_command='old --merge'
             declare -a target_files=('$BATS_TEST_TMPDIR/target/a.txt')
             declare -a file_actions=('merge')
             customize '$BATS_TEST_TMPDIR/target' true
             declare -p file_actions"
    assert_success
    assert_output --partial 'file_actions=([0]="merge")'
}

# =====================================================================================
# resolve_target()
# =====================================================================================

@test "resolve_target: bug-exits with the wrong argument count" {
    run _ds "declare root='' path=''; resolve_target '$BATS_TEST_TMPDIR' 'r' root"
    assert_failure 254
}

@test "resolve_target: bug-exits when the vm2-repos parent argument is not a directory" {
    run _ds "declare root='' path=''; resolve_target '/definitely/not/a/real/path' 'r' root path"
    assert_failure 254
}

@test "resolve_target: bug-exits on undefined output nameref variables" {
    run _ds "resolve_target '$BATS_TEST_TMPDIR' 'r' not_a_var_1 not_a_var_2"
    assert_failure 254
}

@test "resolve_target: fails with err_not_found for a repo name that doesn't exist anywhere" {
    run _ds "declare root='' path=''; resolve_target '$BATS_TEST_TMPDIR' 'no-such-repo' root path"
    assert_failure 9
}

@test "resolve_target: resolves a well-formed local git repo with CI configured" {
    mkdir -p "$BATS_TEST_TMPDIR/parent"
    _make_ci_repo "$BATS_TEST_TMPDIR/parent/goodrepo"
    run _ds "declare root='' path=''
             resolve_target '$BATS_TEST_TMPDIR/parent' 'goodrepo' root path
             echo \"RC=\$?\"
             declare -p root path"
    assert_success
    assert_output --partial "RC=0"
    assert_output --partial "root=\"$BATS_TEST_TMPDIR/parent/goodrepo\""
}

@test "resolve_target: warns and succeeds for a directory with CI configured that isn't a git repo yet" {
    mkdir -p "$BATS_TEST_TMPDIR/parent/nocirepo/.github/workflows"
    echo "name: CI" > "$BATS_TEST_TMPDIR/parent/nocirepo/.github/workflows/ci.yaml"
    run _ds "declare root='' path=''
             resolve_target '$BATS_TEST_TMPDIR/parent' 'nocirepo' root path
             echo \"RC=\$?\""
    assert_success
    assert_output --partial "not a git repository yet"
    assert_output --partial "RC=0"
}

# =====================================================================================
# parameterize()
# =====================================================================================

@test "parameterize: fails when no --file* selectors were provided" {
    run _ds "declare -A selectors_actions=(); declare -a source_files=() file_actions=(); parameterize"
    assert_failure 2
}

@test "parameterize: overrides the action for a matching file and clears the action for any file that matches no selector" {
    run _ds "declare -A selectors_actions=(['a.txt']='ignore')
             declare -a source_files=('/repo/templates/a.txt' '/repo/templates/b.txt')
             declare -a file_actions=('merge' 'merge')
             parameterize
             echo \"RC=\$?\"
             declare -p file_actions"
    assert_success
    assert_output --partial "RC=0"
    assert_output --partial 'file_actions=([0]="ignore" [1]="")'
}

@test "parameterize: clears the action and warns when multiple selectors match with different actions" {
    run _ds "declare -A selectors_actions=(['a.txt']='ignore' ['*.txt']='copy')
             declare -a source_files=('/repo/templates/a.txt')
             declare -a file_actions=('merge')
             parameterize
             declare -p file_actions"
    assert_success
    assert_output --partial "Multiple patterns matched"
    assert_output --partial 'file_actions=([0]="")'
}

@test "parameterize: clears the action for a file matched by no selector" {
    run _ds "declare -A selectors_actions=(['other.txt']='ignore')
             declare -a source_files=('/repo/templates/a.txt')
             declare -a file_actions=('merge')
             parameterize
             declare -p file_actions"
    assert_success
    assert_output --partial 'file_actions=([0]="")'
}

# =====================================================================================
# diff-shared.args.sh: get_arguments()
# =====================================================================================

@test "get_arguments: collects positional arguments as target repos, de-duplicated" {
    run _ds --with-args "declare -a arguments=(); set_quiet
                          get_arguments myrepo myrepo otherrepo
                          declare -p target_repos"
    assert_success
    assert_output --partial 'target_repos=([0]="myrepo" [1]="otherrepo")'
}

@test "get_arguments: --all-repos populates target_repos from vm2_repositories" {
    run _ds --with-args "declare -a arguments=(); set_quiet
                          get_arguments --all-repos
                          echo \"count=\${#target_repos[@]}\""
    assert_success
    assert_output --partial "count=${#vm2_repositories[@]}"
}

@test "get_arguments: --vm2-repos, --source-of-truth, --diff, and --summary set the corresponding variables" {
    run _ds --with-args "declare -a arguments=(); set_quiet
                          get_arguments --vm2-repos /some/path --source-of-truth AddNewPackage --diff --summary '$BATS_TEST_TMPDIR/sum.md'
                          declare -p vm2_repos sot diff_only summary_file"
    assert_success
    assert_output --partial 'vm2_repos="/some/path"'
    assert_output --partial 'sot="AddNewPackage"'
    assert_output --partial 'diff_only="true"'
    assert_output --partial "summary_file=\"$BATS_TEST_TMPDIR/sum.md\""
}

@test "get_arguments: --current-branch/-cb sets not_main, defaulting unset otherwise" {
    run _ds --with-args "declare -a arguments=(); set_quiet
                          get_arguments --current-branch
                          declare -p current_branch"
    assert_success
    assert_output --partial 'current_branch="true"'

    run _ds --with-args "declare -a arguments=(); set_quiet
                          get_arguments -cb
                          declare -p current_branch"
    assert_success
    assert_output --partial 'current_branch="true"'

    run _ds --with-args "declare -a arguments=(); set_quiet
                          get_arguments myrepo
                          declare -p current_branch"
    assert_success
    refute_output --partial 'current_branch="true"'
}

@test "get_arguments: --file* option variants map to the right action via get_selector_action" {
    run _ds --with-args "declare -a arguments=(); set_quiet
                          get_arguments --file-ignore '*.yaml' --file-copy '*.props'
                          declare -p selectors_actions"
    assert_success
    assert_output --partial '["*.yaml"]="ignore"'
    assert_output --partial '["*.props"]="copy"'
}

@test "get_arguments: an unspecified action for --file leaves the selector's action empty (use the pre-configured action)" {
    run _ds --with-args "declare -a arguments=(); set_quiet
                          get_arguments --file '*.yaml'
                          declare -p selectors_actions"
    assert_success
    assert_output --partial '["*.yaml"]=""'
}

@test "get_arguments: fails with usage when a value-taking option is given without a value" {
    run _ds --with-args "declare -a arguments=(); set_quiet; get_arguments --vm2-repos"
    assert_failure 1
    assert_output --partial "Missing value for --vm2-repos"
}

@test "get_arguments: -h prints usage and exits 0" {
    run _ds --with-args "declare -a arguments=(); set_quiet; get_arguments -h"
    assert_success
    assert_output --partial "Usage:"
}

@test "get_arguments: creates and later cleans up a temp summary file when --summary is not given (regression)" {
    # The trap is registered on EXIT of the subshell that get_arguments runs in; checking the
    # file's existence *inside* that same process (before EXIT fires) is what's observable here.
    run _ds --with-args "declare -a arguments=(); set_quiet
                          get_arguments
                          [[ -f \"\$summary_file\" ]] && echo CREATED || echo MISSING"
    assert_success
    assert_output --partial "CREATED"
}

# =====================================================================================
# diff-shared.args.sh: get_selector_action()
# =====================================================================================

@test "get_selector_action: bug-exits on the wrong argument count" {
    run _ds --with-args "get_selector_action 'x'"
    assert_failure 254
    assert_output --partial "requires exactly 2 arguments"
}

@test "get_selector_action: fails with usage on an invalid action name" {
    run _ds --with-args "declare -A selectors_actions=(); get_selector_action '--file-bogus' 'a.txt'"
    assert_failure 1
    assert_output --partial "Invalid action: bogus"
}

@test "get_selector_action: fails with usage when the file selector itself looks like an option" {
    run _ds --with-args "declare -A selectors_actions=(); get_selector_action '--file' '-badselector'"
    assert_failure 1
    assert_output --partial "does not appear to be a valid file selector"
}

@test "get_selector_action: accepts the short 'mc'/'am'/'ac' action aliases" {
    run _ds --with-args "declare -A selectors_actions=()
                          get_selector_action '--filemc' 'a.txt'
                          declare -p selectors_actions"
    assert_success
    assert_output --partial '[a.txt]="merge or copy"'
}
