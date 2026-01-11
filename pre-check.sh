#!/usr/bin/env bash
################################################################################
# Photoshop CC Linux - Pre-Installation Check
#
# Description:
#   Validates system requirements before installation including Wine version,
#   required packages, disk space, and local installation files.
#
# Author:       benjarogit
# Repository:   https://github.com/benjarogit/photoshopCClinux
# License:      GPL-3.0
# Copyright:    (c) 2024 benjarogit
################################################################################

echo "═══════════════════════════════════════════════════════════════"
echo "    Photoshop CC - Pre-Installation Check"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Farben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;36m'
NC='\033[0m'

CHECKS_PASSED=0
CHECKS_FAILED=0
CHECKS_WARNING=0

check_ok() {
    echo -e "${GREEN}[✓]${NC} $1"
    ((CHECKS_PASSED++))
}

check_error() {
    echo -e "${RED}[✗]${NC} $1"
    ((CHECKS_FAILED++))
}

check_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
    ((CHECKS_WARNING++))
}

echo "Überprüfe System-Voraussetzungen..."
echo ""

# Check 1: 64-bit System
echo "1. Überprüfe System-Architektur..."
if [ "$(uname -m)" == "x86_64" ]; then
    check_ok "64-bit System (x86_64)"
else
    check_error "Kein 64-bit System! Photoshop benötigt x86_64"
fi
echo ""

# Check 2: Required Packages
echo "2. Überprüfe erforderliche Pakete..."

if command -v wine &> /dev/null; then
    WINE_VERSION=$(wine --version 2>/dev/null | cut -d'-' -f2 | cut -d' ' -f1)
    check_ok "wine installiert (Version: $WINE_VERSION)"
else
    check_error "wine nicht installiert"
    echo "   Installiere mit: sudo pacman -S wine"
fi

if command -v winetricks &> /dev/null; then
    check_ok "winetricks installiert"
else
    check_error "winetricks nicht installiert"
    echo "   Installiere mit: sudo pacman -S winetricks"
fi

if command -v md5sum &> /dev/null; then
    check_ok "md5sum verfügbar"
else
    check_warning "md5sum nicht gefunden (normalerweise unkritisch)"
fi
echo ""

# Check 3: Disk Space
echo "3. Überprüfe verfügbaren Speicherplatz..."
# Force C locale for consistent output
HOME_SPACE=$(LC_ALL=C df -BG "$HOME" | awk 'NR==2 {print $4}' | sed 's/G//')

if [ "$HOME_SPACE" -ge 5 ]; then
    check_ok "Ausreichend Speicherplatz: ${HOME_SPACE}GB verfügbar (5GB benötigt)"
else
    check_error "Nicht genug Speicherplatz: ${HOME_SPACE}GB verfügbar (5GB benötigt)"
fi
echo ""

# Check 4: RAM
echo "4. Überprüfe Arbeitsspeicher..."
# Force C locale for consistent output across all languages
TOTAL_RAM_MB=$(LC_ALL=C free -m | awk '/^Mem:/{print $2}')
# Only calculate if we got a valid number
if [ -n "$TOTAL_RAM_MB" ] && [ "$TOTAL_RAM_MB" -gt 0 ]; then
    TOTAL_RAM=$(( (TOTAL_RAM_MB + 1023) / 1024 ))  # Ceiling division: round up to nearest GB
    [ $TOTAL_RAM -eq 0 ] && TOTAL_RAM=1  # Minimum 1GB display
else
    TOTAL_RAM=""  # Mark as unknown if detection failed
fi

if [ -n "$TOTAL_RAM" ] && [ "$TOTAL_RAM" -ge 8 ]; then
    check_ok "RAM: ${TOTAL_RAM}GB (Optimal für Photoshop)"
elif [ -n "$TOTAL_RAM" ] && [ "$TOTAL_RAM" -ge 4 ]; then
    check_warning "RAM: ${TOTAL_RAM}GB (Funktioniert, aber 8GB empfohlen)"
elif [ -n "$TOTAL_RAM" ] && [ "$TOTAL_RAM" -gt 0 ]; then
    check_error "RAM: ${TOTAL_RAM}GB (Zu wenig! Mindestens 4GB benötigt)"
else
    check_warning "RAM konnte nicht ermittelt werden"
fi
echo ""

# Check 5: Installation Files
echo "5. Überprüfe lokale Installationsdateien..."
# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
PHOTOSHOP_INSTALLER="$PROJECT_ROOT/photoshop/Set-up.exe"

if [ -f "$PHOTOSHOP_INSTALLER" ]; then
    check_ok "Photoshop Installer gefunden: Set-up.exe"
    
    # Check size (force C locale for consistent output)
    INSTALLER_SIZE=$(LC_ALL=C du -h "$PHOTOSHOP_INSTALLER" | cut -f1)
    echo "   Größe: $INSTALLER_SIZE"
    
    # Check if packages exist
    PACKAGES_DIR="$PROJECT_ROOT/photoshop/packages"
    if [ -d "$PACKAGES_DIR" ]; then
        PACKAGE_COUNT=$(find "$PACKAGES_DIR" -type f | wc -l)
        check_ok "Installations-Pakete gefunden ($PACKAGE_COUNT Dateien)"
    else
        check_error "Packages-Verzeichnis fehlt: $PACKAGES_DIR"
    fi
    
    # Check if products exist
    PRODUCTS_DIR="$PROJECT_ROOT/photoshop/products"
    if [ -d "$PRODUCTS_DIR" ]; then
        PRODUCTS_COUNT=$(find "$PRODUCTS_DIR" -type f -name "*.zip" | wc -l)
        check_ok "Produkt-Dateien gefunden ($PRODUCTS_COUNT ZIP-Archive)"
    else
        check_error "Products-Verzeichnis fehlt: $PRODUCTS_DIR"
    fi
else
    check_error "Photoshop Installer nicht gefunden: $PHOTOSHOP_INSTALLER"
fi
echo ""

# Check 6: Internet Connection
echo "6. Überprüfe Internet-Verbindung..."
if ping -c 1 -W 2 google.com &> /dev/null; then
    check_warning "Internet-Verbindung aktiv"
    echo -e "   ${YELLOW}EMPFEHLUNG: Deaktiviere Internet für die Installation!${NC}"
    echo ""
    
    # Offer to disable internet now
    if command -v nmcli &> /dev/null; then
        echo -e "   ${BLUE}Möchtest du alle Netzwerkverbindungen JETZT deaktivieren? [J/n]${NC}"
        read -p "   Deine Wahl: " -n 1 -r
        echo ""
        
        if [[ $REPLY =~ ^[JjYy]$ ]] || [[ -z $REPLY ]]; then
            echo "   Deaktiviere Verbindungen..."
            active_connections=$(nmcli -t -f NAME,STATE connection show | grep ":activated" | cut -d: -f1 | grep -v "^lo$")
            
            if [ -n "$active_connections" ]; then
                # Save disabled connections for later restoration (same file as setup.sh uses)
                echo "$active_connections" > /tmp/.photoshop_disabled_connections
                
                while IFS= read -r conn; do
                    if [ -n "$conn" ]; then
                        nmcli connection down "$conn" &> /dev/null
                        echo "     ✓ $conn deaktiviert"
                    fi
                done <<< "$active_connections"
                echo ""
                check_ok "Alle Verbindungen deaktiviert (PERFEKT!)"
            fi
        else
            echo -e "   ${YELLOW}Übersprungen - Bitte vor Installation manuell deaktivieren!${NC}"
        fi
    else
        echo "   Manuell: nmcli connection show (Liste)"
        echo "   Manuell: nmcli connection down <name> (Deaktivieren)"
    fi
else
    check_ok "Keine Internet-Verbindung (PERFEKT für Installation!)"
fi
echo ""

# Check 7: Graphics Card
echo "7. Überprüfe Grafikkarte..."
if command -v lspci &> /dev/null; then
    GPU_INFO=$(lspci | grep -i vga | cut -d: -f3 | xargs)
    
    if [ -n "$GPU_INFO" ]; then
        echo "   Gefunden:$GPU_INFO"
        
        # Check for Nvidia
        if echo "$GPU_INFO" | grep -iq "nvidia"; then
            if command -v nvidia-smi &> /dev/null; then
                check_ok "Nvidia-Treiber installiert"
            else
                check_warning "Nvidia-Karte ohne nvidia-smi (proprietärer Treiber empfohlen)"
            fi
        # Check for AMD
        elif echo "$GPU_INFO" | grep -iq "amd\|radeon"; then
            check_ok "AMD Grafikkarte erkannt"
        # Check for Intel
        elif echo "$GPU_INFO" | grep -iq "intel"; then
            check_ok "Intel Grafik erkannt"
        fi
    fi
else
    check_warning "lspci nicht verfügbar, kann Grafikkarte nicht prüfen"
fi
echo ""

# Check 8: Previous Installation
echo "8. Überprüfe auf vorherige Installationen..."
# Check both old and new paths for compatibility
OLD_PATH="$HOME/.photoshopCCV19"
NEW_PATH="$HOME/.photoshop"
FOUND_INSTALLATION=""

if [ -d "$NEW_PATH" ]; then
    FOUND_INSTALLATION="$NEW_PATH"
    check_warning "Vorherige Installation gefunden in ~/.photoshop"
    echo "   ${YELLOW}Die Installation wird das Verzeichnis überschreiben!${NC}"
    echo "   Backup erstellen? Befehl: mv ~/.photoshop ~/.photoshop.backup"
elif [ -d "$OLD_PATH" ]; then
    FOUND_INSTALLATION="$OLD_PATH"
    check_warning "Vorherige Installation gefunden in ~/.photoshopCCV19 (alte Version)"
    echo "   ${YELLOW}Die Installation wird das Verzeichnis überschreiben!${NC}"
    echo "   Backup erstellen? Befehl: mv ~/.photoshopCCV19 ~/.photoshopCCV19.backup"
    echo "   ${BLUE}Hinweis: Neue Installationen verwenden ~/.photoshop${NC}"
else
    check_ok "Keine vorherige Installation gefunden"
fi
echo ""

# Check 9: Required Scripts
echo "9. Überprüfe Installations-Scripts..."
SCRIPTS_DIR="$PROJECT_ROOT/scripts"

REQUIRED_SCRIPTS=(
    "PhotoshopSetup.sh"
    "sharedFuncs.sh"
    "launcher.sh"
    "winecfg.sh"
    "uninstaller.sh"
)

ALL_SCRIPTS_OK=true
for script in "${REQUIRED_SCRIPTS[@]}"; do
    if [ -f "$SCRIPTS_DIR/$script" ]; then
        check_ok "Script gefunden: $script"
    else
        check_error "Script fehlt: $script"
        ALL_SCRIPTS_OK=false
    fi
done
echo ""

# Summary
echo "═══════════════════════════════════════════════════════════════"
echo "                    ZUSAMMENFASSUNG"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo -e "Bestanden: ${GREEN}$CHECKS_PASSED${NC}"
echo -e "Warnungen: ${YELLOW}$CHECKS_WARNING${NC}"
echo -e "Fehler:    ${RED}$CHECKS_FAILED${NC}"
echo ""

if [ $CHECKS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ Alle kritischen Checks bestanden!${NC}"
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "                BEREIT FÜR INSTALLATION!"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "Nächste Schritte:"
    echo ""
    echo "1. Internet deaktivieren (EMPFOHLEN):"
    echo -e "   ${BLUE}nmcli radio wifi off${NC}"
    echo ""
    echo "2. Installation starten:"
    echo -e "   ${BLUE}cd <projekt-verzeichnis>${NC}"
    echo -e "   ${BLUE}./setup.sh${NC}"
    echo ""
    echo "3. Option 1 wählen (install photoshop CC)"
    echo ""
    echo "4. Im Adobe Setup:"
    echo "   - 'Installieren' wählen"
    echo "   - Standard-Pfad beibehalten"
    echo "   - Sprache wählen (z.B. de_DE)"
    echo "   - 10-20 Minuten warten"
    echo ""
    echo "5. Nach Installation Internet wieder aktivieren:"
    echo -e "   ${BLUE}nmcli radio wifi on${NC}"
    echo ""
    
    if [ $CHECKS_WARNING -gt 0 ]; then
        echo "⚠ HINWEISE zu den Warnungen:"
        echo ""
        
        if [ -n "$TOTAL_RAM" ] && [ "$TOTAL_RAM" -gt 0 ] && [ "$TOTAL_RAM" -lt 8 ]; then
            echo "• RAM: Mit ${TOTAL_RAM}GB funktioniert Photoshop, aber größere"
            echo "  Dateien können langsam sein. 8GB sind optimal."
            echo ""
        fi
        
        if ping -c 1 -W 2 google.com &> /dev/null; then
            echo "• Internet: Bitte deaktiviere die Internet-Verbindung"
            echo "  für eine problemlose Installation ohne Adobe-Login."
            echo ""
        fi
        
        if [ -n "$FOUND_INSTALLATION" ]; then
            echo "• Vorherige Installation: Das Verzeichnis $FOUND_INSTALLATION wird"
            echo "  überschrieben. Erstelle ein Backup falls nötig."
            echo ""
        fi
    fi
    
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "📖 Vollständige Anleitung: README.de.md"
    echo "🚀 Schnellstart: SCHNELLSTART.md"
    echo ""
    
    exit 0
else
    echo -e "${RED}✗ Es wurden kritische Fehler gefunden!${NC}"
    echo ""
    echo "Bitte behebe die oben aufgeführten Fehler, bevor du fortfährst."
    echo ""
    
    if ! command -v wine &> /dev/null || ! command -v winetricks &> /dev/null; then
        echo "═══════════════════════════════════════════════════════════════"
        echo "SCHNELLE INSTALLATION DER FEHLENDEN PAKETE:"
        echo "═══════════════════════════════════════════════════════════════"
        echo ""
        echo "Für Arch Linux / CachyOS:"
        echo "  ${BLUE}sudo pacman -S wine winetricks${NC}"
        echo ""
        echo "Für Ubuntu/Debian:"
        echo "  ${BLUE}sudo apt install wine winetricks${NC}"
        echo ""
        echo "Für Fedora:"
        echo "  ${BLUE}sudo dnf install wine winetricks${NC}"
        echo ""
    fi
    
    if [ ! -f "$PHOTOSHOP_INSTALLER" ]; then
        echo "═══════════════════════════════════════════════════════════════"
        echo "PHOTOSHOP INSTALLATIONSDATEIEN FEHLEN:"
        echo "═══════════════════════════════════════════════════════════════"
        echo ""
        echo "Stelle sicher, dass sich die Photoshop-Dateien im richtigen"
        echo "Verzeichnis befinden:"
        echo ""
        echo "  $PHOTOSHOP_INSTALLER"
        echo ""
        echo "Die Struktur sollte sein:"
        echo "  photoshop/"
        echo "  ├── Set-up.exe"
        echo "  ├── packages/"
        echo "  └── products/"
        echo ""
    fi
    
    exit 1
fi




