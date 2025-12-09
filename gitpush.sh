#!/usr/bin/env bash
################################################################################
# Git Push Helper Script
#
# Description:
#   1. Commits changes
#   2. Pushes to GitHub
#   3. Creates GitHub Release with English changelog from local CHANGELOG.md
#
# Author:       benjarogit
# Repository:   https://github.com/benjarogit/photoshopCClinux
# License:      GPL-3.0
# Copyright:    (c) 2025 benjarogit
#
# Usage:
#   ./gitpush.sh [commit-message] [tag]
#
# Examples:
#   ./gitpush.sh "Fix: Security improvements" "v2.2.0"
################################################################################

set -eu
(set -o pipefail 2>/dev/null) || true

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMIT_MSG="${1:-Update}"
TAG="${2:-}"

if [ -z "$TAG" ]; then
    echo "❌ ERROR: Tag is required for release!"
    echo "Usage: ./gitpush.sh \"commit message\" \"v2.2.0\""
    exit 1
fi

echo "═══════════════════════════════════════════════════════════════"
echo "           Git Push & Release"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# 1. Commit
echo "1. Committing changes..."
git add -A
git commit -m "$COMMIT_MSG" || {
    echo "⚠️  No changes to commit"
}

# 2. Push
echo ""
echo "2. Pushing to GitHub..."
git push origin main || {
    echo "❌ Push failed!"
    exit 1
}

# 3. Create tag if not exists
if ! git rev-parse "$TAG" >/dev/null 2>&1; then
    echo ""
    echo "3. Creating tag: $TAG"
    git tag -a "$TAG" -m "Release $TAG"
    git push origin "$TAG"
fi

# 4. Extract changelog for this version
echo ""
echo "4. Extracting changelog for $TAG..."
CHANGELOG_FILE="$PROJECT_ROOT/CHANGELOG.md"
if [ ! -f "$CHANGELOG_FILE" ]; then
    echo "❌ ERROR: CHANGELOG.md not found!"
    exit 1
fi

# Extract version section from CHANGELOG.md
RELEASE_NOTES=$(awk "/^## \[${TAG#v}\]/,/^## \[/" "$CHANGELOG_FILE" | head -n -1 | sed '/^---$/d')

if [ -z "$RELEASE_NOTES" ]; then
    echo "⚠️  WARNING: No changelog found for $TAG in CHANGELOG.md"
    RELEASE_NOTES="Release $TAG"
fi

# 5. Create GitHub Release
echo ""
echo "5. Creating GitHub Release: $TAG"
echo "Release notes:"
echo "$RELEASE_NOTES"
echo ""

# Use GitHub CLI if available, otherwise provide instructions
if command -v gh >/dev/null 2>&1; then
    echo "$RELEASE_NOTES" | gh release create "$TAG" \
        --title "$TAG - Release" \
        --notes-file - \
        --target main
    echo "✅ GitHub Release created!"
else
    echo "⚠️  GitHub CLI (gh) not found. Please create release manually:"
    echo "   https://github.com/benjarogit/photoshopCClinux/releases/new"
    echo ""
    echo "Tag: $TAG"
    echo "Title: $TAG - Release"
    echo "Description:"
    echo "$RELEASE_NOTES"
fi

echo ""
echo "✅ Done!"
echo "Repository: https://github.com/benjarogit/photoshopCClinux"
