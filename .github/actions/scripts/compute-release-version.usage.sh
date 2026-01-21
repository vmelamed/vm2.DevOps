#!/usr/bin/env bash

# shellcheck disable=SC2154 # variable is referenced but not assigned.
function usage_text()
{
    cat << EOF
Usage:

    ${script_name} [--<long option> <value>|-<short option> <value> |
                    --<long switch>|-<short switch> ]*

    Computes the next release version based on conventional commits or manual
    input. Analyzes commit messages since the last stable tag to determine the
    appropriate semantic version bump:
      - BREAKING CHANGE or feat! → major bump
      - feat: → minor bump
      - fix: or other → patch bump

Parameters:
    None

Switches:$common_switches
Options:
    --package-projects | -p
        JSON array of project/solution paths to package and publish, e.g.
        '["src/Project1/Project1.csproj", "src/Project2/Project2.csproj"]'.
        If the array is empty, auto-detects root .sln or .csproj files.
        Does not participate in the release version computation, but will be
        validated to fail the workflow early if invalid.
        Initial value from \$PACKAGE_PROJECTS or default '[""]'

    --nuget-server | -n
        NuGet server to publish to (supported values for now: 'nuget', 'github',
        or custom URI).
        Does not participate in the release version computation, but will be
        validated to fail the workflow early if invalid.
        Initial value from \$NUGET_SERVER or default 'nuget'

    --minver-tag-prefix | -t
        Specifies the tag prefix used by MinVer (e.g., 'v').
        Initial value from \$MINVERTAGPREFIX or default 'v'

    --reason | -r
        Reason for release (e.g., "stable release", "hotfix", etc.).
        Initial value from \$REASON or default "release build"

Environment Variables:
    PACKAGE_PROJECTS    JSON array of project/solution paths to package and
                        publish
                        (default: '[""]')

    NUGET_SERVER        NuGet server to publish to (supported values: 'nuget',
                        'github', or custom URI)
                        (default: 'nuget')

    MINVERTAGPREFIX   Git tag prefix to be recognized by MinVer
                        (default: 'v')

    MANUAL_VERSION      Manual version to override the natural versioning
                        (default: '')

    REASON              Reason for the release build and possibly overriding the
                        natural versioning
                        (default: 'release build')

    GITHUB_OUTPUT       Path to write GitHub Actions outputs (or /dev/null)
                        (default: '/dev/null' if not set by GitHub Actions)

    GITHUB_STEP_SUMMARY Path to write GitHub Actions summary
                        (default: '/dev/stdout' if not set by GitHub Actions)

Outputs (to GITHUB_OUTPUT):
    release-version     The computed version (e.g., '1.2.3')
    release-tag         The full tag (e.g., 'v1.2.3')
    package-projects    The JSON array of project/solution paths to package and
                        publish
    nuget-server        The NuGet server to publish to
    minver-tag-prefix   Tag prefix used by MinVer (e.g., 'v')
    reason              The reason for the release build and possibly overriding
                        the natural versioning
                        (default: 'release build')
EOF
}

function usage()
{
    display_usage_msg "$(usage_text)" "$@"
}
