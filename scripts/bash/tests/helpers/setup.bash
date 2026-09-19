# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Shared bats test setup. Each test file loads this via:
#   load '../helpers/setup'
#
# bats sources every .bats file's top-level code from inside a bash function frame
# (bats_evaluate_preprocessed_source -> main). Bash scopes `declare` (even `-x`/`-r`) to the
# current function unless `-g` is given, so a plain `source core.sh` here would make every one
# of the library's top-level `declare -xr` constants (success, err_*, etc.) vanish the moment
# that frame returns -- confirmed: $success reads back empty in the test body.
#
# Fix: source core.sh in a genuine top-level `bash -c` subshell, where its own `declare -x`
# really is global, then transplant the resulting functions and variables into this process:
#   - functions replay as-is (bash function definitions are always global, frame depth doesn't
#     matter -- only `declare`d variables are affected)
#   - variables replay with the `-x` (export) and `-i` (integer) attributes stripped:
#       * `-x` must go, or every `__VM2_LIB_*_SH_LOADED` include-guard gets exported into this
#         process's environment and inherited by any later child bash (e.g. a test that does
#         `bash -c 'source core.sh; ...'`), which then finds every guard already "loaded" and
#         skips sourcing the library entirely
#       * `-i` must go, or replaying `secret_str` (declared -i despite holding the non-numeric
#         masked value "******") fails arithmetic evaluation
#     the values themselves are unaffected; only the attributes that would misbehave on replay
#     or leak into children are dropped. `-A`/`-a`/`-r` are preserved so associative arrays and
#     readonly-ness still work correctly.
#   - `script_name`/`script_dir`/`lib_dir` are excluded from the transplant: core.sh derives
#     these from its own invocation context in the throwaway subshell (where they come out
#     wrong, since there's no real script file), and replaying them would clobber the correct
#     values this file sets up for the actual test run.

_setup_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Plain assignment, not `declare` -- see note above: `declare` here would scope these to bats'
# load frame and they'd read back empty in the @test body once that frame returns.
# shellcheck disable=SC2034 # script_name appears unused. Verify use (or export if used externally).
{
    script_name="bats-test"
    script_dir="$_setup_dir"
}
lib_dir="$(cd "$_setup_dir/../../lib" && pwd)"

# Both capture subshells run under `env -i` (only HOME/PATH passed through), not just a plain
# `bash -c`: whatever shell happens to invoke `bats` may itself have leaked exported library
# variables into its own environment (e.g. from an earlier ad-hoc `bash -c 'source core.sh; ...'`
# debugging session) -- bats and everything it spawns, including this file, inherit that. The
# before/after `compgen -v` diff below treats any name already present as "not new" and skips
# replaying it, so a stale inherited value would silently shadow a fresh on-disk edit to the
# library forever. Stripping the environment guarantees "before" always reflects a pristine bash
# startup, regardless of what is polluting the invoking shell.
#
# Captured as two separate subshells (not one combined dump split with bash's `%%`/`#*` glob
# operators): those operators are pathologically slow on a ~150KB string (~8s per test file
# load), while `sed`'s linear-time exclude/rewrite below is effectively instant.
_lib_funcs="$(env -i HOME="$HOME" PATH="$PATH" bash -c 'source "$1/core.sh" --no-trap > /dev/null 2>&1; declare -f' _ "$lib_dir")"

# Captured via a before/after `compgen -v` diff, not `declare -p -x`: several library modules
# (e.g. __verbose/__quiet/__dry_run/__table_format in _core_state.sh) are deliberately
# non-exported private state, read directly by predicates like is_verbose(). An export-only
# capture silently drops them, leaving those predicates executing an empty string as a command
# once replayed here. Diffing catches everything core.sh introduces, exported or not, while
# still excluding pre-existing inherited environment (PATH, HOME, etc.) since those are already
# present in the "before" snapshot.
_lib_vars="$(env -i HOME="$HOME" PATH="$PATH" bash -c '
    _vm2_before_vars=$(compgen -v)
    source "$1/core.sh" --no-trap > /dev/null 2>&1
    comm -13 <(printf "%s\n" "$_vm2_before_vars" | sort) <(compgen -v | sort) |
        grep -vE "^(_vm2_before_vars|script_name|script_dir|lib_dir|__VM2_LIB_[A-Z_]+_SH_LOADED)$" |
        while IFS= read -r _vm2_name; do declare -p "$_vm2_name" 2>/dev/null; done
' _ "$lib_dir" | \
    sed -E 's/^declare -([A-Za-z]*)i([A-Za-z]*) /declare -\1\2 /; s/^declare -([A-Za-z]*)x([A-Za-z]*) /declare -\1\2 /; s/^declare -([A-Za-z]+) /declare -g\1 /; s/^declare -- /declare -g -- /; s/^declare - /declare -g /')"

eval "$_lib_funcs"
eval "$_lib_vars"

unset _setup_dir _lib_funcs _lib_vars
