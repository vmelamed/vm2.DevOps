#!/bin/bash

# shellcheck disable=SC2154 # variable is referenced but not assigned.
function usage_text()
{
    cat << EOF
Usage:

    ${script_name} [--<long option> <value>|-<short option> <value> |
                    --<long switch>|-<short switch> ]*

    Computes the next release version based on previous tags.

Parameters:
    None

Switches:$common_switches
Options:
    --package-projects | -p
        JSON array of a solution or projects paths to package and publish, e.g.
        '["src/Project1/Project1.csproj", "src/Project2/Project2.csproj"]'.
        If the array is empty, auto-detects root .sln, .slnx or .csproj files.
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
        Specifies the tag prefix to be recognized by MinVer (e.g., 'v').
        Initial value from \$MINVER_TAG_PREFIX or default 'v'

    --semver-prerelease-prefix | -s
        Specifies the prefix for the semver's prerelease component in prerelease
        versions (e.g., 'preview', 'alpha', 'rc1' as in '1.2.3-preview.1').
        Initial value from \$SEMVER_PRERELEASE_PREFIX or default 'preview'

    --reason | -r
        Reason for prerelease (e.g., "prerelease build", "hotfix", etc.).
        Initial value from \$REASON or default "prerelease build"

Environment Variables:
    PACKAGE_PROJECTS    JSON array of project/solution paths to package and
                        publish
                        (default: '[""]')

    NUGET_SERVER        NuGet server to publish to (supported values: 'nuget',
                        'github', or custom URI)
                        (default: 'nuget')

    MINVER_TAG_PREFIX   Git tag prefix to be recognized by MinVer
                        (default: 'v')

    SEMVER_PRERELEASE_PREFIX Prefix for semver's prerelease component in
                        prerelease versions
                        (default: 'preview' as in '1.2.3-preview.1')

    REASON              Reason for manual prerelease
                        (default: "prerelease build")

    GITHUB_OUTPUT       Path to write GitHub Actions outputs (or /dev/null)
                        (default: '/dev/null' if not set by GitHub Actions)

    GITHUB_STEP_SUMMARY Path to write GitHub Actions summary
                        (default: '/dev/stdout' if not set by GitHub Actions)

    GITHUB_RUN_NUMBER   The unique number for each run of a workflow
                        (default: current UTC time in HHMMSS format if not set
                        by GitHub Actions)

Outputs (to GITHUB_OUTPUT):
    package-projects
    nuget-server
    minver-tag-prefix
    prerelease-version
    prerelease-tag

EOF
}

function usage()
{
    display_usage_msg "$(usage_text)" "$@"
}
