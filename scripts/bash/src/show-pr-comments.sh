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

source "$lib_dir/core.sh"

# core constants
declare -xri success
declare -xri err_not_found
declare -xri err_tool_error

#---------------------------------------------------------------------------------------------
# @description Prints the reviews and the inline review comments of a GitHub pull request, straight from the GitHub API
# ('gh api'), e.g. Copilot's review right after a push -- faster than waiting for an editor's comment panel to sync.
#
# With '--watch', the script first waits until the pull request's latest commit (its head) has at least one review, then
# prints. A review of an older commit does not count: after a push, the new commit is what gets reviewed next.
#
# The script is read-only: every 'gh' call is a query, so none of them goes through 'execute'.
#
# @arg $1 int The pull request number (optional; defaults to the pull request of the current branch).
#
# @exitcode success=0: The comments were printed.
# @exitcode err_not_found: No repository or pull request could be resolved, or '--watch' timed out.
# @exitcode err_tool_error: A 'gh' query failed.
#
# @stdout The pull request's title and URL, then its reviews, then its inline comments ('file:line', author, text).
#
# @example
#   show-pr-comments.sh --watch
#---------------------------------------------------------------------------------------------

source "$script_dir/show-pr-comments.args.sh"
source "$script_dir/show-pr-comments.usage.sh"

get_arguments "$@"

# script arguments
declare -xr pr_number
declare -xr repo
declare -xr watch
declare -xr interval
declare -xr timeout

declare pr_title pr_url pr_head

{
    IFS=$'\t' read -r pr_title pr_url pr_head
} < <(gh pr view "$pr_number" --repo "$repo" --json title,url,headRefOid --jq '[.title, .url, .headRefOid] | @tsv') || exit_with_error -ec "$err_tool_error" "Could not read pull request #$pr_number of '$repo'."
[[ -n $pr_head ]]                                                                                                   || exit_with_error -ec "$err_not_found" "Pull request #$pr_number of '$repo' was not found."

# Counts the submitted reviews of the pull request's head commit. A PENDING review (the authenticated user's draft, not
# yet submitted) already carries the head commit's id, but is not a review yet: it must not end '--watch'. The SHA is 40
# hex digits from GitHub, so it is safe to put into the jq filter.
function count_head_reviews()
{
    gh api --paginate "repos/$repo/pulls/$pr_number/reviews" \
           --jq ".[] | select(.commit_id == \"$pr_head\" and .state != \"PENDING\") | .id" |
        wc -l
}

if $watch; then
    declare -i deadline=$(( SECONDS + timeout ))
    declare -i head_reviews=0
    declare -i remaining=0
    while :; do
        head_reviews=$(count_head_reviews)                                                                          || exit_with_error -ec "$err_tool_error" "Could not read the reviews of #$pr_number."
        (( head_reviews == 0 )) || break
        remaining=$(( deadline - SECONDS ))
        (( remaining > 0 ))                                                                                         || exit_with_error -ec "$err_not_found" "No review of commit ${pr_head:0:7} of #$pr_number within $timeout seconds."
        info "Waiting for a review of commit ${pr_head:0:7} of #$pr_number (checking every $interval seconds)..."
        # never sleep past the deadline: '--timeout' limits the wait, whatever the interval
        sleep $(( interval < remaining ? interval : remaining ))
    done
fi

# Review bodies are Markdown with embedded HTML (Copilot uses <picture>, <details>, ...): strip the HTML comments and the
# tags of a known list, then squeeze the blank lines they leave behind, so the text stays readable in a terminal.
#   - Only known tags: review text often contains tag-like placeholders ('<name>', '<pr-number>') that must survive.
#   - Only outside Markdown code, so a suggestion like "replace `<br>` with `<p>`" keeps its tags:
#     - a fenced block opens with 3+ backticks or tildes (indented up to 3 spaces) and closes only on a fence of the same
#       character, at least as long, with nothing after it -- so a ```` block can show a ``` example (CommonMark 4.5);
#     - a code span opens with a run of N backticks and closes on the next run of exactly N, so ``<br>`` is code too; an
#       unmatched run is literal text (CommonMark 6.1). Code spans are matched within a line, which covers review text.
#   - An HTML comment ends at the first '-->', even several lines later; backticks inside it do not open a code span.
#   - Lowercase tags only (mawk has no case-insensitive matching); GitHub and Copilot emit lowercase HTML.
function strip_html()
{
    local _tags='a|b|br|code|details|div|em|h[1-6]|hr|i|img|kbd|li|ol|p|picture|pre|source|span|strong|sub|summary|sup|table|tbody|td|th|thead|tr|ul'
    awk -v tags="$_tags" '
        # the length of the run of the character c that starts at position p of s
        function run_length(s, p, c,    n) { n = 0; while (substr(s, p + n, 1) == c) n++; return n }

        # the position of the first run of exactly n backticks in s at or after position p, or 0
        function closing_run(s, p, n) {
            while (match(substr(s, p), /`+/)) {
                p += RSTART - 1
                if (RLENGTH == n) return p
                p += RLENGTH
            }
            return 0
        }

        function strip_tags(s) { gsub("</?(" tags ")([[:space:]][^>]*)?/?>", "", s); return s }

        {
            line = $0
            # a fence candidate: up to 3 spaces of indentation, then the fence character c repeated n times
            match(line, /^ ? ? ?/); p = RLENGTH + 1; c = substr(line, p, 1)
            n = (c == "`" || c == "~") ? run_length(line, p, c) : 0

            if (fence_len > 0) {
                if (c == fence_char && n >= fence_len && substr(line, p + n) ~ /^[[:space:]]*$/) fence_len = 0
                print; next
            }
            # an opening fence (a backtick fence cannot have a backtick in its info string)
            if (!in_comment && n >= 3 && !(c == "`" && index(substr(line, p + n), "`"))) {
                fence_char = c; fence_len = n
                print; next
            }

            out = ""; prose = ""; i = 1; len = length(line)
            while (i <= len) {
                if (in_comment) {
                    e = index(substr(line, i), "-->")
                    if (e == 0) break                           # the comment goes on in the next line
                    i += e + 2; in_comment = 0
                    continue
                }
                if (substr(line, i, 4) == "<!--") {
                    out = out strip_tags(prose); prose = ""
                    in_comment = 1; i += 4
                    continue
                }
                ch = substr(line, i, 1)
                if (ch == "`") {
                    n = run_length(line, i, "`")
                    e = closing_run(line, i + n, n)
                    if (e > 0) {                                # a code span: keep it as it is
                        out = out strip_tags(prose) substr(line, i, e + n - i); prose = ""
                        i = e + n
                    } else {                                    # no matching run: literal backticks
                        prose = prose substr(line, i, n)
                        i += n
                    }
                    continue
                }
                # plain text up to the next backtick or "<"
                if (ch != "<" && match(substr(line, i), /[`<]/)) { prose = prose substr(line, i, RSTART - 1); i += RSTART - 1 }
                else if (ch != "<")                             { prose = prose substr(line, i); i = len + 1 }
                else                                            { prose = prose ch; i++ }
            }
            print out strip_tags(prose)
        }' | cat -s
}

printf '#%s: %s\n%s\n' "$pr_number" "$pr_title" "$pr_url"

# PENDING reviews (the authenticated user's draft, not yet submitted) are skipped: they have no 'submitted_at' yet, and the text
# is not final. The '// ""' keeps the formatting safe even so.
printf '\n== Reviews\n\n'
gh api --paginate "repos/$repo/pulls/$pr_number/reviews" \
       --jq '.[] | select(.state != "PENDING" and .body != "") | "-- \(.user.login) [\(.state)] \((.submitted_at // "")[:16] | sub("T"; " "))\n\(.body)\n"' |
    strip_html                                                                                                      || exit_with_error -ec "$err_tool_error" "Could not read the reviews of #$pr_number."

printf '\n== Inline comments\n\n'
gh api --paginate "repos/$repo/pulls/$pr_number/comments" \
       --jq '.[] | "-- \(.path):\(.line // .original_line)\(if .in_reply_to_id then " (reply)" else "" end) -- \(.user.login)\n\(.body)\n"' |
    strip_html                                                                                                      || exit_with_error -ec "$err_tool_error" "Could not read the inline comments of #$pr_number."
