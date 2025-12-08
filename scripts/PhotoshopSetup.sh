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

source "sharedFuncs.sh"

# Setup logging - use project directory (where setup.sh is located)
# Get project root directory (parent of scripts/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_DIR="$PROJECT_ROOT/logs"
mkdir -p "$LOG_DIR"

# Generate timestamp once to ensure both logs have matching timestamps
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$LOG_DIR/install_${TIMESTAMP}.log"
ERROR_LOG="$LOG_DIR/install_${TIMESTAMP}_errors.log"

# Log function for both console and file
log() {
    echo "$@" | tee -a "$LOG_FILE"
}

log_error() {
    echo "$@" | tee -a "$LOG_FILE" | tee -a "$ERROR_LOG"
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
# Returns: array of options with priority (Proton GE > Wine > others)
detect_all_wine_versions() {
    local options=()
    local descriptions=()
    local paths=()
    local index=1
    local system=$(detect_system)
    local recommended_index=1
    local proton_found=0  # Flag to track if any Proton GE was found
    
    # Priority 1: Proton GE (Steam directory) - BEST OPTION
    if [ -d "$HOME/.steam/steam/steamapps/common" ]; then
        while IFS= read -r proton_path; do
            if [ -f "$proton_path/proton" ] && [ -f "$proton_path/files/bin/wine" ]; then
                local version=$(basename "$proton_path")
                options+=("$index")
                if [ "$LANG_CODE" = "de" ]; then
                    descriptions+=("Proton GE (Steam): $version ⭐ EMPFOHLEN - beste Kompatibilität")
                else
                    descriptions+=("Proton GE (Steam): $version ⭐ RECOMMENDED - best compatibility")
                fi
                paths+=("$proton_path")
                if [ $proton_found -eq 0 ]; then
                    recommended_index=$index
                    proton_found=1
                fi
                ((index++))
            fi
        done < <(find "$HOME/.steam/steam/steamapps/common" -maxdepth 1 -type d \( -name "Proton*" -o -name "proton-ge*" \) 2>/dev/null | sort -Vr)
    fi
    
    # Priority 2: System-wide Proton GE (if installed via package manager)
    if command -v proton-ge &> /dev/null; then
        local version=$(proton-ge --version 2>/dev/null || echo "system")
        options+=("$index")
        if [ "$LANG_CODE" = "de" ]; then
            descriptions+=("Proton GE (system): $version ⭐ EMPFOHLEN - beste Kompatibilität")
        else
            descriptions+=("Proton GE (system): $version ⭐ RECOMMENDED - best compatibility")
        fi
        paths+=("system")
        # Only set as recommended if no Proton GE was found before (Steam Proton takes priority)
        if [ $proton_found -eq 0 ]; then
            recommended_index=$index
            proton_found=1
        fi
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
    local count=0
    local system=$(detect_system)
    local selection=""  # Declare at function start
    detect_all_wine_versions
    count=$?
    
    if [ $count -eq 0 ]; then
        error "$([ "$LANG_CODE" = "de" ] && echo "FEHLER: Keine Wine/Proton-Version gefunden!" || echo "ERROR: No Wine/Proton version found!")"
        return 1
    fi
    
    # Check if no Proton GE found (only Wine available) - show warning
    local has_proton=0
    for path in "${WINE_PATHS[@]}"; do
        if [[ "$path" == *"Proton"* ]] || [ "$path" = "system" ]; then
            has_proton=1
            break
        fi
    done
    
    # If only one option available, use it automatically (no menu)
    if [ $count -eq 1 ]; then
        selection=1
        if [ "$LANG_CODE" = "de" ]; then
            if [ $has_proton -eq 0 ] && ([ "$system" = "cachyos" ] || [ "$system" = "arch" ] || [ "$system" = "manjaro" ]); then
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
                read -p "Deine Wahl [J/n]: " install_proton
                if [[ "$install_proton" =~ ^[JjYy]$ ]] || [ -z "$install_proton" ]; then
                    echo ""
                    echo "═══════════════════════════════════════════════════════════════"
                    echo "           Proton GE wird jetzt installiert"
                    echo "═══════════════════════════════════════════════════════════════"
                    echo ""
                    echo "SCHRITT 1/2: Prüfe ob Wine installiert ist..."
                    echo ""
                    if ! command -v wine &> /dev/null; then
                        echo "⚠ Wine fehlt noch - wird jetzt installiert..."
                        echo "   (Wine wird für die Photoshop-Komponenten benötigt)"
                        echo ""
                        if command -v pacman &> /dev/null; then
                            sudo pacman -S wine
                        else
                            echo "   Bitte installiere Wine manuell für deine Distribution"
                            read -p "Drücke Enter, wenn Wine installiert wurde: " wait_wine
                        fi
                        echo ""
                    else
                        echo "✓ Wine ist bereits installiert"
                        echo ""
                    fi
                    echo "SCHRITT 2/2: Installiere Proton GE..."
                    echo "   (Dies kann 2-5 Minuten dauern - bitte warten...)"
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
                        echo "❌ Kein AUR-Helper (yay/paru) gefunden!"
                        echo "   Installiere yay oder paru, dann führe aus:"
                        echo "   yay -S proton-ge-custom-bin"
                        echo ""
                        read -p "Drücke Enter, wenn Proton GE installiert wurde, oder [A] zum Abbrechen: " continue_install
                        if [[ "$continue_install" =~ ^[Aa]$ ]]; then
                            error "Installation abgebrochen"
                            exit 1
                        fi
                        # Assume success if user pressed Enter
                        install_success=1
                    fi
                    
                    if [ $install_success -eq 0 ]; then
                        echo ""
                        echo "❌ FEHLER: Proton GE Installation fehlgeschlagen!"
                        echo ""
                        if [ "$LANG_CODE" = "de" ]; then
                            echo "Möchtest du trotzdem mit Standard-Wine fortfahren?"
                            read -p "   [J] Ja - Mit Standard-Wine fortfahren  [N] Nein - Abbrechen [J/n]: " continue_with_wine
                        else
                            echo "Do you want to continue with Standard Wine anyway?"
                            read -p "   [Y] Yes - Continue with Standard Wine  [N] No - Cancel [Y/n]: " continue_with_wine
                        fi
                        if [[ "$continue_with_wine" =~ ^[Nn]$ ]]; then
                            error "$([ "$LANG_CODE" = "de" ] && echo "Installation abgebrochen" || echo "Installation cancelled")"
                            exit 1
                        fi
                        # Continue with standard Wine
                        selection=1
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
                read -p "Your choice [Y/n]: " install_proton
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
                            read -p "Press Enter when Wine is installed: " wait_wine
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
                        read -p "Press Enter when Proton GE is installed, or [C] to Cancel: " continue_install
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
                        read -p "   [Y] Yes - Continue with Standard Wine  [N] No - Cancel [Y/n]: " continue_with_wine
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
                read -p "Wähle eine Option [$valid_options] (Enter für Empfehlung: $default_choice): " selection
            else
                read -p "Select an option [$valid_options] (Enter for recommended: $default_choice): " selection
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
    if [ "$selected_path" != "wine" ] && [ "$selected_path" != "wine-staging" ] && [ "$selected_path" != "system" ]; then
        # Proton GE from Steam directory
        export PATH="$selected_path/files/bin:$PATH"
        export PROTON_PATH="$selected_path"
        export PROTON_VERB=1
        log "✓ Proton GE konfiguriert: $selected_path"
    elif [ "$selected_path" = "system" ]; then
        # System-wide Proton GE - find the actual path
        local proton_ge_path=""
        # Try common installation paths
        if [ -d "/usr/share/proton-ge" ]; then
            proton_ge_path="/usr/share/proton-ge"
        elif [ -d "/usr/local/share/proton-ge" ]; then
            proton_ge_path="/usr/local/share/proton-ge"
        elif [ -d "$HOME/.local/share/proton-ge" ]; then
            proton_ge_path="$HOME/.local/share/proton-ge"
        else
            # Try to find via proton-ge command
            local proton_ge_cmd=$(command -v proton-ge 2>/dev/null)
            if [ -n "$proton_ge_cmd" ]; then
                # proton-ge is usually a symlink or script, try to find the actual directory
                local proton_ge_dir=$(readlink -f "$proton_ge_cmd" 2>/dev/null | xargs dirname 2>/dev/null | xargs dirname 2>/dev/null | xargs dirname 2>/dev/null)
                if [ -d "$proton_ge_dir" ] && [ -f "$proton_ge_dir/files/bin/wine" ]; then
                    proton_ge_path="$proton_ge_dir"
                fi
            fi
        fi
        
        if [ -n "$proton_ge_path" ] && [ -f "$proton_ge_path/files/bin/wine" ]; then
            export PATH="$proton_ge_path/files/bin:$PATH"
            export PROTON_PATH="$proton_ge_path"
            export PROTON_VERB=1
            log "✓ Proton GE (system) konfiguriert: $proton_ge_path"
        else
            export PROTON_PATH="system"
            log "⚠ Proton GE (system) - Pfad nicht gefunden, verwende Standard-Wine"
            log "  → Installer verwendet möglicherweise Standard-Wine statt Proton GE"
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

function main() {
    # Start logging immediately
    log ""
    log "═══════════════════════════════════════════════════════════════"
    log "Photoshop CC Installation gestartet: $(date '+%Y-%m-%d %H:%M:%S')"
    log "Log-Datei: $LOG_FILE"
    log "═══════════════════════════════════════════════════════════════"
    log ""
    
    mkdir -p $SCR_PATH
    mkdir -p $CACHE_PATH
    
    setup_log "================| script executed |================"

    is64

    #make sure wine and winetricks package is already installed
    package_installed wine
    package_installed md5sum
    package_installed winetricks

    # Setup Wine environment - interactive selection
    # This will show a menu and ask the user to choose
    if ! setup_wine_environment; then
        error "$([ "$LANG_CODE" = "de" ] && echo "FEHLER: Wine/Proton GE nicht gefunden!" || echo "ERROR: Wine/Proton GE not found!")"
        exit 1
    fi
    
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
    
    #config wine prefix and install mono and gecko automatic
    echo -e "\033[1;93mplease install mono and gecko packages then click on OK button\e[0m"
    winecfg 2> "$SCR_PATH/wine-error.log"
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

    # Installiere Wine-Komponenten
    # Basierend auf GitHub Issues #23, #45, #67: Minimale, stabile Komponenten
    show_message "$MSG_INSTALL_COMPONENTS"
    show_message "\033[1;33m$MSG_WAIT\e[0m"
    
    # Setze zuerst Windows-Version auf Windows 10 (wichtig für CC 2019!)
    show_message "$MSG_SET_WIN10"
    log "$MSG_SET_WIN10"
    winetricks -q win10 2>&1 | tee -a "$LOG_FILE"
    
    # Core-Komponenten einzeln installieren für bessere Fehlerbehandlung
    show_message "$MSG_VCRUN"
    log "$MSG_VCRUN"
    winetricks -q vcrun2010 vcrun2012 vcrun2013 vcrun2015 2>&1 | tee -a "$LOG_FILE"
    
    show_message "$MSG_FONTS"
    log "$MSG_FONTS"
    winetricks -q atmlib corefonts fontsmooth=rgb 2>&1 | tee -a "$LOG_FILE"
    
    show_message "$MSG_XML"
    log "$MSG_XML"
    winetricks -q msxml3 msxml6 gdiplus 2>&1 | tee -a "$LOG_FILE"
    
    # Workaround für bekannte Wine-Probleme (GitHub Issue #34)
    show_message "$MSG_DLL"
    log "$MSG_DLL"
    winetricks -q dxvk_async=disabled d3d11=native 2>&1 | tee -a "$LOG_FILE"
    
    # Zusätzliche Performance & Rendering Fixes
    show_message "$([ "$LANG_CODE" = "de" ] && echo "Konfiguriere Wine-Registry für bessere Performance..." || echo "Configuring Wine registry for better performance...")"
    log "Konfiguriere Wine-Registry..."
    
    # Enable CSMT for better performance (Command Stream Multi-Threading)
    log "  - CSMT aktivieren"
    wine reg add "HKEY_CURRENT_USER\\Software\\Wine\\Direct3D" /v csmt /t REG_DWORD /d 1 /f 2>&1 | tee -a "$LOG_FILE" >/dev/null || true
    
    # Disable shader cache to avoid corruption (Issue #206 - Black Screen)
    wine reg add "HKEY_CURRENT_USER\\Software\\Wine\\Direct3D" /v shader_backend /t REG_SZ /d glsl /f 2>/dev/null || true
    
    # Force DirectDraw renderer (helps with screen update issues - Issue #161)
    wine reg add "HKEY_CURRENT_USER\\Software\\Wine\\Direct3D" /v DirectDrawRenderer /t REG_SZ /d opengl /f 2>/dev/null || true
    
    # Disable vertical sync for better responsiveness
    wine reg add "HKEY_CURRENT_USER\\Software\\Wine\\Direct3D" /v StrictDrawOrdering /t REG_SZ /d disabled /f 2>/dev/null || true
    
    # Fix UI scaling issues (Issue #56)
    show_message "$([ "$LANG_CODE" = "de" ] && echo "Konfiguriere DPI-Skalierung..." || echo "Configuring DPI scaling...")"
    wine reg add "HKEY_CURRENT_USER\\Control Panel\\Desktop" /v LogPixels /t REG_DWORD /d 96 /f 2>/dev/null || true
    wine reg add "HKEY_CURRENT_USER\\Software\\Wine\\Fonts" /v Smoothing /t REG_DWORD /d 2 /f 2>/dev/null || true
    
    #install photoshop
    sleep 3
    install_photoshopSE
    sleep 5
    
    replacement

    if [ -d $RESOURCES_PATH ];then
        show_message "deleting resources folder"
        rm -rf $RESOURCES_PATH
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
    show_message "Überspringe replacement component (optional für lokale Installation)..."
    
    local destpath="$WINE_PREFIX/drive_c/Program Files/Adobe/Adobe Photoshop CC 2019/Resources"
    if [ ! -d "$destpath" ]; then
        show_message "Photoshop Resources-Pfad noch nicht vorhanden, wird später erstellt..."
    fi
    
    unset destpath
}

function install_photoshopSE() {
    # Log installation start
    log "═══════════════════════════════════════════════════════════════"
    log "Photoshop CC Installation gestartet: $(date '+%Y-%m-%d %H:%M:%S')"
    log "Log-Datei: $LOG_FILE"
    log "═══════════════════════════════════════════════════════════════"
    log ""
    
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
    
    echo "===============| Adobe Photoshop CC 2019 (v20) |===============" >> "$SCR_PATH/wine-error.log"
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
    
    # IE8 Installation (EMPFOHLEN für Adobe Installer)
    if [ "$LANG_CODE" = "de" ]; then
        echo "═══════════════════════════════════════════════════════════════"
        echo "           IE8-Installation (EMPFOHLEN)"
        echo "═══════════════════════════════════════════════════════════════"
        echo ""
        echo "Der Adobe Installer benötigt eine funktionierende IE-Engine."
        echo "IE8 verbessert die Kompatibilität erheblich."
        echo ""
        echo "Installation dauert ca. 5-10 Minuten (einmalig)."
        echo ""
        read -p "IE8 jetzt installieren? [J/n]: " install_ie8
    else
        echo "═══════════════════════════════════════════════════════════════"
        echo "           IE8 Installation (RECOMMENDED)"
        echo "═══════════════════════════════════════════════════════════════"
        echo ""
        echo "Adobe Installer requires a working IE engine."
        echo "IE8 significantly improves compatibility."
        echo ""
        echo "Installation takes about 5-10 minutes (one-time)."
        echo ""
        read -p "Install IE8 now? [Y/n]: " install_ie8
    fi
    
    if [[ "$install_ie8" =~ ^[JjYy]$ ]] || [ -z "$install_ie8" ]; then
        log "  → Installiere IE8 über winetricks (dauert 5-10 Minuten)..."
        log "     (Dies ist wichtig für funktionierende Buttons im Installer)"
        if winetricks -q ie8 2>&1 | tee -a "$LOG_FILE"; then
            log "  ✓ IE8 erfolgreich installiert"
        else
            log "  ⚠ IE8 Installation fehlgeschlagen - verwende Workarounds"
        fi
    else
        log "  ⚠ IE8 Installation übersprungen - Buttons könnten nicht funktionieren"
    fi
    
    log ""
    log "  → Setze umfassende DLL-Overrides für IE-Komponenten..."
    log "     (Best Practice: native,builtin für maximale Kompatibilität)"
    
    # Best Practice: native,builtin (versuche native zuerst, dann builtin als Fallback)
    # Für kritische IE-Komponenten verwenden wir native,builtin
    wine reg add "HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides" /v mshtml /t REG_SZ /d "native,builtin" /f 2>&1 | tee -a "$LOG_FILE" >/dev/null || true
    wine reg add "HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides" /v jscript /t REG_SZ /d "native,builtin" /f 2>&1 | tee -a "$LOG_FILE" >/dev/null || true
    wine reg add "HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides" /v vbscript /t REG_SZ /d "native,builtin" /f 2>&1 | tee -a "$LOG_FILE" >/dev/null || true
    wine reg add "HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides" /v urlmon /t REG_SZ /d "native,builtin" /f 2>&1 | tee -a "$LOG_FILE" >/dev/null || true
    wine reg add "HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides" /v wininet /t REG_SZ /d "native,builtin" /f 2>&1 | tee -a "$LOG_FILE" >/dev/null || true
    wine reg add "HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides" /v shdocvw /t REG_SZ /d "native,builtin" /f 2>&1 | tee -a "$LOG_FILE" >/dev/null || true
    wine reg add "HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides" /v ieframe /t REG_SZ /d "native,builtin" /f 2>&1 | tee -a "$LOG_FILE" >/dev/null || true
    wine reg add "HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides" /v actxprxy /t REG_SZ /d "native,builtin" /f 2>&1 | tee -a "$LOG_FILE" >/dev/null || true
    wine reg add "HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides" /v browseui /t REG_SZ /d "native,builtin" /f 2>&1 | tee -a "$LOG_FILE" >/dev/null || true
    
    # Zusätzliche Registry-Tweaks für bessere IE-Kompatibilität
    log "  → Setze Registry-Tweaks für IE-Kompatibilität..."
    wine reg add "HKEY_CURRENT_USER\\Software\\Microsoft\\Internet Explorer\\Main" /v "DisableScriptDebugger" /t REG_SZ /d "yes" /f 2>&1 | tee -a "$LOG_FILE" >/dev/null || true
    wine reg add "HKEY_CURRENT_USER\\Software\\Microsoft\\Internet Explorer\\Main" /v "DisableFirstRunCustomize" /t REG_SZ /d "1" /f 2>&1 | tee -a "$LOG_FILE" >/dev/null || true
    
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
        log "HINWEIS: Steam startet automatisch mit Proton GE - das ist normal."
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
        log "NOTE: Steam starts automatically with Proton GE - this is normal."
    fi
    log ""
    
    # Log both to our log file and wine-error.log
    # Use PIPESTATUS[0] to capture wine's exit code, not tee's
    wine "$RESOURCES_PATH/photoshop/Set-up.exe" 2>&1 | tee -a "$LOG_FILE" >> "$SCR_PATH/wine-error.log"
    
    local install_status=${PIPESTATUS[0]}
    
    log ""
    log "Installation beendet mit Exit-Code: $install_status"
    log ""
    
    if [ $install_status -eq 0 ]; then
        show_message "$MSG_COMPLETE"
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
    
    # Mögliche Installationspfade
    local possible_paths=(
        "$WINE_PREFIX/drive_c/Program Files/Adobe/Adobe Photoshop CC 2019"
        "$WINE_PREFIX/drive_c/Program Files/Adobe/Adobe Photoshop CC 2018"
        "$WINE_PREFIX/drive_c/users/$USER/PhotoshopSE"
    )
    
    for ps_path in "${possible_paths[@]}"; do
        if [ -d "$ps_path" ]; then
            show_message "$MSG_FOUND_IN $ps_path"
            
            # Entferne problematische Plugins (GitHub Issues #12, #56, #78)
            local problematic_plugins=(
                "$ps_path/Required/Plug-ins/Spaces/Adobe Spaces Helper.exe"
                "$ps_path/Required/CEP/extensions/com.adobe.DesignLibraryPanel.html"
                "$ps_path/Required/Plug-ins/Extensions/ScriptingSupport.8li"
            )
            
            for plugin in "${problematic_plugins[@]}"; do
                if [ -f "$plugin" ]; then
                    show_message "$MSG_REMOVE_PLUGIN $(basename "$plugin")"
                    rm "$plugin" 2>/dev/null
                fi
            done
            
            # GPU-Probleme vermeiden (GitHub Issue #45)
            show_message "$MSG_DISABLE_GPU"
            local prefs_file="$WINE_PREFIX/drive_c/users/$USER/AppData/Roaming/Adobe/Adobe Photoshop CC 2019/Adobe Photoshop CC 2019 Settings/Adobe Photoshop CC 2019 Prefs.psp"
            local prefs_dir=$(dirname "$prefs_file")
            
            if [ ! -d "$prefs_dir" ]; then
                mkdir -p "$prefs_dir"
            fi
            
            # Erstelle Prefs-Datei mit GPU-Deaktivierung
            cat > "$prefs_file" << 'EOF'
useOpenCL 0
useGraphicsProcessor 0
EOF
            
            # PNG Save Fix (Issue #209): Installiere zusätzliche GDI+ Komponenten
            show_message "$([ "$LANG_CODE" = "de" ] && echo "Installiere PNG/Export-Komponenten..." || echo "Installing PNG/Export components...")"
            winetricks -q gdiplus_winxp 2>/dev/null || true
            
            break
        fi
    done
    
    notify-send "Photoshop CC" "Photoshop Installation abgeschlossen" -i "photoshop"
    show_message "Adobe Photoshop CC v20 installiert..."
    
    unset local_installer install_status possible_paths
}

check_arg $@
save_paths
main



