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
#   - Only outside Markdown code: backtick spans and fenced blocks stay as they are, so a suggestion like "replace `<br>`
#     with `<p>`" keeps its tags. (A line is split on backticks: the odd parts are prose, the even parts are code.)
#   - Lowercase tags only (mawk has no case-insensitive matching); GitHub and Copilot emit lowercase HTML.
function strip_html()
{
    local _tags='a|b|br|code|details|div|em|h[1-6]|hr|i|img|kbd|li|ol|p|picture|pre|source|span|strong|sub|summary|sup|table|tbody|td|th|thead|tr|ul'
    awk -v tags="$_tags" '
        /^[[:space:]]*```/ { fenced = !fenced; print; next }
        fenced             { print; next }
        {
            n = split($0, parts, "`")
            out = ""
            for (k = 1; k <= n; k++) {
                if (k % 2 == 1) {
                    gsub(/<!--([^-]|-[^-])*-->/, "", parts[k])
                    gsub("</?(" tags ")([[:space:]][^>]*)?/?>", "", parts[k])
                }
                out = out (k > 1 ? "`" : "") parts[k]
            }
            print out
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
