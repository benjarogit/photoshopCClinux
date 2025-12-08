#!/usr/bin/env bash
################################################################################
# Photoshop CC Linux - Wine Configuration Launcher
#
# Description:
#   Opens Wine configuration (winecfg) for the Photoshop Wine prefix.
#   Allows users to adjust Wine settings, Windows version, and drives.
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

function main() {
    load_paths 
    RESOURCES_PATH="$SCR_PATH/resources"
    WINE_PREFIX="$SCR_PATH/prefix"
    export WINEPREFIX="$WINE_PREFIX"
    
    echo "═══════════════════════════════════════════════════════════════"
    echo "           Wine-Konfiguration für Photoshop CC"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "Wine-Prefix: $WINE_PREFIX"
    echo ""
    echo "EMPFOHLENE EINSTELLUNGEN:"
    echo "  1. Applications Tab:"
    echo "     → Windows Version: Windows 10"
    echo ""
    echo "  2. Graphics Tab:"
    echo "     → Screen resolution: 96 DPI (Standard)"
    echo "     → Emulate a virtual desktop: Optional (bei Problemen aktivieren)"
    echo ""
    echo "  3. Staging Tab (falls vorhanden):"
    echo "     → CSMT für bessere Performance aktivieren"
    echo ""
    echo "BEKANNTE PROBLEME UND LÖSUNGEN (GitHub Issues):"
    echo "  - Photoshop stürzt ab: GPU-Beschleunigung in PS deaktivieren"
    echo "  - Schrift unleserlich: Font-Smoothing auf RGB setzen"
    echo "  - Langsamer Start: Normal beim ersten Start (1-2 Min)"
    echo "  - VCRUNTIME140.dll fehlt: vcrun2015 über winetricks nachinstallieren"
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    
    notify-send "Photoshop CC" "Wine-Konfiguration wird geöffnet..." -i "photoshop"
    sleep 2
    
    winecfg
    
    echo ""
    echo "✓ Konfiguration abgeschlossen!"
}

main

