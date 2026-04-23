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

# # if old tag is v1.2.3 and new tag is v1.2.4
#
# # 1) create new tag from old one
# git tag v1.2.4 v1.2.3
#
# # 2) delete old local tag
# git tag -d v1.2.3
#
# # 3) delete old remote tag
# git push origin :refs/tags/v1.2.3
#
# # 4) push new tag
# git push origin v1.2.4
