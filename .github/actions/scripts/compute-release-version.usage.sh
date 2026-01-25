#!/usr/bin/env bash

# shellcheck disable=SC2154 # variable is referenced but not assigned
function usage_text()
{
    local std_switches=""
    local std_vars=""

    if [[ $1 == true ]]; then
        std_switches="
Switches:
$common_switches"
        std_vars=$common_vars
    fi

    cat << EOF
Usage: ${script_name} [--<long option> <value>|-<short option> <value> | --<long switch>|-<short switch> ]*
Computes the next release version based on conventional commits or manual input. Analyzes commit messages since the last
stable tag to determine the appropriate semantic version bump:
  - BREAKING CHANGE or feat! -> major bump
  - feat: -> minor bump
  - fix: or other -> patch bump

Options:
  -p, --package-projects        JSON array of project/solution paths to package and publish, e.g
                                '["src/Project1/Project1.csproj", "src/Project2/Project2.csproj"]'. If the array is empty,
                                auto-detects root .sln or .csproj files. Does not participate in the release version
                                computation, but will be validated to fail the workflow early if invalid
                                Initial value from \$PACKAGE_PROJECTS or default '[""]'
  -n, --nuget-server            NuGet server to publish to (supported values for now: 'nuget', 'github', or custom URI)
                                Does not participate in the release version computation, but will be
                                validated to fail the workflow early if invalid
                                Initial value from \$NUGET_SERVER or default 'nuget'
  -t, --minver-tag-prefix       Specifies the tag prefix used by MinVer (e.g., 'v')
                                Initial value from \$MINVERTAGPREFIX or default 'v'
  -r, --reason                  Reason for release (e.g., "stable release", "hotfix", etc.)
                                Initial value from \$REASON or default "release build"

$std_switches
Environment Variables:
    PACKAGE_PROJECTS            JSON array of project/solution paths to package and publish
                                (default: '[""]')
    NUGET_SERVER                NuGet server to publish to (supported values: 'nuget', 'github', or custom URI)
                                (default: 'nuget')
    MINVERTAGPREFIX             Git tag prefix to be recognized by MinVer
                                (default: 'v')
    REASON                      Reason for the release build and possibly overriding the natural versioning
                                (default: 'release build')
$std_vars
Outputs (to GITHUB_OUTPUT):
  release-version               The computed version (e.g., '1.2.3')
  release-tag                   The full tag (e.g., 'v1.2.3')
  package-projects              The JSON array of project/solution paths to package and publish
  nuget-server                  The NuGet server to publish to
  minver-tag-prefix             Tag prefix used by MinVer (e.g., 'v')
  reason                        The reason for the release build and possibly overriding the natural versioning
                                (default: 'release build')
EOF
}

## Displays a usage message with the provided text (above)
## Usage: display_usage_msg "<usage text>" "[<additional info>]"
function usage()
{
    local long_help=true
    if [[ $# -gt 0 && ($1 == true || $1 == false) ]]; then
        long_help=$1
        shift
    fi
    display_usage_msg "$(usage_text "$long_help")" "$@"
}
