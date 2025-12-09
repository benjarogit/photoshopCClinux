#!/usr/bin/env bash
################################################################################
# Photoshop CC Linux - Uninstaller
#
# Description:
#   Removes Adobe Photoshop CC installation including Wine prefix,
#   desktop entries, and all associated files.
#
# Author:       benjarogit
# Repository:   https://github.com/benjarogit/photoshopCClinux
# License:      GPL-3.0
# Copyright:    (c) 2024 benjarogit
#
# Based on:     photoshopCClinux by Gictorbit
#               https://github.com/Gictorbit/photoshopCClinux
################################################################################

# CRITICAL: Initialize LANG_CODE BEFORE sharedFuncs.sh (sharedFuncs.sh enables set -u)
# Initialize LANG_CODE (will be set by detect_language if not already set)
LANG_CODE="${LANG_CODE:-}"

# CRITICAL: Prevent source hijacking - always use absolute path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/sharedFuncs.sh"

# Setup comprehensive logging for uninstaller (similar to PhotoshopSetup.sh)
setup_uninstaller_logging() {
    # Get project root (parent of scripts directory)
    local project_root="$(cd "$SCRIPT_DIR/.." && pwd)"
    local log_dir="$project_root/logs"
    
    # Create logs directory if it doesn't exist
    mkdir -p "$log_dir" 2>/dev/null || true
    
    # Generate timestamp for log filename
    local timestamp=$(date '+%d.%m.%y %H:%M Uhr' 2>/dev/null || date '+%d.%m.%y %H:%M Uhr')
    local log_file="$log_dir/Uninstall: ${timestamp}.log"
    local error_log_file="$log_dir/Uninstall: ${timestamp}_errors.log"
    
    # Export log file paths for use in other functions
    export LOG_FILE="$log_file"
    export ERROR_LOG="$error_log_file"
    export PROJECT_ROOT="$project_root"
    export LOG_DIR="$log_dir"
    
    # Initialize log files
    echo "=== Photoshop Uninstaller Log ===" > "$log_file"
    echo "Started: $(date)" >> "$log_file"
    echo "Log file: $log_file" >> "$log_file"
    echo "Error log: $error_log_file" >> "$log_file"
    echo "================================" >> "$log_file"
    echo "" >> "$log_file"
    
    echo "=== Photoshop Uninstaller Error Log ===" > "$error_log_file"
    echo "Started: $(date)" >> "$error_log_file"
    echo "================================" >> "$error_log_file"
    echo "" >> "$error_log_file"
    
    # Log initial information
    log_debug "=== Uninstaller Initialization ==="
    log_debug "SCRIPT_DIR: $SCRIPT_DIR"
    log_debug "PROJECT_ROOT: $project_root"
    log_debug "LOG_DIR: $log_dir"
    log_debug "LOG_FILE: $log_file"
    log_debug "ERROR_LOG: $error_log_file"
    log_debug "=== End Uninstaller Initialization ==="
}

# Enhanced logging function for uninstaller (similar to log_debug in PhotoshopSetup.sh)
log_debug() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date)
    if [ -n "${LOG_FILE:-}" ] && [ -f "${LOG_FILE:-}" ]; then
        echo "[$timestamp] DEBUG: $@" >> "${LOG_FILE}"
    fi
}

# Log error messages
log_error() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date)
    if [ -n "${LOG_FILE:-}" ] && [ -f "${LOG_FILE:-}" ]; then
        echo "[$timestamp] ERROR: $@" >> "${LOG_FILE}"
    fi
    if [ -n "${ERROR_LOG:-}" ] && [ -f "${ERROR_LOG:-}" ]; then
        echo "[$timestamp] ERROR: $@" >> "${ERROR_LOG}"
    fi
}

# Log warning messages
log_warning() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date)
    if [ -n "${LOG_FILE:-}" ] && [ -f "${LOG_FILE:-}" ]; then
        echo "[$timestamp] WARNING: $@" >> "${LOG_FILE}"
    fi
}

# Log info messages
log_info() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date)
    if [ -n "${LOG_FILE:-}" ] && [ -f "${LOG_FILE:-}" ]; then
        echo "[$timestamp] INFO: $@" >> "${LOG_FILE}"
    fi
}

# Detect language (same as setup.sh)
detect_language() {
    # Skip detection if LANG_CODE is already set (e.g., by manual toggle)
    if [ -z "${LANG_CODE:-}" ]; then
        if [[ "$LANG" =~ ^de ]]; then
            LANG_CODE="de"
        else
            LANG_CODE="en"
        fi
    fi
}

# Multi-language messages
msg_uninstall_confirm() {
    if [ "$LANG_CODE" = "de" ]; then
        echo -e "${C_YELLOW}⚠${C_RESET} ${C_CYAN}Möchtest du Photoshop wirklich deinstallieren?${C_RESET}"
    else
        echo -e "${C_YELLOW}⚠${C_RESET} ${C_CYAN}Are you sure you want to uninstall Photoshop?${C_RESET}"
    fi
}

msg_goodbye() {
    if [ "$LANG_CODE" = "de" ]; then
        echo "Auf Wiedersehen!"
    else
        echo "Goodbye!"
    fi
}

msg_remove_dir() {
    if [ "$LANG_CODE" = "de" ]; then
        echo "Entferne Photoshop-Verzeichnis..."
    else
        echo "Removing Photoshop directory..."
    fi
}

msg_dir_not_found() {
    if [ "$LANG_CODE" = "de" ]; then
        echo "Photoshop-Verzeichnis nicht gefunden!"
    else
        echo "Photoshop directory not found!"
    fi
}

msg_remove_command() {
    if [ "$LANG_CODE" = "de" ]; then
        echo "Entferne Launcher-Befehl..."
    else
        echo "Removing launcher command..."
    fi
}

msg_command_not_found() {
    if [ "$LANG_CODE" = "de" ]; then
        echo "Launcher-Befehl nicht gefunden!"
    else
        echo "Launcher command not found!"
    fi
}

msg_remove_desktop() {
    if [ "$LANG_CODE" = "de" ]; then
        echo "Entferne Desktop-Eintrag..."
    else
        echo "Removing desktop entry..."
    fi
}

msg_desktop_not_found() {
    if [ "$LANG_CODE" = "de" ]; then
        echo "Desktop-Eintrag nicht gefunden!"
    else
        echo "Desktop entry not found!"
    fi
}

msg_cache_info() {
    if [ "$LANG_CODE" = "de" ]; then
        echo "Alle heruntergeladenen Komponenten sind im Cache-Verzeichnis"
        echo "und können für die nächste Installation wiederverwendet werden."
        echo "Cache-Verzeichnis:"
    else
        echo "All downloaded components are in cache directory"
        echo "and can be reused for next installation."
        echo "Cache directory:"
    fi
}

msg_delete_cache() {
    if [ "$LANG_CODE" = "de" ]; then
        echo "Möchtest du das Cache-Verzeichnis löschen?"
    else
        echo "Would you like to delete the cache directory?"
    fi
}

msg_cache_removed() {
    if [ "$LANG_CODE" = "de" ]; then
        echo "Cache-Verzeichnis entfernt."
    else
        echo "Cache directory removed."
    fi
}

msg_cache_kept() {
    if [ "$LANG_CODE" = "de" ]; then
        echo "Gut, du kannst die heruntergeladenen Daten später für die Installation verwenden."
    else
        echo "Nice, you can use downloaded data later for Photoshop installation."
    fi
}

msg_cache_not_found() {
    if [ "$LANG_CODE" = "de" ]; then
        echo "Cache-Verzeichnis nicht gefunden!"
    else
        echo "Cache directory not found!"
    fi
}

main() {    
    # Setup comprehensive logging FIRST (before any other operations)
    setup_uninstaller_logging
    
    # Detect language
    detect_language
    
    log_debug "=== Uninstaller Started ==="
    log_debug "Language: $LANG_CODE"
    log_debug "User: ${USER:-$(id -un)}"
    log_debug "Home: ${HOME:-}"
    
    CMD_PATH="/usr/local/bin/photoshop"
    ENTRY_PATH="$HOME/.local/share/applications/photoshop.desktop"
    
    log_debug "CMD_PATH: $CMD_PATH"
    log_debug "ENTRY_PATH: $ENTRY_PATH"
    
    if [ "$LANG_CODE" = "de" ]; then
        notify-send "Photoshop" "Photoshop-Deinstaller gestartet" -i "photoshop" 2>/dev/null || true
        log_info "Uninstaller started (German)"
    else
        notify-send "Photoshop" "Photoshop uninstaller started" -i "photoshop" 2>/dev/null || true
        log_info "Uninstaller started (English)"
    fi

    # CRITICAL: Load installation paths and Wine version info BEFORE using them
    # This ensures WINE_VERSION_INFO is available for the uninstallation logic
    log_debug "Loading installation paths from ~/.psdata.txt..."
    if [ -f "$HOME/.psdata.txt" ]; then
        load_paths "true"  # Skip validation for uninstaller
        log_debug "SCR_PATH: ${SCR_PATH:-not set}"
        log_debug "CACHE_PATH: ${CACHE_PATH:-not set}"
        log_debug "WINE_VERSION_INFO: ${WINE_VERSION_INFO:-not set}"
    else
        log_warning "Installation data file not found: ~/.psdata.txt"
        log_warning "Continuing with uninstallation anyway..."
    fi

    # Show which Wine version was used (if available)
    if [ -n "${WINE_VERSION_INFO:-}" ] && [ -n "$WINE_VERSION_INFO" ]; then
        if [ "$LANG_CODE" = "de" ]; then
            echo -e "${C_CYAN}ℹ${C_RESET} ${C_GRAY}Installation verwendet: Proton GE${C_RESET}"
            setup_log "Wine-Version: Proton GE ($WINE_VERSION_INFO)" 2>/dev/null || true
        else
            echo -e "${C_CYAN}ℹ${C_RESET} ${C_GRAY}Installation used: Proton GE${C_RESET}"
            setup_log "Wine version: Proton GE ($WINE_VERSION_INFO)" 2>/dev/null || true
        fi
    else
        if [ "$LANG_CODE" = "de" ]; then
            echo -e "${C_CYAN}ℹ${C_RESET} ${C_GRAY}Installation verwendet: Wine Standard${C_RESET}"
            setup_log "Wine-Version: Wine Standard" 2>/dev/null || true
        else
            echo -e "${C_CYAN}ℹ${C_RESET} ${C_GRAY}Installation used: Wine Standard${C_RESET}"
            setup_log "Wine version: Wine Standard" 2>/dev/null || true
        fi
    fi
    echo ""

    ask_question "$(msg_uninstall_confirm)" "N"
    if [ "$result" = "no" ]; then
        log_info "User cancelled uninstallation"
        msg_goodbye
        exit 0
    fi
    
    log_info "User confirmed uninstallation"
    
    # CRITICAL: Kill all Wine/Proton processes before removing the prefix
    # This prevents "version mismatch" errors and ensures clean uninstallation
    if [ "$LANG_CODE" = "de" ]; then
        echo -e "${C_YELLOW}→${C_RESET} ${C_CYAN}Beende Wine/Proton-Prozesse...${C_RESET}"
    else
        echo -e "${C_YELLOW}→${C_RESET} ${C_CYAN}Stopping Wine/Proton processes...${C_RESET}"
    fi
    
    log_debug "Killing Wine/Proton processes..."
    
    # Kill wineserver if it exists
    if command -v wineserver >/dev/null 2>&1; then
        log_debug "Killing wineserver..."
        wineserver -k 2>/dev/null || log_warning "Failed to kill wineserver"
        sleep 1
    else
        log_debug "wineserver not found"
    fi
    
    # Kill any remaining wine processes for this prefix
    if [ -n "${SCR_PATH:-}" ] && [ -d "${SCR_PATH:-}/prefix" ]; then
        log_debug "Killing Wine processes for prefix: ${SCR_PATH}/prefix"
        # Set WINEPREFIX temporarily to kill processes for this prefix
        export WINEPREFIX="${SCR_PATH}/prefix"
        wineserver -k 2>/dev/null || log_warning "Failed to kill wineserver for prefix"
        unset WINEPREFIX
        sleep 1
    else
        log_debug "Prefix directory not found: ${SCR_PATH:-}/prefix"
    fi
    
    # Kill any wine processes that might be using the prefix
    log_debug "Killing any remaining Wine/Proton processes..."
    pkill -f "wine.*${SCR_PATH}" 2>/dev/null && log_debug "Killed Wine processes" || log_debug "No Wine processes found"
    pkill -f "proton.*${SCR_PATH}" 2>/dev/null && log_debug "Killed Proton processes" || log_debug "No Proton processes found"
    sleep 1
    
    #remove photoshop directory
    # CRITICAL: Works for both Wine Standard and Proton GE (both use the same prefix)
    log_debug "Removing Photoshop directory: ${SCR_PATH:-}"
    if [ -d "$SCR_PATH" ];then
        msg_remove_dir
        log_info "Removing directory: $SCR_PATH"
        if rm -rf "$SCR_PATH" 2>&1; then
            log_info "Successfully removed Photoshop directory"
        else
            log_error "Failed to remove Photoshop directory"
            error2 "$([ "$LANG_CODE" = "de" ] && echo "Konnte Photoshop-Verzeichnis nicht entfernen" || echo "Couldn't remove Photoshop directory")"
        fi
    else
        log_warning "Photoshop directory not found: $SCR_PATH"
        msg_dir_not_found
    fi
    
    #Unlink command 
    if [ -L "$CMD_PATH" ];then
        msg_remove_command
        sudo unlink "$CMD_PATH" 2>/dev/null || error2 "$([ "$LANG_CODE" = "de" ] && echo "Konnte Launcher-Befehl nicht entfernen" || echo "Couldn't remove launcher command")"
    else
        msg_command_not_found
    fi

    #delete desktop entry (alle Varianten finden und entfernen)
    msg_remove_desktop
    
    # Search for all possible desktop entries (menu entries)
    local desktop_entries=(
        "$HOME/.local/share/applications/photoshop.desktop"
        "$HOME/.local/share/applications/Adobe Photoshop CC 2019.desktop"
        "$HOME/.local/share/applications/Adobe Photoshop.desktop"
        "$HOME/.local/share/applications/photoshopCC.desktop"
        "$HOME/.local/share/applications/Adobe Photoshop 2021.desktop"
        "$HOME/.local/share/applications/Adobe Photoshop 2022.desktop"
    )
    
    # Search also in Wine categories (e.g., ~/.local/share/applications/wine/Programs/)
    # CRITICAL: Wine creates desktop entries in wine/Programs/ subdirectories
    if [ -d "$HOME/.local/share/applications/wine" ]; then
        while IFS= read -r -d '' entry; do
            desktop_entries+=("$entry")
        done < <(find "$HOME/.local/share/applications/wine" -type f \( -name "*Photoshop*" -o -name "*photoshop*" \) -print0 2>/dev/null || true)
    fi
    
    # Also search in wine/Programs/ directly (common location)
    if [ -d "$HOME/.local/share/applications/wine/Programs" ]; then
        while IFS= read -r -d '' entry; do
            desktop_entries+=("$entry")
        done < <(find "$HOME/.local/share/applications/wine/Programs" -type f \( -name "*Photoshop*" -o -name "*photoshop*" \) -print0 2>/dev/null || true)
    fi
    
    # Search for desktop icons (Desktop shortcuts)
    # Desktop directory can be "Desktop" (English) or "Schreibtisch" (German)
    local desktop_dirs=(
        "$HOME/Desktop"
        "$HOME/Schreibtisch"
        "$HOME/desktop"
        "$HOME/schreibtisch"
    )
    
    local desktop_icons=()
    for desktop_dir in "${desktop_dirs[@]}"; do
        if [ -d "$desktop_dir" ]; then
            while IFS= read -r -d '' icon; do
                desktop_icons+=("$icon")
            done < <(find "$desktop_dir" -type f \( -name "*Photoshop*" -o -name "*photoshop*" \) -print0 2>/dev/null || true)
        fi
    done
    
    local found_any=false
    
    # Remove menu entries
    for entry in "${desktop_entries[@]}"; do
        if [ -f "$entry" ]; then
            if rm "$entry" 2>/dev/null; then
                found_any=true
                if [ "$LANG_CODE" = "de" ]; then
                    setup_log "Entfernt (Menü): $entry" 2>/dev/null || true
                else
                    setup_log "Removed (menu): $entry" 2>/dev/null || true
                fi
            fi
        fi
    done
    
    # Remove desktop icons
    for icon in "${desktop_icons[@]}"; do
        if [ -f "$icon" ]; then
            if rm "$icon" 2>/dev/null; then
                found_any=true
                if [ "$LANG_CODE" = "de" ]; then
                    setup_log "Entfernt (Desktop): $icon" 2>/dev/null || true
                else
                    setup_log "Removed (desktop): $icon" 2>/dev/null || true
                fi
            fi
        fi
    done
    
    # Also remove empty Wine directories if they exist
    if [ -d "$HOME/.local/share/applications/wine/Programs" ]; then
        # Check if Programs directory is empty or only contains empty subdirectories
        if [ -z "$(find "$HOME/.local/share/applications/wine/Programs" -mindepth 1 -maxdepth 1 -type f 2>/dev/null)" ]; then
            # Remove empty Programs directory
            rmdir "$HOME/.local/share/applications/wine/Programs" 2>/dev/null || true
            # If wine directory is also empty, remove it
            rmdir "$HOME/.local/share/applications/wine" 2>/dev/null || true
        fi
    fi
    
    if [ "$found_any" = false ]; then
        msg_desktop_not_found
    fi
    
    # Aktualisiere Desktop-Datenbank
    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
    fi

    #delete cache directory
    if [ -d "$CACHE_PATH" ];then
        echo "--------------------------------"
        msg_cache_info
        echo -e "\033[1;36m$CACHE_PATH\033[0m"
        echo "--------------------------------"
        ask_question "$(msg_delete_cache)" "N"
        if [ "$result" = "yes" ];then
            rm -rf "$CACHE_PATH" 2>/dev/null || error2 "$([ "$LANG_CODE" = "de" ] && echo "Konnte Cache-Verzeichnis nicht entfernen" || echo "Couldn't remove cache directory")"
            msg_cache_removed
        else
            msg_cache_kept
        fi
    else
        msg_cache_not_found
    fi
    
    # CRITICAL: Check if Wine Standard or Proton GE should be uninstalled
    # Only uninstall if they were installed specifically for Photoshop
    # WINE_VERSION_INFO should already be loaded at the beginning of main()
    
    # Check if Wine Standard should be uninstalled
    # Only uninstall if:
    # 1. Wine Standard was used (not Proton GE)
    # 2. No other Wine prefixes exist (except Photoshop prefix which is already deleted)
    # 3. Wine is installed via package manager
    if [ -z "${WINE_VERSION_INFO:-}" ] || [[ "${WINE_VERSION_INFO:-}" != *"Proton"* ]]; then
        # Wine Standard was used - check if we should uninstall it
        local other_wine_prefixes=0
        
        # Check for other Wine prefixes (common locations)
        local wine_prefix_locations=(
            "$HOME/.wine"
            "$HOME/.local/share/wineprefixes"
            "$HOME/.wineprefixes"
        )
        
        for prefix_dir in "${wine_prefix_locations[@]}"; do
            if [ -d "$prefix_dir" ] && [ "$prefix_dir" != "$SCR_PATH/prefix" ]; then
                # Check if directory contains actual Wine prefixes
                if [ -f "$prefix_dir/system.reg" ] || [ -f "$prefix_dir/user.reg" ] || [ -n "$(find "$prefix_dir" -maxdepth 2 -name "*.reg" 2>/dev/null | head -1)" ]; then
                    other_wine_prefixes=1
                    break
                fi
            fi
        done
        
        # Also check for other Wine prefixes in common locations
        if [ -d "$HOME/.local/share/wineprefixes" ]; then
            local prefix_count=$(find "$HOME/.local/share/wineprefixes" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
            if [ "$prefix_count" -gt 0 ]; then
                other_wine_prefixes=1
            fi
        fi
        
        # If no other Wine prefixes exist, ask if Wine should be uninstalled
        if [ "$other_wine_prefixes" -eq 0 ]; then
            if [ "$LANG_CODE" = "de" ]; then
                echo ""
                echo -e "${C_YELLOW}⚠${C_RESET} ${C_CYAN}Wine Standard wurde für Photoshop verwendet.${C_RESET}"
                echo -e "${C_GRAY}   Es wurden keine anderen Wine-Prefixes gefunden.${C_RESET}"
                ask_question "Möchtest du Wine Standard auch deinstallieren? (nur wenn es nur für Photoshop installiert wurde)" "N"
            else
                echo ""
                echo -e "${C_YELLOW}⚠${C_RESET} ${C_CYAN}Wine Standard was used for Photoshop.${C_RESET}"
                echo -e "${C_GRAY}   No other Wine prefixes were found.${C_RESET}"
                ask_question "Do you want to uninstall Wine Standard? (only if it was installed only for Photoshop)" "N"
            fi
            
            if [ "$result" = "yes" ]; then
                if [ "$LANG_CODE" = "de" ]; then
                    echo -e "${C_YELLOW}→${C_RESET} ${C_CYAN}Deinstalliere Wine Standard...${C_RESET}"
                else
                    echo -e "${C_YELLOW}→${C_RESET} ${C_CYAN}Uninstalling Wine Standard...${C_RESET}"
                fi
                
                # Try to uninstall Wine via package manager
                if command -v pacman >/dev/null 2>&1; then
                    # Arch-based
                    sudo pacman -Rns wine wine-staging wine-mono wine-gecko 2>/dev/null || sudo pacman -Rns wine 2>/dev/null || true
                elif command -v apt >/dev/null 2>&1; then
                    # Debian-based
                    sudo apt remove --purge wine wine-stable wine-staging 2>/dev/null || true
                elif command -v dnf >/dev/null 2>&1; then
                    # Fedora-based
                    sudo dnf remove wine 2>/dev/null || true
                else
                    if [ "$LANG_CODE" = "de" ]; then
                        echo -e "${C_YELLOW}⚠${C_RESET} ${C_YELLOW}Bitte deinstalliere Wine manuell für deine Distribution.${C_RESET}"
                    else
                        echo -e "${C_YELLOW}⚠${C_RESET} ${C_YELLOW}Please uninstall Wine manually for your distribution.${C_RESET}"
                    fi
                fi
                
                if [ "$LANG_CODE" = "de" ]; then
                    echo -e "${C_GREEN}✓${C_RESET} ${C_CYAN}Wine Standard deinstalliert${C_RESET}"
                else
                    echo -e "${C_GREEN}✓${C_RESET} ${C_CYAN}Wine Standard uninstalled${C_RESET}"
                fi
            fi
        fi
    fi
    
    # Check if Proton GE should be uninstalled
    # Only uninstall if:
    # 1. Proton GE was used (not Wine Standard)
    # 2. It's NOT Steam Proton (Steam Proton should not be touched)
    # 3. It was installed via package manager or manually for Photoshop
    if [ -n "${WINE_VERSION_INFO:-}" ] && [[ "${WINE_VERSION_INFO:-}" =~ "Proton" ]]; then
        # Proton GE was used - check if we should uninstall it
        local proton_ge_path=""
        
        # Check for system-wide Proton GE (not Steam)
        local possible_proton_paths=(
            "$HOME/.local/share/proton-ge"
            "/usr/local/share/proton-ge"
            "/opt/proton-ge"
        )
        
        for path in "${possible_proton_paths[@]}"; do
            if [ -d "$path" ] && [ -f "$path/files/bin/wine" ] 2>/dev/null; then
                # Make sure it's NOT Steam Proton
                if [[ ! "$path" =~ steam ]] && [[ ! "$path" =~ Steam ]]; then
                    proton_ge_path="$path"
                    break
                fi
            fi
        done
        
        # Also check for AUR-installed Proton GE
        if [ -z "$proton_ge_path" ] && command -v pacman >/dev/null 2>&1; then
            if pacman -Q proton-ge-custom-bin >/dev/null 2>&1; then
                proton_ge_path="aur"
            fi
        fi
        
        # If Proton GE was found (and it's not Steam), ask if it should be uninstalled
        if [ -n "$proton_ge_path" ]; then
            if [ "$LANG_CODE" = "de" ]; then
                echo ""
                echo -e "${C_YELLOW}⚠${C_RESET} ${C_CYAN}Proton GE wurde für Photoshop verwendet.${C_RESET}"
                if [ "$proton_ge_path" = "aur" ]; then
                    echo -e "${C_GRAY}   Proton GE wurde via AUR installiert.${C_RESET}"
                    ask_question "Möchtest du Proton GE auch deinstallieren? (nur wenn es nur für Photoshop installiert wurde)" "N"
                else
                    echo -e "${C_GRAY}   Proton GE wurde manuell installiert: $proton_ge_path${C_RESET}"
                    ask_question "Möchtest du Proton GE auch deinstallieren? (nur wenn es nur für Photoshop installiert wurde)" "N"
                fi
            else
                echo ""
                echo -e "${C_YELLOW}⚠${C_RESET} ${C_CYAN}Proton GE was used for Photoshop.${C_RESET}"
                if [ "$proton_ge_path" = "aur" ]; then
                    echo -e "${C_GRAY}   Proton GE was installed via AUR.${C_RESET}"
                    ask_question "Do you want to uninstall Proton GE? (only if it was installed only for Photoshop)" "N"
                else
                    echo -e "${C_GRAY}   Proton GE was manually installed: $proton_ge_path${C_RESET}"
                    ask_question "Do you want to uninstall Proton GE? (only if it was installed only for Photoshop)" "N"
                fi
            fi
            
            if [ "$result" = "yes" ]; then
                if [ "$LANG_CODE" = "de" ]; then
                    echo -e "${C_YELLOW}→${C_RESET} ${C_CYAN}Deinstalliere Proton GE...${C_RESET}"
                else
                    echo -e "${C_YELLOW}→${C_RESET} ${C_CYAN}Uninstalling Proton GE...${C_RESET}"
                fi
                
                if [ "$proton_ge_path" = "aur" ]; then
                    # AUR-installed: Use package manager
                    if command -v yay >/dev/null 2>&1; then
                        yay -Rns proton-ge-custom-bin 2>/dev/null || true
                    elif command -v paru >/dev/null 2>&1; then
                        paru -Rns proton-ge-custom-bin 2>/dev/null || true
                    elif command -v pacman >/dev/null 2>&1; then
                        sudo pacman -Rns proton-ge-custom-bin 2>/dev/null || true
                    fi
                else
                    # Manually installed: Remove directory
                    if [ -d "$proton_ge_path" ]; then
                        rm -rf "$proton_ge_path" 2>/dev/null || true
                    fi
                fi
                
                if [ "$LANG_CODE" = "de" ]; then
                    echo -e "${C_GREEN}✓${C_RESET} ${C_CYAN}Proton GE deinstalliert${C_RESET}"
                else
                    echo -e "${C_GREEN}✓${C_RESET} ${C_CYAN}Proton GE uninstalled${C_RESET}"
                fi
            fi
        fi
    fi
    
    # Exit cleanly (fixes hanging issue)
    if [ "$LANG_CODE" = "de" ]; then
        echo ""
        echo "✓ Deinstallation abgeschlossen!"
    else
        echo ""
        echo "✓ Uninstallation completed!"
    fi
    exit 0
}

#parameters [Message] [default flag [Y/N]]
function ask_question() {
    result=""
    # CRITICAL: == is not POSIX, use =
    if [ "$2" = "Y" ];then
        # CRITICAL: Reset IFS after read
        local old_IFS="${IFS:-}"
        IFS= read -r -p "$1 [Y/n] " response
        if locale noexpr >/dev/null 2>&1 && [[ "$response" =~ $(locale noexpr) ]];then
            result="no"
        elif [ -n "$response" ] && [[ "$response" =~ ^[Nn] ]]; then
            result="no"
        else
            result="yes"
        fi
        # CRITICAL: Reset IFS
        IFS="$old_IFS"
    elif [ "$2" = "N" ];then
        # CRITICAL: Reset IFS after read
        local old_IFS="${IFS:-}"
        IFS= read -r -p "$1 [N/y] " response
        if locale yesexpr >/dev/null 2>&1 && [[ "$response" =~ $(locale yesexpr) ]];then
            result="yes"
        elif [ -n "$response" ] && [[ "$response" =~ ^[Yy] ]]; then
            result="yes"
        else
            result="no"
        fi
        # CRITICAL: Reset IFS
        IFS="$old_IFS"
    fi
}

# Load paths with skip_validation=true to allow uninstall even if directories are deleted
load_paths "true"

# Detect language before main() is called
detect_language

main



