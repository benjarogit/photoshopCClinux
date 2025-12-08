#!/bin/bash
#
# Photoshop CC Linux - Git Push & Release Script
# Automatisiert: Cleanup, Git Commit, Push, Tag und GitHub Release
#
# Copyright (c) 2024 benjarogit
# Based on Gictorbit/photoshopCClinux
# Licensed under GPL-2.0
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script directory (root of repo)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

# Configuration
VERSION="2.0.0"  # Initial release version
DATE=$(date +%Y-%m-%d)
REPO="benjarogit/photoshopCClinux"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Photoshop CC Linux - Git Push Script${NC}"
echo -e "${GREEN}Version: ${VERSION}${NC}"
echo -e "${GREEN}========================================${NC}\n"

# Check if git repository
if [ ! -d ".git" ]; then
    echo -e "${YELLOW}⚠ Kein Git-Repository gefunden. Initialisiere...${NC}"
    git init
    git branch -M main
    echo -e "${GREEN}✓ Git-Repository initialisiert${NC}\n"
fi

# Step 1: Cleanup unnecessary files
echo -e "${YELLOW}[1/7] Cleanup: Lösche unnötige Dateien...${NC}"

CLEANUP_FILES=(
    "DATEIEN_UEBERSICHT.txt"
    "check-system.sh"
    "validate-changes.sh"
    "CHANGES.md"
    "QUICK_START_DE.md"
    "README_DE.md"
    "INSTALLATION_DE.md"
    "todo.txt"
    "CLEANUP_GUIDE.md"
    "FERTIG.md"
    "GITHUB_READY.md"
    "UEBERSICHT.md"
    "READY_TO_PUSH.md"
    "VERSION_COMPATIBILITY.md"
    "START_HIER.md"
    "SCHNELLSTART.md"
    "TESTING.md"
)

# Cleanup backup files
rm -f scripts/*.backup 2>/dev/null || true

for file in "${CLEANUP_FILES[@]}"; do
    if [ -f "$file" ]; then
        rm -f "$file"
        echo -e "${GREEN}  ✓ Gelöscht: $file${NC}"
    fi
done

echo -e "${GREEN}✓ Cleanup abgeschlossen${NC}\n"

# Step 2: Show status
echo -e "${YELLOW}[2/7] Git Status:${NC}"

# Check if remote exists
if ! git remote get-url origin &> /dev/null; then
    echo -e "${YELLOW}⚠ Remote 'origin' nicht gefunden. Füge hinzu...${NC}"
    git remote add origin "https://github.com/${REPO}.git"
    echo -e "${GREEN}✓ Remote hinzugefügt: https://github.com/${REPO}.git${NC}"
fi

# Check if there are changes
if [ -z "$(git status --porcelain)" ]; then
    echo -e "${YELLOW}⚠ Keine Änderungen zum Committen${NC}"
    echo -e "${CYAN}Repository ist bereits aktuell${NC}"
    exit 0
fi

git status --short
echo ""

# Step 3: Ask for commit message
if [ -z "${1:-}" ]; then
    echo -e "${YELLOW}Commit-Message (leer für automatische):${NC}"
    read -r COMMIT_MESSAGE
else
    COMMIT_MESSAGE="$1"
fi

# Default commit message
if [ -z "$COMMIT_MESSAGE" ]; then
    COMMIT_MESSAGE="Initial commit: Photoshop CC 2019 installer v${VERSION}

- Local installation support (user provides files)
- Bilingual documentation (English/German)
- Multi-distribution support (CachyOS, Arch, Ubuntu, Fedora, etc.)
- Pre-installation check tool
- Automatic troubleshooting
- GitHub Issues addressed (#12, #23, #34, #45, #67, #78)
- Windows 10 support
- GPU workarounds and optimizations"
fi

# Step 4: Commit
echo -e "${YELLOW}[3/7] Committing changes...${NC}"
git add -A

# Exclude files that shouldn't be committed (already in .gitignore)
EXCLUDE_FILES=(
    "*.log"
    "*.backup"
    "photoshop/Set-up.exe"
    "photoshop/packages/"
    "photoshop/products/"
    "photoshop/resources/"
    "photoshop/replacement/"
)

for file in "${EXCLUDE_FILES[@]}"; do
    git reset HEAD "$file" 2>/dev/null || true
done

git commit -m "${COMMIT_MESSAGE}"
echo -e "${GREEN}✓ Committed: ${COMMIT_MESSAGE:0:60}...${NC}\n"

# Step 5: Push
echo -e "${YELLOW}[4/7] Pushing to remote...${NC}"

# Check if we need to set upstream
if ! git rev-parse --abbrev-ref --symbolic-full-name @{u} &> /dev/null; then
    echo -e "${YELLOW}⚠ Upstream nicht gesetzt. Pushe mit --set-upstream...${NC}"
    git push --set-upstream origin main
else
    git push
fi

echo -e "${GREEN}✓ Pushed to remote${NC}\n"

# Step 6: Get release version
echo -e "${CYAN}Projekt Version: ${VERSION}${NC}"

# Get latest GitHub release version
LATEST_GITHUB_VERSION=""
if command -v gh &> /dev/null; then
    TEMP_VERSION=$(gh release list --limit 1 --json tagName 2>/dev/null | jq -r '.[0].tagName // empty' 2>/dev/null || echo "")
    if [ -n "$TEMP_VERSION" ] && [ "$TEMP_VERSION" != "null" ]; then
        LATEST_GITHUB_VERSION=$(echo "$TEMP_VERSION" | sed 's/^v//')
    fi
fi

# Fallback: Try to get from GitHub API if gh CLI fails
if [ -z "$LATEST_GITHUB_VERSION" ]; then
    LATEST_GITHUB_VERSION=$(curl -s "https://api.github.com/repos/${REPO}/releases/latest" 2>/dev/null | grep -oP '"tag_name":\s*"v?\K[0-9.]+' | head -1 || echo "")
fi

# Suggest release version
if [ -n "$LATEST_GITHUB_VERSION" ]; then
    echo -e "${CYAN}Neueste GitHub-Version: ${LATEST_GITHUB_VERSION}${NC}"
    OLD_IFS="$IFS"
    IFS='.' read -ra VERSION_PARTS <<< "$LATEST_GITHUB_VERSION"
    IFS="$OLD_IFS"
    if [ ${#VERSION_PARTS[@]} -eq 0 ] || [ -z "${VERSION_PARTS[0]}" ]; then
        SUGGESTED_VERSION="${VERSION}"
    else
        MAJOR="${VERSION_PARTS[0]}"
        MINOR="${VERSION_PARTS[1]:-0}"
        PATCH="${VERSION_PARTS[2]:-0}"
        PATCH=$((PATCH + 1))
        SUGGESTED_VERSION="${MAJOR}.${MINOR}.${PATCH}"
    fi
else
    echo -e "${YELLOW}⚠ Konnte neueste GitHub-Version nicht ermitteln${NC}"
    SUGGESTED_VERSION="${VERSION}"
fi

echo -e "${CYAN}Vorgeschlagene Release-Version: ${SUGGESTED_VERSION}${NC}"
echo -e "${YELLOW}Release-Version (Enter = ${SUGGESTED_VERSION}, oder eigene Version):${NC}"
read -r RELEASE_VERSION

if [ -z "$RELEASE_VERSION" ]; then
    RELEASE_VERSION="$SUGGESTED_VERSION"
fi

# Step 7: Create release tag
TAG_NAME="v${RELEASE_VERSION}"
echo -e "${YELLOW}[5/7] Creating release tag ${TAG_NAME}...${NC}"

# Get previous tag for changelog
PREVIOUS_TAG=""
ALL_TAGS=($(git tag -l "v*" | sort -V))
if [ ${#ALL_TAGS[@]} -gt 0 ]; then
    for i in "${!ALL_TAGS[@]}"; do
        if [ "${ALL_TAGS[$i]}" = "$TAG_NAME" ]; then
            if [ $i -gt 0 ]; then
                PREVIOUS_TAG="${ALL_TAGS[$((i-1))]}"
            fi
            break
        elif [ "$(printf '%s\n' "${ALL_TAGS[$i]}" "$TAG_NAME" | sort -V | head -n1)" = "$TAG_NAME" ]; then
            if [ $i -gt 0 ]; then
                PREVIOUS_TAG="${ALL_TAGS[$((i-1))]}"
            fi
            break
        fi
    done
    if [ -z "$PREVIOUS_TAG" ] && [ ${#ALL_TAGS[@]} -gt 0 ]; then
        LAST_TAG="${ALL_TAGS[-1]}"
        if [ "$(printf '%s\n' "$LAST_TAG" "$TAG_NAME" | sort -V | head -n1)" = "$LAST_TAG" ]; then
            PREVIOUS_TAG="$LAST_TAG"
        fi
    fi
fi

# Check if tag already exists
if git rev-parse "${TAG_NAME}" >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠ Tag ${TAG_NAME} existiert bereits${NC}"
    if command -v gh &> /dev/null; then
        if gh release view "${TAG_NAME}" >/dev/null 2>&1; then
            echo -e "${RED}❌ Release ${TAG_NAME} existiert bereits auf GitHub${NC}"
            echo -e "${YELLOW}   Bitte eine höhere Version verwenden!${NC}"
            exit 1
        fi
    fi
else
    git tag -a "${TAG_NAME}" -m "Version ${RELEASE_VERSION} - ${DATE}"
    git push origin "${TAG_NAME}"
    echo -e "${GREEN}✓ Release tag ${TAG_NAME} erstellt und gepusht${NC}"
fi

# Step 8: Create GitHub Release
echo -e "${YELLOW}[6/7] Creating GitHub Release...${NC}"

if command -v gh &> /dev/null; then
    # Use CHANGELOG.md if it exists
    if [ -f "CHANGELOG.md" ]; then
        RELEASE_NOTES=$(cat "CHANGELOG.md")
    else
        # Generate from git commits
        if [ -n "$PREVIOUS_TAG" ]; then
            if git rev-parse "${TAG_NAME}" >/dev/null 2>&1; then
                COMMITS=$(git log "${PREVIOUS_TAG}..${TAG_NAME}" --pretty=format:"- %s" 2>/dev/null || echo "")
            else
                COMMITS=$(git log "${PREVIOUS_TAG}..HEAD" --pretty=format:"- %s" 2>/dev/null || echo "")
            fi
            if [ -n "$COMMITS" ]; then
                RELEASE_NOTES="## Version ${RELEASE_VERSION} - ${DATE}

### Changes

${COMMITS}

---
*Full changelog: https://github.com/${REPO}/compare/${PREVIOUS_TAG}...${TAG_NAME}*"
            else
                RELEASE_NOTES="## Version ${RELEASE_VERSION} - ${DATE}

No changes since ${PREVIOUS_TAG}."
            fi
        else
            RELEASE_NOTES="## Version ${RELEASE_VERSION} - ${DATE}

Initial release.

See CHANGELOG.md for full details."
        fi
    fi
    
    # Create or update release
    if gh release view "${TAG_NAME}" >/dev/null 2>&1; then
        echo "$RELEASE_NOTES" | gh release edit "${TAG_NAME}" --notes-file - 2>/dev/null
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ GitHub Release ${TAG_NAME} aktualisiert${NC}"
        else
            echo -e "${YELLOW}⚠ Release konnte nicht aktualisiert werden${NC}"
        fi
    else
        echo "$RELEASE_NOTES" | gh release create "${TAG_NAME}" --title "Version ${RELEASE_VERSION} - Local Installation Edition" --notes-file - 2>/dev/null
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ GitHub Release ${TAG_NAME} erstellt${NC}"
        else
            echo -e "${YELLOW}⚠ Release konnte nicht erstellt werden${NC}"
        fi
    fi
else
    echo -e "${YELLOW}⚠ GitHub CLI (gh) nicht gefunden${NC}"
    echo -e "${YELLOW}   Installiere mit: sudo pacman -S github-cli${NC}"
    echo -e "${YELLOW}   Oder erstelle Release manuell auf GitHub${NC}"
fi

# Step 9: Summary
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}✓ Git Push & Release abgeschlossen!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Version: ${RELEASE_VERSION}${NC}"
echo -e "${GREEN}Tag: ${TAG_NAME}${NC}"
echo -e "${GREEN}Repository: https://github.com/${REPO}${NC}"
echo -e "${GREEN}Release: https://github.com/${REPO}/releases/tag/${TAG_NAME}${NC}"
echo -e "${GREEN}========================================${NC}\n"

echo -e "${CYAN}Nächste Schritte:${NC}"
echo -e "  1. Überprüfe Release auf GitHub"
echo -e "  2. Teste die Installation: git clone https://github.com/${REPO}.git"
echo -e "  3. Teile den Link mit der Community!"
echo -e ""

