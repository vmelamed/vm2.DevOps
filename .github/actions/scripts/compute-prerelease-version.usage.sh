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
Computes the next release version based on previous tags

Options:
  -p, --package-projects        JSON array of a solution or one or more project paths to be packaged and published, e.g
                                '["src/Project1/Project1.csproj", "src/Project2/Project2.csproj"]'. If the array is empty, it
                                auto-detects root .sln, .slnx or .csproj files. Does not participate in the release version
                                computation, but will be validated to fail the workflow early if invalid
                                Initial value from \$PACKAGE_PROJECTS or default '[""]'
  -t, --minver-tag-prefix       Specifies the tag prefix to be recognized by MinVer (e.g., 'v')
                                Initial value from \$MINVERTAGPREFIX or default 'v'
  -s, --minver-prerelease-id    Specifies the prefix for the semver's prerelease component in prerelease versions (e.g.,
                                'preview.0', 'alpha', 'rc1' as in '1.2.3-preview.1')
                                Initial value from \$MINVERDEFAULTPRERELEASEIDENTIFIERS or default 'preview.0'
  -r, --reason                  Reason for prerelease (e.g., "prerelease build", "hotfix", etc.)
                                Initial value from \$REASON or default "prerelease build"
  -n, --nuget-server            NuGet server to publish to (supported values for now: 'nuget', 'github', or custom URI). Does
                                not participate in the release version computation, but will be validated to fail the workflow
                                early if invalid
                                Initial value from \$NUGET_SERVER or default 'nuget'

$std_switches
Environment Variables:
    PACKAGE_PROJECTS            JSON array of project/solution paths to package and publish
                                (default: '[""]')
    MINVERTAGPREFIX             Git tag prefix to be recognized by MinVer
                                (default: 'v')
    MINVERDEFAULTPRERELEASEIDENTIFIERS
                                Prefix for semver's prerelease component in prerelease versions
                                (default: 'preview.0' as in '1.2.3-preview.1')
    REASON                      Reason for manual prerelease (default: "prerelease build")
    NUGET_SERVER                NuGet server to publish to. Supported values: 'nuget', 'github', or custom URI
                                (default: 'nuget')
    GITHUB_OUTPUT               Path to write GitHub Actions outputs (or /dev/null)
                                (default: '/dev/null' if not set by GitHub Actions)
    GITHUB_STEP_SUMMARY         Path to write GitHub Actions summary
                                (default: '/dev/stdout' if not set by GitHub Actions)
    GITHUB_RUN_NUMBER           The unique number for each run of a workflow
                                (default: current UTC time in HHMMSS format if not set by GitHub Actions)
$std_vars
Output to \$GITHUB_OUTPUT:
  package-projects
  minver-tag-prefix
  prerelease-version
  prerelease-tag
  nuget-server

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
