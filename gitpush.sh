#!/usr/bin/env bash
################################################################################
# Git Push Helper Script
#
# Description:
#   Helper script for pushing changes to GitHub with proper commit messages
#   and tag management. Includes safety checks before pushing.
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
#   ./gitpush.sh "Fix: Security improvements"
#   ./gitpush.sh "Release: v2.2.0" "v2.2.0"
################################################################################

# KRITISCH: Robuste Fehlerbehandlung
set -eu
(set -o pipefail 2>/dev/null) || true

# Get project root
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default values
COMMIT_MSG="${1:-Update}"
TAG="${2:-}"

echo "═══════════════════════════════════════════════════════════════"
echo "           Git Push Helper"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Safety checks
echo "1. Prüfe Git-Status..."
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "❌ FEHLER: Kein Git-Repository gefunden!"
    exit 1
fi

echo "2. Prüfe ob Photoshop-Dateien im Index sind..."
PHOTOSHOP_FILES=$(git ls-files | grep -E "photoshop/.*\.(exe|dll|msi|psd|psb|zip|pima|pimx|sig)$" | grep -v "allredist/" || true)
if [ -n "$PHOTOSHOP_FILES" ]; then
    echo "⚠️  WARNUNG: Photoshop-Dateien im Git-Index gefunden:"
    echo "$PHOTOSHOP_FILES"
    echo ""
    read -p "Trotzdem fortfahren? [N/y]: " continue_anyway
    if [[ ! "$continue_anyway" =~ ^[Yy] ]]; then
        echo "Abgebrochen."
        exit 1
    fi
fi

echo "3. Zeige Git-Status..."
git status --short
echo ""

# Ask for confirmation
read -p "Alle Änderungen committen und pushen? [N/y]: " confirm
if [[ ! "$confirm" =~ ^[Yy] ]]; then
    echo "Abgebrochen."
    exit 0
fi

echo ""
echo "4. Committe Änderungen..."
git add -A
git commit -m "$COMMIT_MSG" || {
    echo "❌ Commit fehlgeschlagen (möglicherweise keine Änderungen)"
    exit 1
}

# Create tag if provided
if [ -n "$TAG" ]; then
    echo ""
    echo "5. Erstelle Tag: $TAG"
    git tag -a "$TAG" -m "Release $TAG" || {
        echo "⚠️  Tag-Erstellung fehlgeschlagen (möglicherweise existiert bereits)"
    }
fi

echo ""
echo "6. Push zu GitHub..."
git push origin main || {
    echo "❌ Push fehlgeschlagen!"
    exit 1
}

# Push tag if provided
if [ -n "$TAG" ]; then
    echo ""
    echo "7. Push Tag: $TAG"
    git push origin "$TAG" || {
        echo "⚠️  Tag-Push fehlgeschlagen!"
    }
fi

echo ""
echo "✅ Erfolgreich gepusht!"
echo ""
echo "Repository: https://github.com/benjarogit/photoshopCClinux"

