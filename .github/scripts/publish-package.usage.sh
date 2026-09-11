# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Val Melamed

# shellcheck disable=SC2148 # This script is intended to be sourced, not executed directly.

declare -xr common_switches
declare -xr common_vars
declare -xr script_name

declare -xr common_dotnet_parameters
declare -xr common_dotnet_vars

function usage_text()
{
    local _long_text=$1
    local _common_switches=""
    local _common_vars=""

    if $_long_text; then
        _common_vars=$common_vars
        _common_switches="\

Switches:
$common_switches"
    fi

    cat << EOF
Usage: $script_name [<package-project>] [--<long option> <value>|-<short option> <value> | --<long switch>|-<short switch> ]*
Packages and publishes NuGet packages to the specified server

Arguments:
  <package-project>             Path to the project or solution to package and publish. The file must exist and cannot be empty.
                                Initial value from the \$PACKAGE_PROJECT environment variable.

Options:
  -r, --reason <reason text>    Reason for release (e.g., "prerelease", "stable release", "hotfix", etc.). The reason is also
                                added as a release note in the package metadata.
                                Initial value from \$REASON or default "release build".
  -s, --save-artifacts [true|false]
                                Whether the package(s) should be uploaded as workflow artifact(s) as well.
                                Initial value from \$SAVE_ARTIFACTS or default false.
  -n, --nuget-server <NuGet moniker>
                                NuGet server to push the packages to. Valid values are, "nuget" for NuGet.org, "github" for
                                GitHub Packages, or a custom server URL for pushing to.
                                Initial value from the \$NUGET_SERVER environment variable or "nuget".
                                NOTE: the corresponding API key environment variable MUST be set for authentication in the NuGet
                                API key: \$NUGET_API_KEY.
  -o, --repo-owner <repo owner> Repository owner. When run on a GitHub runner, this is automatically set from the
                                \$GITHUB_REPOSITORY_OWNER environment variable. Required only if publishing to GitHub Packages
                                Initial value from the \$GITHUB_REPOSITORY_OWNER environment variable or "vmelamed".
$common_dotnet_parameters
$_common_switches
Environment Variables:
  PACKAGE_PROJECT               Project/solution paths to package and publish.
  REASON                        Reason for triggering the release
                                (defaults: for stable release: 'stable release'; for prerelease: 'prerelease')
  NUGET_SERVER                  NuGet server to publish to (supported values: 'nuget', 'github', or custom URI)
                                (default: 'nuget').
  GITHUB_REPOSITORY_OWNER       The owner of the GitHub repository
                                (default: 'vmelamed').
  SAVE_ARTIFACTS                Whether the package(s) will be uploaded as workflow artifacts as well
                                Initial value from \$SAVE_ARTIFACTS or default false.
  NUGET_API_KEY                 The NuGet API key for the selected NuGet server. Mandatory.
$common_dotnet_vars
$_common_vars
EOF
}
