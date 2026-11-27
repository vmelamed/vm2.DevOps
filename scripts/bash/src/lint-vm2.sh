#!/usr/bin/env bash

# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

set -euo pipefail

script_name=$(basename "${BASH_SOURCE[0]}")
script_dir=$(dirname "$(realpath -e "${BASH_SOURCE[0]}")")
lib_dir=$(realpath -e "$script_dir/../lib")

declare -x script_name
declare -x script_dir
declare -x lib_dir

#===============================================================================================
# Sanity checks of the library in vm2.DevOps/scripts/bash/lib/*.sh, for the silly errors that the
# tests would only report as a wall of failures with no message: stray characters, a new file that
# is never sourced or never committed, a copy-pasted include guard, a function left behind in two
# files, a forward declaration of a constant that does not exist, a syntax error in a script, a
# message that departs from the message templates in vm2.DevOps/CLAUDE.md.
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

# vm2 core lib exit codes (declared here, after sourcing: a readonly declaration without a value
# before the library defines them would make their definitions fail)
declare -x err_not_file
declare -x err_tool_error
declare -x err_logic_error

# vm2 core lib variables
declare -x noise_sink

# 2) Every _*.sh and core.*.sh is sourced by core.sh: an active `source "$lib_dir/<file>"` line, optionally followed
#    by a comment. A substring match would also accept a commented-out `# source ...` line.
declare file=''
declare name=''
for file in "$lib_dir"/_*.sh "$lib_dir"/core.*.sh; do
    name=${file##*/}
    # shellcheck disable=SC2016 # '$lib_dir' is literal text to find in core.sh, not something to expand
    grep -qE '^[[:space:]]*source[[:space:]]+"\$lib_dir/'"${name//./\\.}"'"[[:space:]]*(#.*)?$' "$lib_dir/core.sh" \
                                                                                || error "$err_logic_error" "'$name' is not sourced by core.sh."
done

# 3) No library file is left uncommitted.
declare untracked=''
untracked=$(git -C "$lib_dir" ls-files --others --exclude-standard -- '*.sh')   || error "$err_tool_error" "Failed to list the untracked files in '$lib_dir'."
[[ -z $untracked ]]                                                             || error "$err_not_file" "Untracked library files:" "$untracked"

# 4) Every include guard is named after its file: core.args.sh -> __VM2_LIB_CORE_ARGS_SH_LOADED.
#    Two files with the same guard silently skip each other.
declare guard='' expected=''
for file in "$lib_dir"/*.sh; do
    expected=${file##*/}
    expected=${expected%.sh}
    expected=${expected//./_}
    expected="__VM2_LIB_${expected#_}_SH_LOADED"
    expected=${expected^^}
    guard=$(grep -oE '__VM2_LIB_[A-Z0-9_]+_SH_LOADED' "$file" | head -n 1)      || true
    [[ $guard == "$expected" ]]                                                 || error "$err_logic_error" "'${file##*/}': the include guard is '${guard:-<none>}', expected '$expected'."
done

# 5) No function is defined in two files, except the deliberate overrides: gh_core.sh overrides
#    the tee_* functions, and core.args.sh overrides the usage() placeholder in _diagnostics.sh.
declare -ra known_overrides=(tee_stdout tee_stderr tee_output usage)
declare function_name=''
while IFS= read -r function_name; do
    is_in "$function_name" "${known_overrides[@]}"                              || error "$err_logic_error" "The function '$function_name' is defined in more than one library file."
done < <(grep -hoE '^function [a-zA-Z_][a-zA-Z0-9_]*' "$lib_dir"/*.sh | sort | uniq -d | cut -d' ' -f2)

# 6) No readonly variable is left without a value: a readonly variable can never get one later,
#    so it is a forward declaration of a constant that does not exist (e.g. a renamed $err_* code).
#    Plain forward declarations (e.g. 'declare -x repo_owner', set by the calling script) are fine.
declare declarations=''
# shellcheck disable=SC2016 # $1 is expanded by the child shell, not here
declarations=$(env -i HOME="$HOME" PATH="$PATH" bash -c 'source "$1/gh_core.sh" > /dev/null 2>&1; declare -p' _ "$lib_dir") \
                                                                                || error "$err_tool_error" "Failed to list the variables declared by the library."
declare variable_name=''
while IFS= read -r variable_name; do
    error "$err_logic_error" "The readonly variable '$variable_name' is declared, but never given a value."
done < <(awk '/^declare -[a-zA-Z]*r[a-zA-Z]* [a-zA-Z_][a-zA-Z0-9_]*$/ { print $3 }' <<< "$declarations") # awk, not grep: no match is not a failure

# 7) No syntax errors in the library and in the scripts. bash -n parses without running anything.
for file in "$lib_dir"/*.sh "$script_dir"/*.sh "$lib_dir"/../../../.github/scripts/*.sh; do
    [[ -f $file ]] || continue # an unmatched glob stays as the literal pattern
    bash -n "$file" 2>&1                                                        || error "$err_logic_error" "Syntax error in '$(realpath "$file")'."
done

# 8) Messages follow the templates in vm2.DevOps/CLAUDE.md ("Message Templates"). Each rule is a common departure,
#    found by a pattern; a deny list, not a grammar, so a correct message is never rejected. Comment lines are skipped.
#    "Please" is checked only in message parts: a string on a line that calls a message function, or a string that
#    starts a continuation line (the next part of a multi-line message). Other strings are data ("Please wait" as a
#    title), and the help texts (*.usage.sh) are prose, not messages. A message built in a variable first is missed.
declare -rA message_rules=(
    ['\(\) (expects|takes|accepts) ']="the verb is 'requires', not 'expects', 'takes', or 'accepts'"
    ['\(\) requires (exactly |either |from )?(a single|one|two|three|four|five|six|seven) ((nameref|boolean|positional) )?(argument|parameter)']="the argument count uses digits: 'requires 2 arguments'"
    ['\(\) requires exactly ']="the argument count has no 'exactly': 'requires 2 arguments'"
    ['\(\$# provided\)|\(provided: ']="the provided value reads '(provided \$#)' or '(provided '<value>')'"
    ['\(provided \$\{?[0-9]']="the provided value is quoted: '(provided '\${1-<missing>}')'"
    ['-ec "[^"]*" +"']="'-ec' comes after the message parts"
)
declare -r please_rule='\b(error|with_error|warning|info|trace|bug|usage|exit_with_error|exit_with_bug|fatal_exit)\b.*"[^"]*\bPlease\b|^[[:space:]]*"[^"]*\bPlease\b'
declare -a message_files=()
declare -r this_file="$script_dir/$script_name"
for file in "$lib_dir"/*.sh "$script_dir"/*.sh "$lib_dir"/../../../.github/scripts/*.sh; do
    [[ -f $file && $file != "$this_file" ]] && message_files+=("$(realpath "$file")") # not this file: its rules match themselves
done
declare rule='' hits=''
for rule in "${!message_rules[@]}"; do
    hits=$(grep -nHE -- "$rule" "${message_files[@]}" | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#') || true # no match is the good outcome
    [[ -z $hits ]]                                                              || error "$err_logic_error" "Messages that depart from the templates: ${message_rules[$rule]}." "$hits"
done
hits=$(grep -nHE -- "$please_rule" "${message_files[@]}" | grep -vE '^[^:]+\.usage\.sh:|^[^:]+:[0-9]+:[[:space:]]*#') || true
[[ -z $hits ]]                                                                  || error "$err_logic_error" "Messages that depart from the templates: a fix hint is an imperative, without 'Please'." "$hits"

# 9) A library function's name says whether it reports (vm2.DevOps/CLAUDE.md, "Function Types"): a predicate
#    (is_*, has_*) and an assert_* never call error, with_error, warning, or info (a bug is fine: it reports a
#    broken contract); a validator (is_valid_*, is_safe_*, validate_*, verify_*) calls at least one of them.
#    The body of 'function name()' runs to the first '}' in column 1, as the library writes it. A name counts only in a
#    command position: the start of a command (not of a continued line), or after ; & | ( ) { ! and the reserved words
#    if elif while until then else do. The scan carries its state across lines, and drops what is data:
#    - the text of '...' and "..." strings, but not a command substitution inside "...": "$(error ...)" is a call;
#    - comments, here-document bodies, and [[ ... ]] tests on one line ('[[ $1 == error ]]' is not a call).
#    It is a heuristic, like check 8, not a bash parser: a case it gets wrong is a documented limitation, not a reason to
#    grow it into one. Known limitations: a reporter called inside a [[ ... ]] test ('[[ "$(error ...)" == ok ]]', which
#    loses the error count in the subshell anyway) is not counted; a [[ ... ]] test across lines is scanned as code. A validator that only delegates its reporting to another validator is flagged too: let it report
#    its own failure.
declare -r validator_rule='^(is_valid|is_safe|validate|verify)_'
declare -r silent_rule='^(is_|has_|assert_)'
# shellcheck disable=SC2016 # the $ signs are awk's and the shell's text to scan, not something to expand here
declare -r report_scanner='
    # Removes the data from one line, and keeps the code. The state carries over to the next line:
    # q: "" outside quotes, "\"" or "\047" inside; stack[1..depth]: what each open "(" closes back to:
    # "dq" (a "$(" inside "..."), "cs" (an unquoted "$("), or "p" (a plain "(", e.g. a subshell);
    # continued: the line ended with an unquoted "\" after an argument, so the next line does not start a command;
    # pending: the delimiter of a here-document opened on this line: its body starts on the next line.
    function strip(line,    out, i, c, n, top, word) {
        out = continued ? "x" : ""                                      # "x": no command position at the start
        continued = 0
        n = length(line)
        for (i = 1; i <= n; i++) {
            c = substr(line, i, 1)
            if (q == "\047") {                                          # single quotes: nothing is special but the end
                if (c == "\047") q = ""
            } else if (q == "\"") {
                if (c == "\\") i++                                      # an escaped character
                else if (c == "\"") q = ""
                else if (substr(line, i, 2) == "$(") { q = ""; stack[++depth] = "dq"; i++; out = out " ( " }
            } else {
                if (c == "\\") {                                         # at the end: a continued line, unless the
                    if (i == n && out !~ /([;&|({!]|(^|[[:space:]])(then|else|do))[[:space:]]*$/) continued = 1  # command goes on
                    i++; continue
                }
                if (substr(line, i, 3) == "<<<") { out = out " <<< "; i += 2; continue }  # a here-string: a word follows
                if (substr(line, i, 2) == "<<") {                       # a here-document: <<, an optional -, spaces, a quoted or bare WORD
                    word = substr(line, i + 2)
                    sub(/^-?[[:space:]]*/, "", word)
                    if (match(word, /^["\047]?[A-Za-z_][A-Za-z0-9_]*/)) {
                        pending = substr(word, RSTART, RLENGTH)
                        sub(/^["\047]/, "", pending)
                    }
                    out = out " x "; i = n; continue                    # the rest of the line is the redirection
                }
                if (c == "#" && (i == 1 || substr(line, i - 1, 1) ~ /[[:space:];|&()]/)) break
                if (c == "\047" || c == "\"") { q = c; out = out " x "; continue }   # a string is a word, not a command
                if (substr(line, i, 2) == "$(") { stack[++depth] = "cs"; i++; out = out " ( "; continue }
                if (c == "(") { stack[++depth] = "p"; out = out "("; continue }
                if (c == ")") {
                    top = depth > 0 ? stack[depth--] : ""
                    if (top == "dq") { q = "\""; out = out " x "; continue }   # back inside "...": the rest is a word
                    if (top == "cs") { out = out " x "; continue }             # $(...) is a word: an argument may follow
                    out = out ")"                                               # a subshell, or a case arm
                    continue
                }
                out = out c
            }
        }
        gsub(/\[\[([^]]|\][^]])*\]\]/, " x ", out)                      # a [[ ... ]] test on one line is data
        return out
    }
    FNR == 1                                    { fn = ""; q = ""; depth = 0; continued = 0; heredoc = ""; pending = "" }
    /^function [a-zA-Z_][a-zA-Z0-9_]*\(\)/      { fn = $2; sub(/\(\).*/, "", fn); key = FILENAME ":" FNR ":" fn; calls[key] = 0
                                                  q = ""; depth = 0; continued = 0; heredoc = ""; pending = ""; next }
    heredoc != ""                               { if ($0 ~ ("^[[:space:]]*" heredoc "$")) heredoc = ""; next }   # data
    /^}/ && q == ""                             { fn = ""; next }
    fn != ""                                    {
                                                    s = strip($0)
                                                    if (pending != "") { heredoc = pending; pending = "" }
                                                    if (s ~ /(^|[;&|(){!])[[:space:]]*((if|elif|while|until)[[:space:]]+)?(error|with_error|warning|info)([[:space:]]|;|$)/ ||
                                                        s ~ /(^|[[:space:]])(then|else|do)[[:space:]]+(error|with_error|warning|info)([[:space:]]|;|$)/)
                                                        calls[key]++
                                                }
    END                                         { for (key in calls) print key, calls[key] }
'
declare reports_text=''
reports_text=$(awk "$report_scanner" "$lib_dir"/*.sh)                           || error "$err_tool_error" "Failed to scan the library functions in '$lib_dir'."

declare location='' function_calls=''
declare -a silent_hits=() validator_hits=()
while read -r location function_calls; do
    [[ -n $location ]] || continue
    function_name=${location##*:}
    if [[ $function_name =~ $validator_rule ]]; then
        (( function_calls > 0 )) || validator_hits+=("$location")
    elif [[ $function_name =~ $silent_rule ]]; then
        (( function_calls == 0 )) || silent_hits+=("$location")
    fi
done <<< "$reports_text"
(( ${#silent_hits[@]} == 0 ))                                                   || error "$err_logic_error" "Predicates and assert_* functions that report (call error, with_error, warning, or info):" \
                                                                                                            "$(printf '%s\n' "${silent_hits[@]}" | sort)"
(( ${#validator_hits[@]} == 0 ))                                                || error "$err_logic_error" "Validators that never report (no call to error, with_error, warning, or info):" \
                                                                                                            "$(printf '%s\n' "${validator_hits[@]}" | sort)"

exit_if_has_errors false

info "vm2.DevOps/scripts/bash/lib/*.sh loaded fine!"

# 10) ShellCheck, last: it is the slowest check, and its findings matter only once the library loads.
#     Each file picks up the repository's .shellcheckrc, as in the VSCode extension, so the results match.
#     Report only, for now: the findings do not change the exit code, so the library checks above stay
#     usable while older findings remain. Make it an error once ShellCheck is clean.
#     ShellCheck runs from the repository root, as the VSCode extension does. Its result depends on the current
#     directory: for `source "$lib_dir/_x.sh"` it also tries `_x.sh` relative to it, so started from
#     scripts/bash/lib it follows every source line into the whole library, for each of the ~100 files, and takes
#     minutes instead of seconds. The timeout is the guard in case something else makes it that slow again.
declare -ri shellcheck_timeout=120 # seconds; a normal run takes under 10
if command -v shellcheck > "$noise_sink"; then
    declare -a shellcheck_files=()
    # TODO: lint the test files too:
    # "$script_dir"/../tests/lib/*.bats  "$script_dir"/../tests/src/*.bats  "$script_dir"/../tests/github-scripts/*.bats  "$script_dir"/../tests/helpers/*.bats
    for file in "$lib_dir"/*.sh "$script_dir"/*.sh "$lib_dir"/../../../.github/scripts/*.sh; do
        [[ -f $file ]] && shellcheck_files+=("$(realpath "$file")")
    done
    declare -i shellcheck_rc=0
    (cd "$lib_dir/../../.." && timeout "$shellcheck_timeout" shellcheck "${shellcheck_files[@]}") || shellcheck_rc=$?
    if (( shellcheck_rc == 0 )); then
        info "ShellCheck found nothing in ${#shellcheck_files[@]} files."
    elif (( shellcheck_rc == 124 )); then # timeout's exit code when it stops the command
        warning "ShellCheck did not finish in ${shellcheck_timeout} seconds and was stopped."
    else
        warning "ShellCheck reported the findings above, in ${#shellcheck_files[@]} files."
    fi
else
    warning "ShellCheck is not installed, so it was skipped."
fi
