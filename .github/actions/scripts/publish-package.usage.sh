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
Packages and publishes NuGet packages to the specified server

Options:
  -p, --package-project         Path to the project or solution to package and publish. The file must exist and cannot be empty.
                                Initial value from the \$PACKAGE_PROJECT environment variable.
  -n, --nuget-server            NuGet server to push packages to. Valid values are "github" for  GitHub. Packages, "nuget" for
                                NuGet.org, or a custom server URL for pushing to
                                Initial value from the \$NUGET_SERVER environment variable or "github"
                                NOTE: a corresponding API key environment variable must be set for authentication:
                                - github - \$NUGET_API_GITHUB_KEY or \$NUGET_API_KEY for GitHub Packages
                                - nuget  - \$NUGET_API_NUGET_KEY or \$NUGET_API_KEY for NuGet.org
                                - custom - \$NUGET_API_KEY for a custom NuGet server
  -s, --preprocessor-symbols    Pre-processor symbols for compilation
                                Initial value from \$PREPROCESSOR_SYMBOLS or default ''
  -t, --minver-tag-prefix       Specifies the tag prefix used by MinVer (e.g., 'v')
                                Initial value from \$MINVERTAGPREFIX environment variable or 'v'
  -i, --minver-prerelease-id    Default semver pre-release identifiers for MinVer (e.g., 'preview.0')
                                Initial value from \$MINVERDEFAULTPRERELEASEIDENTIFIERS environment variable or 'preview.0'
  -o, --repo-owner              Repository owner. When run on a GitHub runner, this is automatically set from the
                                \$GITHUB_REPOSITORY_OWNER environment variable. Required only if publishing to GitHub Packages
                                Initial value from the \$GITHUB_REPOSITORY_OWNER environment variable or "vmelamed"
  -v, --version                 Semantic Version (SemVer 2.0.0) of the package. Usually computed by the scripts
                                'compute-prerelease-version.sh' or  'compute-release-version.sh'
                                Initial value from the \$VERSION environment variable
  -g, --git-tag                 The git tag to associate with the release. Usually \$MINVERTAGPREFIX concatenated with \$VERSION
                                (e.g., 'v2.0.0-preview.1')
                                Initial value from the \$GIT_TAG environment variable, or "${minver_tag_prefix}<version>"
  -r, --reason                  Reason for release (e.g., "prerelease", "stable release", "hotfix", etc.) Added also as a
                                release note in the package metadata
                                Initial value from \$REASON or default "release build"
  -a, --artifacts-saved         Whether the package(s) should be uploaded as workflow artifacts as well
                                Initial value from \$ARTIFACTS_SAVED or default "false"
  -d, --artifacts-dir           Directory where artifacts will be saved, if --artifacts-saved is true
                                Initial value from \$ARTIFACTS_DIR or default "artifacts/pack"

$std_switches
Environment Variables:
  PROJECT                       Project/solution paths to package and publish
  NUGET_SERVER                  NuGet server to publish to (supported values: 'nuget', 'github', or custom URI)
                                (default: 'nuget')
  PREPROCESSOR_SYMBOLS          Pre-processor symbols for compilation
                                (default: '')
  MINVERDEFAULTPRERELEASEIDENTIFIERS
                                Default semver pre-release identifiers for MinVer
                                (default: 'preview.0')
  MINVERTAGPREFIX               Git tag prefix to be recognized by MinVer
                                (default: 'v')
  GITHUB_REPOSITORY_OWNER       The owner of the GitHub repository
                                (default: 'vmelamed')
  VERSION                       Semantic Version  of the package (e.g. for a stable release 2.0.0 or for a prerelease
                                2.0.0-preview.0...)
  GIT_TAG                       The git tag associated with the release. Usually \$MINVERTAGPREFIX and \$VERSION concatenated
                                (e.g., 'v2.0.0-preview.0')
  REASON                        Reason for triggering the release
                                (defaults: for stable release: 'stable release'; for prerelease: 'prerelease')
  ARTIFACTS_SAVED               Whether the package(s) will be uploaded as workflow artifacts as well
                                Initial value from \$ARTIFACTS_SAVED or default "false"
  ARTIFACTS_DIR                 Directory where artifacts will be saved if --artifacts-saved is true
                                Initial value from \$ARTIFACTS_DIR or default "artifacts/pack"
  NUGET_API_GITHUB_KEY or       Required NuGet API key for GitHub Packages
  NUGET_API_KEY
  NUGET_API_NUGET_KEY or        Required NuGet API key for NuGet.org
  NUGET_API_KEY
  NUGET_API_KEY                 Required NuGet API key for a custom NuGet server
$std_vars
EOF
}

function usage()
{
    local long_help=true
    if [[ $# -gt 0 && ($1 == true || $1 == false) ]]; then
        long_help=$1
        shift
    fi
    display_usage_msg "$(usage_text "$long_help")" "$@"
}
