#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Characterization tests for scripts/bash/src/setup-repo.defaults.sh, as it behaves TODAY.
#
# Most of this file is data tables (default settings, rulesets, secrets, variables) rather than
# logic, so besides the one real function (is_one_of_nuget_servers), these tests also assert on
# internal consistency between a table and its companion "*_order" display-order array --
# exactly the kind of silent drift (a key renamed/added/removed in one but not the other) that
# is invisible on casual reading and would otherwise only surface as a missing/extra line in a
# human staring at 'setup-repo.sh --audit' output.

bats_require_minimum_version 1.5.0

load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../helpers/setup'

_src_dir="$(cd "$lib_dir/../src" && pwd)"

_sr() {
    env -i HOME="$HOME" PATH="/usr/local/bin:/usr/bin:/bin" bash -c "
        source '$lib_dir/core.sh' --no-trap > /dev/null
        source '$_src_dir/setup-repo.defaults.sh'
        $1
    "
}

# =====================================================================================
# is_one_of_nuget_servers()
# =====================================================================================

@test "is_one_of_nuget_servers: bug-exits with the wrong argument count" {
    run _sr "is_one_of_nuget_servers"
    assert_failure 254
}

@test "is_one_of_nuget_servers: bug-exits on a malformed server moniker" {
    run _sr "is_one_of_nuget_servers bogus"
    assert_failure 254
}

@test "is_one_of_nuget_servers: succeeds (returns positive) for 'nuget' and 'github'" {
    run _sr "is_one_of_nuget_servers nuget"
    assert_success
    run _sr "is_one_of_nuget_servers github"
    assert_success
}

@test "is_one_of_nuget_servers: returns negative for a well-formed but unlisted server (a custom URL)" {
    run _sr "is_one_of_nuget_servers https://example.com/v3/index.json"
    assert_failure 1
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

@test "actions_default_vars_order lists exactly the keys of actions_default_vars, plus section headers" {
    run _sr 'printf "%s\n" "${!actions_default_vars[@]}" | sort > /tmp/a.$$;
              printf "%s\n" "${actions_default_vars_order[@]}" | grep -v "^--" | sort > /tmp/b.$$;
              diff /tmp/a.$$ /tmp/b.$$ && echo MATCH'
    assert_success
    assert_output --partial "MATCH"
}

@test "every key in actions_var_validators names a key that actually exists in actions_default_vars" {
    run _sr 'for k in "${!actions_var_validators[@]}"; do
                  [[ -v actions_default_vars[$k] ]] || echo "ORPHAN: $k"
              done
              echo DONE'
    assert_success
    refute_output --partial "ORPHAN"
}

@test "every validator named in actions_var_validators is a defined function" {
    run _sr 'for k in "${!actions_var_validators[@]}"; do
                  fn="${actions_var_validators[$k]}"
                  declare -F "$fn" > /dev/null || echo "MISSING FUNCTION: $fn (for $k)"
              done
              echo DONE'
    assert_success
    refute_output --partial "MISSING FUNCTION"
}

@test "nuget_servers contains 'nuget' and 'github'" {
    run _sr 'declare -p nuget_servers'
    assert_success
    assert_output --partial '"nuget"'
    assert_output --partial '"github"'
}

@test "apps_with_secrets lists the four expected GitHub Apps" {
    run _sr 'printf "%s\n" "${apps_with_secrets[@]}"'
    assert_success
    assert_line "actions"
    assert_line "dependabot"
    assert_line "agents"
    assert_line "codespaces"
}
