#!/usr/bin/env bash
set -euo pipefail

# delete a tag and add it again - useful when you need to move a tag to point to a different commit, e.g. after force-pushing when debugging changing CI scripts
if [[ $# -ne 1 || "$1" == "-h" || "$1" == "--help" ]]; then
  echo "Usage: retag.sh <tag>"
  exit 1
fi
git tag -d "$1"
git push origin -d "$1"
git tag "$1"
git push origin "$1"
