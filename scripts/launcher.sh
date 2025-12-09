#!/usr/bin/env bash
################################################################################
# Photoshop CC Linux Launcher
#
# Description:
#   Launches Adobe Photoshop CC with optimized Wine environment variables
#   for improved performance and stability. Includes GPU acceleration tweaks
#   and multi-threading optimizations.
#
# Author:       benjarogit
# Repository:   https://github.com/benjarogit/photoshopCClinux
# License:      GPL-3.0
# Copyright:    (c) 2024 benjarogit
#
# Based on:     photoshopCClinux by Gictorbit
#               https://github.com/Gictorbit/photoshopCClinux
################################################################################

# CRITICAL: Enable robust error handling
set -eu
(set -o pipefail 2>/dev/null) || true

# Locale/UTF-8 for DE/EN (with check for existing locale)
# CRITICAL: Check if locale exists (Alpine often only has C.UTF-8)
if command -v locale >/dev/null 2>&1; then
    if locale -a 2>/dev/null | grep -qE "^(de_DE|de_DE\.utf8|de_DE\.UTF-8)$"; then
        export LANG="${LANG:-de_DE.UTF-8}"
    elif locale -a 2>/dev/null | grep -qE "^(C\.utf8|C\.UTF-8)$"; then
        export LANG="${LANG:-C.UTF-8}"
    else
        export LANG="${LANG:-C}"
    fi
else
    # Fallback if locale not available
    export LANG="${LANG:-C.UTF-8}"
fi
export LC_ALL="${LC_ALL:-$LANG}"

# WINAPPS-TECHNIK: Parameter werden akzeptiert (für "Öffnen mit")
# Dateien können als Parameter übergeben werden: launcher.sh /path/to/file.psd
# Keine Parameter-Prüfung mehr - Dateien werden später verarbeitet

# Get the directory where this script is located (resolves symlinks)
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0" || echo "$0")")" && pwd)"

# Load shared functions and paths from the script's directory
source "$SCRIPT_DIR/sharedFuncs.sh"
load_paths

# Simple log function (if not available from sharedFuncs.sh)
if ! command -v log &>/dev/null; then
    log() {
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $@" >> "$SCR_PATH/photoshop-runtime.log" 2>/dev/null || true
    }
fi

RESOURCES_PATH="$SCR_PATH/resources"
WINE_PREFIX="$SCR_PATH/prefix"

# CRITICAL: WINEPREFIX validation - prevent manipulation
if [[ "$WINE_PREFIX" =~ ^/etc|^/usr/bin|^/usr/sbin|^/bin|^/sbin|^/lib|^/var/log|^/root ]]; then
    echo "ERROR: WINEPREFIX zeigt auf System-Verzeichnis (Sicherheitsrisiko): $WINE_PREFIX" >&2
    exit 1
fi
export WINEPREFIX="$WINE_PREFIX"

# Workarounds für bekannte Probleme (GitHub Issues)

# Fix für GPU-Probleme (Issue #45, #67)
export MESA_GL_VERSION_OVERRIDE=3.3
export __GL_SHADER_DISK_CACHE=0

# Fix für Font-Rendering (Issue #23)
export FREETYPE_PROPERTIES="truetype:interpreter-version=35"

# Fix für DLL-Probleme (Issue #34, #56)
export WINEDLLOVERRIDES="winemenubuilder.exe=d"

# Performance-Optimierungen (Issue #135 - Zoom lag)
export WINE_CPU_TOPOLOGY="4:2"  # Optimal CPU usage
export __GL_THREADED_OPTIMIZATIONS=1  # Better OpenGL performance
export __GL_YIELD="USLEEP"  # Reduce input lag

# Fix für Screen Update Issues (Issue #161 - Undo/Redo lag)
export CSMT=enabled  # Command Stream Multi-Threading

# Prüfe Wine-Konfiguration
if [ ! -d "$WINE_PREFIX" ]; then
    echo "FEHLER: Wine-Prefix nicht gefunden: $WINE_PREFIX"
    notify-send "Photoshop CC" "Wine-Prefix nicht gefunden! Bitte Photoshop neu installieren." -i "error"
    exit 1
fi

# Suche nach Photoshop.exe in verschiedenen möglichen Pfaden
PHOTOSHOP_EXE=""

# Mögliche Installationspfade (dynamisch - alle unterstützten Versionen)
POSSIBLE_PATHS=(
    "$WINE_PREFIX/drive_c/Program Files/Adobe/Adobe Photoshop CC 2021/Photoshop.exe"
    "$WINE_PREFIX/drive_c/Program Files/Adobe/Adobe Photoshop 2022/Photoshop.exe"
    "$WINE_PREFIX/drive_c/Program Files/Adobe/Adobe Photoshop 2021/Photoshop.exe"
    "$WINE_PREFIX/drive_c/Program Files/Adobe/Adobe Photoshop CC 2019/Photoshop.exe"
    "$WINE_PREFIX/drive_c/Program Files/Adobe/Adobe Photoshop CC 2018/Photoshop.exe"
    "$WINE_PREFIX/drive_c/users/${USER:-$(id -un)}/PhotoshopSE/Photoshop.exe"
    "$WINE_PREFIX/drive_c/Program Files (x86)/Adobe/Adobe Photoshop CC 2021/Photoshop.exe"
    "$WINE_PREFIX/drive_c/Program Files (x86)/Adobe/Adobe Photoshop CC 2019/Photoshop.exe"
)

for path in "${POSSIBLE_PATHS[@]}"; do
    if [ -f "$path" ]; then
        PHOTOSHOP_EXE="$path"
        echo "✓ Photoshop gefunden: $path"
        break
    fi
done

if [ -z "$PHOTOSHOP_EXE" ]; then
    notify-send "Photoshop CC" "Photoshop.exe nicht gefunden! Überprüfe die Installation." -i "error"
    echo "═══════════════════════════════════════════════════════════════"
    echo "FEHLER: Photoshop.exe nicht in folgenden Pfaden gefunden:"
    echo "═══════════════════════════════════════════════════════════════"
    for path in "${POSSIBLE_PATHS[@]}"; do
        echo "  ✗ $path"
    done
    echo ""
    echo "Bitte überprüfe die Installation oder führe setup.sh erneut aus."
    echo "═══════════════════════════════════════════════════════════════"
    exit 1
fi

echo "═══════════════════════════════════════════════════════════════"
echo "           Adobe Photoshop CC - Linux Launcher"
echo "═══════════════════════════════════════════════════════════════"
echo "Photoshop-Pfad: $PHOTOSHOP_EXE"
echo "Wine-Prefix: $WINE_PREFIX"
echo ""
echo "Tipps bei Problemen:"
echo "  - Beim ersten Start kann es 1-2 Minuten dauern"
echo "  - Bei Abstürzen: GPU-Beschleunigung deaktivieren (Strg+K)"
echo "  - Bei Fehler 'VCRUNTIME140.dll': winecfg.sh ausführen"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# WINAPPS-TECHNIK: Progress-Indikator und Status-Notification
echo ""
echo "🔄 Photoshop wird gestartet..."
notify-send "Photoshop CC" "Photoshop CC wird gestartet..." -i "photoshopicon" 2>/dev/null || true

# WINAPPS-TECHNIK: Dateien übergeben (wenn als Parameter übergeben)
# Konvertiere Linux-Pfade zu Windows-Pfaden für Wine
wine_args=()
if [ $# -gt 0 ]; then
    for file in "$@"; do
        if [ -f "$file" ] || [ -d "$file" ]; then
            # Konvertiere Linux-Pfad zu Windows-Pfad für Wine
            abs_path=$(readlink -f "$file" 2>/dev/null || echo "$file")
            # Wine mapped /home -> Z:/
            # Ersetze /home/user -> Z:/home/user, dann / -> \
            wine_path=$(echo "$abs_path" | sed "s|^/|Z:/|" | sed 's|/|\\|g')
            wine_args+=("$wine_path")
            echo "📂 Öffne Datei: $(basename "$file")"
            log "Öffne Datei: $file -> $wine_path"
        fi
    done
fi

# Starte Photoshop mit Wine (mit Dateien als Parameter, falls vorhanden)
# WINAPPS-TECHNIK: Progress-Anzeige während des Starts
echo "⏳ Initialisiere Wine-Umgebung..."
log "Starte Photoshop: $PHOTOSHOP_EXE"

if [ ${#wine_args[@]} -gt 0 ]; then
    wine "$PHOTOSHOP_EXE" "${wine_args[@]}" 2>&1 | tee -a "$SCR_PATH/photoshop-runtime.log"
else
    wine "$PHOTOSHOP_EXE" 2>&1 | tee -a "$SCR_PATH/photoshop-runtime.log"
fi

exit_code=$?

if [ $exit_code -ne 0 ]; then
    echo ""
    echo "⚠ Photoshop wurde mit Exit-Code $exit_code beendet"
    echo "Überprüfe die Logs: $SCR_PATH/photoshop-runtime.log"
fi

exit $exit_code



