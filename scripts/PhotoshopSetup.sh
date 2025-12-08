#!/usr/bin/env bash
source "sharedFuncs.sh"

# Detect system language
LANG_CODE="${LANG:0:2}"
if [ "$LANG_CODE" != "de" ]; then
    LANG_CODE="en"
fi

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
    
    mkdir -p $SCR_PATH
    mkdir -p $CACHE_PATH
    
    setup_log "================| script executed |================"

    is64

    #make sure wine and winetricks package is already installed
    package_installed wine
    package_installed md5sum
    package_installed winetricks

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
    winetricks -q win10
    
    # Core-Komponenten einzeln installieren für bessere Fehlerbehandlung
    show_message "$MSG_VCRUN"
    winetricks -q vcrun2010 vcrun2012 vcrun2013 vcrun2015
    
    show_message "$MSG_FONTS"
    winetricks -q atmlib corefonts fontsmooth=rgb
    
    show_message "$MSG_XML"
    winetricks -q msxml3 msxml6 gdiplus
    
    # Workaround für bekannte Wine-Probleme (GitHub Issue #34)
    show_message "$MSG_DLL"
    winetricks -q dxvk_async=disabled d3d11=native
    
    # Zusätzliche Performance & Rendering Fixes
    show_message "$([ "$LANG_CODE" = "de" ] && echo "Konfiguriere Wine-Registry für bessere Performance..." || echo "Configuring Wine registry for better performance...")"
    
    # Enable CSMT for better performance (Command Stream Multi-Threading)
    wine reg add "HKEY_CURRENT_USER\\Software\\Wine\\Direct3D" /v csmt /t REG_DWORD /d 1 /f 2>/dev/null || true
    
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
    # Verwende das lokale Adobe Photoshop Installationspaket
    local local_installer="/home/benny/Dokumente/Gictorbit-photoshopCClinux-ea730a5/photoshop/Set-up.exe"
    
    # Try to find the installation files in current directory as well
    if [ ! -f "$local_installer" ]; then
        # Try relative path from script location
        local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        local_installer="$script_dir/../photoshop/Set-up.exe"
    fi
    
    if [ ! -f "$local_installer" ]; then
        error "$([ "$LANG_CODE" = "de" ] && echo "Lokales Photoshop Installationspaket nicht gefunden: $local_installer" || echo "Local Photoshop installation package not found: $local_installer")"
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
    
    # Starte den Adobe Installer
    wine "$RESOURCES_PATH/photoshop/Set-up.exe" &>> "$SCR_PATH/wine-error.log"
    
    local install_status=$?
    
    if [ $install_status -eq 0 ]; then
        show_message "$MSG_COMPLETE"
    else
        if [ "$LANG_CODE" = "de" ]; then
            warning "Installation mit Exit-Code $install_status beendet. Prüfe die Logs..."
        else
            warning "Installation finished with exit code $install_status. Check logs..."
        fi
    fi
    
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
