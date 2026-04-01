#!/usr/bin/env bash

declare -xr common_switches
declare -xr common_vars
declare -xr script_name

function usage_text()
{
    local long_text=$1
    local switches=""
    local vars=""

    if $long_text; then
        switches="Switches:"$'\n'"$common_switches"
        vars=$common_vars
    fi

    cat << EOF
Usage: ${script_name} [--<long option> <value>|-<short option> <value> | --<long switch>|-<short switch> ]*
Updates CHANGELOG.md using git-cliff, then creates and pushes a Git tag.

Accepts both release tags (e.g., v1.2.3) and prerelease tags (e.g., v1.2.3-preview.1).
Automatically selects the correct git-cliff config based on tag type:
  - Release:    changelog/cliff.release-header.toml
  - Prerelease: changelog/cliff.prerelease.toml

Requirements:
  - git-cliff must be installed
  - The appropriate cliff config file should exist (optional, will warn if missing)

Options:
  -t, --release-tag             Specifies the tag to create (required, e.g., 'v1.2.3' or 'v1.2.3-preview.1')
                                Initial value from \$RELEASE_TAG
  -p, --minver-tag-prefix       Specifies the tag prefix used by MinVer (e.g., 'v')
                                Initial value from \$MINVERTAGPREFIX or default 'v'
  -r, --reason                  Specifies the reason for the release (included in tag annotation)
                                Initial value from \$REASON or default based on tag type
      --needs-empty-commit      'true' to create an empty commit before changelog/tag (used when
                                promoting a prerelease-tagged HEAD to stable). Default: 'false'
                                Initial value from \$NEEDS_EMPTY_COMMIT

$switches
Environment Variables:
  RELEASE_TAG                   The tag to create (e.g., 'v1.2.3' or 'v1.2.3-preview.1')
  MINVERTAGPREFIX               Tag prefix (default: 'v')
  REASON                        Release reason (default: auto-detected from tag type)
  NEEDS_EMPTY_COMMIT            'true' or 'false' (default: 'false')
$vars
EOF
}
