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
script_name="bats-test"
script_dir="$_setup_dir"
lib_dir="$(cd "$_setup_dir/../../lib" && pwd)"

# Captured as two separate subshells (not one combined dump split with bash's `%%`/`#*` glob
# operators): those operators are pathologically slow on a ~150KB string (~8s per test file
# load), while `sed`'s linear-time exclude/rewrite below is effectively instant.
_lib_funcs="$(bash -c 'source "$1/core.sh" --no-trap > /dev/null; declare -f' _ "$lib_dir")"

_lib_vars="$(bash -c 'source "$1/core.sh" --no-trap > /dev/null; declare -p -x' _ "$lib_dir" | \
    grep -vE '^declare -[A-Za-z]+ (script_name|script_dir|lib_dir|__VM2_LIB_[A-Z_]+_SH_LOADED)=' | \
    sed -E 's/^declare -([A-Za-z]*)i([A-Za-z]*) /declare -\1\2 /; s/^declare -([A-Za-z]*)x([A-Za-z]*) /declare -\1\2 /; s/^declare -([A-Za-z]+) /declare -g\1 /; s/^declare - /declare -g /')"

eval "$_lib_funcs"
eval "$_lib_vars"

unset _setup_dir _lib_funcs _lib_vars
