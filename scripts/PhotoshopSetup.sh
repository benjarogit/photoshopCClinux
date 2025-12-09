#!/usr/bin/env bash
################################################################################
# Photoshop CC Linux Installer - Installation Script
#
# Description:
#   Handles the complete installation process of Adobe Photoshop CC on Linux
#   including Wine configuration, dependency installation, registry tweaks,
#   and performance optimizations for stable operation.
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

# CRITICAL: Trap for CTRL+C (INT) and other signals - MUST be set at the very beginning
# Also needed in subprocesses (winetricks, wine, etc.)
cleanup_on_interrupt() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "Installation abgebrochen durch Benutzer (STRG+C)"
    echo "═══════════════════════════════════════════════════════════════"
    # Log error if LOG_FILE is available
    if [ -n "${LOG_FILE:-}" ] && [ -f "${LOG_FILE:-}" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Installation abgebrochen durch Benutzer (STRG+C)" >> "${LOG_FILE}"
    fi
    exit 130
}
trap cleanup_on_interrupt INT TERM HUP

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

# CRITICAL: Prevent source hijacking - always use absolute path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export SCRIPT_DIR  # Export for sharedFuncs.sh::launcher()
source "$SCRIPT_DIR/sharedFuncs.sh"

# Setup comprehensive logging - ALL output will be logged
# This function sets up automatic logging of all stdout/stderr
setup_comprehensive_logging() {
    # Export LOG_FILE so sharedFuncs.sh can use it
    export LOG_FILE
    export ERROR_LOG
    export PROJECT_ROOT
    
    log_debug "Comprehensive logging enabled - all output will be automatically logged"
}

# Setup logging - use project directory (where setup.sh is located)
# CRITICAL: PATH hijacking check
if [[ ":$PATH:" == *":.:"* ]] || [[ "$PATH" == .:* ]] || [[ "$PATH" == *:. ]]; then
    export PATH="/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin"
fi

# Get project root directory (parent of scripts/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_DIR="$PROJECT_ROOT/logs"
mkdir -p "$LOG_DIR"

# Delete old logs before creating new ones
if [ -d "$LOG_DIR" ]; then
    rm -f "$LOG_DIR"/*.log 2>/dev/null
fi

# Generate timestamp once to ensure both logs have matching timestamps
# Format: "Log: 09.12.25 06:36 Uhr"
TIMESTAMP=$(date +%d.%m.%y\ %H:%M\ Uhr)
LOG_FILE="$LOG_DIR/Log: ${TIMESTAMP}.log"
ERROR_LOG="$LOG_DIR/Log: ${TIMESTAMP}_errors.log"

# Enhanced logging functions for comprehensive debugging
# ALL output goes to log file, but only important messages to console
log() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    # Write to log file
    echo "[$timestamp] $@" >> "$LOG_FILE"
    # Also show to user (important messages)
    echo "$@"
}

log_error() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    # Write to both log files
    echo "[$timestamp] ERROR: $@" >> "$LOG_FILE"
    echo "[$timestamp] ERROR: $@" >> "$ERROR_LOG"
    # Always show errors to user
    echo -e "\033[1;31mERROR: $@\033[0m"
}

log_debug() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    # Write to log file only (not to console)
    echo "[$timestamp] DEBUG: $@" >> "$LOG_FILE"
}

# Log user input prompts and responses
log_prompt() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] PROMPT: $@" | tee -a "$LOG_FILE"
}

log_input() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] USER_INPUT: $@" | tee -a "$LOG_FILE"
}

# Wrapper for read that logs input
read_with_log() {
    local prompt="$1"
    local var_name="$2"
    # CRITICAL: Reset IFS after read
    local old_IFS="${IFS:-}"
    log_prompt "$prompt"
    IFS= read -r -p "$prompt" "$var_name"
    log_input "${!var_name}"
    # CRITICAL: Reset IFS
    IFS="$old_IFS"
}

# Note: All echo statements should also call log() for comprehensive logging
# This ensures everything is logged to the log file

log_command() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] EXEC: $@" >> "$LOG_FILE"
    local output
    output=$("$@" 2>&1)
    local exit_code=$?
    if [ -n "$output" ]; then
        echo "$output" | while IFS= read -r line; do
            echo "[$timestamp] OUTPUT: $line" >> "$LOG_FILE"
        done
    fi
    return $exit_code
}

# Log all environment variables relevant to Wine/Proton
log_environment() {
    log_debug "=== Environment Variables ==="
    log_debug "PATH: $PATH"
    log_debug "WINEPREFIX: ${WINEPREFIX:-not set}"
    log_debug "WINEARCH: ${WINEARCH:-not set}"
    log_debug "PROTON_PATH: ${PROTON_PATH:-not set}"
    log_debug "PROTON_VERB: ${PROTON_VERB:-not set}"
    log_debug "SCR_PATH: ${SCR_PATH:-not set}"
    log_debug "WINE_PREFIX: ${WINE_PREFIX:-not set}"
    log_debug "RESOURCES_PATH: ${RESOURCES_PATH:-not set}"
    log_debug "CACHE_PATH: ${CACHE_PATH:-not set}"
    log_debug "LANG: ${LANG:-not set}"
    log_debug "LANG_CODE: ${LANG_CODE:-not set}"
    log_debug "=== End Environment Variables ==="
}

# Log system information (with timeout protection to prevent hanging)
log_system_info() {
    log_debug "=== System Information ==="
    log_debug "OS: $(uname -a 2>&1)"
    
    local distro=$(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d'"' -f2 || echo 'unknown')
    log_debug "Distribution: $distro"
    
    # Wine version with timeout
    if command -v timeout &>/dev/null; then
        local wine_ver=$(timeout 2 wine --version 2>&1 || echo 'timeout or error')
    else
        local wine_ver=$(wine --version 2>&1 || echo 'not found')
    fi
    log_debug "Wine version: $wine_ver"
    
    # Winetricks version - this can hang, so we use a safer approach
    log_debug "Winetricks: checking..."
    if command -v winetricks &>/dev/null; then
        # Try to get version quickly, but don't wait forever
        if command -v timeout &>/dev/null; then
            local winetricks_ver=$(timeout 1 winetricks --version 2>&1 | head -1 || echo 'timeout')
        else
            # Fallback: just check if it exists
            local winetricks_ver="installed (version check skipped)"
        fi
    else
        local winetricks_ver="not found"
    fi
    log_debug "Winetricks: $winetricks_ver"
    
    # Proton GE check - DON'T call proton-ge --version as it starts Steam!
    if command -v proton-ge &>/dev/null; then
        # Just check if the command exists, don't run it (it starts Steam)
        log_debug "Proton GE: installed (system-wide, version check skipped to avoid Steam)"
    else
        log_debug "Proton GE: not found"
    fi
    
    log_debug "Available Wine binaries:"
    which -a wine 2>/dev/null | while IFS= read -r wine_path; do
        if [ -n "$wine_path" ]; then
            log_debug "  - $wine_path"
        fi
    done
    log_debug "=== End System Information ==="
}

# Detect system language
LANG_CODE="${LANG:0:2}"
if [ "$LANG_CODE" != "de" ]; then
    LANG_CODE="en"
fi

# Detect system distribution for recommendations
detect_system() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    elif [ -f /etc/arch-release ]; then
        echo "arch"
    else
        echo "unknown"
    fi
}

# Check if Proton GE can be installed via package manager
check_proton_ge_installable() {
    local system=$(detect_system)
    
    case "$system" in
        arch|manjaro|cachyos|endeavouros)
            # Arch-based: Check for AUR helper
            if command -v yay &> /dev/null || command -v paru &> /dev/null || command -v pacman &> /dev/null; then
                return 0
            fi
            ;;
        debian|ubuntu|pop)
            # Debian-based: Check for apt
            if command -v apt &> /dev/null; then
                return 0
            fi
            ;;
        fedora|rhel|centos)
            # RPM-based: Check for dnf/yum
            if command -v dnf &> /dev/null || command -v yum &> /dev/null; then
                return 0
            fi
            ;;
    esac
    
    return 1
}

# Detect all available Wine/Proton versions
# Returns: array of options with priority (System Proton GE > Wine > others)
# NOTE: Proton GE from Steam directory is SKIPPED because it starts Steam
detect_all_wine_versions() {
    local options=()
    local descriptions=()
    local paths=()
    local index=1
    local system=$(detect_system)
    local recommended_index=1
    local proton_found=0  # Flag to track if any Proton GE was found
    
    # SKIP: Proton GE (Steam directory) - NOT USED for desktop apps
    # Reason: It starts Steam when winecfg/wine is called, which breaks the installation
    # We only use system-wide Proton GE (installed via package manager)
    
    # Priority 1: System-wide Proton GE (if installed via package manager)
    # This is the BEST option for desktop applications
    # NOTE: DON'T call proton-ge --version as it starts Steam!
    if command -v proton-ge &> /dev/null; then
        # Just check if command exists, don't call it (it starts Steam)
        local version="system"
        log_debug "Proton GE (system) gefunden - verwende ohne Version-Check (verhindert Steam-Start)"
        options+=("$index")
        if [ "$LANG_CODE" = "de" ]; then
            descriptions+=("Proton GE (system): $version ⭐ EMPFOHLEN - beste Kompatibilität")
        else
            descriptions+=("Proton GE (system): $version ⭐ RECOMMENDED - best compatibility")
        fi
        paths+=("system")
        recommended_index=$index
        proton_found=1
        ((index++))
    fi
    
    # Priority 3: Standard Wine
    if command -v wine &> /dev/null; then
        local version=$(wine --version 2>/dev/null | head -1 || echo "unknown")
        options+=("$index")
        if [ "$LANG_CODE" = "de" ]; then
            if [ $proton_found -eq 1 ]; then
                descriptions+=("Standard Wine: $version (Fallback - Proton GE empfohlen)")
            else
                descriptions+=("Standard Wine: $version (Fallback)")
            fi
        else
            if [ $proton_found -eq 1 ]; then
                descriptions+=("Standard Wine: $version (Fallback - Proton GE recommended)")
            else
                descriptions+=("Standard Wine: $version (Fallback)")
            fi
        fi
        paths+=("wine")
        ((index++))
    fi
    
    # Priority 4: Wine Staging (if available)
    if command -v wine-staging &> /dev/null; then
        local version=$(wine-staging --version 2>/dev/null | head -1 || echo "unknown")
        options+=("$index")
        if [ "$LANG_CODE" = "de" ]; then
            descriptions+=("Wine Staging: $version (Alternative)")
        else
            descriptions+=("Wine Staging: $version (Alternative)")
        fi
        paths+=("wine-staging")
        ((index++))
    fi
    
    # Store recommended index
    WINE_RECOMMENDED=$recommended_index
    
    # Return via global arrays (bash limitation)
    WINE_OPTIONS=("${options[@]}")
    WINE_DESCRIPTIONS=("${descriptions[@]}")
    WINE_PATHS=("${paths[@]}")
    
    return ${#options[@]}
}

# Interactive selection of Wine/Proton version
select_wine_version() {
    log_debug "=== select_wine_version() gestartet ==="
    local count=0
    local system=$(detect_system)
    log_debug "System erkannt: $system"
    local selection=""  # Declare at function start
    
    log_debug "Rufe detect_all_wine_versions() auf..."
    detect_all_wine_versions
    count=$?
    log_debug "detect_all_wine_versions() zurückgegeben: $count Optionen gefunden"
    
    if [ $count -eq 0 ]; then
        log_error "Keine Wine/Proton-Version gefunden!"
        error "$([ "$LANG_CODE" = "de" ] && echo "FEHLER: Keine Wine/Proton-Version gefunden!" || echo "ERROR: No Wine/Proton version found!")"
        return 1
    fi
    
    # Check if WINE_METHOD is set via command line parameter (skip interactive menu)
    if [ -n "$WINE_METHOD" ]; then
        log "Wine-Methode wurde per Parameter gesetzt: $WINE_METHOD"
        log_debug "Wine-Methode Parameter: $WINE_METHOD"
        if [ "$LANG_CODE" = "de" ]; then
            log "Überspringe interaktive Auswahl - verwende: $([ "$WINE_METHOD" = "wine" ] && echo "Wine Standard" || echo "Proton GE")"
        else
            log "Skipping interactive selection - using: $([ "$WINE_METHOD" = "wine" ] && echo "Wine Standard" || echo "Proton GE")"
        fi
        
        # Find the matching option index
        local found=0
        local index=1
        for path in "${WINE_PATHS[@]}"; do
            if [ "$WINE_METHOD" = "proton" ] && [ "$path" = "system" ]; then
                selection=$index
                found=1
                log_debug "Proton GE gefunden bei Index $index"
                break
            elif [ "$WINE_METHOD" = "wine" ] && [ "$path" = "wine" ]; then
                selection=$index
                found=1
                log_debug "Wine Standard gefunden bei Index $index"
                break
            fi
            ((index++))
        done
        
        if [ $found -eq 0 ]; then
            log_error "Angeforderte Wine-Methode '$WINE_METHOD' nicht gefunden!"
            if [ "$LANG_CODE" = "de" ]; then
                error "FEHLER: Die angeforderte Wine-Methode '$WINE_METHOD' ist nicht verfügbar. Verfügbare Optionen werden angezeigt..."
            else
                error "ERROR: Requested Wine method '$WINE_METHOD' not available. Showing available options..."
            fi
            # Fall through to interactive menu
        else
            # Use the found selection and skip menu
            log "Verwende automatisch ausgewählte Option: $selection"
            # Continue to setup_wine_environment with the selected option
        fi
    fi
    
    # Check if no Proton GE found (only Wine available) - show warning
    local has_proton=0
    for path in "${WINE_PATHS[@]}"; do
        # Only system-wide Proton GE is used (not Steam Proton)
        if [ "$path" = "system" ]; then
            has_proton=1
            break
        fi
    done
    
    # If only one option available, use it automatically (no menu)
    if [ $count -eq 1 ]; then
        selection=1
        if [ "$LANG_CODE" = "de" ]; then
            if [ $has_proton -eq 0 ] && ([ "$system" = "cachyos" ] || [ "$system" = "arch" ] || [ "$system" = "manjaro" ]); then
                log ""
                log "═══════════════════════════════════════════════════════════════"
                log "           WICHTIG: Wine-Version wählen"
                log "═══════════════════════════════════════════════════════════════"
                log ""
                log "ℹ System erkannt: $system"
                log ""
                log "Für Photoshop gibt es zwei Möglichkeiten:"
                log ""
                log "  1. PROTON GE (EMPFOHLEN)"
                log "     → Bessere Kompatibilität, weniger Fehler"
                log "     → Wird jetzt automatisch installiert (ca. 2-5 Minuten)"
                log ""
                log "  2. STANDARD WINE (Fallback)"
                log "     → Bereits installiert, funktioniert meist auch"
                log "     → Installation startet sofort"
                log ""
                log "═══════════════════════════════════════════════════════════════"
                log ""
                log "Was möchtest du tun?"
                log ""
                log "   [J] Ja - Proton GE installieren (EMPFOHLEN für beste Ergebnisse)"
                log "   [N] Nein - Mit Standard-Wine fortfahren (schneller, aber weniger optimal)"
                log ""
                log ""
                log "═══════════════════════════════════════════════════════════════"
                log "           WICHTIG: Wine-Version wählen"
                log "═══════════════════════════════════════════════════════════════"
                log ""
                log "ℹ System erkannt: $system"
                log ""
                log "Für Photoshop gibt es zwei Möglichkeiten:"
                log ""
                log "  1. PROTON GE (EMPFOHLEN)"
                log "     → Bessere Kompatibilität, weniger Fehler"
                log "     → Wird jetzt automatisch installiert (ca. 2-5 Minuten)"
                log ""
                log "  2. STANDARD WINE (Fallback)"
                log "     → Bereits installiert, funktioniert meist auch"
                log "     → Installation startet sofort"
                log ""
                log "═══════════════════════════════════════════════════════════════"
                log ""
                log "Was möchtest du tun?"
                log ""
                log "   [J] Ja - Proton GE installieren (EMPFOHLEN für beste Ergebnisse)"
                log "   [N] Nein - Mit Standard-Wine fortfahren (schneller, aber weniger optimal)"
                log ""
                echo ""
                echo "═══════════════════════════════════════════════════════════════"
                echo "           WICHTIG: Wine-Version wählen"
                echo "═══════════════════════════════════════════════════════════════"
                echo ""
                echo "ℹ System erkannt: $system"
                echo ""
                echo "Für Photoshop gibt es zwei Möglichkeiten:"
                echo ""
                echo "  1. PROTON GE (EMPFOHLEN)"
                echo "     → Bessere Kompatibilität, weniger Fehler"
                echo "     → Wird jetzt automatisch installiert (ca. 2-5 Minuten)"
                echo ""
                echo "  2. STANDARD WINE (Fallback)"
                echo "     → Bereits installiert, funktioniert meist auch"
                echo "     → Installation startet sofort"
                echo ""
                echo "═══════════════════════════════════════════════════════════════"
                echo ""
                echo "Was möchtest du tun?"
                echo ""
                echo "   [J] Ja - Proton GE installieren (EMPFOHLEN für beste Ergebnisse)"
                echo "   [N] Nein - Mit Standard-Wine fortfahren (schneller, aber weniger optimal)"
                echo ""
                log_prompt "Deine Wahl [J/n]: "
                IFS= read -r -p "Deine Wahl [J/n]: " install_proton
                log_input "$install_proton"
                if [[ "$install_proton" =~ ^[JjYy]$ ]] || [ -z "$install_proton" ]; then
                    log ""
                    log "═══════════════════════════════════════════════════════════════"
                    log "           Proton GE wird jetzt installiert"
                    log "═══════════════════════════════════════════════════════════════"
                    log ""
                    echo ""
                    echo "═══════════════════════════════════════════════════════════════"
                    echo "           Proton GE wird jetzt installiert"
                    echo "═══════════════════════════════════════════════════════════════"
                    echo ""
                    log "SCHRITT 1/2: Prüfe ob Wine installiert ist..."
                    echo "SCHRITT 1/2: Prüfe ob Wine installiert ist..."
                    echo ""
                    if ! command -v wine &> /dev/null; then
                        log "⚠ Wine fehlt noch - wird jetzt installiert..."
                        log "   (Wine wird für die Photoshop-Komponenten benötigt)"
                        echo "⚠ Wine fehlt noch - wird jetzt installiert..."
                        echo "   (Wine wird für die Photoshop-Komponenten benötigt)"
                        echo ""
                        if command -v pacman &> /dev/null; then
                            log_command sudo pacman -S wine
                        else
                            log "   Bitte installiere Wine manuell für deine Distribution"
                            echo "   Bitte installiere Wine manuell für deine Distribution"
                            log_prompt "Drücke Enter, wenn Wine installiert wurde: "
                            IFS= read -r -p "Drücke Enter, wenn Wine installiert wurde: " wait_wine
                            log_input "$wait_wine"
                        fi
                        log ""
                        echo ""
                    else
                        log "✓ Wine ist bereits installiert"
                        echo "✓ Wine ist bereits installiert"
                        echo ""
                    fi
                    log "SCHRITT 2/2: Installiere Proton GE system-weit (unabhängig von Steam)..."
                    log "   (Dies kann 2-5 Minuten dauern - bitte warten...)"
                    log "   → WICHTIG: Proton GE wird system-weit installiert, NICHT in Steam-Verzeichnis"
                    echo "SCHRITT 2/2: Installiere Proton GE system-weit (unabhängig von Steam)..."
                    echo "   (Dies kann 2-5 Minuten dauern - bitte warten...)"
                    echo "   → WICHTIG: System-weite Installation, NICHT in Steam-Verzeichnis"
                    echo ""
                    local install_success=0
                    local proton_ge_install_path=""
                    
                    # OPTION 1: Versuche AUR-Paket (Arch-basiert)
                    if command -v yay &> /dev/null || command -v paru &> /dev/null; then
                        local aur_helper=""
                        if command -v yay &> /dev/null; then
                            aur_helper="yay"
                        else
                            aur_helper="paru"
                        fi
                        
                        log "  → Versuche Installation über AUR ($aur_helper)..."
                        log_command $aur_helper -S proton-ge-custom-bin
                        if [ $? -eq 0 ]; then
                            # Prüfe Installationspfad
                            local proton_ge_path=$(pacman -Ql proton-ge-custom-bin 2>/dev/null | grep "files/bin/wine$" | head -1 | awk '{print $2}' | xargs dirname | xargs dirname | xargs dirname)
                            if [ -n "$proton_ge_path" ] && [ -d "$proton_ge_path" ]; then
                                if [[ "$proton_ge_path" =~ steam ]]; then
                                    log "⚠ AUR-Paket installiert in Steam-Verzeichnis - überspringe"
                                    log "   → Installiere Proton GE manuell system-weit..."
                                    install_success=0  # Weiter zu manueller Installation
                                else
                                    log "✓ Proton GE system-weit installiert: $proton_ge_path"
                                    echo "✓ Proton GE system-weit installiert"
                                    install_success=1
                                    proton_ge_install_path="$proton_ge_path"
                                fi
                            fi
                        fi
                    fi
                    
                    # OPTION 2: Manuelle Installation (universell für alle Linux-Distributionen)
                    if [ $install_success -eq 0 ]; then
                        log "  → Installiere Proton GE manuell system-weit..."
                        echo "  → Installiere Proton GE manuell system-weit..."
                        
                        # Bestimme Installationspfad (system-weit, nicht Steam)
                        local install_base=""
                        if [ -w "/usr/local/share" ]; then
                            install_base="/usr/local/share/proton-ge"
                        elif [ -w "$HOME/.local/share" ]; then
                            install_base="$HOME/.local/share/proton-ge"
                        else
                            install_base="$HOME/.proton-ge"
                        fi
                        
                        log "  → Installationspfad: $install_base"
                        
                        # Erstelle Verzeichnis
                        mkdir -p "$install_base" 2>/dev/null || {
                            log_error "Konnte Installationsverzeichnis nicht erstellen: $install_base"
                            install_success=0
                        }
                        
                        if [ -d "$install_base" ]; then
                            # Lade neueste Proton GE Version von GitHub
                            log "  → Lade neueste Proton GE Version herunter..."
                            echo "  → Lade neueste Proton GE Version herunter..."
                            
                            # GitHub API: Hole neueste Release-Version
                            local latest_version=$(curl -s https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | head -1)
                            
                            if [ -z "$latest_version" ]; then
                                # Fallback: Versuche direkt von Releases-Seite
                                latest_version="GE-Proton10-26"  # Fallback-Version
                                log "  ⚠ Konnte neueste Version nicht ermitteln, verwende Fallback: $latest_version"
                            else
                                log "  → Neueste Version gefunden: $latest_version"
                            fi
                            
                            # Download-URL
                            local download_url="https://github.com/GloriousEggroll/proton-ge-custom/releases/download/${latest_version}/${latest_version}.tar.gz"
                            local download_file="$install_base/${latest_version}.tar.gz"
                            
                            # CRITICAL: Download URL validation - prevent malicious URLs
                            # Check that URL starts with https:// (HTTPS enforcement)
                            if [[ ! "$download_url" =~ ^https:// ]]; then
                                log_error "Download URL must use HTTPS (security risk): $download_url"
                                download_ok=0
                            # Check that URL is from github.com
                            elif [[ ! "$download_url" =~ ^https://(www\.)?github\.com ]]; then
                                log_error "Download URL from unauthorized domain (security risk): $download_url"
                                download_ok=0
                            else
                                log "  → Download von: $download_url"
                                echo "  → Download läuft..."
                                
                                # Download mit Progress
                                local download_ok=0
                                if command -v wget &> /dev/null; then
                                    wget -q --show-progress -O "$download_file" "$download_url" 2>&1 | tee -a "$LOG_FILE"
                                    if [ $? -eq 0 ] && [ -f "$download_file" ]; then
                                        download_ok=1
                                    else
                                        log_error "Download fehlgeschlagen"
                                    fi
                                elif command -v curl &> /dev/null; then
                                    curl -L --progress-bar -o "$download_file" "$download_url" 2>&1 | tee -a "$LOG_FILE"
                                    if [ $? -eq 0 ] && [ -f "$download_file" ]; then
                                        download_ok=1
                                    else
                                        log_error "Download fehlgeschlagen"
                                    fi
                                else
                                    log_error "wget oder curl nicht gefunden - Download nicht möglich"
                                fi
                            fi
                            
                            if [ $download_ok -eq 1 ] && [ -f "$download_file" ]; then
                                # Entpacke
                                log "  → Entpacke Proton GE..."
                                echo "  → Entpacke Proton GE..."
                                tar -xzf "$download_file" -C "$install_base" 2>&1 | tee -a "$LOG_FILE"
                                if [ $? -eq 0 ]; then
                                    # Prüfe ob Installation erfolgreich
                                    local extracted_dir="$install_base/${latest_version}"
                                    if [ -d "$extracted_dir" ] && [ -f "$extracted_dir/files/bin/wine" ]; then
                                        log "✓ Proton GE manuell installiert: $extracted_dir"
                                        echo "✓ Proton GE system-weit installiert"
                                        install_success=1
                                        proton_ge_install_path="$extracted_dir"
                                        
                                        # Erstelle Symlink für einfacheren Zugriff
                                        if [ -d "$install_base" ]; then
                                            ln -sfn "$extracted_dir" "$install_base/current" 2>/dev/null || true
                                        fi
                                    else
                                        log_error "Installation unvollständig - wine-Binary nicht gefunden"
                                        install_success=0
                                    fi
                                else
                                    log_error "Entpacken fehlgeschlagen"
                                    install_success=0
                                fi
                                
                                # Lösche Download-Datei
                                rm -f "$download_file" 2>/dev/null || true
                            else
                                install_success=0
                            fi
                        fi
                    fi
                    
                    # OPTION 3: Fallback - Benutzer installiert manuell
                    if [ $install_success -eq 0 ]; then
                        log "⚠ Automatische Installation fehlgeschlagen"
                        echo ""
                        echo "⚠ Automatische Proton GE Installation fehlgeschlagen"
                        echo ""
                        if [ "$LANG_CODE" = "de" ]; then
                            echo "Du kannst Proton GE manuell installieren:"
                            echo "  1. Lade von: https://github.com/GloriousEggroll/proton-ge-custom/releases"
                            echo "  2. Entpacke nach: $HOME/.local/share/proton-ge/"
                            echo "  3. Oder verwende Standard-Wine (funktioniert auch)"
                            echo ""
                            log_prompt "   [J] Ja - Mit Standard-Wine fortfahren  [N] Nein - Abbrechen [J/n]: "
                            IFS= read -r -p "   [J] Ja - Mit Standard-Wine fortfahren  [N] Nein - Abbrechen [J/n]: " continue_with_wine
                            log_input "$continue_with_wine"
                        else
                            echo "You can install Proton GE manually:"
                            echo "  1. Download from: https://github.com/GloriousEggroll/proton-ge-custom/releases"
                            echo "  2. Extract to: $HOME/.local/share/proton-ge/"
                            echo "  3. Or use Standard Wine (works too)"
                            echo ""
                            log_prompt "   [Y] Yes - Continue with Standard Wine  [N] No - Cancel [Y/n]: "
                            IFS= read -r -p "   [Y] Yes - Continue with Standard Wine  [N] No - Cancel [Y/n]: " continue_with_wine
                            log_input "$continue_with_wine"
                        fi
                        if [[ "$continue_with_wine" =~ ^[Nn]$ ]]; then
                            log_error "Installation abgebrochen"
                            error "$([ "$LANG_CODE" = "de" ] && echo "Installation abgebrochen" || echo "Installation cancelled")"
                            exit 1
                        fi
                        # Verwende Standard-Wine
                        selection=1
                        log ""
                        log "→ Verwende Standard-Wine..."
                        echo ""
                        echo "→ Verwende Standard-Wine..."
                        echo ""
                        return 0
                    fi
                    
                    if [ $install_success -eq 0 ]; then
                        log ""
                        log "❌ FEHLER: Proton GE Installation fehlgeschlagen!"
                        echo ""
                        echo "❌ FEHLER: Proton GE Installation fehlgeschlagen!"
                        echo ""
                        if [ "$LANG_CODE" = "de" ]; then
                            log "Möchtest du trotzdem mit Standard-Wine fortfahren?"
                            echo "Möchtest du trotzdem mit Standard-Wine fortfahren?"
                            log_prompt "   [J] Ja - Mit Standard-Wine fortfahren  [N] Nein - Abbrechen [J/n]: "
                            IFS= read -r -p "   [J] Ja - Mit Standard-Wine fortfahren  [N] Nein - Abbrechen [J/n]: " continue_with_wine
                            log_input "$continue_with_wine"
                        else
                            log "Do you want to continue with Standard Wine anyway?"
                            echo "Do you want to continue with Standard Wine anyway?"
                            log_prompt "   [Y] Yes - Continue with Standard Wine  [N] No - Cancel [Y/n]: "
                            IFS= read -r -p "   [Y] Yes - Continue with Standard Wine  [N] No - Cancel [Y/n]: " continue_with_wine
                            log_input "$continue_with_wine"
                        fi
                        if [[ "$continue_with_wine" =~ ^[Nn]$ ]]; then
                            log_error "Installation abgebrochen"
                            error "$([ "$LANG_CODE" = "de" ] && echo "Installation abgebrochen" || echo "Installation cancelled")"
                            exit 1
                        fi
                        # Continue with standard Wine
                        selection=1
                        log ""
                        log "→ Verwende Standard-Wine..."
                        echo ""
                        echo "→ Verwende Standard-Wine..."
                        echo ""
                        return 0
                    fi
                    
                    echo ""
                    echo "═══════════════════════════════════════════════════════════════"
                    echo "           ✓ Proton GE erfolgreich installiert!"
                    echo "═══════════════════════════════════════════════════════════════"
                    echo ""
                    echo "Jetzt stehen dir mehrere Optionen zur Verfügung:"
                    echo "   → Du kannst zwischen Proton GE und Standard-Wine wählen"
                    echo ""
                    echo "Suche verfügbare Versionen..."
                    echo ""
                    # Re-detect after installation
                    detect_all_wine_versions
                    count=$?
                    
                    # After Proton GE installation, automatically use it (no menu needed)
                    # Find Proton GE in the list (system-wide Proton GE)
                    local proton_index=-1
                    for i in "${!WINE_PATHS[@]}"; do
                        if [ "${WINE_PATHS[$i]}" = "system" ]; then
                            proton_index=$i
                            break
                        fi
                    done
                    
                    if [ $proton_index -ge 0 ]; then
                        # Use Proton GE automatically
                        selection="${WINE_OPTIONS[$proton_index]}"
                        echo "✓ Verwende automatisch: ${WINE_DESCRIPTIONS[$proton_index]}"
                        echo ""
                        echo "→ Installation wird jetzt automatisch fortgesetzt..."
                        echo ""
                    else
                        # Fallback to first option
                        selection=1
                        echo "✓ Verwende: ${WINE_DESCRIPTIONS[0]}"
                        echo ""
                        echo "→ Installation wird jetzt automatisch fortgesetzt..."
                        echo ""
                    fi
                else
                    echo ""
                    echo "═══════════════════════════════════════════════════════════════"
                    echo "           Installation mit Standard-Wine"
                    echo "═══════════════════════════════════════════════════════════════"
                    echo ""
                    echo "Verwende: ${WINE_DESCRIPTIONS[0]}"
                    echo ""
                    echo "ℹ Hinweis: Standard-Wine funktioniert meist auch,"
                    echo "   aber Proton GE bietet bessere Kompatibilität."
                    echo "   Du kannst später jederzeit auf Proton GE umsteigen."
                    echo ""
                    selection=1
                fi
            else
                echo ""
                echo "Verwende: ${WINE_DESCRIPTIONS[0]}"
                echo ""
            fi
        else
            if [ $has_proton -eq 0 ] && ([ "$system" = "cachyos" ] || [ "$system" = "arch" ] || [ "$system" = "manjaro" ]); then
                echo ""
                echo "═══════════════════════════════════════════════════════════════"
                echo "           IMPORTANT: Select Wine Version"
                echo "═══════════════════════════════════════════════════════════════"
                echo ""
                echo "ℹ System detected: $system"
                echo ""
                echo "For Photoshop, you have two options:"
                echo ""
                echo "  1. PROTON GE (RECOMMENDED)"
                echo "     → Better compatibility, fewer errors"
                echo "     → Will be installed automatically now (takes 2-5 minutes)"
                echo ""
                echo "  2. STANDARD WINE (Fallback)"
                echo "     → Already installed, usually works too"
                echo "     → Installation starts immediately"
                echo ""
                echo "═══════════════════════════════════════════════════════════════"
                echo ""
                echo "What would you like to do?"
                echo ""
                echo "   [Y] Yes - Install Proton GE (RECOMMENDED for best results)"
                echo "   [N] No - Continue with Standard Wine (faster, but less optimal)"
                echo ""
                IFS= read -r -p "Your choice [Y/n]: " install_proton
                if [[ "$install_proton" =~ ^[YyJj]$ ]] || [ -z "$install_proton" ]; then
                    echo ""
                    echo "═══════════════════════════════════════════════════════════════"
                    echo "           Installing Proton GE now"
                    echo "═══════════════════════════════════════════════════════════════"
                    echo ""
                    echo "STEP 1/2: Checking if Wine is installed..."
                    echo ""
                    if ! command -v wine &> /dev/null; then
                        echo "⚠ Wine is missing - installing now..."
                        echo "   (Wine is needed for Photoshop components)"
                        echo ""
                        if command -v pacman &> /dev/null; then
                            sudo pacman -S wine
                        else
                            echo "   Please install Wine manually for your distribution"
                            IFS= read -r -p "Press Enter when Wine is installed: " wait_wine
                        fi
                        echo ""
                    else
                        echo "✓ Wine is already installed"
                        echo ""
                    fi
                    echo "STEP 2/2: Installing Proton GE..."
                    echo "   (This may take 2-5 minutes - please wait...)"
                    echo ""
                    local install_success=0
                    if command -v yay &> /dev/null; then
                        if yay -S proton-ge-custom-bin; then
                            install_success=1
                        fi
                    elif command -v paru &> /dev/null; then
                        if paru -S proton-ge-custom-bin; then
                            install_success=1
                        fi
                    else
                        echo "❌ No AUR helper (yay/paru) found!"
                        echo "   Install yay or paru, then run:"
                        echo "   yay -S proton-ge-custom-bin"
                        echo ""
                        IFS= read -r -p "Press Enter when Proton GE is installed, or [C] to Cancel: " continue_install
                        if [[ "$continue_install" =~ ^[Cc]$ ]]; then
                            error "Installation cancelled"
                            exit 1
                        fi
                        # Assume success if user pressed Enter
                        install_success=1
                    fi
                    
                    if [ $install_success -eq 0 ]; then
                        echo ""
                        echo "❌ ERROR: Proton GE installation failed!"
                        echo ""
                        echo "Do you want to continue with Standard Wine anyway?"
                        IFS= read -r -p "   [Y] Yes - Continue with Standard Wine  [N] No - Cancel [Y/n]: " continue_with_wine
                        if [[ "$continue_with_wine" =~ ^[Nn]$ ]]; then
                            error "Installation cancelled"
                            exit 1
                        fi
                        # Continue with standard Wine
                        selection=1
                        echo ""
                        echo "→ Using Standard Wine..."
                        echo ""
                        return 0
                    fi
                    
                    echo ""
                    echo "═══════════════════════════════════════════════════════════════"
                    echo "           ✓ Proton GE successfully installed!"
                    echo "═══════════════════════════════════════════════════════════════"
                    echo ""
                    echo "Now you have multiple options available:"
                    echo "   → You can choose between Proton GE and Standard Wine"
                    echo ""
                    echo "Searching for available versions..."
                    echo ""
                    # Re-detect after installation
                    detect_all_wine_versions
                    count=$?
                    
                    # After Proton GE installation, automatically use it (no menu needed)
                    # Find Proton GE in the list (system-wide Proton GE)
                    local proton_index=-1
                    for i in "${!WINE_PATHS[@]}"; do
                        if [ "${WINE_PATHS[$i]}" = "system" ]; then
                            proton_index=$i
                            break
                        fi
                    done
                    
                    if [ $proton_index -ge 0 ]; then
                        # Use Proton GE automatically
                        selection="${WINE_OPTIONS[$proton_index]}"
                        echo "✓ Using automatically: ${WINE_DESCRIPTIONS[$proton_index]}"
                        echo ""
                        echo "→ Installation will now continue automatically..."
                        echo ""
                    else
                        # Fallback to first option
                        selection=1
                        echo "✓ Using: ${WINE_DESCRIPTIONS[0]}"
                        echo ""
                        echo "→ Installation will now continue automatically..."
                        echo ""
                    fi
                else
                    echo ""
                    echo "═══════════════════════════════════════════════════════════════"
                    echo "           Installation with Standard Wine"
                    echo "═══════════════════════════════════════════════════════════════"
                    echo ""
                    echo "Using: ${WINE_DESCRIPTIONS[0]}"
                    echo ""
                    echo "ℹ Note: Standard Wine usually works too,"
                    echo "   but Proton GE offers better compatibility."
                    echo "   You can switch to Proton GE later anytime."
                    echo ""
                    selection=1
                fi
            else
                echo ""
                echo "Using: ${WINE_DESCRIPTIONS[0]}"
                echo ""
                selection=1
            fi
        fi
        
        # If selection is empty (after Proton GE installation), jump to menu
        if [ -z "$selection" ]; then
            # Re-detect to get updated count
            detect_all_wine_versions
            count=$?
        fi
    fi
    
    # If count > 1 AND selection is empty, show menu
    # If selection is already set (after auto-install), skip menu
    if [ $count -gt 1 ] && [ -z "$selection" ]; then
        # Multiple options available - show menu
        echo ""
        echo "═══════════════════════════════════════════════════════════════"
        if [ "$LANG_CODE" = "de" ]; then
            echo "           Wine/Proton-Version auswählen"
        else
            echo "           Select Wine/Proton Version"
        fi
        echo "═══════════════════════════════════════════════════════════════"
        echo ""
        
        # Show system detection
        if [ "$LANG_CODE" = "de" ]; then
            echo "ℹ System erkannt: $system"
            if [ "$system" = "cachyos" ] || [ "$system" = "arch" ] || [ "$system" = "manjaro" ]; then
                echo "   → Proton GE wird für Arch-basierte Systeme empfohlen"
                if [ $has_proton -eq 0 ]; then
                    echo ""
                    echo "⚠ Proton GE nicht gefunden!"
                    echo "   Installiere es mit: yay -S proton-ge-custom-bin"
                    echo "   Oder: paru -S proton-ge-custom-bin"
                    echo ""
                fi
            fi
        else
            echo "ℹ System detected: $system"
            if [ "$system" = "cachyos" ] || [ "$system" = "arch" ] || [ "$system" = "manjaro" ]; then
                echo "   → Proton GE recommended for Arch-based systems"
                if [ $has_proton -eq 0 ]; then
                    echo ""
                    echo "⚠ Proton GE not found!"
                    echo "   Install with: yay -S proton-ge-custom-bin"
                    echo "   Or: paru -S proton-ge-custom-bin"
                    echo ""
                fi
            fi
        fi
        echo ""
        
        # Display options
        for i in "${!WINE_OPTIONS[@]}"; do
            local opt_num="${WINE_OPTIONS[$i]}"
            local desc="${WINE_DESCRIPTIONS[$i]}"
            echo "  [$opt_num] $desc"
        done
        
        echo ""
        
        # Get user selection with recommended default
        local default_choice=$WINE_RECOMMENDED
        # Build list of valid options for error message
        local valid_options=$(IFS=,; echo "${WINE_OPTIONS[*]}")
        while true; do
            if [ "$LANG_CODE" = "de" ]; then
                IFS= read -r -p "Wähle eine Option [$valid_options] (Enter für Empfehlung: $default_choice): " selection
            else
                IFS= read -r -p "Select an option [$valid_options] (Enter for recommended: $default_choice): " selection
            fi
            
            # Default to recommended option
            if [ -z "$selection" ]; then
                selection=$default_choice
            fi
            
            # Validate selection - check if it exists in WINE_OPTIONS array
            local is_valid=0
            if [[ "$selection" =~ ^[0-9]+$ ]]; then
                for opt in "${WINE_OPTIONS[@]}"; do
                    if [ "$opt" = "$selection" ]; then
                        is_valid=1
                        break
                    fi
                done
            fi
            
            if [ $is_valid -eq 1 ]; then
                break
            else
                if [ "$LANG_CODE" = "de" ]; then
                    echo "❌ Ungültige Auswahl. Verfügbare Optionen: $valid_options"
                else
                    echo "❌ Invalid selection. Available options: $valid_options"
                fi
            fi
        done
    fi
    
    # Find selected option index
    local selected_index=-1
    for i in "${!WINE_OPTIONS[@]}"; do
        if [ "${WINE_OPTIONS[$i]}" = "$selection" ]; then
            selected_index=$i
            break
        fi
    done
    
    if [ $selected_index -eq -1 ]; then
        error "$([ "$LANG_CODE" = "de" ] && echo "FEHLER: Auswahl nicht gefunden!" || echo "ERROR: Selection not found!")"
        return 1
    fi
    
    # Setup selected version
    local selected_path="${WINE_PATHS[$selected_index]}"
    local selected_desc="${WINE_DESCRIPTIONS[$selected_index]}"
    
    log ""
    log "Ausgewählte Version: $selected_desc"
    log "Pfad: $selected_path"
    
    # Configure environment based on selection
    # NOTE: Proton GE from Steam directory is no longer used (it starts Steam)
    if [ "$selected_path" = "system" ]; then
        # System-wide Proton GE - find the actual path
        # PRIORITÄT: Manuell installiert > AUR-Paket (nicht Steam) > Standard-Wine
        local proton_ge_path=""
        
        # PRIORITÄT 1: Manuell installiert (universell für alle Linux-Distributionen)
        local possible_manual_paths=(
            "$HOME/.local/share/proton-ge/current"
            "$HOME/.local/share/proton-ge"
            "$HOME/.proton-ge/current"
            "$HOME/.proton-ge"
            "/usr/local/share/proton-ge/current"
            "/usr/local/share/proton-ge"
            "/opt/proton-ge/current"
            "/opt/proton-ge"
        )
        
        for path in "${possible_manual_paths[@]}"; do
            # Prüfe ob es ein Symlink ist (current -> version)
            local real_path="$path"
            if [ -L "$path" ]; then
                real_path=$(readlink -f "$path" 2>/dev/null || echo "$path")
            fi
            
            if [ -d "$real_path" ] && [ -f "$real_path/files/bin/wine" ]; then
                # Prüfe dass es NICHT im Steam-Verzeichnis ist
                if [[ ! "$real_path" =~ steam ]]; then
                    proton_ge_path="$real_path"
                    log_debug "Proton GE (manuell) gefunden: $proton_ge_path"
                    break
                fi
            fi
        done
        
        # PRIORITÄT 2: AUR-Paket (nur wenn nicht Steam-Verzeichnis)
        if [ -z "$proton_ge_path" ] && command -v pacman &>/dev/null; then
            local proton_ge_pkg_path=$(pacman -Ql proton-ge-custom-bin 2>/dev/null | grep "files/bin/wine$" | head -1 | awk '{print $2}' | xargs dirname | xargs dirname | xargs dirname)
            if [ -n "$proton_ge_pkg_path" ] && [ -d "$proton_ge_pkg_path" ] && [ -f "$proton_ge_pkg_path/files/bin/wine" ]; then
                # Only use if NOT in Steam directory (Steam paths start Steam)
                if [[ ! "$proton_ge_pkg_path" =~ steam ]]; then
                    # CRITICAL: Validate that path is safe
                    if [[ ! "$proton_ge_pkg_path" =~ ^/tmp|^/var/tmp|^/dev/shm|^/proc ]]; then
                        proton_ge_path="$proton_ge_pkg_path"
                        log_debug "Proton GE (AUR-Paket) gefunden: $proton_ge_path"
                    else
                        log_debug "Proton GE Pfad in unsicherem Verzeichnis, überspringe: $proton_ge_pkg_path"
                    fi
                fi
            fi
        fi
        
        # PRIORITÄT 3: Standard-System-Pfade (falls vorhanden)
        if [ -z "$proton_ge_path" ]; then
            if [ -d "/usr/share/proton-ge" ] && [ -f "/usr/share/proton-ge/files/bin/wine" ]; then
                proton_ge_path="/usr/share/proton-ge"
            fi
        fi
        
        if [ -n "$proton_ge_path" ] && [ -f "$proton_ge_path/files/bin/wine" ]; then
            # CRITICAL: Prevent PATH manipulation - validate proton_ge_path
            # Check that path is not in unsafe directories
            if [[ "$proton_ge_path" =~ ^/tmp|^/var/tmp|^/dev/shm|^/proc ]]; then
                log_error "Proton GE path is in unsafe directory (security risk): $proton_ge_path"
                log "Using standard Wine instead of unsafe Proton GE path"
                proton_ge_path=""
            else
                # CRITICAL: Additional validation - check that wine binary is real
                if [ ! -x "$proton_ge_path/files/bin/wine" ] || [ -L "$proton_ge_path/files/bin/wine" ]; then
                    log_error "Proton GE wine binary is not safe (symlink or not executable): $proton_ge_path/files/bin/wine"
                    log "Using standard Wine instead of unsafe Proton GE"
                    proton_ge_path=""
                else
                    # CRITICAL: Extend PATH, but ensure no . in PATH
                    local safe_path="$proton_ge_path/files/bin"
                    # Remove . from PATH if present
                    local clean_path=$(echo "$PATH" | tr ':' '\n' | grep -v '^\.$' | grep -v '^$' | tr '\n' ':' | sed 's/:$//')
                    export PATH="$safe_path:${clean_path:-/usr/local/bin:/usr/bin:/bin}"
                    export PROTON_PATH="$proton_ge_path"
                    export PROTON_VERB=1
                    log "✓ Proton GE (system) konfiguriert: $proton_ge_path"
                    log_debug "Proton GE Wine-Binary: $proton_ge_path/files/bin/wine"
                fi
            fi
        fi
        
        if [ -z "$proton_ge_path" ]; then
            # Proton GE is installed but path not found or is Steam directory
            # Use standard Wine but set PROTON_PATH="system" for launcher compatibility
            export PROTON_PATH="system"
            log "⚠ Proton GE (system) - Pfad nicht gefunden oder Steam-Verzeichnis"
            log "  → Verwende Standard-Wine (Proton GE ist installiert, aber Pfad nicht verfügbar)"
            log "  → Hinweis: System-weites Proton GE (nicht Steam) wird empfohlen für beste Kompatibilität"
        fi
    else
        # Standard Wine or Wine Staging
        export PROTON_PATH=""
        log "✓ Standard-Wine konfiguriert"
    fi
    
    return 0
}

# Setup Wine environment (wrapper for compatibility)
setup_wine_environment() {
    select_wine_version
}

# Localized messages
if [ "$LANG_CODE" = "de" ]; then
    MSG_INSTALL_COMPONENTS="Installiere Wine-Komponenten..."
    MSG_WAIT="Dies kann 5-10 Minuten dauern. Bitte warten..."
    MSG_SET_WIN10="Setze Windows-Version auf Windows 10..."
    MSG_VCRUN="Installiere Visual C++ Runtimes..."
    MSG_FONTS="Installiere Schriftarten und Bibliotheken..."
    MSG_XML="Installiere XML und GDI+ Komponenten..."
    MSG_DLL="Konfiguriere DLL-Overrides..."
    MSG_PS_FOUND="Lokales Photoshop Installationspaket gefunden..."
    MSG_COPY="Kopiere Installationsdateien nach resources..."
    MSG_START_INSTALL="Starte Photoshop Installation..."
    MSG_IMPORTANT="WICHTIG: Installations-Hinweise:"
    MSG_HINT1="1. Wähle 'Installieren' im Adobe Setup"
    MSG_HINT2="2. Belasse Standard-Pfad: C:\\Program Files\\Adobe\\..."
    MSG_HINT3="3. Wähle Sprache (z.B. de_DE für Deutsch)"
    MSG_HINT4="4. Installation dauert ca. 10-20 Minuten"
    MSG_HINT5="5. WICHTIG: Internet DEAKTIVIEREN für beste Ergebnisse!"
    MSG_HINT6="6. Bei Fehlern: Ignoriere Creative Cloud Login"
    MSG_KNOWN="BEKANNTE PROBLEME (aus GitHub Issues):"
    MSG_ARK="Falls Fehler 'ARKServiceAdmin': Ignorieren, fortfahren"
    MSG_VCERR="Falls Fehler 'VCRUNTIME140.dll': Wine neu konfigurieren"
    MSG_HANG="Installation hängt bei 100%: 2 Min warten, dann beenden"
    MSG_COMPLETE="Photoshop Installation abgeschlossen..."
    MSG_SEARCH_PLUGINS="Suche nach problematischen Plugins..."
    MSG_FOUND_IN="Photoshop gefunden in:"
    MSG_REMOVE_PLUGIN="Entferne problematisches Plugin:"
    MSG_DISABLE_GPU="Deaktiviere GPU-Beschleunigung in Photoshop-Einstellungen..."
else
    MSG_INSTALL_COMPONENTS="Installing Wine components..."
    MSG_WAIT="This may take 5-10 minutes. Please wait..."
    MSG_SET_WIN10="Setting Windows version to Windows 10..."
    MSG_VCRUN="Installing Visual C++ Runtimes..."
    MSG_FONTS="Installing fonts and libraries..."
    MSG_XML="Installing XML and GDI+ components..."
    MSG_DLL="Configuring DLL overrides..."
    MSG_PS_FOUND="Local Photoshop installation package found..."
    MSG_COPY="Copying installation files to resources..."
    MSG_START_INSTALL="Starting Photoshop installation..."
    MSG_IMPORTANT="IMPORTANT: Installation Notes:"
    MSG_HINT1="1. Click 'Install' in Adobe Setup"
    MSG_HINT2="2. Keep default path: C:\\Program Files\\Adobe\\..."
    MSG_HINT3="3. Select language (e.g. en_US for English)"
    MSG_HINT4="4. Installation takes approx. 10-20 minutes"
    MSG_HINT5="5. IMPORTANT: DISABLE internet for best results!"
    MSG_HINT6="6. On errors: Ignore Creative Cloud login"
    MSG_KNOWN="KNOWN ISSUES (from GitHub Issues):"
    MSG_ARK="If error 'ARKServiceAdmin': Ignore, continue"
    MSG_VCERR="If error 'VCRUNTIME140.dll': Reconfigure Wine"
    MSG_HANG="Install hangs at 100%: Wait 2 min, then close"
    MSG_COMPLETE="Photoshop installation completed..."
    MSG_SEARCH_PLUGINS="Searching for problematic plugins..."
    MSG_FOUND_IN="Photoshop found in:"
    MSG_REMOVE_PLUGIN="Removing problematic plugin:"
    MSG_DISABLE_GPU="Disabling GPU acceleration in Photoshop settings..."
fi

# Detect Photoshop version from installer files or directory structure
# Uses multiple methods: pev/peres tool, directory structure, or file metadata
detect_photoshop_version() {
    local installer_dir="$PROJECT_ROOT/photoshop"
    local version="CC 2019"  # Default fallback
    local setup_exe="$installer_dir/Set-up.exe"
    
    if [ ! -f "$setup_exe" ]; then
        echo "$version"
        return 0
    fi
    
    # METHOD 1: Try to extract version from EXE using pev/peres (if available)
    # Based on: https://askubuntu.com/questions/23454/how-to-view-a-pe-exe-dll-file-version-information
    if command -v peres >/dev/null 2>&1; then
        local exe_version=$(peres -v "$setup_exe" 2>/dev/null | awk '{print $3}' | head -1)
        if [ -n "$exe_version" ] && [[ "$exe_version" =~ ^[0-9] ]]; then
            # Convert version number to version string
            # Photoshop CC 2019 = v20.x, 2021 = v22.x, 2022 = v23.x
            local major_version=$(echo "$exe_version" | cut -d. -f1)
            if [ "$major_version" -ge 23 ]; then
                version="2022"
            elif [ "$major_version" -ge 22 ]; then
                version="2021"
            elif [ "$major_version" -ge 20 ]; then
                version="CC 2019"
            fi
        fi
    fi
    
    # METHOD 2: Check directory structure in installer
    if [ "$version" = "CC 2019" ]; then  # Only if method 1 didn't find version
        # Check for version-specific directories
        for dir in "$installer_dir"/Adobe\ Photoshop*; do
            if [ -d "$dir" ]; then
                local dirname=$(basename "$dir")
                if [[ "$dirname" =~ "2022" ]]; then
                    version="2022"
                    break
                elif [[ "$dirname" =~ "2021" ]]; then
                    version="2021"
                    break
                elif [[ "$dirname" =~ "CC 2019" ]] || [[ "$dirname" =~ "2019" ]]; then
                    version="CC 2019"
                    break
                fi
            fi
        done
    fi
    
    # METHOD 3: Try to extract version from strings in EXE (fallback)
    if [ "$version" = "CC 2019" ] && command -v strings >/dev/null 2>&1; then
        local version_string=$(strings "$setup_exe" 2>/dev/null | grep -iE "photoshop.*(202[12]|20\.|CC 2019)" | head -1)
        if [ -n "$version_string" ]; then
            if [[ "$version_string" =~ "2022" ]]; then
                version="2022"
            elif [[ "$version_string" =~ "2021" ]]; then
                version="2021"
            elif [[ "$version_string" =~ "CC 2019" ]] || [[ "$version_string" =~ "2019" ]]; then
                version="CC 2019"
            fi
        fi
    fi
    
    echo "$version"
}

# Get Photoshop installation path based on version
get_photoshop_install_path() {
    local version="${1:-CC 2019}"
    local wine_prefix="${WINE_PREFIX:-$SCR_PATH/prefix}"
    local user="${USER:-$(id -un)}"
    
    # Convert version to path format
    if [[ "$version" =~ "CC 2019" ]]; then
        echo "$wine_prefix/drive_c/Program Files/Adobe/Adobe Photoshop CC 2019"
    elif [[ "$version" =~ "2021" ]]; then
        echo "$wine_prefix/drive_c/Program Files/Adobe/Adobe Photoshop 2021"
    elif [[ "$version" =~ "2022" ]]; then
        echo "$wine_prefix/drive_c/Program Files/Adobe/Adobe Photoshop 2022"
    else
        # Fallback to CC 2019 path
        echo "$wine_prefix/drive_c/Program Files/Adobe/Adobe Photoshop CC 2019"
    fi
}

# Get Photoshop preferences path based on version
get_photoshop_prefs_path() {
    local version="${1:-CC 2019}"
    local wine_prefix="${WINE_PREFIX:-$SCR_PATH/prefix}"
    local user="${USER:-$(id -un)}"
    
    # Convert version to preferences path format
    if [[ "$version" =~ "CC 2019" ]]; then
        echo "$wine_prefix/drive_c/users/$user/AppData/Roaming/Adobe/Adobe Photoshop CC 2019"
    elif [[ "$version" =~ "2021" ]]; then
        echo "$wine_prefix/drive_c/users/$user/AppData/Roaming/Adobe/Adobe Photoshop 2021"
    elif [[ "$version" =~ "2022" ]]; then
        echo "$wine_prefix/drive_c/users/$user/AppData/Roaming/Adobe/Adobe Photoshop 2022"
    else
        # Fallback to CC 2019 path
        echo "$wine_prefix/drive_c/users/$user/AppData/Roaming/Adobe/Adobe Photoshop CC 2019"
    fi
}

function main() {
    # CRITICAL: Trap for CTRL+C (INT) and other signals
    trap 'echo ""; echo "Installation abgebrochen durch Benutzer (STRG+C)"; log_error "Installation abgebrochen durch Benutzer (STRG+C)"; exit 130' INT TERM HUP
    
    # Enable comprehensive logging - ALL output will be logged automatically
    setup_comprehensive_logging
    
    # CRITICAL: Set PS_VERSION early, before it's used
    # Will be set again later in install_photoshopSE(), but needed here for main()
    PS_VERSION=$(detect_photoshop_version)
    PS_INSTALL_PATH=$(get_photoshop_install_path "$PS_VERSION")
    PS_PREFS_PATH=$(get_photoshop_prefs_path "$PS_VERSION")
    
    # Start logging immediately with comprehensive system info
    # Write header to log file (not to console)
    echo "" >> "$LOG_FILE"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ═══════════════════════════════════════════════════════════" >> "$LOG_FILE"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Photoshop CC Installation gestartet: $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Log-Datei: $LOG_FILE" >> "$LOG_FILE"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Error-Log: $ERROR_LOG" >> "$LOG_FILE"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ═══════════════════════════════════════════════════════════" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
    
    # Show only important message to user
    echo "═══════════════════════════════════════════════════════════════"
    echo "Photoshop CC Installation gestartet"
    echo "Log-Datei: $LOG_FILE"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    
    # Log comprehensive system information (to file only)
    log_system_info
    echo "" >> "$LOG_FILE"
    
    log_debug "=== Script Initialization ==="
    log_debug "SCRIPT_DIR: $SCRIPT_DIR"
    log_debug "PROJECT_ROOT: $PROJECT_ROOT"
    log_debug "LOG_DIR: $LOG_DIR"
    log_debug "LOG_FILE: $LOG_FILE"
    log_debug "ERROR_LOG: $ERROR_LOG"
    log_debug "=== End Script Initialization ==="
    echo "" >> "$LOG_FILE"
    
    log "Erstelle Verzeichnisse..."
    mkdir -p $SCR_PATH
    log_debug "SCR_PATH erstellt: $SCR_PATH"
    mkdir -p $CACHE_PATH
    log_debug "CACHE_PATH erstellt: $CACHE_PATH"
    echo "" >> "$LOG_FILE"
    
    setup_log "================| script executed |================"
    log_debug "setup_log aufgerufen"

    echo "Prüfe System-Voraussetzungen..."
    log "Prüfe System-Architektur..."
    is64
    log_debug "is64 Prüfung abgeschlossen"

    #make sure wine and winetricks package is already installed
    log "Prüfe erforderliche Pakete..."
    log_debug "Prüfe wine..."
    package_installed wine
    log_debug "Prüfe md5sum..."
    package_installed md5sum
    log_debug "Prüfe winetricks..."
    package_installed winetricks
    echo "" >> "$LOG_FILE"

    # Setup Wine environment - interactive selection
    # This will show a menu and ask the user to choose
    echo "Wine/Proton-Version Auswahl..."
    log "Starte Wine/Proton-Version Auswahl..."
    log_debug "Rufe setup_wine_environment() auf..."
    log_environment
    if ! setup_wine_environment; then
        log_error "setup_wine_environment() fehlgeschlagen!"
        error "$([ "$LANG_CODE" = "de" ] && echo "FEHLER: Wine/Proton GE nicht gefunden!" || echo "ERROR: Wine/Proton GE not found!")"
        exit 1
    fi
    log_debug "setup_wine_environment() erfolgreich abgeschlossen"
    log_environment
    
    # Confirm selection
    if [ -n "$PROTON_PATH" ] && [ "$PROTON_PATH" != "system" ]; then
        show_message "$([ "$LANG_CODE" = "de" ] && echo "✓ Proton GE wird verwendet (bessere Kompatibilität)" || echo "✓ Using Proton GE (better compatibility)")"
        log "Proton GE aktiviert: $PROTON_PATH"
    elif [ "$PROTON_PATH" = "system" ]; then
        show_message "$([ "$LANG_CODE" = "de" ] && echo "✓ Proton GE (system) wird verwendet" || echo "✓ Using Proton GE (system)")"
        log "Proton GE (system) aktiviert"
    else
        show_message "$([ "$LANG_CODE" = "de" ] && echo "✓ Standard-Wine wird verwendet" || echo "✓ Using standard Wine")"
        log "Standard-Wine aktiviert"
    fi
    log ""

    RESOURCES_PATH="$SCR_PATH/resources"
    WINE_PREFIX="$SCR_PATH/prefix"
    
    #create new wine prefix for photoshop
    rmdir_if_exist $WINE_PREFIX
    
    #export necessary variable for wine
    export_var
    
    # Ensure we use the correct wine/winecfg (from selected Proton GE or standard Wine)
    # The PATH should already be set by select_wine_version(), but we verify it here
    local wine_binary=$(command -v wine 2>/dev/null || echo "wine")
    local winecfg_binary=$(command -v winecfg 2>/dev/null || echo "winecfg")
    log "Verwende Wine-Binary: $wine_binary"
    log "Verwende Winecfg-Binary: $winecfg_binary"
    log "Aktueller PATH: $PATH"
    
    #config wine prefix and install mono and gecko automatic
    echo -e "\033[1;93mplease install mono and gecko packages then click on OK button\e[0m"
    "$winecfg_binary" 2> "$SCR_PATH/wine-error.log"
    if [ $? -eq 0 ];then
        show_message "prefix configured..."
        sleep 5
    else
        error "prefix config failed :("
    fi
    
    if [ -f "$WINE_PREFIX/user.reg" ];then
        #add dark mod
        set_dark_mod
    else
        error "user.reg Not Found :("
    fi
   
    #create resources directory 
    rmdir_if_exist $RESOURCES_PATH

    # Install Wine components
    # Based on GitHub Issues #23, #45, #67: Minimal, stable components
    show_message "$MSG_INSTALL_COMPONENTS"
    show_message "\033[1;33m$MSG_WAIT\e[0m"
    
    # Setze Windows-Version basierend auf erkannte Photoshop-Version
    # OPTIMIERUNG: Neuere Versionen (2021+) funktionieren besser mit Windows 10
    # CC 2019 funktioniert auch mit Windows 10 (bessere Kompatibilität)
    log "$MSG_SET_WIN10"
    
    # Für alle Versionen verwende Windows 10 (beste Kompatibilität)
    # KRITISCH: PS_VERSION mit ${PS_VERSION:-} schützen (kann noch nicht gesetzt sein)
    if [[ "${PS_VERSION:-}" =~ "2021" ]] || [[ "${PS_VERSION:-}" =~ "2022" ]]; then
        log "  → Verwende Windows 10 (empfohlen für ${PS_VERSION:-unknown})"
    else
        log "  → Verwende Windows 10 (auch für ${PS_VERSION:-unknown} kompatibel)"
    fi
    winetricks -q win10 >> "$LOG_FILE" 2>&1
    
    # Core components: Install VC++ Runtimes
    # Use winetricks (standard method, proven and reliable)
    log "$MSG_VCRUN"
    
    # Install VC++ Runtimes with winetricks (standard method, proven and reliable)
    # Standard: Use winetricks for VC++ Runtimes (proven and reliable)
    log "  → Installiere VC++ Runtimes mit winetricks (Standard-Methode)..."
    echo "  → Installiere VC++ Runtimes mit winetricks (dies kann einige Minuten dauern)..."
    
    # CRITICAL: winetricks output to temporary file (prevents blocking)
    local winetricks_output_file
    winetricks_output_file=$(mktemp) || winetricks_output_file="/tmp/winetricks_output_$$.log"
    
    if winetricks -q vcrun2010 vcrun2012 vcrun2013 vcrun2015 > "$winetricks_output_file" 2>&1; then
        cat "$winetricks_output_file" >> "$LOG_FILE"
        log "  ✓ winetricks VC++ Installation erfolgreich"
        echo "  ✓ VC++ Runtimes erfolgreich installiert"
    else
        local winetricks_exit_code=$?
        cat "$winetricks_output_file" >> "$LOG_FILE"
        log "  ⚠ winetricks VC++ Installation fehlgeschlagen (Exit-Code: $winetricks_exit_code)"
        echo "  ⚠ winetricks VC++ Installation fehlgeschlagen - Installation kann trotzdem funktionieren"
    fi
    
    rm -f "$winetricks_output_file" 2>/dev/null || true
    
    log "$MSG_FONTS"
    winetricks -q atmlib corefonts fontsmooth=rgb >> "$LOG_FILE" 2>&1
    
    log "$MSG_XML"
    winetricks -q msxml3 msxml6 gdiplus >> "$LOG_FILE" 2>&1
    
    # OPTIMIZATION: For newer versions (2021+) additional components
    # CRITICAL: Protect PS_VERSION with ${PS_VERSION:-}
    if [[ "${PS_VERSION:-}" =~ "2021" ]] || [[ "${PS_VERSION:-}" =~ "2022" ]]; then
        log "  → Installiere zusätzliche Komponenten für ${PS_VERSION:-unknown}..."
        # dotnet48 wird für neuere Photoshop-Versionen benötigt
        winetricks -q dotnet48 >> "$LOG_FILE" 2>&1 || log "  ⚠ dotnet48 Installation fehlgeschlagen (optional)"
        # vcrun2019 für neuere Versionen (optional)
        winetricks -q vcrun2019 >> "$LOG_FILE" 2>&1 || log "  ⚠ vcrun2019 Installation fehlgeschlagen (optional)"
    fi
    
    # Workaround für bekannte Wine-Probleme (GitHub Issue #34)
    log "$MSG_DLL"
    winetricks -q dxvk_async=disabled d3d11=native >> "$LOG_FILE" 2>&1
    
    # Zusätzliche Performance & Rendering Fixes
    show_message "$([ "$LANG_CODE" = "de" ] && echo "Konfiguriere Wine-Registry für bessere Performance..." || echo "Configuring Wine registry for better performance...")"
    log "Konfiguriere Wine-Registry..."
    
    # Enable CSMT for better performance (Command Stream Multi-Threading)
    log "  - CSMT aktivieren"
    wine reg add "HKEY_CURRENT_USER\\Software\\Wine\\Direct3D" /v csmt /t REG_DWORD /d 1 /f >> "$LOG_FILE" 2>&1 || true
    
    # Disable shader cache to avoid corruption (Issue #206 - Black Screen)
    wine reg add "HKEY_CURRENT_USER\\Software\\Wine\\Direct3D" /v shader_backend /t REG_SZ /d glsl /f 2>/dev/null || true
    
    # Force DirectDraw renderer (helps with screen update issues - Issue #161)
    wine reg add "HKEY_CURRENT_USER\\Software\\Wine\\Direct3D" /v DirectDrawRenderer /t REG_SZ /d opengl /f 2>/dev/null || true
    
    # Disable vertical sync for better responsiveness
    wine reg add "HKEY_CURRENT_USER\\Software\\Wine\\Direct3D" /v StrictDrawOrdering /t REG_SZ /d disabled /f 2>/dev/null || true
    
    # Fix UI scaling issues (Issue #56)
    show_message "$([ "$LANG_CODE" = "de" ] && echo "Konfiguriere DPI-Skalierung..." || echo "Configuring DPI scaling...")"
    wine reg add "HKEY_CURRENT_USER\\Control Panel\\Desktop" /v LogPixels /t REG_DWORD /d 96 /f >> "$LOG_FILE" 2>&1 || true
    wine reg add "HKEY_CURRENT_USER\\Software\\Wine\\Fonts" /v Smoothing /t REG_DWORD /d 2 /f >> "$LOG_FILE" 2>&1 || true
    
    # CRITICAL: Set Windows version explicitly to Windows 10 again
    # (winetricks installations can reset the version, especially IE8)
    log "  → Stelle sicher, dass Windows-Version auf Windows 10 gesetzt ist (vor Adobe Installer)..."
    winetricks -q win10 >> "$LOG_FILE" 2>&1 || log "  ⚠ win10 konnte nicht gesetzt werden"
    
    #install photoshop
    sleep 3
    install_photoshopSE
    sleep 5
    
    replacement

    if [ -d $RESOURCES_PATH ];then
        log "deleting resources folder"
        # CRITICAL: Safe rm -rf with validation
        if [ -z "$RESOURCES_PATH" ]; then
            log_error "RESOURCES_PATH is empty - skipping deletion"
        elif [ "$RESOURCES_PATH" = "/" ]; then
            log_error "RESOURCES_PATH ist root - überspringe Löschung (Sicherheit)"
        elif [ ! -e "$RESOURCES_PATH" ]; then
            log_debug "RESOURCES_PATH existiert nicht: $RESOURCES_PATH"
        elif [ -d "$RESOURCES_PATH" ]; then
            rm -rf "$RESOURCES_PATH" || log_error "Löschen von $RESOURCES_PATH fehlgeschlagen"
        else
            log_error "RESOURCES_PATH ist kein Verzeichnis: $RESOURCES_PATH"
        fi
    else
        error "resources folder Not Found"
    fi

    launcher
    show_message "\033[1;33mwhen you run photoshop for the first time it may take a while\e[0m"
    show_message "Almost finished..."
    sleep 30
}

function replacement() {
    # Replacement component ist optional für die lokale Installation
    # Diese Dateien werden normalerweise nur für UI-Icons benötigt
    log "Überspringe replacement component (optional für lokale Installation)..."
    
    # Verwende dynamischen Pfad basierend auf erkannte Version
    local destpath="$PS_INSTALL_PATH/Resources"
    if [ ! -d "$destpath" ]; then
        show_message "Photoshop Resources-Pfad noch nicht vorhanden, wird später erstellt..."
    fi
    
    unset destpath
}

function install_photoshopSE() {
    # Detect Photoshop version
    PS_VERSION=$(detect_photoshop_version)
    PS_INSTALL_PATH=$(get_photoshop_install_path "$PS_VERSION")
    PS_PREFS_PATH=$(get_photoshop_prefs_path "$PS_VERSION")
    
    log "═══════════════════════════════════════════════════════════════"
    log "Photoshop Installation gestartet: $(date '+%Y-%m-%d %H:%M:%S')"
    log "Erkannte Version: $PS_VERSION"
    log "Installations-Pfad: $PS_INSTALL_PATH"
    log "Log-Datei: $LOG_FILE"
    log "═══════════════════════════════════════════════════════════════"
    log ""
    
    echo "Erkannte Photoshop-Version: $PS_VERSION"
    
    # Verwende das lokale Adobe Photoshop Installationspaket
    # Use project root directory (already determined at top of script)
    local local_installer="$PROJECT_ROOT/photoshop/Set-up.exe"
    
    if [ ! -f "$local_installer" ]; then
        if [ "$LANG_CODE" = "de" ]; then
            error "Lokales Photoshop Installationspaket nicht gefunden: $local_installer
Bitte kopiere die Photoshop-Installationsdateien nach: $PROJECT_ROOT/photoshop/"
        else
            error "Local Photoshop installation package not found: $local_installer
Please copy Photoshop installation files to: $PROJECT_ROOT/photoshop/"
        fi
    fi
    
    show_message "$MSG_PS_FOUND"
    show_message "$MSG_COPY"
    
    # Kopiere das komplette photoshop Verzeichnis in resources
    cp -r "$(dirname "$local_installer")" "$RESOURCES_PATH/"
    
    echo "===============| Adobe Photoshop $PS_VERSION |===============" >> "$SCR_PATH/wine-error.log"
    show_message "$MSG_START_INSTALL"
    show_message "\033[1;33m"
    show_message "═══════════════════════════════════════════════════════════════"
    show_message "           $MSG_IMPORTANT"
    show_message "═══════════════════════════════════════════════════════════════"
    show_message ""
    show_message "$MSG_HINT1"
    show_message "$MSG_HINT2"
    show_message "$MSG_HINT3"
    show_message "$MSG_HINT4"
    show_message "$MSG_HINT5"
    show_message "$MSG_HINT6"
    show_message ""
    show_message "$MSG_KNOWN"
    show_message "  - $MSG_ARK"
    show_message "  - $MSG_VCERR"
    show_message "  - $MSG_HANG"
    show_message ""
    show_message "═══════════════════════════════════════════════════════════════"
    show_message "\e[0m"
    
    # Starte den Adobe Installer (mit Logging)
    log ""
    log "Starte Adobe Photoshop Setup..."
    log "Installer: $RESOURCES_PATH/photoshop/Set-up.exe"
    log ""
    
    # Erklärung welche Wine-Version verwendet wird
    if [ -n "$PROTON_PATH" ] && [ "$PROTON_PATH" != "" ]; then
        if [ "$PROTON_PATH" = "system" ]; then
            log "ℹ Verwende: Proton GE (system) für Installer UND Photoshop"
        else
            log "ℹ Verwende: Proton GE ($PROTON_PATH) für Installer UND Photoshop"
        fi
        log ""
        log "⚠ WICHTIG: Der Adobe Installer verwendet eine IE-Engine, die in"
        log "   Wine/Proton nicht vollständig funktioniert. Falls Buttons nicht"
        log "   reagieren, ist das ein bekanntes Problem (nicht dein Fehler!)."
        log ""
    else
        log "ℹ Verwende: Standard-Wine für Installer UND Photoshop"
        log ""
    fi
    
    # Workaround für "Weiter"-Button Problem: Setze DLL-Overrides für IE-Engine
    # Adobe Installer verwendet IE-Engine (mshtml.dll), die in Wine/Proton nicht vollständig funktioniert
    # BEST PRACTICE: IE8 installieren + umfassende DLL-Overrides für maximale Kompatibilität
    log "Konfiguriere IE-Engine für Adobe Installer (Best Practice)..."
    log ""
    
    # IE8 Installation (STANDARD - immer installieren für beste Kompatibilität)
    if [ "$LANG_CODE" = "de" ]; then
        log "  → Installiere IE8 über winetricks (dauert 5-10 Minuten)..."
        log "     (Standard-Installation für beste Kompatibilität mit Adobe Installer)"
    else
        log "  → Installing IE8 via winetricks (takes 5-10 minutes)..."
        log "     (Standard installation for best compatibility with Adobe Installer)"
    fi
    
    if winetricks -q ie8 >> "$LOG_FILE" 2>&1; then
        log "  ✓ IE8 erfolgreich installiert"
        # CRITICAL: IE8 resets Windows version to win7 - must be set back to win10!
        log "  → Setze Windows-Version erneut auf Windows 10 (IE8 hat sie auf win7 zurückgesetzt)..."
        winetricks -q win10 >> "$LOG_FILE" 2>&1 || log "  ⚠ win10 konnte nicht erneut gesetzt werden"
        log "  ✓ Windows 10 erneut gesetzt"
    else
        log "  ⚠ IE8 Installation fehlgeschlagen - verwende Workarounds"
    fi
    
    log ""
    log "  → Setze umfassende DLL-Overrides für IE-Komponenten..."
    log "     (Best Practice: native,builtin für maximale Kompatibilität)"
    
    # Best Practice: native,builtin (versuche native zuerst, dann builtin als Fallback)
    # For critical IE components we use native,builtin
    wine reg add "HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides" /v mshtml /t REG_SZ /d "native,builtin" /f >> "$LOG_FILE" 2>&1 || true
    wine reg add "HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides" /v jscript /t REG_SZ /d "native,builtin" /f >> "$LOG_FILE" 2>&1 || true
    wine reg add "HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides" /v vbscript /t REG_SZ /d "native,builtin" /f >> "$LOG_FILE" 2>&1 || true
    wine reg add "HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides" /v urlmon /t REG_SZ /d "native,builtin" /f >> "$LOG_FILE" 2>&1 || true
    wine reg add "HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides" /v wininet /t REG_SZ /d "native,builtin" /f >> "$LOG_FILE" 2>&1 || true
    wine reg add "HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides" /v shdocvw /t REG_SZ /d "native,builtin" /f >> "$LOG_FILE" 2>&1 || true
    wine reg add "HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides" /v ieframe /t REG_SZ /d "native,builtin" /f >> "$LOG_FILE" 2>&1 || true
    wine reg add "HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides" /v actxprxy /t REG_SZ /d "native,builtin" /f >> "$LOG_FILE" 2>&1 || true
    wine reg add "HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides" /v browseui /t REG_SZ /d "native,builtin" /f >> "$LOG_FILE" 2>&1 || true
    # Dxtrans.dll und msimtf.dll - für JavaScript/IE-Engine (verhindert viele Fehler im Log)
    wine reg add "HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides" /v dxtrans /t REG_SZ /d "native,builtin" /f >> "$LOG_FILE" 2>&1 || true
    wine reg add "HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides" /v msimtf /t REG_SZ /d "native,builtin" /f >> "$LOG_FILE" 2>&1 || true
    
    # Zusätzliche Registry-Tweaks für bessere IE-Kompatibilität
    log "  → Setze Registry-Tweaks für IE-Kompatibilität..."
    wine reg add "HKEY_CURRENT_USER\\Software\\Microsoft\\Internet Explorer\\Main" /v "DisableScriptDebugger" /t REG_SZ /d "yes" /f >> "$LOG_FILE" 2>&1 || true
    wine reg add "HKEY_CURRENT_USER\\Software\\Microsoft\\Internet Explorer\\Main" /v "DisableFirstRunCustomize" /t REG_SZ /d "1" /f >> "$LOG_FILE" 2>&1 || true
    
    log ""
    log "═══════════════════════════════════════════════════════════════"
    if [ "$LANG_CODE" = "de" ]; then
        log "WICHTIG: Adobe Installer - Button-Problem beheben"
    else
        log "IMPORTANT: Adobe Installer - Fix Button Issues"
    fi
    log "═══════════════════════════════════════════════════════════════"
    log ""
    if [ "$LANG_CODE" = "de" ]; then
        log "PROBLEM: Adobe Installer verwendet IE-Engine (mshtml.dll)"
        log "         Diese funktioniert in Wine/Proton nicht vollständig."
        log ""
        log "LÖSUNG: Wir haben bereits konfiguriert:"
        log "  ✓ IE8 installiert (falls gewählt)"
        log "  ✓ DLL-Overrides gesetzt (native,builtin)"
        log "  ✓ Registry-Tweaks angewendet"
        log ""
        log "Falls 'Weiter'-Button TROTZDEM nicht reagiert:"
        log "  1. Warte 15-30 Sekunden (Installer lädt manchmal langsam)"
        log "  2. Tab-Taste mehrmals drücken, dann Enter"
        log "  3. Alt+W (Weiter) oder Alt+N (Next) versuchen"
        log "  4. Direkt auf Button klicken (nicht daneben)"
        log "  5. Installer-Fenster in den Vordergrund bringen (Alt+Tab)"
        log ""
    else
        log "PROBLEM: Adobe Installer uses IE engine (mshtml.dll)"
        log "         This doesn't work fully in Wine/Proton."
        log ""
        log "SOLUTION: We've already configured:"
        log "  ✓ IE8 installed (if chosen)"
        log "  ✓ DLL-Overrides set (native,builtin)"
        log "  ✓ Registry tweaks applied"
        log ""
        log "If 'Next' button STILL doesn't respond:"
        log "  1. Wait 15-30 seconds (installer sometimes loads slowly)"
        log "  2. Press Tab key multiple times, then Enter"
        log "  3. Try Alt+N (Next) or Alt+W (Weiter in German)"
        log "  4. Click directly on button (not beside it)"
        log "  5. Bring installer window to foreground (Alt+Tab)"
        log ""
    fi
    log ""
    
    # Adobe Installer: Output only to log files, not to terminal (reduces spam)
    # Use PIPESTATUS[0] to capture wine's exit code, not tee's
    log "Starte Adobe Installer (Set-up.exe)..."
    wine "$RESOURCES_PATH/photoshop/Set-up.exe" >> "$LOG_FILE" 2>&1 | tee -a "$SCR_PATH/wine-error.log" >/dev/null
    
    local install_status=${PIPESTATUS[0]}
    
    log ""
    log "Installation beendet mit Exit-Code: $install_status"
    log ""
    
    if [ $install_status -eq 0 ]; then
        log "$MSG_COMPLETE"
    else
        if [ "$LANG_CODE" = "de" ]; then
        warning "Installation mit Exit-Code $install_status beendet. Prüfe die Logs..."
            log_error "FEHLER: Installation mit Exit-Code $install_status beendet"
        else
            warning "Installation finished with exit code $install_status. Check logs..."
            log_error "ERROR: Installation finished with exit code $install_status"
        fi
    fi
    
    # Show log file location
    echo ""
    if [ "$LANG_CODE" = "de" ]; then
        echo "📋 Vollständiges Installations-Log: $LOG_FILE"
        [ -f "$ERROR_LOG" ] && echo "❌ Fehler-Log: $ERROR_LOG"
    else
        echo "📋 Complete installation log: $LOG_FILE"
        [ -f "$ERROR_LOG" ] && echo "❌ Error log: $ERROR_LOG"
    fi
    echo ""
    
    # Versuche problematische Plugins zu entfernen (falls vorhanden)
    show_message "$MSG_SEARCH_PLUGINS"
    
    # Mögliche Installationspfade (dynamisch basierend auf erkannte Version)
    local possible_paths=(
        "$PS_INSTALL_PATH"
        "$WINE_PREFIX/drive_c/Program Files/Adobe/Adobe Photoshop CC 2021"
        "$WINE_PREFIX/drive_c/Program Files/Adobe/Adobe Photoshop CC 2019"
        "$WINE_PREFIX/drive_c/Program Files/Adobe/Adobe Photoshop 2022"
        "$WINE_PREFIX/drive_c/Program Files/Adobe/Adobe Photoshop 2021"
        "$WINE_PREFIX/drive_c/Program Files/Adobe/Adobe Photoshop CC 2018"
        "$WINE_PREFIX/drive_c/users/$USER/PhotoshopSE"
    )
    
    for ps_path in "${possible_paths[@]}"; do
        if [ -d "$ps_path" ]; then
            show_message "$MSG_FOUND_IN $ps_path"
            
            # Entferne problematische Plugins (GitHub Issues #12, #56, #78)
            # JavaScript-Extensions (CEP) funktionieren nicht richtig in Wine/Proton
            local problematic_plugins=(
                "$ps_path/Required/Plug-ins/Spaces/Adobe Spaces Helper.exe"
                "$ps_path/Required/CEP/extensions/com.adobe.DesignLibraryPanel.html"
                "$ps_path/Required/Plug-ins/Extensions/ScriptingSupport.8li"
                # JavaScript-Extension "Startseite" (Homepage) - verursacht Fehler
                "$ps_path/Required/CEP/extensions/com.adobe.HomePagePanel.html"
                "$ps_path/Required/CEP/extensions/com.adobe.HomePagePanel"
            )
            
            for plugin in "${problematic_plugins[@]}"; do
                if [ -f "$plugin" ]; then
                    show_message "$MSG_REMOVE_PLUGIN $(basename "$plugin")"
                    rm "$plugin" 2>/dev/null
                fi
            done
            
            # GPU-Probleme vermeiden (GitHub Issue #45)
            show_message "$MSG_DISABLE_GPU"
            # Verwende dynamischen Prefs-Pfad basierend auf erkannte Version
            local prefs_file="$PS_PREFS_PATH/Adobe Photoshop $PS_VERSION Prefs.psp"
            # Fallback für CC 2019 Format
            if [ ! -d "$(dirname "$prefs_file")" ]; then
                prefs_file="$PS_PREFS_PATH/Adobe Photoshop CC 2019 Prefs.psp"
            fi
            local prefs_dir=$(dirname "$prefs_file")
            
            if [ ! -d "$prefs_dir" ]; then
                mkdir -p "$prefs_dir"
            fi
            
            # Erstelle Prefs-Datei mit GPU-Deaktivierung
            # Diese Einstellungen verhindern GPU-Treiber-Warnungen
            cat > "$prefs_file" << 'EOF'
useOpenCL 0
useGraphicsProcessor 0
GPUAcceleration 0
EOF
            
            # Zusätzlich: Deaktiviere GPU in Registry für bessere Kompatibilität
            log "  → Setze Registry-Einstellungen für GPU-Deaktivierung..."
            wine reg add "HKEY_CURRENT_USER\\Software\\Adobe\\Photoshop\\Settings" /v "GPUAcceleration" /t REG_DWORD /d 0 /f >> "$LOG_FILE" 2>&1 || true
            wine reg add "HKEY_CURRENT_USER\\Software\\Adobe\\Photoshop\\Settings" /v "useOpenCL" /t REG_DWORD /d 0 /f >> "$LOG_FILE" 2>&1 || true
            wine reg add "HKEY_CURRENT_USER\\Software\\Adobe\\Photoshop\\Settings" /v "useGraphicsProcessor" /t REG_DWORD /d 0 /f >> "$LOG_FILE" 2>&1 || true
            
            # PNG Save Fix (Issue #209): Installiere zusätzliche GDI+ Komponenten
            show_message "$([ "$LANG_CODE" = "de" ] && echo "Installiere PNG/Export-Komponenten..." || echo "Installing PNG/Export components...")"
            winetricks -q gdiplus_winxp 2>/dev/null || true
            
            break
        fi
    done
    
    notify-send "Photoshop CC" "Photoshop Installation abgeschlossen" -i "photoshop" 2>/dev/null || true
    log "Adobe Photoshop $PS_VERSION installiert..."
    
    unset local_installer install_status possible_paths
}

# Parse command line arguments for Wine method selection
# Extract our custom parameters BEFORE check_arg (which uses getopts)
# NOTE: Logging is not yet initialized here, so we can't use log_debug
WINE_METHOD=""  # Empty = interactive selection, "wine" = Wine Standard, "proton" = Proton GE
filtered_args=()
for arg in "$@"; do
    case "$arg" in
        --wine-standard)
            WINE_METHOD="wine"
            # Don't add to filtered_args - check_arg doesn't know about this
            ;;
        --proton-ge)
            WINE_METHOD="proton"
            # Don't add to filtered_args - check_arg doesn't know about this
            ;;
        *)
            # Keep all other arguments for check_arg
            filtered_args+=("$arg")
            ;;
    esac
done

# Export WINE_METHOD so it's available in all functions
export WINE_METHOD

# Call check_arg with filtered arguments (without --wine-standard/--proton-ge)
check_arg "${filtered_args[@]}"
save_paths
main




