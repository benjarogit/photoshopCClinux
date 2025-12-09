#!/usr/bin/env bash
################################################################################
# Photoshop CC Linux - Shared Functions Library
#
# Description:
#   Common utility functions used across all installer scripts including
#   package detection, path management, progress indicators, and notifications.
#
# Author:       benjarogit
# Repository:   https://github.com/benjarogit/photoshopCClinux
# License:      GPL-3.0
# Copyright:    (c) 2024 benjarogit
#
# Based on:     photoshopCClinux by Gictorbit
#               https://github.com/Gictorbit/photoshopCClinux
################################################################################

# CRITICAL: Robust error handling (if not already set)
if [ "${BASH_SET_EUO:-}" != "set" ]; then
    set -eu
    (set -o pipefail 2>/dev/null) || true
    export BASH_SET_EUO="set"
fi

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

#has tow mode [pkgName] [mode=summary]
function package_installed() {
    # CRITICAL: command -v instead of which (POSIX-compliant, safer)
    # CRITICAL: "$1" quoted against command injection
    if command -v "$1" >/dev/null 2>&1; then
        local pkginstalled=0
    else
        local pkginstalled=1
    fi

    # CRITICAL: == is not POSIX, use =
    # CRITICAL: $2 is optional, therefore use ${2:-}
    if [ "${2:-}" = "summary" ];then
        if [ "$pkginstalled" -eq 0 ];then
            echo "true"
        else
            echo "false"
        fi
    else    
        if [ "$pkginstalled" -eq 0 ];then
            show_message "package\033[1;36m $1\e[0m is installed..."
        else
            warning "package\033[1;33m $1\e[0m is not installed.\nplease make sure it's already installed"
            ask_question "would you continue?" "N"
            if [ "$question_result" = "no" ];then
                echo "exit..."
                exit 5
            fi
        fi
    fi
}

# Get main log file if available (from PhotoshopSetup.sh)
get_main_log() {
    # Try to find the main log file from environment or project root
    if [ -n "${LOG_FILE:-}" ]; then
        echo "${LOG_FILE}"
    elif [ -n "${PROJECT_ROOT:-}" ] && [ -d "${PROJECT_ROOT}/logs" ]; then
        # Find the most recent log file
        ls -t "${PROJECT_ROOT}/logs"/*.log 2>/dev/null | head -1 || echo ""
    else
        echo ""
    fi
}

function setup_log() {
    local main_log=$(get_main_log)
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Log to main log if available
    if [ -n "${main_log:-}" ] && [ -f "${main_log}" ]; then
        echo "[$timestamp] $@" >> "${main_log}"
    fi
    
    # Also log to new LOG_FILE if available (from PhotoshopSetup.sh)
    if [ -n "${LOG_FILE:-}" ] && [ -f "${LOG_FILE:-}" ]; then
        echo "[$timestamp] $@" >> "${LOG_FILE}" 2>/dev/null || true
    fi
    
    # Also log to old location for compatibility (only if SCR_PATH is set and directory exists)
    if [ -n "${SCR_PATH:-}" ] && [ -d "${SCR_PATH:-}" ]; then
        echo -e "$(date) : $@" >> "${SCR_PATH}/setuplog.log" 2>/dev/null || true
    fi
}

function show_message() {
    local main_log=$(get_main_log)
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Log to main log file if available
    if [ -n "${main_log:-}" ] && [ -f "${main_log}" ]; then
        echo "[$timestamp] $@" >> "${main_log}"
    fi
    
    # Also log to new LOG_FILE if available (from PhotoshopSetup.sh)
    if [ -n "${LOG_FILE:-}" ] && [ -f "${LOG_FILE:-}" ]; then
        echo "[$timestamp] $@" >> "${LOG_FILE}"
    fi
    
    # Also log to old setuplog.log for compatibility
    if [ -n "${SCR_PATH:-}" ] && [ -d "${SCR_PATH:-}" ]; then
        echo -e "$(date) : $@" >> "${SCR_PATH}/setuplog.log" 2>/dev/null || true
    fi
    
    echo -e "$@"
    
    # Log to main log if available
    if [ -n "${main_log:-}" ] && [ -f "${main_log}" ]; then
        echo "[$timestamp] $@" >> "${main_log}"
    fi
    
    # Also log to old location for compatibility
    setup_log "$@"
}

function error() {
    local main_log=$(get_main_log)
    local error_log=""
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Try to find error log
    if [ -n "$ERROR_LOG" ]; then
        error_log="$ERROR_LOG"
    elif [ -n "$PROJECT_ROOT" ] && [ -d "$PROJECT_ROOT/logs" ]; then
        error_log=$(ls -t "$PROJECT_ROOT/logs"/*_errors.log 2>/dev/null | head -1 || echo "")
    fi
    
    echo -e "\033[1;31merror:\e[0m $@"
    
    # Log to main log if available
    if [ -n "$main_log" ] && [ -f "$main_log" ]; then
        echo "[$timestamp] ERROR: $@" >> "$main_log"
    fi
    
    # Log to error log if available
    if [ -n "$error_log" ] && [ -f "$error_log" ]; then
        echo "[$timestamp] ERROR: $@" >> "$error_log"
    fi
    
    setup_log "$@"
    exit 1
}

function error2() {
    local main_log=$(get_main_log)
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo -e "\033[1;31merror:\e[0m $@"
    
    # Log to main log if available
    if [ -n "$main_log" ] && [ -f "$main_log" ]; then
        echo "[$timestamp] ERROR: $@" >> "$main_log"
    fi
    
    exit 1
}

function warning() {
    local main_log=$(get_main_log)
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo -e "\033[1;33mWarning:\e[0m $@"
    
    # Log to main log if available
    if [ -n "$main_log" ] && [ -f "$main_log" ]; then
        echo "[$timestamp] WARNING: $@" >> "$main_log"
    fi
    
    setup_log "$@"
}

function warning2() {
    local main_log=$(get_main_log)
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo -e "\033[1;33mWarning:\e[0m $@"
    
    # Log to main log if available
    if [ -n "$main_log" ] && [ -f "$main_log" ]; then
        echo "[$timestamp] WARNING: $@" >> "$main_log"
    fi
}

function show_message2() {
    local main_log=$(get_main_log)
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo -e "$@"
    
    # Log to main log if available
    if [ -n "${main_log:-}" ] && [ -f "${main_log}" ]; then
        echo "[$timestamp] $@" >> "${main_log}"
    fi
}

function launcher() {
    
    #create launcher script
    # KRITISCH: SCRIPT_DIR sollte von aufrufendem Script exportiert werden
    # Fallback: Versuche es selbst zu ermitteln
    if [ -z "${SCRIPT_DIR:-}" ]; then
        # Versuche über BASH_SOURCE (wenn von PhotoshopSetup.sh aufgerufen)
        local caller_script="${BASH_SOURCE[1]:-}"
        if [ -n "$caller_script" ] && [ -f "$caller_script" ]; then
            SCRIPT_DIR="$(cd "$(dirname "$caller_script")" && pwd)" 2>/dev/null || true
        fi
        # Letzter Fallback: Versuche scripts/ Verzeichnis relativ zu SCR_PATH zu finden
        if [ -z "${SCRIPT_DIR:-}" ] && [ -n "${SCR_PATH:-}" ]; then
            # SCR_PATH ist normalerweise ~/.photoshopCCV19, Projekt ist ein Verzeichnis darüber
            local possible_script_dir="$(dirname "$(dirname "$SCR_PATH")")/scripts" 2>/dev/null || true
            if [ -d "$possible_script_dir" ] && [ -f "$possible_script_dir/launcher.sh" ]; then
                SCRIPT_DIR="$possible_script_dir"
            fi
        fi
    fi
    
    # KRITISCH: Prüfe ob SCRIPT_DIR gesetzt ist
    if [ -z "${SCRIPT_DIR:-}" ]; then
        error "SCRIPT_DIR ist nicht gesetzt - kann launcher.sh nicht finden"
        return 1
    fi
    
    # KRITISCH: Verwende SCRIPT_DIR statt PWD (PWD kann falsch sein)
    local launcher_path="$SCRIPT_DIR/launcher.sh"
    local launcher_dest="$SCR_PATH/launcher"
    rmdir_if_exist "$launcher_dest"
    mkdir -p "$launcher_dest" || error "can't create launcher directory"

    if [ -f "$launcher_path" ]; then
        show_message "launcher.sh detected..."
        
        cp "$launcher_path" "$launcher_dest" || error "can't copy launcher"
        
        # Copy sharedFuncs.sh to launcher directory so launcher.sh can source it
        local shared_funcs_path="$SCRIPT_DIR/sharedFuncs.sh"
        if [ -f "$shared_funcs_path" ]; then
            cp "$shared_funcs_path" "$launcher_dest" || error "can't copy sharedFuncs.sh"
        else
            error "sharedFuncs.sh Not Found"
        fi
        
        chmod +x "$SCR_PATH/launcher/launcher.sh" || error "can't chmod launcher script"
    else
        error "launcher.sh Not Found"
    fi

    #create desktop entry
    # CRITICAL: Use SCRIPT_DIR instead of PWD (PWD can be wrong)
    local desktop_entry="$SCRIPT_DIR/photoshop.desktop"
    local desktop_entry_dest="$HOME/.local/share/applications/photoshop.desktop"
    
    if [ -f "$desktop_entry" ];then
        show_message "desktop entry detected..."
       
        #delete desktop entry if exists
        if [ -f "$desktop_entry_dest" ];then
            show_message "desktop entry exist deleted..."
            rm "$desktop_entry_dest"
        fi
        cp "$desktop_entry" "$desktop_entry_dest" || error "can't copy desktop entry"
        
        # Replace pspath placeholder in desktop entry
        # CRITICAL: sed -i GNU/BusyBox compatibility
        # CRITICAL: Use absolute path and remove "bash" (script is executable)
        local launcher_script_path="$SCR_PATH/launcher/launcher.sh"
        if sed -i '' "s|bash pspath/launcher/launcher.sh|$launcher_script_path|g" "$desktop_entry_dest" 2>/dev/null; then
            : # GNU sed (kein Backup)
        elif sed -i.bak "s|bash pspath/launcher/launcher.sh|$launcher_script_path|g" "$desktop_entry_dest" 2>/dev/null; then
            rm -f "${desktop_entry_dest}.bak" 2>/dev/null || true
        else
            # KRITISCH: mktemp statt vorhersagbarem .tmp (Symlink-Angriff verhindern)
            local tmp_file
            tmp_file=$(mktemp "${desktop_entry_dest}.XXXXXX" 2>/dev/null) || {
                error "mktemp failed for desktop entry"
                return 1
            }
            # KRITISCH: TOCTOU-Schutz - prüfe dass tmp_file keine Symlink ist
            if [ -L "$tmp_file" ]; then
                rm -f "$tmp_file"
                error "Temporäre Datei ist Symlink (Sicherheitsrisiko)"
                return 1
            fi
            # KRITISCH: Cleanup bei allen Signalen (nicht nur EXIT) - verhindere Race-Conditions
            # Verwende Funktion statt String für trap (sicherer)
            trap "rm -f '$tmp_file' 2>/dev/null || true" EXIT INT TERM HUP
            # KRITISCH: Escaping für sed
            local escaped_path
            escaped_path=$(printf '%s\n' "$SCR_PATH" | sed 's/[[\.*^$()+?{|]/\\&/g; s|/|\\/|g')
            sed "s|bash pspath/launcher/launcher.sh|$launcher_script_path|g" "$desktop_entry_dest" > "$tmp_file" || {
                rm -f "$tmp_file"
                error "can't edit desktop entry"
                return 1
            }
            # CRITICAL: install instead of mv (atomic)
            install -m "$(stat -c '%a' "$desktop_entry_dest" 2>/dev/null || echo 644)" "$tmp_file" "$desktop_entry_dest" 2>/dev/null || {
                if [ -f "$tmp_file" ] && [ ! -L "$tmp_file" ]; then
                    mv "$tmp_file" "$desktop_entry_dest" || {
                        rm -f "$tmp_file"
                        error "can't edit desktop entry"
                        return 1
                    }
                else
                    rm -f "$tmp_file"
                    error "can't edit desktop entry"
                    return 1
                fi
            }
            rm -f "$tmp_file" 2>/dev/null || true
        fi
        
        # Mache Desktop-Entry ausführbar
        chmod +x "$desktop_entry_dest" || warning "can't make desktop entry executable"
    else
        error "desktop entry Not Found"
    fi

    #change photoshop icon of desktop entry
    local entry_icon="../images/AdobePhotoshop-icon.png"
    local launch_icon="$launcher_dest/AdobePhotoshop-icon.png"

    if [ -f "$entry_icon" ]; then
        cp "$entry_icon" "$launcher_dest" || error "can't copy icon image"
        # CRITICAL: sed -i GNU/BusyBox compatibility + security
        # CRITICAL: Escaping for sed pattern/replacement
        sed_escape() {
            # Escape sed-spezielle Zeichen: / \ & . * ^ $ ( ) + ? { | [ ]
            printf '%s\n' "$1" | sed 's/[[\.*^$()+?{|]/\\&/g; s|/|\\/|g'
        }
        
        safe_sed_replace() {
            local file="$1" pattern="$2" replacement="$3"
            local escaped_pattern escaped_replacement
            
            # KRITISCH: Escape Pattern und Replacement
            escaped_pattern=$(sed_escape "$pattern")
            escaped_replacement=$(sed_escape "$replacement")
            
            # Versuche sed -i (GNU/BusyBox)
            if sed -i '' "s|$escaped_pattern|$escaped_replacement|g" "$file" 2>/dev/null; then
                : # GNU sed (kein Backup)
            elif sed -i.bak "s|$escaped_pattern|$escaped_replacement|g" "$file" 2>/dev/null; then
                rm -f "${file}.bak" 2>/dev/null || true
            else
                # KRITISCH: mktemp statt vorhersagbarem .tmp (Symlink-Angriff verhindern)
                local tmp_file
                tmp_file=$(mktemp "${file}.XXXXXX" 2>/dev/null) || {
                    error "mktemp failed for $file"
                    return 1
                }
                # KRITISCH: TOCTOU-Schutz: Prüfe dass tmp_file keine Symlink ist
                if [ -L "$tmp_file" ]; then
                    rm -f "$tmp_file"
                    error "Temporäre Datei ist Symlink (Sicherheitsrisiko)"
                    return 1
                fi
                # KRITISCH: Cleanup bei allen Signalen (nicht nur EXIT) - verhindere Race-Conditions
                local cleanup_tmp="rm -f '$tmp_file' 2>/dev/null || true"
                trap "$cleanup_tmp" EXIT INT TERM HUP
                sed "s|$escaped_pattern|$escaped_replacement|g" "$file" > "$tmp_file" || {
                    rm -f "$tmp_file"
                    return 1
                }
                # CRITICAL: install instead of mv (atomic on many filesystems)
                install -m "$(stat -c '%a' "$file" 2>/dev/null || echo 644)" "$tmp_file" "$file" 2>/dev/null || {
                    # Fallback zu mv mit Prüfung
                    if [ -f "$tmp_file" ] && [ ! -L "$tmp_file" ]; then
                        mv "$tmp_file" "$file" || {
                            rm -f "$tmp_file"
                            return 1
                        }
                    else
                        rm -f "$tmp_file"
                        return 1
                    fi
                }
                rm -f "$tmp_file" 2>/dev/null || true
            fi
        }
        safe_sed_replace "$desktop_entry_dest" "photoshopicon" "$launch_icon" || error "can't edit desktop entry"
        safe_sed_replace "$launcher_dest/launcher.sh" "photoshopicon" "$launch_icon" || error "can't edit launcher script"
    else
        warning "Icon not found, using default icon"
    fi
    
    # WINAPPS-TECHNIK: MIME-Type Registrierung für "Öffnen mit Photoshop"
    # Erstelle MIME-Type Definition für Photoshop-Dateien
    # KRITISCH: Umgebungsvariablen-Validierung - prüfe dass $HOME sicher ist
    if [ -z "$HOME" ] || [ "$HOME" = "/" ] || [ "$HOME" = "/root" ]; then
        warning "Unsichere HOME-Umgebungsvariable, überspringe MIME-Type Registrierung"
        return 0
    fi
    local mime_dir="$HOME/.local/share/mime/packages"
    mkdir -p "$mime_dir" 2>/dev/null || true
    
    if [ -d "$mime_dir" ]; then
        local mime_file="$mime_dir/photoshop.xml"
        # Use absolute path for icon (launch_icon is set earlier in the function)
        local icon_path="$launch_icon"
        if [ ! -f "$icon_path" ]; then
            # Fallback: try to find icon in launcher directory
            icon_path="$launcher_dest/AdobePhotoshop-icon.png"
        fi
        
        # Create MIME-Type XML with absolute icon path
        cat > "$mime_file" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
  <mime-type type="image/vnd.adobe.photoshop">
    <comment>Adobe Photoshop Document</comment>
    <comment xml:lang="de">Adobe Photoshop Dokument</comment>
    <glob pattern="*.psd"/>
    <glob pattern="*.PSD"/>
    <icon>$icon_path</icon>
  </mime-type>
  <mime-type type="image/x-photoshop">
    <comment>Adobe Photoshop Document</comment>
    <comment xml:lang="de">Adobe Photoshop Dokument</comment>
    <glob pattern="*.psd"/>
    <glob pattern="*.psb"/>
    <glob pattern="*.PSD"/>
    <glob pattern="*.PSB"/>
    <icon>$icon_path</icon>
  </mime-type>
  <mime-type type="application/x-photoshop">
    <comment>Adobe Photoshop Document</comment>
    <comment xml:lang="de">Adobe Photoshop Dokument</comment>
    <glob pattern="*.psd"/>
    <glob pattern="*.psb"/>
    <glob pattern="*.PSD"/>
    <glob pattern="*.PSB"/>
    <icon>$icon_path</icon>
  </mime-type>
</mime-info>
EOF
        # Aktualisiere MIME-Datenbank
        if command -v update-desktop-database &>/dev/null; then
            update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
        fi
        if command -v update-mime-database &>/dev/null; then
            update-mime-database "$HOME/.local/share/mime" 2>/dev/null || true
        fi
        show_message "MIME-Type Registrierung erstellt (PSD/PSB Dateien können mit Photoshop geöffnet werden)"
    fi
    
    #create photoshop command
    show_message "create photoshop command..."
    # CRITICAL: Validation BEFORE sudo operation - prevent privilege escalation
    if [[ "$SCR_PATH" =~ ^/etc|^/usr/bin|^/usr/sbin|^/bin|^/sbin|^/lib|^/var/log|^/root ]]; then
        error "SCR_PATH zeigt auf System-Verzeichnis (Sicherheitsrisiko): $SCR_PATH"
        return 1
    fi
    if [ ! -f "$SCR_PATH/launcher/launcher.sh" ]; then
        error "Launcher-Script nicht gefunden: $SCR_PATH/launcher/launcher.sh"
        return 1
    fi
    if [ -f "/usr/local/bin/photoshop" ];then
        show_message "photoshop command exist deleted..."
        sudo rm "/usr/local/bin/photoshop"
    fi
    sudo ln -s "$SCR_PATH/launcher/launcher.sh" "/usr/local/bin/photoshop" || error "can't create photoshop command"
    
    show_message "\033[1;32mLauncher erstellt! Du kannst Photoshop starten mit:\e[0m"
    show_message "\033[1;36m  - Befehl: photoshop\e[0m"
    show_message "\033[1;36m  - Desktop-Menü: Suche nach 'Photoshop'\e[0m"
    show_message "\033[1;36m  - Direkt: $SCR_PATH/launcher/launcher.sh\e[0m"

    unset desktop_entry desktop_entry_dest launcher_path launcher_dest
}

function set_dark_mod() {
    echo " " >> "$WINE_PREFIX/user.reg"
    local colorarray=(
        '[Control Panel\\Colors] 1491939580'
        '#time=1d2b2fb5c69191c'
        '"ActiveBorder"="49 54 58"'
        '"ActiveTitle"="49 54 58"'
        '"AppWorkSpace"="60 64 72"'
        '"Background"="49 54 58"'
        '"ButtonAlternativeFace"="200 0 0"'
        '"ButtonDkShadow"="154 154 154"'
        '"ButtonFace"="49 54 58"'
        '"ButtonHilight"="119 126 140"'
        '"ButtonLight"="60 64 72"'
        '"ButtonShadow"="60 64 72"'
        '"ButtonText"="219 220 222"'
        '"GradientActiveTitle"="49 54 58"'
        '"GradientInactiveTitle"="49 54 58"'
        '"GrayText"="155 155 155"'
        '"Hilight"="119 126 140"'
        '"HilightText"="255 255 255"'
        '"InactiveBorder"="49 54 58"'
        '"InactiveTitle"="49 54 58"'
        '"InactiveTitleText"="219 220 222"'
        '"InfoText"="159 167 180"'
        '"InfoWindow"="49 54 58"'
        '"Menu"="49 54 58"'
        '"MenuBar"="49 54 58"'
        '"MenuHilight"="119 126 140"'
        '"MenuText"="219 220 222"'
        '"Scrollbar"="73 78 88"'
        '"TitleText"="219 220 222"'
        '"Window"="35 38 41"'
        '"WindowFrame"="49 54 58"'
        '"WindowText"="219 220 222"'
    )
    for i in "${colorarray[@]}";do
        echo "$i" >> "$WINE_PREFIX/user.reg"
    done
    show_message "set dark mode for wine..." 
    unset colorarray
}

function export_var() {
    # CRITICAL: WINEPREFIX validation - prevent manipulation
    if [[ "$WINE_PREFIX" =~ ^/etc|^/usr/bin|^/usr/sbin|^/bin|^/sbin|^/lib|^/var/log|^/root ]]; then
        error "WINEPREFIX zeigt auf System-Verzeichnis (Sicherheitsrisiko): $WINE_PREFIX"
        return 1
    fi
    export WINEPREFIX="$WINE_PREFIX"
    show_message "wine variables exported..."
}

#parameters is [PATH] [CheckSum] [URL] [FILE NAME]
function download_component() {
    local tout=0
    local url="$3"
    
    # CRITICAL: Download URL validation - prevent malicious URLs
    # Whitelist: Nur erlaubte Domains
    local allowed_domains=(
        "github.com"
        "githubusercontent.com"
        "sourceforge.net"
        "microsoft.com"
        "adobe.com"
    )
    
    # Prüfe dass URL mit https:// beginnt (HTTPS-Erzwingung)
    if [[ ! "$url" =~ ^https:// ]]; then
        error "Download URL must use HTTPS (security risk): $url"
        return 1
    fi
    
    # Prüfe dass URL von erlaubter Domain stammt
    local url_domain=$(echo "$url" | sed -E 's|^https?://([^/]+).*|\1|' | sed 's|^www\.||')
    local domain_allowed=0
    for domain in "${allowed_domains[@]}"; do
        if [[ "$url_domain" == "$domain" ]] || [[ "$url_domain" == *".$domain" ]]; then
            domain_allowed=1
            break
        fi
    done
    
    if [ $domain_allowed -eq 0 ]; then
        error "Download-URL von nicht erlaubter Domain (Sicherheitsrisiko): $url_domain"
        return 1
    fi
    
    while true;do
        if [ $tout -ge 3 ];then
            error "sorry something went wrong during download $4"
        fi
        if [ -f $1 ];then
            local FILE_ID=$(md5sum $1 | cut -d" " -f1)
            if [ "$FILE_ID" = "${2:-}" ];then
                show_message "\033[1;36m$4\e[0m detected"
                return 0
            else
                show_message "md5 is not match"
                rm $1 
            fi
        else   
            show_message "downloading $4 ..."
            ariapkg=$(package_installed aria2c "summary")
            curlpkg=$(package_installed curl "summary")
            
            if [ "$ariapkg" = "true" ];then
                show_message "using aria2c to download $4"
                aria2c -c -x 8 -d "$CACHE_PATH" -o $4 "$url"
                
                if [ $? -eq 0 ];then
                    notify-send "Photoshop CC" "$4 download completed" -i "download"
                fi

            elif [ "$curlpkg" = "true" ];then
                show_message "using curl to download $4"
                curl "$url" -o $1
            else
                show_message "using wget to download $4"
                wget "$url" -P "$CACHE_PATH"
                
                if [ $? -eq 0 ];then
                    notify-send "Photoshop CC" "$4 download completed" -i "download"
                fi
            fi
            ((tout++))
        fi
    done
}

function rmdir_if_exist() {
    # CRITICAL: Safe rm -rf with validation
    local dir="$1"
    if [ -z "$dir" ]; then
        error "rmdir_if_exist: Verzeichnisname ist leer"
        return 1
    fi
    if [ "$dir" = "/" ]; then
        error "rmdir_if_exist: Verzeichnis ist root (Sicherheit)"
        return 1
    fi
    if [ -d "$dir" ]; then
        rm -rf "$dir" || { error "rmdir_if_exist: Löschen fehlgeschlagen: $dir"; return 1; }
        show_message "\033[0;36m$dir\e[0m directory exists deleting it..."
    fi
    mkdir -p "$dir" || { error "rmdir_if_exist: Erstellen fehlgeschlagen: $dir"; return 1; }
    show_message "create\033[0;36m $dir\e[0m directory..."
}

function check_arg() {
    # Initialize variables before use (required for set -u)
    local dashd=0
    local dashc=0
    
    while getopts "hd:c:" OPTION; do
        case $OPTION in
        d)
            PARAMd="$OPTARG"
            SCR_PATH=$(readlink -f "$PARAMd")
            
            dashd=1
            echo "install path is $SCR_PATH"
            setup_log "install path is $SCR_PATH"
            ;;
        c)
            PARAMc="$OPTARG"
            CACHE_PATH=$(readlink -f "$PARAMc")
            dashc=1
            echo "cahce is $CACHE_PATH"
            setup_log "cache is $CACHE_PATH"
            ;;
        h)
            usage
            ;; 
        *)
            echo "wrong argument"
            exit 1
            ;;
        esac
    done
    shift $(($OPTIND - 1))

    if [[ $# != 0 ]];then
        usage
        error2 "unknown argument"
    fi

    if [[ $dashd != 1 ]] ;then
        echo "-d not define default directory used..."
        setup_log "-d not define default directory used..."
        # KRITISCH: Umgebungsvariablen-Validierung - prüfe dass $HOME sicher ist
        if [ -z "$HOME" ] || [ "$HOME" = "/" ] || [ "$HOME" = "/root" ]; then
            error "Unsichere HOME-Umgebungsvariable: ${HOME:-not set}"
            exit 1
        fi
        SCR_PATH="$HOME/.photoshopCCV19"
    fi

    if [[ $dashc != 1 ]];then
        echo "-c not define default directory used..."
        setup_log "-c not define default directory used..."
        # KRITISCH: Umgebungsvariablen-Validierung - prüfe dass $HOME sicher ist
        if [ -z "$HOME" ] || [ "$HOME" = "/" ] || [ "$HOME" = "/root" ]; then
            error "Unsichere HOME-Umgebungsvariable: ${HOME:-not set}"
            exit 1
        fi
        CACHE_PATH="$HOME/.cache/photoshopCCV19"
    fi
}

function is64() {
    local arch=$(uname -m)
    if [ $arch != "x86_64"  ];then
        warning "your distro is not 64 bit"
        read -r -p "Would you continue? [N/y] " response
        if [[ ! "$response" =~ ^([yY][eE][sS]|[yY])$ ]];then
           echo "Good Bye!"
           exit 0
        fi
    fi
   show_message "is64 checked..."
}

#parameters [Message] [default flag [Y/N]]
function ask_question() {
    question_result=""
    # KRITISCH: == ist nicht POSIX, verwende =
    # KRITISCH: read -r mit IFS= für Whitespace-Sicherheit
    # KRITISCH: IFS zurücksetzen nach read
    # KRITISCH: $2 ist optional, daher ${2:-} verwenden
    local old_IFS="${IFS:-}"
    if [ "${2:-}" = "Y" ];then
        IFS= read -r -p "$1 [Y/n] " response
        # KRITISCH: locale yesexpr/noexpr kann fehlen, Fallback
        if locale noexpr >/dev/null 2>&1 && [[ "$response" =~ $(locale noexpr) ]];then
            question_result="no"
        elif [ -n "$response" ] && [[ "$response" =~ ^[Nn] ]]; then
            question_result="no"
        else
            question_result="yes"
        fi
    elif [ "${2:-}" = "N" ];then
        IFS= read -r -p "$1 [N/y] " response
        if locale yesexpr >/dev/null 2>&1 && [[ "$response" =~ $(locale yesexpr) ]];then
            question_result="yes"
        elif [ -n "$response" ] && [[ "$response" =~ ^[Yy] ]]; then
            question_result="yes"
        else
            question_result="no"
        fi
    fi
    # KRITISCH: IFS zurücksetzen
    IFS="$old_IFS"
}

function usage() {
    echo "USAGE: [-c cache directory] [-d installation directory]"
}

function save_paths() {
    # KRITISCH: Validierung BEVOR Speicherung - verhindere Privilege-Escalation
    # Prüfe dass Pfade nicht auf System-Verzeichnisse zeigen
    if [[ "$SCR_PATH" =~ ^/etc|^/usr/bin|^/usr/sbin|^/bin|^/sbin|^/lib|^/var/log|^/root ]]; then
        error "SCR_PATH zeigt auf System-Verzeichnis (Sicherheitsrisiko): $SCR_PATH"
        return 1
    fi
    
    if [[ "$CACHE_PATH" =~ ^/etc|^/usr/bin|^/usr/sbin|^/bin|^/sbin|^/lib|^/var/log|^/root ]]; then
        error "CACHE_PATH zeigt auf System-Verzeichnis (Sicherheitsrisiko): $CACHE_PATH"
        return 1
    fi
    
    # Prüfe dass Pfade nicht leer sind
    if [ -z "$SCR_PATH" ]; then
        error "SCR_PATH ist leer (Sicherheitsrisiko)"
        return 1
    fi
    
    if [ -z "$CACHE_PATH" ]; then
        error "CACHE_PATH ist leer (Sicherheitsrisiko)"
        return 1
    fi
    
    # KRITISCH: Umgebungsvariablen-Validierung - prüfe dass $HOME sicher ist
    if [ -z "$HOME" ] || [ "$HOME" = "/" ] || [ "$HOME" = "/root" ]; then
        error "Unsichere HOME-Umgebungsvariable: ${HOME:-not set}"
        return 1
    fi
    
    local datafile="$HOME/.psdata.txt"
    echo "$SCR_PATH" > "$datafile"
    echo "$CACHE_PATH" >> "$datafile"
    unset datafile
}

function load_paths() {
    local skip_validation="${1:-false}"  # Optional parameter: skip directory validation
    local datafile="$HOME/.psdata.txt"
    
    # Validate datafile exists and is readable
    if [ ! -f "$datafile" ]; then
        echo "ERROR: Installation data file not found: $datafile"
        if [ "$skip_validation" = "false" ]; then
            echo "Please reinstall Photoshop CC using setup.sh"
            exit 1
        else
            # For uninstaller: set empty paths and continue
            SCR_PATH=""
            CACHE_PATH=""
            return 0
        fi
    fi
    
    if [ ! -r "$datafile" ]; then
        echo "ERROR: Cannot read installation data file: $datafile"
        if [ "$skip_validation" = "false" ]; then
            echo "Please check file permissions"
            exit 1
        else
            # For uninstaller: set empty paths and continue
            SCR_PATH=""
            CACHE_PATH=""
            return 0
        fi
    fi
    
    # Load paths and validate they are not empty
    SCR_PATH=$(head -n 1 "$datafile" 2>/dev/null)
    CACHE_PATH=$(tail -n 1 "$datafile" 2>/dev/null)
    
    if [ -z "$SCR_PATH" ]; then
        echo "ERROR: Installation path (SCR_PATH) is empty or corrupted in $datafile"
        if [ "$skip_validation" = "false" ]; then
            echo "Please reinstall Photoshop CC using setup.sh"
            exit 1
        fi
    fi
    
    if [ -z "$CACHE_PATH" ]; then
        echo "ERROR: Cache path (CACHE_PATH) is empty or corrupted in $datafile"
        if [ "$skip_validation" = "false" ]; then
            echo "Please reinstall Photoshop CC using setup.sh"
            exit 1
        fi
    fi
    
    # KRITISCH: Pfad-Sicherheitsprüfung - verhindere Privilege-Escalation
    # Prüfe dass Pfade nicht auf System-Verzeichnisse zeigen
    if [[ "$SCR_PATH" =~ ^/etc|^/usr/bin|^/usr/sbin|^/bin|^/sbin|^/lib|^/var/log|^/root ]]; then
        echo "ERROR: SCR_PATH zeigt auf System-Verzeichnis (Sicherheitsrisiko): $SCR_PATH"
        if [ "$skip_validation" = "false" ]; then
            echo "Please reinstall Photoshop CC using setup.sh"
            exit 1
        fi
    fi
    
    if [[ "$CACHE_PATH" =~ ^/etc|^/usr/bin|^/usr/sbin|^/bin|^/sbin|^/lib|^/var/log|^/root ]]; then
        echo "ERROR: CACHE_PATH zeigt auf System-Verzeichnis (Sicherheitsrisiko): $CACHE_PATH"
        if [ "$skip_validation" = "false" ]; then
            echo "Please reinstall Photoshop CC using setup.sh"
            exit 1
        fi
    fi
    
    # Prüfe dass SCR_PATH wirklich ein Verzeichnis ist (nicht Datei)
    if [ "$skip_validation" = "false" ]; then
        if [ ! -d "$SCR_PATH" ]; then
            echo "ERROR: Installation directory does not exist or is not a directory: $SCR_PATH"
            echo "Photoshop may have been moved or deleted"
            echo "Please reinstall Photoshop CC using setup.sh"
            exit 1
        fi
        
        if [ ! -d "$CACHE_PATH" ]; then
            echo "ERROR: Cache directory does not exist: $CACHE_PATH"
            echo "Photoshop cache may have been moved or deleted"
            echo "Please reinstall Photoshop CC using setup.sh"
            exit 1
        fi
    fi
    
    unset datafile
}



