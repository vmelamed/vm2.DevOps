#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# Tests for scripts/bash/src/show-pr-comments.sh.
#
# A fake `gh` first on $PATH answers the script's queries without the network:
#   - `gh repo view` / `gh pr view` print configurable values (or fail, to simulate "no repository" / "no PR");
#   - `gh api --paginate <endpoint> --jq <filter>` runs the REAL jq with the script's own filter on a JSON fixture, so
#     the tests also cover the script's jq expressions, not just canned output. For '--watch', the reviews fixture can
#     switch to a second file after a given number of calls ($FAKE_REVIEWS_AFTER), as if a review arrived meanwhile.

bats_require_minimum_version 1.5.0

load '../libs/bats-support/load'
load '../libs/bats-assert/load'
load '../helpers/setup'

declare -gx lib_dir
declare -gxi err_argument_value
declare -gxi err_missing_argument
declare -gxi err_not_found

_src_dir="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../../src" && pwd)"
_pr_comments="$_src_dir/show-pr-comments.sh"

_install_fake_gh() {
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    cat > "$BATS_TEST_TMPDIR/bin/gh" <<'EOF'
#!/usr/bin/env bash
echo "$*" >> "$FAKE_GH_DIR/calls.log"
case "$1 $2" in
    "repo view" )
        [[ -z ${FAKE_NO_REPO:-} ]] || exit 1
        echo "${FAKE_REPO:-acme/repo}"
        exit 0
        ;;
    "pr view" )
        if [[ ${3:-} == --json ]]; then                       # no number: the PR of the current branch
            [[ -z ${FAKE_NO_PR:-} ]] || exit 1
            echo "${FAKE_PR:-7}"
            exit 0
        fi
        printf 'Fix the thing\thttps://github.com/%s/pull/%s\t%s\n' "${FAKE_REPO:-acme/repo}" "$3" "${FAKE_HEAD:-headsha}"
        exit 0
        ;;
    "api --paginate" )
        endpoint=$3; shift 3; filter=''
        while (( $# > 0 )); do [[ $1 == --jq ]] && { filter=$2; break; }; shift; done
        case $endpoint in
            */reviews )
                calls=$(( $(cat "$FAKE_GH_DIR/review_calls" 2>/dev/null || echo 0) + 1 ))
                echo "$calls" > "$FAKE_GH_DIR/review_calls"
                fixture="$FAKE_GH_DIR/reviews.json"
                [[ -z ${FAKE_REVIEWS_AFTER:-} ]] || (( calls < FAKE_REVIEWS_AFTER )) || fixture="$FAKE_GH_DIR/reviews.later.json"
                jq -r "$filter" < "$fixture"
                ;;
            */comments )
                jq -r "$filter" < "$FAKE_GH_DIR/comments.json"
                ;;
        esac
        exit 0
        ;;
esac
exit 1
EOF
    chmod +x "$BATS_TEST_TMPDIR/bin/gh"

    cat > "$BATS_TEST_TMPDIR/reviews.json" <<'EOF'
[
  { "user": { "login": "copilot-pull-request-reviewer[bot]" }, "state": "COMMENTED", "submitted_at": "2026-10-25T22:45:34Z",
    "commit_id": "headsha",
    "body": "<!-- ccr-overview-v2 -->\n<details open><summary>1 open issue</summary>Keep the placeholder `<name>` intact.</details>" },
  { "user": { "login": "val" }, "state": "APPROVED", "submitted_at": "2026-10-25T23:00:00Z", "commit_id": "headsha", "body": "" }
]
EOF
    cat > "$BATS_TEST_TMPDIR/comments.json" <<'EOF'
[
  { "path": "src/a.sh", "line": 12, "original_line": 10, "in_reply_to_id": null,
    "user": { "login": "Copilot" }, "body": "Quote this variable." },
  { "path": "src/a.sh", "line": null, "original_line": 10, "in_reply_to_id": 1,
    "user": { "login": "val" }, "body": "Done." }
]
EOF
}

# _run <env assignments> <arguments...> -- runs the script from a scratch directory, with only the fake gh on PATH
_run() {
    local _env=$1; shift
    run env -i HOME="$HOME" PATH="$BATS_TEST_TMPDIR/bin:/usr/local/bin:/usr/bin:/bin" FAKE_GH_DIR="$BATS_TEST_TMPDIR" \
        bash -c "cd '$BATS_TEST_TMPDIR' && $_env bash '$_pr_comments' $*"
}

# --- help and argument validation -------------------------------------------------------------

@test "show-pr-comments: --help prints the usage, even without gh" {
    run env -i HOME="$HOME" PATH="/usr/bin:/bin" bash -c "bash '$_pr_comments' --help"
    assert_success
    assert_output --partial "Usage:"
    assert_output --partial "--watch"
}

@test "show-pr-comments: rejects a pull request number that is not a positive integer" {
    _install_fake_gh
    _run '' abc
    assert_failure "$err_argument_value"
    assert_output --partial "must be a positive integer"
}

@test "show-pr-comments: rejects a repository that is not 'owner/repo'" {
    _install_fake_gh
    _run '' 7 --repo just-a-name
    assert_failure "$err_argument_value"
    assert_output --partial "'owner/repo'"
}

@test "show-pr-comments: --repo without a pull request number is an error" {
    _install_fake_gh
    _run '' --repo acme/repo
    assert_failure "$err_missing_argument"
    assert_output --partial "the pull request number is required"
}

@test "show-pr-comments: without a number, fails when the current branch has no pull request" {
    _install_fake_gh
    _run 'FAKE_NO_PR=1' ''
    assert_failure "$err_not_found"
    assert_output --partial "has no pull request"
}

# --- output -----------------------------------------------------------------------------------

@test "show-pr-comments: prints the title, the reviews with a body, and the inline comments with file:line and replies" {
    _install_fake_gh
    _run '' 7
    assert_success
    assert_line "#7: Fix the thing"
    assert_line "https://github.com/acme/repo/pull/7"
    assert_line "-- copilot-pull-request-reviewer[bot] [COMMENTED] 2026-10-25 22:45"
    refute_output --partial "[APPROVED]"                                   # a review without a body is skipped
    assert_line "-- src/a.sh:12 -- Copilot"
    assert_line "Quote this variable."
    assert_line "-- src/a.sh:10 (reply) -- val"                           # no current line: falls back to the original
}

@test "show-pr-comments: strips Copilot's HTML, but keeps tag-like placeholders such as <name>" {
    _install_fake_gh
    _run '' 7
    assert_success
    assert_output --partial 'Keep the placeholder `<name>` intact.'
    refute_output --partial "<details"
    refute_output --partial "<summary"
    refute_output --partial "<!--"
}

@test "show-pr-comments: keeps HTML inside Markdown code spans and fenced blocks, strips it outside" {
    # regression (Copilot, PR #58): "replace `<br>` with `<p>`" lost both tags
    _install_fake_gh
    cat > "$BATS_TEST_TMPDIR/comments.json" <<'EOF'
[ { "path": "README.md", "line": 3, "original_line": 3, "in_reply_to_id": null, "user": { "login": "Copilot" },
    "body": "<details><summary>Fix</summary>Replace `<br>` with `<p>`.</details>\n```html\n<div class=\"x\">kept</div>\n```" } ]
EOF
    _run '' 7
    assert_success
    assert_line 'FixReplace `<br>` with `<p>`.'
    assert_line '<div class="x">kept</div>'
    refute_output --partial "<details>"
}

@test "show-pr-comments: a fence closes only on a matching fence -- a \`\`\`\` block can show \`\`\`, and ~~~ blocks are code too" {
    # regression (Copilot, PR #59): every line starting with ``` toggled the state, and tilde fences were not recognized
    _install_fake_gh
    cat > "$BATS_TEST_TMPDIR/comments.json" <<'EOF'
[ { "path": "README.md", "line": 3, "original_line": 3, "in_reply_to_id": null, "user": { "login": "Copilot" },
    "body": "````markdown\n```html\n<div>inner</div>\n```\n<p>still code</p>\n````\n<b>prose</b>\n~~~html\n<span>tilde</span>\n```\n<i>still tilde</i>\n~~~\n<em>after</em>" } ]
EOF
    _run '' 7
    assert_success
    assert_line '<div>inner</div>'
    assert_line '<p>still code</p>'                                      # the inner ``` did not close the ```` block
    assert_line 'prose'
    assert_line '<span>tilde</span>'
    assert_line '<i>still tilde</i>'                                     # a ``` fence does not close a ~~~ block
    assert_line 'after'
}

@test "show-pr-comments: keeps HTML in double-backtick code spans; strips HTML comments that contain backticks or span lines" {
    # regression (Copilot, PR #59): splitting on single backticks treated ``<br>`` as prose and left `-ticked comments in
    _install_fake_gh
    cat > "$BATS_TEST_TMPDIR/comments.json" <<'EOF'
[ { "path": "README.md", "line": 3, "original_line": 3, "in_reply_to_id": null, "user": { "login": "Copilot" },
    "body": "Use ``<br>`` or `` `<p>` ``, not <b>bold</b>.\n<!-- a `hidden` note -->Visible.\nBefore<!-- one\n`two`\nthree -->after\nA lone ` stays." } ]
EOF
    _run '' 7
    assert_success
    assert_line 'Use ``<br>`` or `` `<p>` ``, not bold.'
    assert_line 'Visible.'
    assert_line 'Before'
    assert_line 'after'
    assert_line 'A lone ` stays.'
    refute_output --partial 'hidden'
    refute_output --partial 'two'
}

@test "show-pr-comments: skips a pending (not yet submitted) review instead of failing on its missing timestamp" {
    # regression (Copilot, PR #58): sub("T"; " ") on a null 'submitted_at' failed, before the inline comments were printed
    _install_fake_gh
    cat > "$BATS_TEST_TMPDIR/reviews.json" <<'EOF'
[ { "user": { "login": "val" }, "state": "PENDING", "submitted_at": null, "commit_id": "headsha",
    "body": "A draft, not yet submitted." } ]
EOF
    _run '' 7
    assert_success
    refute_output --partial "A draft, not yet submitted."
    assert_line "Quote this variable."                                     # the inline comments still come
}

@test "show-pr-comments: --watch does not count a pending review of the head commit" {
    # regression (Copilot, PR #58): a draft carries the head commit's id and ended the wait before the review was submitted
    _install_fake_gh
    cat > "$BATS_TEST_TMPDIR/reviews.json" <<'EOF'
[ { "user": { "login": "val" }, "state": "PENDING", "submitted_at": null, "commit_id": "headsha", "body": "A draft." } ]
EOF
    _run '' 7 --watch --interval 1 --timeout 2
    assert_failure "$err_not_found"
    assert_output --partial "within 2 seconds"
}

@test "show-pr-comments: --watch never sleeps past the timeout, even with a longer interval" {
    # regression (Copilot, PR #58): '--timeout 2' with a 30-second interval slept the full 30 seconds
    _install_fake_gh
    cat > "$BATS_TEST_TMPDIR/reviews.json" <<'EOF'
[ { "user": { "login": "copilot-pull-request-reviewer[bot]" }, "state": "COMMENTED",
    "submitted_at": "2026-10-25T20:00:00Z", "commit_id": "oldsha", "body": "A review of the previous commit." } ]
EOF
    local -i _started=$SECONDS
    _run '' 7 --watch --interval 30 --timeout 2
    assert_failure "$err_not_found"
    (( SECONDS - _started < 10 ))
}

@test "show-pr-comments: without a number, uses the pull request of the current branch" {
    _install_fake_gh
    _run 'FAKE_PR=42' ''
    assert_success
    assert_line "#42: Fix the thing"
}

# --- --watch ----------------------------------------------------------------------------------

@test "show-pr-comments: --watch waits until the head commit has a review, then prints it" {
    _install_fake_gh
    cat > "$BATS_TEST_TMPDIR/reviews.json" <<'EOF'
[ { "user": { "login": "copilot-pull-request-reviewer[bot]" }, "state": "COMMENTED",
    "submitted_at": "2026-10-25T20:00:00Z", "commit_id": "oldsha", "body": "A review of the previous commit." } ]
EOF
    cat > "$BATS_TEST_TMPDIR/reviews.later.json" <<'EOF'
[ { "user": { "login": "copilot-pull-request-reviewer[bot]" }, "state": "COMMENTED",
    "submitted_at": "2026-10-25T20:00:00Z", "commit_id": "oldsha", "body": "A review of the previous commit." },
  { "user": { "login": "copilot-pull-request-reviewer[bot]" }, "state": "COMMENTED",
    "submitted_at": "2026-10-25T22:00:00Z", "commit_id": "headsha", "body": "A review of the new commit." } ]
EOF
    _run 'FAKE_REVIEWS_AFTER=2' 7 --watch --interval 1 --timeout 30
    assert_success
    assert_output --partial "Waiting for a review of commit headsha"           # the first poll found only the old review
    assert_line "A review of the new commit."
}

@test "show-pr-comments: --watch fails with err_not_found when no review of the head commit arrives in time" {
    _install_fake_gh
    cat > "$BATS_TEST_TMPDIR/reviews.json" <<'EOF'
[ { "user": { "login": "copilot-pull-request-reviewer[bot]" }, "state": "COMMENTED",
    "submitted_at": "2026-10-25T20:00:00Z", "commit_id": "oldsha", "body": "A review of the previous commit." } ]
EOF
    _run '' 7 --watch --interval 1 --timeout 2
    assert_failure "$err_not_found"
    assert_output --partial "within 2 seconds"
}
