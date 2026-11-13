#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Tests for .github/scripts/download-artifact.args.sh (with download-artifact.usage.sh), following the seams of the
# get_arguments() pipeline (see scripts/bash/tests/src/test_diff_shared_args.bats, the reference implementation). Each
# test sources gh_core.sh and the files under test in a fresh, ambient-environment-free ('env -i') bash subshell. A fake
# 'gh' (version + auth status only) stands in for the real one, so verify_environment() never depends on the machine's
# login.

bats_require_minimum_version 1.5.0

load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../helpers/setup'

# ShellCheck can't see that '../helpers/setup' transplants these into this file's scope at load
# time. '-g' is required (see feedback_bats_declare_g_readonly memory for the root cause).
declare -gx lib_dir
declare -gxi err_missing_argument
declare -gxi err_unknown_argument

declare BATS_TEST_TMPDIR

_gh_scripts_dir="$(cd "$lib_dir/../../../.github/scripts" && pwd)"

# Runs the snippet $1 with the optional environment assignments $2 (several, space-separated).
_da() {
    # shellcheck disable=SC2086 # $2 holds zero or more assignments: word splitting is intended
    env -i HOME="$HOME" PATH="$BATS_TEST_TMPDIR/bin:/usr/local/bin:/usr/bin:/bin" ${2:-} bash -c "
        source '$lib_dir/gh_core.sh' --no-trap > /dev/null 2>&1
        source '$_gh_scripts_dir/download-artifact.args.sh'
        source '$_gh_scripts_dir/download-artifact.usage.sh'
        $1
    "
}

setup() {
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    cat > "$BATS_TEST_TMPDIR/bin/gh" <<'EOF'
#!/usr/bin/env bash
[[ ${1:-} != version && ${1:-} != --version ]] || { echo "gh version $gh_min_version"; exit 0; }
[[ "$*" == "auth status" ]] && exit 0
exit 99
EOF
    chmod +x "$BATS_TEST_TMPDIR/bin/gh"
}

# =====================================================================================
# parse_arguments()
# =====================================================================================

@test "parse_arguments: leaves everything empty when no arguments and no variables are given" {
    run _da "parse_arguments
             declare -p artifact_name artifacts repository workflow_id workflow_name workflow_path"
    assert_success
    assert_output --partial 'artifact_name=""'
    assert_output --partial 'artifacts=""'
    assert_output --partial 'repository=""'
    assert_output --partial 'workflow_id=""'
    assert_output --partial 'workflow_name=""'
    assert_output --partial 'workflow_path=""'
}

@test "parse_arguments: the defaults come from the corresponding environment variables" {
    run _da "parse_arguments
             declare -p artifact_name artifacts repository workflow_id" \
            "ARTIFACT_NAME=pkgs ARTIFACT_DIR=out REPOSITORY=acme/repo WORKFLOW_ID=42"
    assert_success
    assert_output --partial 'artifact_name="pkgs"'
    assert_output --partial 'artifacts="out"'
    assert_output --partial 'repository="acme/repo"'
    assert_output --partial 'workflow_id="42"'
}

@test "parse_arguments: --artifact, --directory, and --repository (and --repo) set the corresponding variables" {
    run _da "parse_arguments --artifact pkgs --directory out --repository acme/repo
             declare -p artifact_name artifacts repository"
    assert_success
    assert_output --partial 'artifact_name="pkgs"'
    assert_output --partial 'artifacts="out"'
    assert_output --partial 'repository="acme/repo"'

    run _da "parse_arguments -A pkgs -d out --REPO acme/other
             declare -p artifact_name artifacts repository"
    assert_success
    assert_output --partial 'artifact_name="pkgs"'
    assert_output --partial 'artifacts="out"'
    assert_output --partial 'repository="acme/other"'
}

@test "parse_arguments: --wf-id, --wf-name, and --wf-path are mutually exclusive: the last one given wins" {
    run _da "parse_arguments --wf-name CI --wf-path .github/workflows/ci.yaml --wf-id 42
             declare -p workflow_id workflow_name workflow_path"
    assert_success
    assert_output --partial 'workflow_id="42"'
    assert_output --partial 'workflow_name=""'
    assert_output --partial 'workflow_path=""'

    run _da "parse_arguments -i 42 -p .github/workflows/ci.yaml -n CI
             declare -p workflow_id workflow_name workflow_path"
    assert_success
    assert_output --partial 'workflow_id=""'
    assert_output --partial 'workflow_name="CI"'
    assert_output --partial 'workflow_path=""'

    run _da "parse_arguments --wf-id 42 --wf-path .github/workflows/ci.yaml
             declare -p workflow_id workflow_name workflow_path"
    assert_success
    assert_output --partial 'workflow_id=""'
    assert_output --partial 'workflow_path=".github/workflows/ci.yaml"'
}

@test "parse_arguments: a workflow option also overrides a workflow given by an environment variable" {
    run _da "parse_arguments --wf-name CI
             declare -p workflow_id workflow_name" "WORKFLOW_ID=42"
    assert_success
    assert_output --partial 'workflow_id=""'
    assert_output --partial 'workflow_name="CI"'
}

@test "parse_arguments: fails with usage when a value-taking option is given without a value" {
    local _option
    for _option in --artifact --directory --repository --wf-id --wf-name --wf-path; do
        run _da "parse_arguments $_option"
        assert_failure "$err_missing_argument"
        assert_output --partial "Missing value for $_option"
    done
}

@test "parse_arguments: rejects an unknown option and any positional argument" {
    run _da "parse_arguments --bogus; echo AFTER"
    assert_failure "$err_unknown_argument"
    assert_output --partial "Unknown argument '--bogus'."
    refute_output --partial "AFTER"

    run _da "parse_arguments pkgs; echo AFTER"
    assert_failure "$err_unknown_argument"
    assert_output --partial "Unknown argument 'pkgs'."
    refute_output --partial "AFTER"
}

@test "parse_arguments: -h and --help only record the request; they neither print usage nor exit" {
    run _da "parse_arguments -h; echo \"requested=\$usage_requested\""
    assert_success
    assert_output "requested=short"

    run _da "parse_arguments --help; echo \"requested=\$usage_requested\""
    assert_success
    assert_output "requested=long"
}

# =====================================================================================
# verify_environment()
# =====================================================================================

@test "verify_environment: succeeds silently when jq and an authenticated gh are present" {
    run _da "verify_environment; echo \"rc=\$?\"; has_errors && echo HAS_ERRORS || echo NO_ERRORS"
    assert_success
    assert_output "rc=0
NO_ERRORS"
}

@test "verify_environment: reports a missing jq and a missing gh together, and returns instead of exiting" {
    run _da "is_tool_present() { [[ \$1 != jq && \$1 != gh ]]; }
             verify_environment
             echo REACHED
             echo \"errors=\$(get_errors)\""
    assert_success
    assert_output --partial "'jq' is not installed"
    assert_output --partial "'gh' is not installed"
    assert_output --partial "REACHED"
    assert_output --partial "errors=2"
}

# =====================================================================================
# resolve_arguments()
# =====================================================================================

@test "resolve_arguments: accepts valid values and freezes them" {
    run _da "artifact_name=pkgs artifacts=out repository=acme/repo workflow_id=42
             resolve_arguments
             has_errors && echo HAS_ERRORS || echo NO_ERRORS
             declare -p artifact_name artifacts repository workflow_id workflow_name workflow_path"
    assert_success
    assert_output --partial "NO_ERRORS"
    assert_output --partial 'declare -rx artifact_name="pkgs"'
    assert_output --partial 'declare -rx artifacts="out"'
    assert_output --partial 'declare -rx repository="acme/repo"'
    assert_output --partial 'declare -rx workflow_id="42"'
    assert_output --partial 'declare -rx workflow_name=""'
    assert_output --partial 'declare -rx workflow_path=""'
}

@test "resolve_arguments: reports a missing artifact name and a missing directory together, and returns" {
    run _da "resolve_arguments
             echo REACHED
             echo \"errors=\$(get_errors)\""
    assert_success
    assert_output --partial "The name of the artifact to download must be specified."
    assert_output --partial "The directory to download the artifact to must be specified."
    assert_output --partial "REACHED"
    assert_output --partial "errors=2"
}

@test "resolve_arguments: reports a workflow id that is not a number" {
    run _da "artifact_name=pkgs artifacts=out workflow_id=abc
             resolve_arguments
             has_errors && echo HAS_ERRORS || echo NO_ERRORS"
    assert_success
    assert_output --partial "The specified workflow identifier 'abc' is not valid."
    assert_output --partial "HAS_ERRORS"
}

@test "resolve_arguments: reports unsafe values: shell metacharacters in names, directory traversal in paths" {
    run _da "artifact_name='a;rm -rf' artifacts='../out' repository='acme/repo\$(id)'
             resolve_arguments
             echo \"errors=\$(get_errors)\""
    assert_success
    assert_output --partial "The input 'a;rm -rf' contains one or more of the unsafe characters"
    assert_output --partial "The path '../out' contains directory traversal sequences"
    assert_output --partial "The input 'acme/repo\$(id)' contains one or more of the unsafe characters"
    assert_output --partial "errors=3"
}

# =====================================================================================
# get_arguments(): the pipeline end to end
# =====================================================================================

@test "get_arguments: parses, resolves, and freezes the arguments in one call" {
    run _da "get_arguments --artifact pkgs --directory out --wf-name CI
             declare -p artifact_name artifacts workflow_name"
    assert_success
    assert_output --partial 'declare -rx artifact_name="pkgs"'
    assert_output --partial 'declare -rx artifacts="out"'
    assert_output --partial 'declare -rx workflow_name="CI"'
}

@test "get_arguments: -h prints the usage and exits 0, even without the required arguments" {
    run _da "get_arguments -h; echo AFTER"
    assert_success
    assert_output --partial "Usage:"
    refute_output --partial "AFTER"
}

@test "get_arguments: missing required arguments end the run with the errors and the usage" {
    run _da "get_arguments; echo AFTER"
    assert_failure
    assert_output --partial "The name of the artifact to download must be specified."
    assert_output --partial "The directory to download the artifact to must be specified."
    assert_output --partial "Usage:"
    refute_output --partial "AFTER"
}
