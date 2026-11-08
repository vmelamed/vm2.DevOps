#!/usr/bin/env bash

# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

set -euo pipefail

script_name=$(basename "${BASH_SOURCE[0]}")
script_dir=$(dirname "$(realpath -e "${BASH_SOURCE[0]}")")
lib_dir=$(realpath -e "$script_dir/../lib")

declare -xr script_name
declare -xr script_dir
declare -xr lib_dir

#===============================================================================================
# Sanity checks of the library in vm2.DevOps/scripts/bash/lib/*.sh, for the silly errors that the
# tests would only report as a wall of failures with no message: stray characters, a new file that
# is never sourced or never committed, a copy-pasted include guard, a function left behind in two
# files, a forward declaration of a constant that does not exist, a syntax error in a script.
#
# It cannot catch a stray command inside a function body: sourcing only defines the function.
# That is what ShellCheck and the tests that call the function are for.
#===============================================================================================

# 1) Sourcing the library must succeed and print nothing. Checked in a clean child shell, before
#    this script sources the library itself: a broken library would otherwise kill this script
#    before it can say anything useful.
declare source_output=''
declare -i source_rc=0
# shellcheck disable=SC2016 # $1 is expanded by the child shell, not here
source_output=$(env -i HOME="$HOME" PATH="$PATH" bash -c 'set -euo pipefail; source "$1/gh_core.sh"' _ "$lib_dir" 2>&1) || source_rc=$?
if (( source_rc != 0 )) || [[ -n $source_output ]]; then
    printf '❌  Sourcing %s/gh_core.sh failed (exit code %d) or printed something:\n%s\n' "$lib_dir" "$source_rc" "$source_output" >&2
    exit 1
fi

source "$lib_dir/gh_core.sh"

# vm2 core error codes (declared here, after sourcing: a readonly declaration without a value
# before the library defines them would make their definitions fail)
declare -xri err_not_file
declare -xri err_tool_error
declare -xri err_logic_error

# vm2 core variables
declare -x _ignore

# 2) Every _*.sh is sourced by core.sh: an active `source "$lib_dir/<file>"` line, optionally followed by a
#    comment. A substring match would also accept a commented-out `# source ...` line.
declare file=''
declare name=''
for file in "$lib_dir"/_*.sh; do
    name=${file##*/}
    # shellcheck disable=SC2016 # '$lib_dir' is literal text to find in core.sh, not something to expand
    grep -qE '^[[:space:]]*source[[:space:]]+"\$lib_dir/'"${name//./\\.}"'"[[:space:]]*(#.*)?$' "$lib_dir/core.sh" ||
        error "'$name' is not sourced by core.sh." -ec "$err_logic_error"
done

# 3) No library file is left uncommitted.
declare untracked=''
untracked=$(git -C "$lib_dir" ls-files --others --exclude-standard -- '*.sh') ||
    error "Failed to list the untracked files in '$lib_dir'." -ec "$err_tool_error"
[[ -z $untracked ]] ||
    error "Untracked library files:" "$untracked" -ec "$err_not_file"

# 4) Every include guard is named after its file: _core_args.sh -> __VM2_LIB_CORE_ARGS_SH_LOADED.
#    Two files with the same guard silently skip each other.
declare guard='' expected=''
for file in "$lib_dir"/*.sh; do
    expected=${file##*/}
    expected=${expected%.sh}
    expected="__VM2_LIB_${expected#_}_SH_LOADED"
    expected=${expected^^}
    guard=$(grep -oE '__VM2_LIB_[A-Z0-9_]+_SH_LOADED' "$file" | head -n 1) || true
    [[ $guard == "$expected" ]] ||
        error "'${file##*/}': the include guard is '${guard:-<none>}', expected '$expected'." -ec "$err_logic_error"
done

# 5) No function is defined in two files, except the deliberate overrides: gh_core.sh overrides
#    the to_* functions, and _core_args.sh overrides the usage() placeholder in _diagnostics.sh.
declare -ra known_overrides=(to_stdout to_stderr to_output usage)
declare function_name=''
while IFS= read -r function_name; do
    is_in "$function_name" "${known_overrides[@]}" ||
        error "The function '$function_name' is defined in more than one library file." -ec "$err_logic_error"
done < <(grep -hoE '^function [a-zA-Z_][a-zA-Z0-9_]*' "$lib_dir"/*.sh | sort | uniq -d | cut -d' ' -f2)

# 6) No readonly variable is left without a value: a readonly variable can never get one later,
#    so it is a forward declaration of a constant that does not exist (e.g. a renamed $err_* code).
#    Plain forward declarations (e.g. 'declare -x repo_owner', set by the calling script) are fine.
declare declarations=''
# shellcheck disable=SC2016 # $1 is expanded by the child shell, not here
declarations=$(env -i HOME="$HOME" PATH="$PATH" bash -c 'source "$1/gh_core.sh" > /dev/null 2>&1; declare -p' _ "$lib_dir") ||
    error "Failed to list the variables declared by the library." -ec "$err_tool_error"
declare variable_name=''
while IFS= read -r variable_name; do
    error "The readonly variable '$variable_name' is declared, but never given a value." -ec "$err_logic_error"
done < <(awk '/^declare -[a-zA-Z]*r[a-zA-Z]* [a-zA-Z_][a-zA-Z0-9_]*$/ { print $3 }' <<< "$declarations") # awk, not grep: no match is not a failure

# 7) No syntax errors in the library and in the scripts. bash -n parses without running anything.
for file in "$lib_dir"/*.sh "$script_dir"/*.sh "$lib_dir"/../../../.github/scripts/*.sh; do
    [[ -f $file ]] || continue # an unmatched glob stays as the literal pattern
    bash -n "$file" 2>&1 ||
        error "Syntax error in '$(realpath "$file")'." -ec "$err_logic_error"
done

exit_if_has_errors false

info "vm2.DevOps/scripts/bash/lib/*.sh loaded fine!"

# 8) ShellCheck, last: it is the slowest check, and its findings matter only once the library loads.
#    Each file picks up the repository's .shellcheckrc, as in the VSCode extension, so the results match.
#    Report only, for now: the findings do not change the exit code, so the library checks above stay
#    usable while older findings remain. Make it an error once ShellCheck is clean.
if command -v shellcheck > "$_ignore"; then
    declare -a shellcheck_files=()
    for file in "$lib_dir"/*.sh "$script_dir"/*.sh "$lib_dir"/../../../.github/scripts/*.sh; do
        [[ -f $file ]] && shellcheck_files+=("$(realpath "$file")")
    done
    if shellcheck "${shellcheck_files[@]}"; then
        info "ShellCheck found nothing in ${#shellcheck_files[@]} files."
    else
        warning "ShellCheck reported the findings above, in ${#shellcheck_files[@]} files."
    fi
else
    warning "ShellCheck is not installed, so it was skipped."
fi
