#!/usr/bin/env bash

# shellcheck disable=SC2154 # variables referenced but not assigned here
function usage_text()
{
    local std_switches=""

    if [[ $1 == true ]]; then
        std_switches="$common_switches"
    fi

    cat << EOF
Usage: ${script_name} [--repo <owner/repo> | --name <PackageName>] [options]

Bootstrap and configure a vm2 package repository using the GitHub CLI.

When run from within a git repository with an origin remote, --repo and --name
are optional — the repo is auto-detected from the remote URL.

This script will:
  - Initialize git, commit, and create the GitHub repository (unless --configure-only)
  - Set required secrets and variables for CI/CD workflows
  - Configure repository settings (squash merge, auto-delete branches, etc.)
  - Configure Actions workflow permissions (GITHUB_TOKEN default=read)
  - Set up branch protection with required status checks

Options:
  --repo <owner/repo>           Full repository name (e.g., vmelamed/vm2.MyPackage)
  --name <PackageName>          Package name — repo will be <org>/<PackageName>
  --org <github-org>            GitHub owner/org (default: vmelamed; used with --name)
  --visibility <public|private> Repository visibility (default: public)
  --branch <branch>             Branch to protect (default: main)
  --audit                       Read-only: report current vs expected settings without changes

Either --repo or --name is required when not inside a repo directory (but not both).

Switches:
  --configure-only              Skip repo creation; configure an existing repo only
  --skip-secrets                Skip setting repository secrets
  --skip-variables              Skip setting repository variables
$std_switches
Examples:
  ${script_name} --name Glob
  ${script_name} --repo vmelamed/vm2.Glob --configure-only
  ${script_name} --repo vmelamed/vm2.Glob --configure-only --skip-secrets --dry-run
  ${script_name} --name MyPackage --org myorg --visibility private
EOF
}

function usage()
{
    local long_help=false
    if [[ $# -gt 0 && ($1 == true || $1 == false) ]]; then
        long_help=$1
        shift
    fi
    display_usage_msg "$(usage_text "$long_help")" "$@"
}
