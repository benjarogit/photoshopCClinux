#!/usr/bin/env bash
################################################################################
# Stage Files for Agent Review
#
# Description:
#   Marks all tool files (scripts, not Photoshop installation files) as modified
#   for Agent Review, even if they haven't been changed. This is useful for
#   code review workflows where you want to mark files as reviewed.
#
# Author:       benjarogit
# Repository:   https://github.com/benjarogit/photoshopCClinux
# License:      GPL-3.0
# Copyright:    (c) 2025 benjarogit
################################################################################

# KRITISCH: Robuste Fehlerbehandlung
set -eu
(set -o pipefail 2>/dev/null) || true

# Get project root
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Staging all tool files for Agent Review..."
echo ""

# List of tool files to stage (scripts, configs, docs - NOT Photoshop files)
TOOL_FILES=(
    "setup.sh"
    "pre-check.sh"
    "troubleshoot.sh"
    "scripts/PhotoshopSetup.sh"
    "scripts/sharedFuncs.sh"
    "scripts/launcher.sh"
    "scripts/uninstaller.sh"
    "scripts/winecfg.sh"
    "scripts/cameraRawInstaller.sh"
    "scripts/photoshop.desktop"
    "README.md"
    "README.de.md"
    "CHANGELOG.md"
    "LICENSE"
    ".gitignore"
    "DEINSTALLATION.md"
    "RELEASE_NOTES_v2.2.0.md"
    "ATTACK_SCENARIO_REPORT.md"
    "BLIND_SPOT_AUDIT.md"
    "CODE_REVIEW_REPORT.md"
)

# Stage each file (even if unchanged, it will be marked as modified)
staged_count=0
for file in "${TOOL_FILES[@]}"; do
    file_path="$PROJECT_ROOT/$file"
    if [ -f "$file_path" ]; then
        # Use git update-index to mark as modified (even if unchanged)
        git update-index --add --cacheinfo 100644 "$(git hash-object -w "$file_path" 2>/dev/null || echo "")" "$file" 2>/dev/null || {
            # Fallback: normal add
            git add "$file" 2>/dev/null || true
        }
        # Ensure executable permissions are preserved for scripts
        if [[ "$file" == *.sh ]]; then
            chmod +x "$file_path" 2>/dev/null || true
        fi
        echo "  ✓ Staged: $file"
        ((staged_count++))
    else
        echo "  ⚠ Not found: $file"
    fi
done

echo ""
echo "✅ Staged $staged_count files for Agent Review"
echo ""
echo "Files are now marked as modified in Git (ready for review)."

