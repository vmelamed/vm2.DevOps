#!/bin/bash

# shellcheck disable=SC2154 # variable is referenced but not assigned.
function usage_text()
{
    cat << EOF
Usage:

    ${script_name} [--<long option> <value>|-<short option> <value> |
                    --<long switch>|-<short switch> ]*

    Packages and publishes NuGet packages to the specified server.

Parameters:
    None

Switches:$common_switches
Options:
    --package-project | -p
        Project/solution path to package and publish.
        Initial value from the \$PACKAGE_PROJECT environment variable. The file
        must exist and cannot be empty.

    --nuget-server | -n
        NuGet server to push packages to. Valid values are "github" for  GitHub
        Packages, "nuget" for NuGet.org, or a custom server URL for pushing to.
        Initial value from the \$NUGET_SERVER environment variable or "github".

        NOTE: a corresponding API key environment variable must be set for
        authentication:
            github - \$NUGET_API_GITHUB_KEY or \$NUGET_API_KEY for GitHub
                     Packages
            nuget  - \$NUGET_API_NUGET_KEY or \$NUGET_API_KEY for NuGet.org
            custom - \$NUGET_API_KEY for a custom NuGet server.

    --minver-tag-prefix | -t
        Specifies the tag prefix used by MinVer (e.g., 'v').
        Initial value from \$MINVER_TAG_PREFIX environment variable or 'v'.

    --repo-owner | -o
        Repository owner. When run on a GitHub runner, this is automatically set
        from the \$GITHUB_REPOSITORY_OWNER environment variable. Required only
        if publishing to GitHub Packages.
        Initial value from the \$GITHUB_REPOSITORY_OWNER environment variable or
        "vmelamed".

    --version | -v
        Semantic Version (SemVer 2.0.0) of the package. Usually computed by the
        scripts 'compute-prerelease-version.sh' or  'compute-release-version.sh'.
        Initial value from the \$VERSION environment variable.

    --git-tag | -g
        The git tag to associate with the release. Usually \$MINVER_TAG_PREFIX
        concatenated with \$VERSION (e.g., 'v2.0.0-preview.1')
        Initial value from the \$GIT_TAG environment variable, or
        "${minver_tag_prefix}${version}"

    --reason | -r
        Reason for release (e.g., "prerelease", "stable release", "hotfix", etc.)
        Added as release note.
        Initial value from \$REASON or default "release build"

    --artifacts-saved | -a
        Whether the package(s) should be uploaded as workflow artifacts as well.
        Initial value from \$ARTIFACTS_SAVED or default "false".

    --artifacts-dir | -d
        Directory where artifacts will be saved, if --artifacts-saved is true.
        Initial value from \$ARTIFACTS_DIR or default "artifacts/pack".

Environment Variables:
    PROJECT             Project/solution paths to package and publish

    NUGET_SERVER        NuGet server to publish to (supported values: 'nuget',
                        'github', or custom URI)
                        (default: 'nuget')

    MINVER_TAG_PREFIX   Git tag prefix to be recognized by MinVer
                        (default: 'v')

    GITHUB_REPOSITORY_OWNER The owner of the GitHub repository
                        (default: 'vmelamed')

    VERSION             Semantic Version  of the package (e.g. for a stable
                        release 2.0.0 or for a prerelease 2.0.0-preview...).

    GIT_TAG             The git tag associated with the release. Usually
                        \$MINVER_TAG_PREFIX and \$VERSION concatenated (e.g.,
                        'v2.0.0-preview.1')

    REASON              Reason for triggering the release.
                        (default for stable release: 'stable release' and for
                        prerelease: 'prerelease')

    ARTIFACTS_SAVED     Whether the package(s) will be uploaded as workflow
                        artifacts as well.
                        Initial value from \$ARTIFACTS_SAVED or default "false".

    ARTIFACTS_DIR       Directory where artifacts will be saved if
                        --artifacts-saved is true.
                        Initial value from \$ARTIFACTS_DIR or default
                        "artifacts/pack".

    NUGET_API_GITHUB_KEY or
    NUGET_API_KEY       Required NuGet API key for GitHub Packages

    NUGET_API_NUGET_KEY or
    NUGET_API_KEYfor    Required NuGet API key for NuGet.org

    NUGET_API_KEY       Required NuGet API key for a custom NuGet server.

EOF
}

function usage()
{
    display_usage_msg "$(usage_text)" "$@"
}
