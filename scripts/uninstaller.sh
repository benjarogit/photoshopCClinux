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
        echo "Möchtest du Photoshop CC wirklich deinstallieren?"
    else
        echo "Are you sure you want to uninstall Photoshop CC?"
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
    # Detect language
    detect_language
    
    CMD_PATH="/usr/local/bin/photoshop"
    ENTRY_PATH="$HOME/.local/share/applications/photoshop.desktop"
    
    if [ "$LANG_CODE" = "de" ]; then
        notify-send "Photoshop CC" "Photoshop-Deinstaller gestartet" -i "photoshop" 2>/dev/null || true
    else
        notify-send "Photoshop CC" "Photoshop uninstaller started" -i "photoshop" 2>/dev/null || true
    fi

    ask_question "$(msg_uninstall_confirm)" "N"
    if [ "$result" = "no" ]; then
        msg_goodbye
        exit 0
    fi
    
    #remove photoshop directory
    if [ -d "$SCR_PATH" ];then
        msg_remove_dir
        rm -rf "$SCR_PATH" || error2 "$([ "$LANG_CODE" = "de" ] && echo "Konnte Photoshop-Verzeichnis nicht entfernen" || echo "Couldn't remove Photoshop directory")"
    else
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
    
    # Suche nach allen möglichen Desktop-Einträgen
    local desktop_entries=(
        "$HOME/.local/share/applications/photoshop.desktop"
        "$HOME/.local/share/applications/Adobe Photoshop CC 2019.desktop"
        "$HOME/.local/share/applications/Adobe Photoshop.desktop"
        "$HOME/.local/share/applications/photoshopCC.desktop"
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
    
    local found_any=false
    for entry in "${desktop_entries[@]}"; do
        if [ -f "$entry" ]; then
            if rm "$entry" 2>/dev/null; then
                found_any=true
                if [ "$LANG_CODE" = "de" ]; then
                    log "Entfernt: $entry" 2>/dev/null || true
                else
                    log "Removed: $entry" 2>/dev/null || true
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



