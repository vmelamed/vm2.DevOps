#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Characterization tests for scripts/bash/src/diff-shared.configuration.sh, as it behaves TODAY.
#
# These files are designed to be 'source'd from diff-shared.sh, after core.sh has already established
# script_name/script_dir/lib_dir as readonly globals. They are exercised the same way as the scripts/bash/lib/*.sh
# characterization tests: each test spawns a fresh, ambient-environment-free ('env -i HOME="$HOME" PATH=...') bash
# subshell that sources core.sh and then the file(s) under test, so every test starts from a pristine, deterministic state.
#
# diff-shared.sh proper (the top-level orchestrator) is not exercised end-to-end here -- it is an interactive tool that
# shells out to real diff/merge tools and prompts the user via 'confirm'/'choose'. Its logic lives almost entirely in the
# functions tested in test_diff_shared_*.bats; the top-level script itself is a thin driver loop over them.

bats_require_minimum_version 1.5.0

load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../helpers/setup'

# ShellCheck can't see that '../helpers/setup' transplants these into this file's scope at load
# time. '-g' is required (see feedback_bats_declare_g_readonly memory for the root cause).
declare -gx lib_dir
declare -gxi err_invalid_arguments
declare -gxi err_argument_value
declare -gxi err_invalid_json

_src_dir="$(cd "$lib_dir/../src" && pwd)"

# Sources core.sh, then diff-shared.configuration.sh, diff-shared.functions.sh, and diff-shared.summary.sh inside a fresh
# env -i subshell, then runs the caller-supplied bash snippet.
_ds() {
    env -i HOME="$HOME" PATH="/usr/local/bin:/usr/bin:/bin" bash -c "
        source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1
        source '$_src_dir/diff-shared.configuration.sh'
        source '$_src_dir/diff-shared.functions.sh'
        source '$_src_dir/diff-shared.summary.sh'
        $1
    "
}

# configure()/customize() validate their JSON config against a sibling schema file (see validate_json_schema() in
# _sanitize.sh); a directory must have this schema file present, or validate_json_schema() itself bug-exits on the
# missing/empty argument before configure()'s own graceful error handling for the config file ever runs. These helpers
# place a real copy of the schema next to a test's fixture config, matching production layout.
_stub_config_schema() {
    cp "$_src_dir/diff-shared.config.schema.json" "$1/diff-shared.config.schema.json"
}

_stub_custom_schema() {
    cp "$_src_dir/diff-shared.custom.schema.json" "$1/diff-shared.custom.schema.json"
}

# =====================================================================================
# configure()
# =====================================================================================

@test "configure: bug-exits with the wrong argument count" {
    run _ds 'declare -a source_files=() target_files=() file_actions=(); configure "/tmp" "second"'
    assert_failure "$err_invalid_arguments"
    refute_output --partial "requires argument 2" # a missing argument is reported once, as missing
}

@test "configure: bug-exits when the SoT directory does not exist" {
    run _ds 'declare -a source_files=() target_files=() file_actions=(); configure "/definitely/not/a/real/path"'
    assert_failure "$err_argument_value"
}

declare -xr BATS_TEST_TMPDIR

@test "configure: fails when the config file is missing or empty" {
    mkdir -p "$BATS_TEST_TMPDIR/sot" "$BATS_TEST_TMPDIR/target"
    _stub_config_schema "$BATS_TEST_TMPDIR/sot"
    run _ds "declare -a source_files=() target_files=() file_actions=(); configure '$BATS_TEST_TMPDIR/sot'"
    assert_failure "$err_argument_value"
    assert_output --partial "was not found or is empty"
}

@test "configure: fails on invalid JSON in the config file" {
    mkdir -p "$BATS_TEST_TMPDIR/sot" "$BATS_TEST_TMPDIR/target"
    _stub_config_schema "$BATS_TEST_TMPDIR/sot"
    echo "not json" > "$BATS_TEST_TMPDIR/sot/diff-shared.config.json"
    run _ds "declare -a source_files=() target_files=() file_actions=(); configure '$BATS_TEST_TMPDIR/sot'"
    assert_failure "$err_argument_value"
    assert_output --partial "contains invalid JSON"
}

@test "configure: fails on an invalid action for a file entry" {
    # This sandboxed test PATH has no check-jsonschema, so real schema enforcement of the
    # "action" enum never runs here -- this exercises the redundant runtime
    # 'is_in "$_file_action" ...' check inside configure()'s own per-file loop instead.
    mkdir -p "$BATS_TEST_TMPDIR/sot" "$BATS_TEST_TMPDIR/target"
    _stub_config_schema "$BATS_TEST_TMPDIR/sot"
    echo "x" > "$BATS_TEST_TMPDIR/sot/x.txt"
    cat > "$BATS_TEST_TMPDIR/sot/diff-shared.config.json" <<EOF
{"files":[{"sourceFile":"\$1/x.txt","targetFile":"\$2/x.txt","action":"bogus"}]}
EOF
    run _ds "declare -a source_files=() target_files=() file_actions=(); configure '$BATS_TEST_TMPDIR/sot'"
    assert_failure "$err_argument_value"
    assert_output --partial "'bogus' is not a valid action"
}

@test "configure: fails when a listed source file does not exist" {
    mkdir -p "$BATS_TEST_TMPDIR/sot" "$BATS_TEST_TMPDIR/target"
    _stub_config_schema "$BATS_TEST_TMPDIR/sot"
    cat > "$BATS_TEST_TMPDIR/sot/diff-shared.config.json" <<EOF
{"files":[{"sourceFile":"\$1/missing.txt","targetFile":"\$2/x.txt","action":"copy"}]}
EOF
    run _ds "declare -a source_files=() target_files=() file_actions=(); configure '$BATS_TEST_TMPDIR/sot'"
    assert_failure "$err_argument_value"
    assert_output --partial "does not exist or is empty"
}

@test "configure: succeeds with an empty 'files' array" {
    mkdir -p "$BATS_TEST_TMPDIR/sot" "$BATS_TEST_TMPDIR/target"
    _stub_config_schema "$BATS_TEST_TMPDIR/sot"
    echo '{"files":[]}' > "$BATS_TEST_TMPDIR/sot/diff-shared.config.json"
    run _ds "declare -a source_files=() target_files=() file_actions=(); configure '$BATS_TEST_TMPDIR/sot'"
    assert_success
}

@test "configure: populates the model arrays, expanding \$1 as a macro for the SoT dir but leaving the target file as an unexpanded template" {
    # configure() writes into 'config_source_files'/'config_target_files'/'config_file_actions'
    # (the SoT-loaded defaults) -- not the plain 'source_files'/'target_files'/'file_actions'
    # names, which are only populated later, per-repository, by copying from these config_*
    # arrays (see diff-shared.sh's main loop). The FIX this test now pins: with multiple target
    # repos, target file paths can no longer be expanded once during general configuration (that
    # bug reused the FIRST target repo's paths for every repo) -- configure() now stores
    # 'targetFile' as a raw '${target_repo_path}' template, deferring expansion to
    # configure_target_files(), which runs once per target repo (see the tests below).
    mkdir -p "$BATS_TEST_TMPDIR/sot" "$BATS_TEST_TMPDIR/target"
    _stub_config_schema "$BATS_TEST_TMPDIR/sot"
    echo "hello" > "$BATS_TEST_TMPDIR/sot/a.txt"
    cat > "$BATS_TEST_TMPDIR/sot/diff-shared.config.json" <<'EOF'
{"files":[{"sourceFile":"$1/a.txt","targetFile":"${target_repo_path}/a.txt","action":"copy"}]}
EOF
    run _ds "declare -a config_source_files=() config_target_files=() config_file_actions=(); configure '$BATS_TEST_TMPDIR/sot'; declare -p config_source_files config_target_files config_file_actions"
    assert_success
    assert_output --partial "config_source_files=([0]=\"$BATS_TEST_TMPDIR/sot/a.txt\")"
    assert_output --partial 'config_target_files=([0]="\${target_repo_path}/a.txt")'
    assert_output --partial "config_file_actions=([0]=\"copy\")"
}

@test "configure: expands the real \${vm2_repos}/\${vm2_sot_shared} macros used in the production config for the source file (regression)" {
    # Was previously broken: 'vm2_sot_shared' was never 'local'-declared inside configure(), so
    # the eval-based macro expansion of a real diff-shared.config.json entry (which uses exactly
    # this macro name, not the '$1' shorthand the test above uses) silently expanded to an empty
    # string under 'set -u', or picked up a stale value left over from a previous configure()
    # call in the same process.
    mkdir -p "$BATS_TEST_TMPDIR/sot_config" \
             "$BATS_TEST_TMPDIR/vm2_repos/vm2.Templates/templates/AddNewPackage/content" \
             "$BATS_TEST_TMPDIR/target"
    _stub_config_schema "$BATS_TEST_TMPDIR/sot_config"
    echo "hello" > "$BATS_TEST_TMPDIR/vm2_repos/vm2.Templates/templates/AddNewPackage/content/a.txt"
    cat > "$BATS_TEST_TMPDIR/sot_config/diff-shared.config.json" <<'JSON'
{"files":[{"sourceFile":"${vm2_repos}/${vm2_sot_shared}/a.txt","targetFile":"${target_repo_path}/a.txt","action":"copy"}]}
JSON
    run _ds "declare vm2_repos='$BATS_TEST_TMPDIR/vm2_repos'; declare sot='AddNewPackage'; declare -a config_source_files=() config_target_files=() config_file_actions=(); configure '$BATS_TEST_TMPDIR/sot_config'; declare -p config_source_files config_target_files config_file_actions"
    assert_success
    assert_output --partial "config_source_files=([0]=\"$BATS_TEST_TMPDIR/vm2_repos/vm2.Templates/templates/AddNewPackage/content/a.txt\")"
    assert_output --partial 'config_target_files=([0]="\${target_repo_path}/a.txt")'
    assert_output --partial "config_file_actions=([0]=\"copy\")"
}

# =====================================================================================
# configure_target_files()
# =====================================================================================

@test "configure_target_files: expands each target file template against the given target repo path" {
    mkdir -p "$BATS_TEST_TMPDIR/sot" "$BATS_TEST_TMPDIR/target"
    _stub_config_schema "$BATS_TEST_TMPDIR/sot"
    echo "hello" > "$BATS_TEST_TMPDIR/sot/a.txt"
    cat > "$BATS_TEST_TMPDIR/sot/diff-shared.config.json" <<'EOF'
{"files":[{"sourceFile":"$1/a.txt","targetFile":"${target_repo_path}/a.txt","action":"copy"}]}
EOF
    run _ds "declare -a config_source_files=() config_target_files=() config_file_actions=()
             configure '$BATS_TEST_TMPDIR/sot'
             declare -a expanded=()
             configure_target_files '$BATS_TEST_TMPDIR/target' expanded
             echo \"RC=\$?\"
             declare -p expanded"
    assert_success
    assert_output --partial "RC=0"
    assert_output --partial "expanded=([0]=\"$BATS_TEST_TMPDIR/target/a.txt\")"
}

@test "configure_target_files: re-expands against a DIFFERENT target repo path on a second call (regression: multi-repo bug)" {
    # The bug this pins: target file paths used to be expanded once, during general
    # configuration, against whichever target repo happened to be configured first -- every
    # OTHER target repo in a multi-repo run then silently got the first repo's paths. Calling
    # configure_target_files() twice, once per (different) target repo, must yield two
    # DIFFERENT expansions from the same config_target_files templates.
    mkdir -p "$BATS_TEST_TMPDIR/sot" "$BATS_TEST_TMPDIR/target1" "$BATS_TEST_TMPDIR/target2"
    _stub_config_schema "$BATS_TEST_TMPDIR/sot"
    echo "hello" > "$BATS_TEST_TMPDIR/sot/a.txt"
    cat > "$BATS_TEST_TMPDIR/sot/diff-shared.config.json" <<'EOF'
{"files":[{"sourceFile":"$1/a.txt","targetFile":"${target_repo_path}/a.txt","action":"copy"}]}
EOF
    run _ds "declare -a config_source_files=() config_target_files=() config_file_actions=()
             configure '$BATS_TEST_TMPDIR/sot'
             declare -a expanded1=() expanded2=()
             configure_target_files '$BATS_TEST_TMPDIR/target1' expanded1
             configure_target_files '$BATS_TEST_TMPDIR/target2' expanded2
             declare -p expanded1 expanded2"
    assert_success
    assert_output --partial "expanded1=([0]=\"$BATS_TEST_TMPDIR/target1/a.txt\")"
    assert_output --partial "expanded2=([0]=\"$BATS_TEST_TMPDIR/target2/a.txt\")"
}

@test "configure_target_files: bug-exits with the wrong argument count" {
    run _ds "configure_target_files '$BATS_TEST_TMPDIR'"
    assert_failure "$err_invalid_arguments"
}

@test "configure_target_files: bug-exits when the target repo directory does not exist" {
    run _ds "declare -a out=(); configure_target_files '/definitely/not/a/real/path' out"
    assert_failure "$err_argument_value"
}

@test "configure_target_files: bug-exits on a non-indexed-array output variable name" {
    run _ds "declare -A not_an_array=(); configure_target_files '$BATS_TEST_TMPDIR' not_an_array"
    assert_failure "$err_argument_value"
}

# =====================================================================================
# get_tools()
# =====================================================================================

@test "get_tools: bug-exits with the wrong argument count" {
    run _ds 'get_tools'
    assert_failure "$err_invalid_arguments"
}

@test "get_tools: bug-exits when the config/customization file does not exist or is empty" {
    run _ds "get_tools '$BATS_TEST_TMPDIR/nope.json'"
    assert_failure "$err_argument_value"
}

@test "get_tools: uses the configured tool and command when the tool is available on PATH" {
    cat > "$BATS_TEST_TMPDIR/cfg.json" <<'EOF'
{"diff":{"tool":"diff","command":"diff -q \"$LOCAL\" \"$REMOTE\""},"merge":{"tool":"","command":""}}
EOF
    run _ds "get_tools '$BATS_TEST_TMPDIR/cfg.json' true 2>/dev/null"
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
    run _ds "get_tools '$BATS_TEST_TMPDIR/cfg.json' true"
    assert_success
    assert_output --partial "No 'merge' tool was configured or none is available"
    run _ds "get_tools '$BATS_TEST_TMPDIR/cfg.json' true 2>/dev/null"
    assert_line --index 2 ""
    assert_line --index 3 ""
}

# =====================================================================================
# customize()
# =====================================================================================

@test "customize: bug-exits with the wrong argument count" {
    run _ds "customize"
    assert_failure "$err_invalid_arguments"
}

@test "customize: bug-exits when the target directory does not exist" {
    run _ds "customize '/definitely/not/a/real/path'"
    assert_failure "$err_argument_value"
}

@test "customize: bug-exits with an extra argument" {
    # customize() takes exactly two arguments (SoT dir, target dir); a third is an arity bug.
    # arg2 is a real directory here, so only the arity check fires -- no compounding.
    run _ds "customize '$BATS_TEST_TMPDIR' '$BATS_TEST_TMPDIR' maybe"
    assert_failure "$err_invalid_arguments"
}

@test "customize: is a no-op when no custom config file exists" {
    mkdir -p "$BATS_TEST_TMPDIR/sot" "$BATS_TEST_TMPDIR/target"
    run _ds "customize '$BATS_TEST_TMPDIR/sot' '$BATS_TEST_TMPDIR/target'"
    assert_success
}

@test "customize: fails on invalid JSON in the custom config file" {
    mkdir -p "$BATS_TEST_TMPDIR/sot" "$BATS_TEST_TMPDIR/target"
    _stub_custom_schema "$BATS_TEST_TMPDIR/sot"
    echo "not json" > "$BATS_TEST_TMPDIR/target/diff-shared.custom.json"
    run _ds "customize '$BATS_TEST_TMPDIR/sot' '$BATS_TEST_TMPDIR/target'"
    assert_failure "$err_invalid_json"
    assert_output --partial "is not a valid JSON"
}

@test "customize: overrides the diff/merge tools and per-file actions from the custom config" {
    # customize() now takes two arguments (SoT dir + target dir) and reads the schema from the
    # SoT dir, not the target -- see the get_shared_block/copy-shared-block work's summary note
    # on why the schema moved there (target-repo copies of it are optional, IDE-only convenience).
    mkdir -p "$BATS_TEST_TMPDIR/sot" "$BATS_TEST_TMPDIR/target"
    _stub_custom_schema "$BATS_TEST_TMPDIR/sot"
    cat > "$BATS_TEST_TMPDIR/target/diff-shared.custom.json" <<'EOF'
{
  "diff": {"tool": "diff", "command": "diff -q \"$LOCAL\" \"$REMOTE\""},
  "action_overrides": {"a.txt": "ignore", "unknown/path.txt": "copy"}
}
EOF
    run _ds "set_verbose
             diff_tool='olddiff'; diff_command='old --cmd'
             merge_tool='oldmerge'; merge_command='old --merge'
             declare -a target_files=('$BATS_TEST_TMPDIR/target/a.txt' '$BATS_TEST_TMPDIR/target/b.txt')
             declare -a file_actions=('merge' 'merge')
             diff_only=false
             customize '$BATS_TEST_TMPDIR/sot' '$BATS_TEST_TMPDIR/target'
             echo \"RC=\$?\"
             declare -p diff_tool diff_command merge_tool merge_command file_actions"
    assert_success
    assert_output --partial "RC=0"
    assert_output --partial 'diff_tool="diff"'
    assert_output --partial 'merge_tool="oldmerge"'
    assert_output --partial 'file_actions=([0]="ignore" [1]="merge")'
    assert_output --partial "does not match any known target relative path"
}

# =====================================================================================
# parameterize()
# =====================================================================================

@test "parameterize: is a no-op success when no --file* selectors were provided" {
    # NOTE: this used to be 'assert_failure 2' -- parameterize() now returns success immediately
    # when 'selectors_actions' is empty ('((${#selectors_actions[@]} > 0)) || return "$success"'),
    # treating no selectors as a no-op rather than an error. See the summary note.
    run _ds "declare -A selectors_actions=(); declare -a source_files=() file_actions=(); parameterize; echo \"RC=\$?\""
    assert_success
    assert_output --partial "RC=0"
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
