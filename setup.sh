#!/usr/bin/env bash

# Detect system language
detect_language() {
    if [[ "$LANG" =~ ^de ]]; then
        LANG_CODE="de"
    else
        LANG_CODE="en"
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
        msg_run_winecfg
        run_script "scripts/winecfg.sh" "winecfg.sh"
        ;;
    4)  
        msg_uninstall
        run_script "scripts/uninstaller.sh" "uninstaller.sh"
        ;;
    5)  
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
        if [[ "$choose" =~ (^[1-5]$) ]];then
            break
        fi
        if [ "$LANG_CODE" = "de" ]; then
            warning "Wähle eine Zahl zwischen 1 und 5"
        else
            warning "choose a number between 1 to 5"
        fi
    done

    return $choose
}

function exitScript() {
    msg_goodbye
}

function banner() {
    # Try colored banner first, fallback to text version
    local banner_path="$PWD/images/banner"
    local banner_txt="$PWD/images/banner.txt"
    
    clear && echo ""
    
    # Check if we have the colored banner (without {OPTION} placeholders)
    if [ -f "$banner_path" ] && ! grep -q "{OPTION" "$banner_path" 2>/dev/null; then
        # Use colored banner as-is (already has menu text)
        cat "$banner_path"
    elif [ -f "$banner_txt" ]; then
        # Use text template with language support
        # Define menu options based on language (max 70 chars after number)
        if [ "$LANG_CODE" = "de" ]; then
            local opt1="1- Photoshop CC installieren                                 "
            local opt2="2- Camera Raw v12 installieren                               "
            local opt3="3- Wine konfigurieren              (winecfg)                 "
            local opt4="4- Photoshop deinstallieren                                  "
            local opt5="5- Beenden                                                   "
        else
            local opt1="1- Install photoshop CC                                      "
            local opt2="2- Install camera raw v12                                    "
            local opt3="3- configure wine                  (winecfg)                 "
            local opt4="4- uninstall photoshop                                       "
            local opt5="5- exit                                                      "
        fi
        
        # Display banner with language-specific options
        cat "$banner_txt" | sed \
            -e "s/{OPTION1}/$opt1/" \
            -e "s/{OPTION2}/$opt2/" \
            -e "s/{OPTION3}/$opt3/" \
            -e "s/{OPTION4}/$opt4/" \
            -e "s/{OPTION5}/$opt5/"
    else
        msg_banner_not_found
    fi
    
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
