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

# Detect system language (only if not already set by user)
detect_language() {
    # Skip detection if LANG_CODE is already set (e.g., by manual toggle)
    if [ -z "$LANG_CODE" ]; then
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

function main() {
    # Detect language
    detect_language
    
    #print banner
    banner

    #read inputs
    read_input
    let answer=$?

    case "$answer" in

    1)  
        msg_run_photoshop
        run_script "scripts/PhotoshopSetup.sh" "PhotoshopSetup.sh"
        ;;
    2)  
        msg_run_camera_raw
        run_script "scripts/cameraRawInstaller.sh" "cameraRawInstaller.sh"
        ;;
    3)  
        msg_pre_check
        run_script "pre-check.sh" "pre-check.sh"
        ;;
    4)  
        msg_troubleshoot
        run_script "troubleshoot.sh" "troubleshoot.sh"
        ;;
    5)  
        msg_run_winecfg
        run_script "scripts/winecfg.sh" "winecfg.sh"
        ;;
    6)  
        msg_uninstall
        run_script "scripts/uninstaller.sh" "uninstaller.sh"
        ;;
    7)  
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
    8)  
        msg_exit
        exitScript
        ;;
    esac
}

#argumaents 1=script_path 2=script_name 
function run_script() {
    local script_path=$1
    local script_name=$2

    wait_second 5
    if [ -f "$script_path" ];then
        msg_found "$script_path"
        chmod +x "$script_path"
    else
        msg_not_found "$script_name"
    fi
    cd "./scripts/" && bash $script_name
    unset script_path
}

function wait_second() {
    for (( i=0 ; i<$1 ; i++ ));do
        echo -n "."
        sleep 1
    done
    echo ""
}

function read_input() {
    while true ;do
        read -p "$(msg_choose_option)" choose
        if [[ "$choose" =~ (^[1-8]$) ]];then
            break
        fi
        if [ "$LANG_CODE" = "de" ]; then
            warning "Wähle eine Zahl zwischen 1 und 8"
        else
            warning "choose a number between 1 to 8"
        fi
    done

    return $choose
}

function exitScript() {
    msg_goodbye
}

function get_system_info() {
    # Get system information for display
    local distro=$(grep "^PRETTY_NAME" /etc/os-release 2>/dev/null | cut -d'"' -f2 || echo "Unknown Linux")
    local kernel=$(uname -r | cut -d'-' -f1)
    local ram_mb=$(free -m | awk '/^Mem:/{print $2}')
    local ram_gb=$((ram_mb / 1024))
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
    
    # Dynamic copyright year (current year)
    local current_year=$(date +%Y)
    local copyright="© ${current_year} benjarogit | GPL-3.0 License"
    
    # Define menu options based on language
    if [ "$LANG_CODE" = "de" ]; then
        local opt1="1- Photoshop CC installieren"
        local opt2="2- Camera Raw v12 installieren"
        local opt3="3- System-Vorprüfung               (empfohlen)"
        local opt4="4- Fehlerbehebung                  (Troubleshoot)"
        local opt5="5- Wine konfigurieren              (winecfg)"
        local opt6="6- Photoshop deinstallieren"
        local opt7="7- Sprache: Deutsch                (L)"
        local opt8="8- Beenden"
        local sys_label="System:"
    else
        local opt1="1- Install photoshop CC"
        local opt2="2- Install camera raw v12"
        local opt3="3- Pre-installation check          (recommended)"
        local opt4="4- Troubleshooting                 (Fix issues)"
        local opt5="5- configure wine                  (winecfg)"
        local opt6="6- uninstall photoshop"
        local opt7="7- Language: English               (L)"
        local opt8="8- exit"
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
    
    opt1="${opt1}$(printf '%*s' $pad1 '')"
    opt2="${opt2}$(printf '%*s' $pad2 '')"
    opt3="${opt3}$(printf '%*s' $pad3 '')"
    opt4="${opt4}$(printf '%*s' $pad4 '')"
    opt5="${opt5}$(printf '%*s' $pad5 '')"
    opt6="${opt6}$(printf '%*s' $pad6 '')"
    opt7="${opt7}$(printf '%*s' $pad7 '')"
    opt8="${opt8}$(printf '%*s' $pad8 '')"
    
    # System info line (truncate distro if too long)
    local max_distro_len=30
    if [ ${#distro} -gt $max_distro_len ]; then
        distro="${distro:0:$max_distro_len}..."
    fi
    local sys_info_line="${sys_label} ${distro} | Kernel ${kernel} | RAM ${ram} | Wine ${wine_ver}"
    local sys_info_len=${#sys_info_line}
    local sys_padding=$((75 - sys_info_len))
    if [ $sys_padding -lt 0 ]; then sys_padding=0; fi
    sys_info_line="${sys_info_line}$(printf '%*s' $sys_padding '')"
    
    # Print colored banner with echo -e (bash/sh compatible)
    echo -e "${C_CYAN}                     ┏━━━━━━━━━━━━━━━━━━━━━━━━━┫ ${C_MAGENTA}Photoshop CC Installer${C_CYAN} ┣━━━━━━━━━━━━━━━━━━━━━━━━┓${C_RESET}"
    echo -e "${C_CYAN}                     ┃${C_RESET} ${C_GRAY}${sys_info_line}${C_CYAN}┃${C_RESET}"
    echo -e "${C_CYAN}                     ┃${C_RESET}                                                                           ${C_CYAN}┃${C_RESET}"
    echo -e "${C_BLUE}  ███████████████████████████${C_RESET}                                                                    ${C_CYAN}┃${C_RESET}"
    echo -e "${C_BLUE}  ██${C_RESET}                       ${C_BLUE}██${C_RESET}      ${C_YELLOW}${opt1}${C_CYAN}┃${C_RESET}"
    echo -e "${C_BLUE}  ██  ███████▆▃${C_RESET}            ${C_BLUE}██${C_RESET}      ${C_YELLOW}${opt2}${C_CYAN}┃${C_RESET}"
    echo -e "${C_BLUE}  ██  ███   ▝██▙${C_RESET}           ${C_BLUE}██${C_RESET}                                                                    ${C_CYAN}┃${C_RESET}"
    echo -e "${C_BLUE}  ██  ███    ███${C_RESET}           ${C_BLUE}██${C_RESET}      ${C_GREEN}${opt3}${C_CYAN}┃${C_RESET}"
    echo -e "${C_BLUE}  ██  ███   ▟██▛▗▟████▙${C_RESET}    ${C_BLUE}██${C_RESET}      ${C_GREEN}${opt4}${C_CYAN}┃${C_RESET}"
    echo -e "${C_BLUE}  ██  ███████▛  ██▋${C_RESET}        ${C_BLUE}██${C_RESET}                                                                    ${C_CYAN}┃${C_RESET}"
    echo -e "${C_BLUE}  ██  ███       ▝▜█████▙${C_RESET}   ${C_BLUE}██${C_RESET}      ${C_YELLOW}${opt5}${C_CYAN}┃${C_RESET}"
    echo -e "${C_BLUE}  ██  ███             ██▌${C_RESET}  ${C_BLUE}██${C_RESET}      ${C_YELLOW}${opt6}${C_CYAN}┃${C_RESET}"
    echo -e "${C_BLUE}  ██  ███        ▗▟████▛${C_RESET}   ${C_BLUE}██${C_RESET}                                                                    ${C_CYAN}┃${C_RESET}"
    echo -e "${C_BLUE}  ██${C_RESET}                       ${C_BLUE}██${C_RESET}      ${C_YELLOW}${opt7}${C_CYAN}┃${C_RESET}"
    echo -e "${C_BLUE}  ███████████████████████████${C_RESET}      ${C_YELLOW}${opt8}${C_CYAN}┃${C_RESET}"
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
