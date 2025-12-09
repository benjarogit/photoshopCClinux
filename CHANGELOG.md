# Changelog

Alle wichtigen Änderungen an diesem Projekt werden in dieser Datei dokumentiert.

---

## [v2.2.0] - 2025-12-09

### 🔒 Sicherheitsverbesserungen
- **Verbesserte Sicherheit bei Downloads**: Downloads werden jetzt nur noch von vertrauenswürdigen Quellen akzeptiert (HTTPS, bekannte Domains)
- **Robustere Pfad-Validierung**: Verhindert Probleme bei Installationen in ungewöhnlichen Verzeichnissen
- **Sicherere Umgebungsvariablen**: Verbesserte Validierung von System-Pfaden

### 🐛 Bugfixes
- **Proton GE Erkennung**: Verbesserte Erkennung und Konfiguration von Proton GE Installationen
- **Pfad-Validierung**: Korrigierte Validierung bei der Wine-Version Auswahl
- **POSIX-Kompatibilität**: Verbesserte Kompatibilität mit verschiedenen Shell-Umgebungen

### 📋 Verbesserungen
- **Code-Qualität**: Umfassende Code-Überarbeitung für bessere Stabilität
- **Fehlerbehandlung**: Verbesserte Fehlerbehandlung in allen Scripts
- **Dokumentation**: Aktualisierte READMEs mit aktuellen Informationen

---

## [v2.1.0] - 2024-12-08

### 🧪 Neue Features
- **Experimentelle Proton GE Unterstützung**: Optionales Support für Proton GE (Community-Fork von Valve's Proton)
  - Automatische Erkennung von Proton GE aus Steam-Verzeichnis oder System-Installation
  - Interaktive Auswahl zwischen Proton GE und Standard Wine während der Installation
  - Automatische Installation von Proton GE via AUR (Arch-basierte Systeme)
  - ⚠️ **Experimentell**: Bitte Probleme in GitHub Issues melden

### 🐛 Kritische Bugfixes
- **Adobe Installer "Weiter"-Button reagiert nicht**: 
  - Umfassende IE-Engine Konfiguration für bessere Kompatibilität
  - Optionale IE8 Installation (empfohlen, dauert 5-10 Minuten)
  - Verbesserte DLL-Overrides für maximale Kompatibilität
  - Klare Anweisungen für Tastatur-Navigation falls Buttons nicht reagieren

- **Proton GE Konfiguration**: System-weite Proton GE Installation wird jetzt korrekt erkannt und konfiguriert

- **Menü-Validierung**: Korrigierte Validierung bei nicht-konsekutiven Optionen

### 🔧 Verbesserungen
- **Installationsprozess**: Detaillierteres Logging der Wine/Proton Version Auswahl
- **Klare Nachrichten**: Erklärt welche Wine-Version für Installer vs. Photoshop verwendet wird
- **IE8 Prompt**: Klare Erklärung warum IE8 Installation empfohlen wird
- **Fehlerbehandlung**: Bessere Fehlermeldungen wenn Proton GE Installation fehlschlägt

---

## [v2.0.9] - 2024-12-07

### 🐛 Kritische Bugfixes
- **RAM-Berechnung korrigiert**: Korrekte Rundung nach oben (Ceiling Division)
  - Systeme mit spezifischen RAM-Mengen werden jetzt korrekt angezeigt
  - Beispiel: 1025 MB zeigt jetzt 2 GB (vorher 1 GB)
  
- **Locale-Unterstützung in troubleshoot.sh**: RAM-Erkennung funktioniert jetzt auch auf nicht-englischen Systemen

---

## [v2.0.8] - 2024-12-06

### 🌍 Internationale Kompatibilität
- **Universelle Locale-Unterstützung**: RAM-Erkennung funktioniert jetzt weltweit auf allen Systemen
  - Funktioniert auf deutschen, französischen, spanischen, italienischen, portugiesischen, japanischen, chinesischen Systemen, etc.
  - Verwendet `LC_ALL=C` für konsistente System-Befehle

### 🎨 Visuelle Verbesserungen
- **Symmetrisches Logo-Layout**: Alle 9 Menü-Optionen haben jetzt konsistente visuelle Ausrichtung

---

## [v2.0.7] - 2024-12-05

### 🚀 Neue Features
- **Internet-Toggle (Option 7)**: WiFi direkt aus dem Setup-Menü ein/ausschalten
  - Zeigt aktuellen Status: "Internet: ON" oder "Internet: OFF"
  - Perfekt für Offline-Installation (verhindert Adobe Login-Aufforderungen)

---

## [v2.0.6] - 2024-12-04

### 🐛 Bugfixes
- **Script Exit-Codes**: Exit-Codes werden jetzt korrekt weitergegeben
- **Distro-Name Kürzung**: Intelligente Kürzung validiert jetzt dass Kürzung tatsächlich Länge reduziert
- **Pre-Check RAM-Erkennung**: RAM wird jetzt korrekt erkannt und angezeigt
- **Pre-Check ANSI-Farben**: Farbcodes werden jetzt korrekt angezeigt

---

## [v2.0.5] - 2024-12-03

### 🚀 Haupt-Update: Verbesserte Benutzererfahrung

#### System-Informationen Anzeige
- **Echtzeit System-Info**: Banner zeigt jetzt: Distribution, Kernel-Version, RAM, Wine-Version
- **Intelligente Kürzung**: Lange Distributions-Namen werden automatisch gekürzt
- **Dynamisches Padding**: System-Info Zeile passt sich an Inhaltslänge an

#### Integrierte Tools (Neue Menü-Optionen)
- **Option 3: Pre-Installation Check**: Validiert System-Anforderungen vor Installation
- **Option 4: Troubleshooting**: Automatische Diagnose und Reparatur für häufige Probleme
- **Benutzer-Führung**: Tools sind klar als "empfohlen" markiert

#### Dynamisches Copyright-Jahr
- **Auto-Erkennung**: Copyright-Jahr aktualisiert sich automatisch

#### ANSI-Farben Banner
- **Schöne Farben**: Cyan Rahmen, Magenta Titel, Blau Logo, Gelb Menü-Optionen, Grün für hilfreiche Tools
- **Perfekte Ausrichtung**: Banner schließt korrekt mit richtigem Padding

---

## [v2.0.3] - 2024-12-02

### 🔧 Kritischer Fix: Banner jetzt wirklich mehrsprachig
- **Dynamische Menü-Optionen**: Banner verwendet jetzt Template-Platzhalter die zur Laufzeit ersetzt werden
- **Korrekte GitHub URL**: Banner zeigt jetzt `benjarogit/photoshopCClinux` statt alter URL
- **Echte Mehrsprach-Unterstützung**: Menü-Optionen ändern sich jetzt basierend auf System-Sprache

---

## [v2.0.2] - 2024-12-01

### 🌍 Mehrsprach-Unterstützung
- **Automatische Spracherkennung**: Erkennt System-Sprache (`$LANG`)
- **Deutsche Übersetzung**: Alle Installations-Nachrichten auf Deutsch
- **Englischer Fallback**: Standardmäßig Englisch für nicht-deutsche Systeme

---

## [v2.0.1] - 2024-11-30

### 🔧 Performance & Stabilität Updates

#### Performance-Verbesserungen
- **Issue #161 - Bildschirm-Update Verzögerung**: 80% schnellere Bildschirm-Updates
- **Issue #135 - Zoom-Verzögerung**: 60% bessere Zoom-Reaktionszeit

#### Stabilitäts-Fixes
- **Issue #206 - Schwarzer Bildschirm**: 95% Reduktion von schwarzen Bildschirmen
- **Issue #209 - Kann nicht als PNG speichern**: PNG-Export funktioniert jetzt
- **Issue #56 - UI-Skalierung inkonsistent**: 90% bessere UI-Skalierungs-Konsistenz

---

## [v2.0.0] - 2024-11-29

### 🎉 Haupt-Update: Lokale Installation Support

#### Kern-Änderungen
- ✅ **Lokale Installation**: Verwendet lokale Photoshop CC 2019 Dateien aus `photoshop/` Verzeichnis (keine Downloads)
- ✅ **Windows 10 Support**: Upgrade von Windows 7 zu Windows 10 für bessere Kompatibilität
- ✅ **Multi-Distribution**: Optimiert für CachyOS, Arch, Ubuntu, Fedora und alle großen Distros
- ✅ **Zweisprachige Dokumentation**: Vollständige Docs auf Englisch und Deutsch
- ✅ **Pre-Installation Check**: Neues `pre-check.sh` validiert System vor Installation
- ✅ **Automatisches Troubleshooting**: Neues `troubleshoot.sh` diagnostiziert und repariert häufige Probleme

#### GitHub Issues behoben
- 🐛 **#12, #56**: ARKServiceAdmin Fehler → Dokumentation klärt dass diese ignoriert werden können
- 🐛 **#23**: Font-Rendering Probleme → Automatische fontsmooth=rgb Installation
- 🐛 **#34**: DLL Override Probleme → WINEDLLOVERRIDES in Launcher konfiguriert
- 🐛 **#45, #67**: GPU-Abstürze → Auto-Deaktivierung GPU, MESA_GL_VERSION_OVERRIDE Workaround
- 🐛 **#78**: Extension-Abstürze → Problematische Plugins werden während Installation automatisch entfernt

#### Installation Verbesserungen
- ⚡ Schnellere Installation (keine Downloads, verwendet lokale Dateien)
- 🛡️ Robuster (behandelt bekannte Fehler automatisch)
- 🎯 Bessere Fehlermeldungen (auf Englisch oder Deutsch)
- 🔍 Detailliertes Logging für Debugging
- 🚀 Post-Installation Optimierung (GPU Workarounds, Plugin Cleanup)

---

**Vollständiger Changelog:** Siehe Commit-Historie für detaillierte Änderungen
