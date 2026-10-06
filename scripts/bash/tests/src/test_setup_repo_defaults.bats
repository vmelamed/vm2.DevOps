#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Characterization tests for scripts/bash/src/setup-repo.defaults.sh, as it behaves TODAY.
#
# Most of this file is data tables (default settings, rulesets, secrets, variables) rather than
# logic, so besides the one real function (is_valid_nuget_server, in _sanitize.sh but exercised
# here via the NUGET_SERVER validator table entry), these tests also assert on internal
# consistency between a table and its companion "*_order" display-order array -- exactly the
# kind of silent drift (a key renamed/added/removed in one but not the other) that is invisible
# on casual reading and would otherwise only surface as a missing/extra line in a human staring
# at 'setup-repo.sh --audit' output.

bats_require_minimum_version 1.5.0

load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../helpers/setup'

# ShellCheck can't see that '../helpers/setup' transplants these into this file's scope at load
# time. '-g' is required (see feedback_bats_declare_g_readonly memory for the root cause).
declare -gx lib_dir
declare -gxi failure
declare -gxi err_invalid_arguments
declare -gxi err_argument_value

_src_dir="$(cd "$lib_dir/../src" && pwd)"

_sr() {
    env -i HOME="$HOME" PATH="/usr/local/bin:/usr/bin:/bin" bash -c "
        source '$lib_dir/core.sh' --no-trap > /dev/null 2>&1
        source '$_src_dir/setup-repo.defaults.sh'
        $1
    "
}

# =====================================================================================
# is_valid_nuget_server()
# =====================================================================================

@test "is_valid_nuget_server: bug-exits with the wrong argument count" {
    run _sr "is_valid_nuget_server"
    assert_failure "$err_invalid_arguments"
}

@test "is_valid_nuget_server: returns negative for a malformed server moniker" {
    run _sr "is_valid_nuget_server bogus"
    assert_failure "$failure"
}

@test "is_valid_nuget_server: succeeds (returns positive) for 'nuget' and 'github'" {
    run _sr "is_valid_nuget_server nuget"
    assert_success
    run _sr "is_valid_nuget_server github"
    assert_success
}

@test "is_valid_nuget_server: succeeds for a well-formed https:// custom server URL" {
    run _sr "is_valid_nuget_server https://example.com/v3/index.json"
    assert_success
}

# =====================================================================================
# Table / display-order consistency
# =====================================================================================

@test "default_repo_settings_order lists exactly the keys of default_repo_settings" {
    run _sr 'printf "%s\n" "${!default_repo_settings[@]}" | sort > /tmp/a.$$;
              printf "%s\n" "${default_repo_settings_order[@]}" | sort > /tmp/b.$$;
              diff /tmp/a.$$ /tmp/b.$$ && echo MATCH'
    assert_success
    assert_output --partial "MATCH"
}

@test "default_ruleset_order lists exactly the keys of default_ruleset" {
    run _sr 'printf "%s\n" "${!default_ruleset[@]}" | sort > /tmp/a.$$;
              printf "%s\n" "${default_ruleset_order[@]}" | sort > /tmp/b.$$;
              diff /tmp/a.$$ /tmp/b.$$ && echo MATCH'
    assert_success
    assert_output --partial "MATCH"
}

@test "default_local_git_settings_order lists exactly the keys of default_local_git_settings" {
    run _sr 'printf "%s\n" "${!default_local_git_settings[@]}" | sort > /tmp/a.$$;
              printf "%s\n" "${default_local_git_settings_order[@]}" | sort > /tmp/b.$$;
              diff /tmp/a.$$ /tmp/b.$$ && echo MATCH'
    assert_success
    assert_output --partial "MATCH"
}

@test "actions_vars_order lists exactly the keys of actions_vars_defaults, plus section headers" {
    run _sr 'printf "%s\n" "${!actions_vars_defaults[@]}" | sort > /tmp/a.$$;
              printf "%s\n" "${actions_vars_order[@]}" | grep -v "^--" | sort > /tmp/b.$$;
              diff /tmp/a.$$ /tmp/b.$$ && echo MATCH'
    assert_success
    assert_output --partial "MATCH"
}

@test "every key in actions_vars_validators names a key that actually exists in actions_vars_defaults" {
    run _sr 'for k in "${!actions_vars_validators[@]}"; do
                  [[ -v actions_vars_defaults[$k] ]] || echo "ORPHAN: $k"
              done
              echo DONE'
    assert_success
    refute_output --partial "ORPHAN"
}

@test "every validator named in actions_vars_validators is a defined function" {
    run _sr 'for k in "${!actions_vars_validators[@]}"; do
                  fn="${actions_vars_validators[$k]}"
                  declare -F "$fn" > /dev/null || echo "MISSING FUNCTION: $fn (for $k)"
              done
              echo DONE'
    assert_success
    refute_output --partial "MISSING FUNCTION"
}

@test "gh_apps_with_secrets lists the three expected GitHub Apps ('agents' is commented out, not used yet)" {
    run _sr 'printf "%s\n" "${gh_apps_with_secrets[@]}"'
    assert_success
    assert_line "actions"
    assert_line "dependabot"
    assert_line "codespaces"
    refute_line "agents"
}
