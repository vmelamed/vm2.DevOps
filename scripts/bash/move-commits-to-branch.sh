#!/bin/bash
set -euo pipefail

# Script to move commits from a specific SHA onwards to a new branch
# Usage: ./move-commits-to-branch.sh <commit-sha> <new-branch-name>

if [ $# -lt 2 ]; then
    echo "Usage: $0 <commit-sha> <new-branch-name>" >&2
    echo "Example: $0 ff5c2d182c0d3a01c1f1dfd66c9267f0569d9802 feature/my-feature" >&2
    exit 1
fi

COMMIT_SHA="$1"
NEW_BRANCH="$2"

# Verify we're on main branch
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "main" ]; then
    echo "Error: You must be on the 'main' branch. Currently on '$CURRENT_BRANCH'" >&2
    exit 1
fi

# Check for uncommitted changes
if ! git diff-index --quiet HEAD --; then
    echo "Error: You have uncommitted changes. Please commit or stash them first." >&2
    git status --short
    exit 1
fi

# Verify the commit exists
if ! git cat-file -e "$COMMIT_SHA^{commit}" 2>/dev/null; then
    echo "Error: Commit '$COMMIT_SHA' does not exist" >&2
    exit 1
fi

# Show what will happen
echo "Current branch: $CURRENT_BRANCH"
echo "Commit to split at: $COMMIT_SHA"
echo ""
echo "This will:"
echo "  1. Create new branch '$NEW_BRANCH' with all current commits"
echo "  2. Reset main to commit BEFORE $COMMIT_SHA"
echo "  3. Push both branches to GitHub"
echo ""
echo "Commits from $COMMIT_SHA onwards will be moved to '$NEW_BRANCH'"
echo ""

# Show the commits that will be moved
echo "Commits that will be moved to '$NEW_BRANCH':"
git log --oneline "$COMMIT_SHA^..$CURRENT_BRANCH"
echo ""

read -p "Do you want to continue? (yes/no): " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Aborted."
    exit 0
fi

echo ""
echo "Step 1: Creating branch '$NEW_BRANCH' at current HEAD..."
git branch "$NEW_BRANCH"

echo "Step 2: Resetting main to commit before $COMMIT_SHA..."
git reset --hard "$COMMIT_SHA^"

echo "Step 3: Pushing new branch to GitHub..."
git push -u origin "$NEW_BRANCH"

echo "Step 4: Force pushing main to GitHub..."
git push --force origin main

echo ""
echo "✅ Done!"
echo "   - Branch '$NEW_BRANCH' created with commits from $COMMIT_SHA onwards"
echo "   - Main reset to commit before $COMMIT_SHA"
echo "   - Both branches pushed to GitHub"
echo ""
echo "To switch to the new branch: git checkout $NEW_BRANCH"
