#!/usr/bin/env bash
################################################################################
# Photoshop CC Linux Installer - Main Setup Script
#
# Description:
#   Interactive menu system for installing and managing Adobe Photoshop CC
#   on Linux using Wine. Supports multi-language (English/German) interface
#   with ANSI colored banner display.
#
# Author:       benjarogit
# Repository:   https://github.com/benjarogit/photoshopCClinux
# License:      GPL-3.0
# Copyright:    (c) 2024 benjarogit
#
# Based on:     photoshopCClinux by Gictorbit
#               https://github.com/Gictorbit/photoshopCClinux
################################################################################

# KRITISCH: Robuste Fehlerbehandlung aktivieren
# set -e: Exit bei Fehlern
# set -u: Exit bei undefinierten Variablen
# set -o pipefail: Exit bei Pipeline-Fehlern
# BusyBox-Kompatibilität: pipefail kann fehlen, daher || true
set -eu
(set -o pipefail 2>/dev/null) || true

# Locale/UTF-8 für DE/EN sicherstellen (mit Prüfung auf existierende Locale)
# KRITISCH: Prüfe ob Locale existiert (Alpine hat oft nur C.UTF-8)
if command -v locale >/dev/null 2>&1; then
    if locale -a 2>/dev/null | grep -qE "^(de_DE|de_DE\.utf8|de_DE\.UTF-8)$"; then
        export LANG="${LANG:-de_DE.UTF-8}"
    elif locale -a 2>/dev/null | grep -qE "^(C\.utf8|C\.UTF-8)$"; then
        export LANG="${LANG:-C.UTF-8}"
    else
        export LANG="${LANG:-C}"
    fi
else
    # Fallback wenn locale nicht verfügbar
    export LANG="${LANG:-C.UTF-8}"
fi
export LC_ALL="${LC_ALL:-$LANG}"

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Initialize LANG_CODE (will be set by detect_language if not already set)
LANG_CODE="${LANG_CODE:-}"

# Detect system language (only if not already set by user)
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
msg_choose_option() {
    if [ "$LANG_CODE" = "de" ]; then
        echo "[Wähle eine Option]$ "
    else
        echo "[choose an option]$ "
    fi
}

msg_run_photoshop() {
    if [ "$LANG_CODE" = "de" ]; then
        echo "Starte Photoshop CC Installation..."
        echo -n "Verwende winetricks für Komponenten-Installation..."
    else
        echo "run photoshop CC Installation..."
        echo -n "using winetricks for component installation..."
    fi
}

msg_run_camera_raw() {
    if [ "$LANG_CODE" = "de" ]; then
        echo -n "Starte Adobe Camera Raw Installer"
    else
        echo -n "run adobe camera Raw installer"
    fi
}

msg_run_winecfg() {
    if [ "$LANG_CODE" = "de" ]; then
        echo "Starte winecfg..."
        echo -n "Öffne virtuelles Laufwerk Konfiguration..."
    else
        echo "run winecfg..."
        echo -n "open virtualdrive configuration..."
    fi
}

msg_uninstall() {
    if [ "$LANG_CODE" = "de" ]; then
        echo -n "Deinstalliere Photoshop CC ..."
    else
        echo -n "uninstall photoshop CC ..."
    fi
}

msg_pre_check() {
    if [ "$LANG_CODE" = "de" ]; then
        echo "Starte System-Vorprüfung..."
    else
        echo "run pre-installation check..."
    fi
}

msg_troubleshoot() {
    if [ "$LANG_CODE" = "de" ]; then
        echo "Starte Fehlerbehebung..."
    else
        echo "run troubleshooting..."
    fi
}

msg_exit() {
    if [ "$LANG_CODE" = "de" ]; then
        echo "Setup beenden..."
    else
        echo "exit setup..."
    fi
}

msg_goodbye() {
    if [ "$LANG_CODE" = "de" ]; then
        echo "Auf Wiedersehen :)"
    else
        echo "Good Bye :)"
    fi
}

msg_found() {
    if [ "$LANG_CODE" = "de" ]; then
        echo "$1 gefunden..."
    else
        echo "$1 Found..."
    fi
}

msg_not_found() {
    if [ "$LANG_CODE" = "de" ]; then
        error "$1 nicht gefunden..."
    else
        error "$1 not Found..."
    fi
}

msg_banner_not_found() {
    if [ "$LANG_CODE" = "de" ]; then
        error "Banner nicht gefunden..."
    else
        error "banner not Found..."
    fi
}

function show_wine_selection_menu() {
    clear && echo ""
    if [ "$LANG_CODE" = "de" ]; then
        echo "═══════════════════════════════════════════════════════════════"
        echo "            Wine/Proton Auswahl für Photoshop CC"
        echo "═══════════════════════════════════════════════════════════════"
        echo ""
        echo "  [1] Wine Standard installieren"
        echo "  [2] Proton GE installieren (empfohlen)"
        echo "  [3] Zurück zum Hauptmenü"
        echo ""
        IFS= read -r -p "Wähle eine Option [1-3]: " wine_choice
    else
        echo "═══════════════════════════════════════════════════════════════"
        echo "            Wine/Proton Selection for Photoshop CC"
        echo "═══════════════════════════════════════════════════════════════"
        echo ""
        echo "  Choose a Wine version:"
        echo ""
        echo "  [1] Install with Wine Standard"
        echo "  [2] Install with Proton GE (recommended)"
        echo "  [3] Back to main menu"
        echo ""
        IFS= read -r -p "Choose an option [1-3]: " wine_choice
    fi
    
    case "$wine_choice" in
        1)
            msg_run_photoshop
            run_script "$SCRIPT_DIR/scripts/PhotoshopSetup.sh" "PhotoshopSetup.sh" --wine-standard
            local exit_code=$?
            # Exit code 130 = STRG+C (user interrupt) - return to main menu
            if [ $exit_code -eq 130 ]; then
                if [ "$LANG_CODE" = "de" ]; then
                    echo ""
                    echo "Installation abgebrochen. Zurück zum Hauptmenü..."
                else
                    echo ""
                    echo "Installation cancelled. Returning to main menu..."
                fi
                wait_second 2
                main
            fi
            ;;
        2)
            msg_run_photoshop
            run_script "$SCRIPT_DIR/scripts/PhotoshopSetup.sh" "PhotoshopSetup.sh" --proton-ge
            local exit_code=$?
            # Exit code 130 = STRG+C (user interrupt) - return to main menu
            if [ $exit_code -eq 130 ]; then
                if [ "$LANG_CODE" = "de" ]; then
                    echo ""
                    echo "Installation abgebrochen. Zurück zum Hauptmenü..."
                else
                    echo ""
                    echo "Installation cancelled. Returning to main menu..."
                fi
                wait_second 2
                main
            fi
            ;;
        3|"")
            main
            ;;
        *)
            if [ "$LANG_CODE" = "de" ]; then
                warning "Ungültige Auswahl. Zurück zum Hauptmenü..."
            else
                warning "Invalid selection. Returning to main menu..."
            fi
            wait_second 2
            main
            ;;
    esac
}

function main() {
    # Detect language
    detect_language
    
    #print banner
    banner

    #read inputs
    read_input
    local answer="${CHOICE:-}"  # Use empty string if CHOICE is not set

    case "$answer" in

    1)
        # Show Wine selection submenu
        show_wine_selection_menu
        ;;
    2)  
        msg_run_camera_raw
        run_script "scripts/cameraRawInstaller.sh" "cameraRawInstaller.sh"
        wait_second 2
        main
        ;;
    3)  
        msg_pre_check
        # Pre-check is in root directory - use script directory
        local precheck_path="$SCRIPT_DIR/pre-check.sh"
        if [ -f "$precheck_path" ]; then
            chmod +x "$precheck_path"
            bash "$precheck_path"
        else
            error "pre-check.sh not found at $precheck_path"
        fi
        wait_second 2
        main
        ;;
    4)  
        msg_troubleshoot
        # Troubleshoot is in root directory - use script directory
        local troubleshoot_path="$SCRIPT_DIR/troubleshoot.sh"
        if [ -f "$troubleshoot_path" ]; then
            chmod +x "$troubleshoot_path"
            bash "$troubleshoot_path"
        else
            error "troubleshoot.sh not found at $troubleshoot_path"
        fi
        wait_second 2
        main
        ;;
    5)  
        msg_run_winecfg
        run_script "scripts/winecfg.sh" "winecfg.sh"
        wait_second 2
        main
        ;;
    6)  
        msg_uninstall
        run_script "scripts/uninstaller.sh" "uninstaller.sh"
        wait_second 2
        main
        ;;
    7)  
        # Toggle Internet
        toggle_internet
        wait_second 2
        main
        ;;
    8)  
        # Toggle language
        if [ "$LANG_CODE" = "de" ]; then
            LANG_CODE="en"
            echo "Language switched to English"
        else
            LANG_CODE="de"
            echo "Sprache auf Deutsch umgestellt"
        fi
        
        wait_second 2
        main
        ;;
    9)  
        msg_exit
        exitScript
        ;;
    esac
}

#arguments 1=script_path 2=script_name [additional args...]
function run_script() {
    local script_path=$1
    local script_name=$2
    shift 2  # Remove first two arguments, rest are passed to script

    wait_second 5
    
    # KRITISCH: File-System-Umleitung verhindern - verwende absoluten Pfad
    local absolute_script_path="$SCRIPT_DIR/scripts/$script_name"
    
    # Prüfe dass Script wirklich im erwarteten Verzeichnis ist
    if [[ "$absolute_script_path" != "$SCRIPT_DIR/scripts/"* ]]; then
        error "Script-Pfad außerhalb erwartetem Verzeichnis (Sicherheitsrisiko): $absolute_script_path"
        return 1
    fi
    
    if [ -f "$absolute_script_path" ];then
        msg_found "$absolute_script_path"
        chmod +x "$absolute_script_path"
    else
        msg_not_found "$script_name"
        return 1
    fi
    
    # KRITISCH: Führe Script mit absolutem Pfad aus (kein cd + relativer Name)
    bash "$absolute_script_path" "$@"
    local exit_code=$?
    
    unset script_path absolute_script_path
    return $exit_code  # Preserve the script's exit code
}

function toggle_internet() {
    if ! command -v nmcli &> /dev/null; then
        if [ "$LANG_CODE" = "de" ]; then
            warning "nmcli nicht gefunden - kann Internet nicht umschalten"
            echo "Manuell alle Verbindungen auflisten: nmcli connection show"
            echo "Manuell deaktivieren: nmcli connection down <name>"
        else
            warning "nmcli not found - cannot toggle internet"
            echo "Manual list connections: nmcli connection show"
            echo "Manual disable: nmcli connection down <name>"
        fi
        return 1
    fi
    
    # KRITISCH: mktemp statt vorhersagbarem Dateinamen (Sicherheit)
    local disabled_connections_file
    disabled_connections_file=$(mktemp "/tmp/.photoshop_disabled_connections.XXXXXX" 2>/dev/null) || {
        if [ "$LANG_CODE" = "de" ]; then
            warning "mktemp fehlgeschlagen - verwende Fallback"
        else
            warning "mktemp failed - using fallback"
        fi
        disabled_connections_file="/tmp/.photoshop_disabled_connections.$$"
    }
    
    # KRITISCH: TOCTOU-Schutz - prüfe dass tmp_file keine Symlink ist
    if [ -L "$disabled_connections_file" ]; then
        rm -f "$disabled_connections_file" 2>/dev/null || true
        error "Temporäre Datei ist Symlink (Sicherheitsrisiko)"
        return 1
    fi
    
    # KRITISCH: Cleanup bei allen Signalen (nicht nur EXIT) - verhindere Race-Conditions
    trap "rm -f '$disabled_connections_file' 2>/dev/null" EXIT INT TERM HUP
    
    # Check if any connection is active (exclude loopback)
    local active_connections=$(nmcli -t -f NAME,STATE connection show | grep ":activated" | cut -d: -f1 | grep -v "^lo$")
    
    if [ -n "$active_connections" ]; then
        # Internet is ON - turn it OFF
        if [ "$LANG_CODE" = "de" ]; then
            echo "Deaktiviere alle Netzwerkverbindungen..."
        else
            echo "Disabling all network connections..."
        fi
        
        # Save disabled connections to file for later restoration
        echo "$active_connections" > "$disabled_connections_file"
        
        while IFS= read -r conn; do
            if [ -n "$conn" ]; then
                nmcli connection down "$conn" &> /dev/null
                if [ "$LANG_CODE" = "de" ]; then
                    echo "  ✓ $conn deaktiviert"
                else
                    echo "  ✓ $conn disabled"
                fi
            fi
        done <<< "$active_connections"
        
        if [ "$LANG_CODE" = "de" ]; then
            echo -e "\n\033[1;32m✓\033[0m Alle Verbindungen deaktiviert (PERFEKT für Installation!)"
        else
            echo -e "\n\033[1;32m✓\033[0m All connections disabled (PERFECT for installation!)"
        fi
    else
        # Internet is OFF - turn it ON
        if [ "$LANG_CODE" = "de" ]; then
            echo "Aktiviere Netzwerkverbindungen..."
        else
            echo "Enabling network connections..."
        fi
        
        # Re-enable only the connections that were previously disabled
        if [ -f "$disabled_connections_file" ]; then
            local connections_to_restore=$(cat "$disabled_connections_file")
            
            while IFS= read -r conn; do
                if [ -n "$conn" ]; then
                    nmcli connection up "$conn" &> /dev/null && {
                        if [ "$LANG_CODE" = "de" ]; then
                            echo "  ✓ $conn aktiviert"
                        else
                            echo "  ✓ $conn enabled"
                        fi
                    }
                fi
            done <<< "$connections_to_restore"
            
            # Clean up temp file
            rm -f "$disabled_connections_file"
        else
            # Fallback: if no saved state, try to enable the first active ethernet/wifi connection
            if [ "$LANG_CODE" = "de" ]; then
                echo "  (Keine gespeicherten Verbindungen - verwende Fallback)"
            else
                echo "  (No saved connections - using fallback)"
            fi
            
            local fallback_conn=$(nmcli -t -f NAME,TYPE connection show | grep -E ":(802-3-ethernet|802-11-wireless)" | head -1 | cut -d: -f1)
            if [ -n "$fallback_conn" ]; then
                nmcli connection up "$fallback_conn" &> /dev/null && {
                    if [ "$LANG_CODE" = "de" ]; then
                        echo "  ✓ $fallback_conn aktiviert"
                    else
                        echo "  ✓ $fallback_conn enabled"
                    fi
                }
            fi
        fi
        
        if [ "$LANG_CODE" = "de" ]; then
            echo -e "\n\033[1;32m✓\033[0m Verbindungen wiederhergestellt"
        else
            echo -e "\n\033[1;32m✓\033[0m Connections restored"
        fi
    fi
}

function wait_second() {
    for (( i=0 ; i<$1 ; i++ ));do
        echo -n "."
        sleep 1
    done
    echo ""
}

function read_input() {
    # KRITISCH: IFS zurücksetzen nach read
    local old_IFS="${IFS:-}"
    while true ;do
        # KRITISCH: read -r verhindert Backslash-Interpretation
        IFS= read -r -p "$(msg_choose_option)" choose
        # Accept 1-9 for menu selection
        if [[ "$choose" =~ ^[1-9]$ ]];then
            break
        fi
        if [ "$LANG_CODE" = "de" ]; then
            warning "Wähle eine Zahl zwischen 1 und 9"
        else
            warning "Choose a number between 1 and 9"
        fi
    done

    # Return the choice as a global variable (since return can only be 0-255)
    CHOICE="$choose"
    # KRITISCH: IFS zurücksetzen
    IFS="$old_IFS"
}

function exitScript() {
    msg_goodbye
}

function get_system_info() {
    # Get system information for display
    local distro=$(grep "^PRETTY_NAME" /etc/os-release 2>/dev/null | cut -d'"' -f2 || echo "Unknown Linux")
    local kernel=$(uname -r | cut -d'-' -f1)
    # Force C locale for consistent output across all languages
    local ram_mb=$(LC_ALL=C free -m | awk '/^Mem:/{print $2}')
    # Ceiling division: round up RAM to nearest GB (avoid showing 0GB)
    local ram_gb=$(( (ram_mb + 1023) / 1024 ))
    [ $ram_gb -eq 0 ] && ram_gb=1  # Minimum 1GB display
    local wine_ver=$(wine --version 2>/dev/null | cut -d'-' -f2 || echo "not installed")
    
    echo "$distro|$kernel|${ram_gb}GB|$wine_ver"
}

function banner() {
    clear && echo ""
    
    # Check if terminal supports colors (fallback for dumb terminals)
    if [ -t 1 ] && [ "$TERM" != "dumb" ]; then
        # ANSI Color codes (using \033 for maximum compatibility)
        local C_RESET="\033[0m"
        local C_CYAN="\033[0;36;1m"
        local C_MAGENTA="\033[0;35;1m"
        local C_BLUE="\033[0;34;1m"
        local C_YELLOW="\033[0;33;1m"
        local C_WHITE="\033[0;37;1m"
        local C_GREEN="\033[0;32;1m"
        local C_GRAY="\033[0;37m"
    else
        # No colors for dumb terminals
        local C_RESET=""
        local C_CYAN=""
        local C_MAGENTA=""
        local C_BLUE=""
        local C_YELLOW=""
        local C_WHITE=""
        local C_GREEN=""
        local C_GRAY=""
    fi
    
    # Get system information
    local sys_info=$(get_system_info)
    local distro=$(echo "$sys_info" | cut -d'|' -f1)
    local kernel=$(echo "$sys_info" | cut -d'|' -f2)
    local ram=$(echo "$sys_info" | cut -d'|' -f3)
    local wine_ver=$(echo "$sys_info" | cut -d'|' -f4)
    
    # Dynamic copyright year (start year - current year)
    # Note: This fork started in 2025, so start_year is 2025 (not 2024 from original project)
    local start_year="2025"
    local current_year=$(date +%Y)
    local copyright="© ${start_year}-${current_year} benjarogit | GPL-3.0 License"
    
    # Define menu options based on language
    # Check internet status for menu display (check all connections except loopback)
    local internet_status=""
    if command -v nmcli &> /dev/null; then
        local active_connections=$(nmcli -t -f NAME,STATE connection show | grep ":activated" | cut -d: -f1 | grep -v "^lo$" | wc -l)
        if [ "$active_connections" -gt 0 ]; then
            internet_status="ON "
        else
            internet_status="OFF"
        fi
    fi
    
    if [ "$LANG_CODE" = "de" ]; then
        local opt1="1- Photoshop CC installieren"
        local opt2="2- Camera Raw v12 installieren"
        local opt3="3- System-Vorprüfung               (empfohlen)"
        local opt4="4- Fehlerbehebung                  (Troubleshoot)"
        local opt5="5- Wine konfigurieren              (winecfg)"
        local opt6="6- Photoshop deinstallieren"
        local opt7="7- Internet: ${internet_status}                    (Toggle)"
        local opt8="8- Sprache: Deutsch                (L)"
        local opt9="9- Beenden"
        local sys_label="System:"
    else
        local opt1="1- Install photoshop CC"
        local opt2="2- Install camera raw v12"
        local opt3="3- Pre-installation check          (recommended)"
        local opt4="4- Troubleshooting                 (Fix issues)"
        local opt5="5- configure wine                  (winecfg)"
        local opt6="6- uninstall photoshop"
        local opt7="7- Internet: ${internet_status}                    (Toggle)"
        local opt8="8- Language: English               (L)"
        local opt9="9- exit"
        local sys_label="System:"
    fi
    
    # Banner width for text padding
    local text_width=62
    
    # Add padding to options (with safety check for negative values)
    local pad1=$((text_width - ${#opt1})); [ $pad1 -lt 0 ] && pad1=0
    local pad2=$((text_width - ${#opt2})); [ $pad2 -lt 0 ] && pad2=0
    local pad3=$((text_width - ${#opt3})); [ $pad3 -lt 0 ] && pad3=0
    local pad4=$((text_width - ${#opt4})); [ $pad4 -lt 0 ] && pad4=0
    local pad5=$((text_width - ${#opt5})); [ $pad5 -lt 0 ] && pad5=0
    local pad6=$((text_width - ${#opt6})); [ $pad6 -lt 0 ] && pad6=0
    local pad7=$((text_width - ${#opt7})); [ $pad7 -lt 0 ] && pad7=0
    local pad8=$((text_width - ${#opt8})); [ $pad8 -lt 0 ] && pad8=0
    local pad9=$((text_width - ${#opt9})); [ $pad9 -lt 0 ] && pad9=0
    
    opt1="${opt1}$(printf '%*s' $pad1 '')"
    opt2="${opt2}$(printf '%*s' $pad2 '')"
    opt3="${opt3}$(printf '%*s' $pad3 '')"
    opt4="${opt4}$(printf '%*s' $pad4 '')"
    opt5="${opt5}$(printf '%*s' $pad5 '')"
    opt6="${opt6}$(printf '%*s' $pad6 '')"
    opt7="${opt7}$(printf '%*s' $pad7 '')"
    opt8="${opt8}$(printf '%*s' $pad8 '')"
    opt9="${opt9}$(printf '%*s' $pad9 '')"
    
    # System info line - width is 74 chars (75 from empty line - 1 for leading space in echo)
    local sys_info_width=74
    local sys_info_line="${sys_label} ${distro} | Kernel ${kernel} | RAM ${ram} | Wine ${wine_ver}"
    
    # Truncate distro if line is too long
    if [ ${#sys_info_line} -gt $sys_info_width ]; then
        local overflow=$((${#sys_info_line} - sys_info_width))
        local new_distro_len=$((${#distro} - overflow - 3))  # -3 for "..."
        
        # Only truncate if result would be shorter than original distro (avoid expanding short names)
        if [ $new_distro_len -gt 3 ] && [ $((new_distro_len + 3)) -lt ${#distro} ]; then
            distro="${distro:0:$new_distro_len}..."
            sys_info_line="${sys_label} ${distro} | Kernel ${kernel} | RAM ${ram} | Wine ${wine_ver}"
        fi
        # If distro is already very short, leave it unchanged - padding will be reduced to fit
    fi
    
    # Pad to exact 74 chars
    local sys_padding=$((sys_info_width - ${#sys_info_line}))
    [ $sys_padding -lt 0 ] && sys_padding=0
    sys_info_line="${sys_info_line}$(printf '%*s' $sys_padding '')"
    
    # Print colored banner with echo -e (bash/sh compatible)
    echo -e "${C_CYAN}                     ┏━━━━━━━━━━━━━━━━━━━━━━━━━┫ ${C_MAGENTA}Photoshop CC Installer${C_CYAN} ┣━━━━━━━━━━━━━━━━━━━━━━━━┓${C_RESET}"
    echo -e "${C_CYAN}                     ┃${C_RESET} ${C_GRAY}${sys_info_line}${C_CYAN}┃${C_RESET}"
    echo -e "${C_CYAN}                     ┃${C_RESET}                                                                           ${C_CYAN}┃${C_RESET}"
    echo -e "${C_BLUE}  ███████████████████████████${C_RESET}                                                                    ${C_CYAN}┃${C_RESET}"
    echo -e "${C_BLUE}  ██${C_RESET}                       ${C_BLUE}██${C_RESET}      ${C_YELLOW}${opt1}${C_CYAN}┃${C_RESET}"
    echo -e "${C_BLUE}  ██  ███████▆▃${C_RESET}            ${C_BLUE}██${C_RESET}      ${C_YELLOW}${opt2}${C_CYAN}┃${C_RESET}"
    echo -e "${C_BLUE}  ██  ███   ▝██▙${C_RESET}           ${C_BLUE}██${C_RESET}      ${C_GREEN}${opt3}${C_CYAN}┃${C_RESET}"
    echo -e "${C_BLUE}  ██  ███    ███${C_RESET}           ${C_BLUE}██${C_RESET}      ${C_GREEN}${opt4}${C_CYAN}┃${C_RESET}"
    echo -e "${C_BLUE}  ██  ███   ▟██▛▗▟████▙${C_RESET}    ${C_BLUE}██${C_RESET}      ${C_YELLOW}${opt5}${C_CYAN}┃${C_RESET}"
    echo -e "${C_BLUE}  ██  ███████▛  ██▋${C_RESET}        ${C_BLUE}██${C_RESET}      ${C_YELLOW}${opt6}${C_CYAN}┃${C_RESET}"
    echo -e "${C_BLUE}  ██  ███       ▝▜█████▙${C_RESET}   ${C_BLUE}██${C_RESET}      ${C_YELLOW}${opt7}${C_CYAN}┃${C_RESET}"
    echo -e "${C_BLUE}  ██  ███             ██▌${C_RESET}  ${C_BLUE}██${C_RESET}      ${C_YELLOW}${opt8}${C_CYAN}┃${C_RESET}"
    echo -e "${C_BLUE}  ██  ███        ▗▟████▛${C_RESET}   ${C_BLUE}██${C_RESET}                                                                    ${C_CYAN}┃${C_RESET}"
    echo -e "${C_BLUE}  ██${C_RESET}                       ${C_BLUE}██${C_RESET}      ${C_YELLOW}${opt9}${C_CYAN}┃${C_RESET}"
    echo -e "${C_BLUE}  ███████████████████████████${C_RESET}                                                                    ${C_CYAN}┃${C_RESET}"
    echo -e "${C_CYAN}                     ┃${C_RESET}                                                                           ${C_CYAN}┃${C_RESET}"
    echo -e "${C_CYAN}                     ┗━━━━━━━━━━━━━━━┫ ${C_WHITE}https://github.com/benjarogit/photoshopCClinux${C_CYAN} ┣━━━━━━━━━━┛${C_RESET}"
    echo -e "                     ${C_WHITE}${copyright}${C_RESET}"
    
    echo ""
}

function error() {
    echo -e "\033[1;31merror:\e[0m $@"
    exit 1
}

function warning() {
    echo -e "\033[1;33mWarning:\e[0m $@"
}

main



