# Troubleshoot-Tool - Übersicht

## Was ist troubleshoot.sh?

`troubleshoot.sh` ist ein **automatisches Diagnose- und Reparatur-Tool** für Photoshop CC Linux Installationen.

## Was macht es?

### 1. System-Voraussetzungen prüfen
- ✅ 64-bit System
- ✅ Wine installiert
- ✅ Winetricks installiert
- ✅ md5sum verfügbar

### 2. Photoshop Installation prüfen
- ✅ Installations-Verzeichnis (`~/.photoshopCCV19`)
- ✅ Wine-Prefix vorhanden
- ✅ Photoshop.exe gefunden (alle Versionen: 2021, 2022, 2023, CC 2019, CC 2018)
- ✅ Launcher-Script vorhanden
- ✅ Desktop-Eintrag vorhanden
- ✅ Photoshop-Befehl verfügbar

### 3. Wine-Konfiguration prüfen
- ✅ Windows-Version (sollte Windows 10 sein)
- ✅ Visual C++ Runtimes (vcrun2010, vcrun2012, vcrun2013, vcrun2015)
- ✅ Automatische Installation fehlender Runtimes (mit Bestätigung)

### 4. Bekannte Probleme prüfen
- ✅ Problematische Plugins (z.B. Adobe Spaces Helper.exe)
- ✅ Automatische Entfernung problematischer Plugins (mit Bestätigung)
- ✅ Photoshop-Einstellungen vorhanden

### 5. Log-Dateien analysieren
- ✅ Suche nach bekannten Fehlern:
  - VCRUNTIME140.dll Fehler
  - DirectX 11 Warnungen (GPU-Probleme)
  - X11 Fehler (Grafik-Probleme)
- ✅ Zeigt letzte 10 Fehlerzeilen

### 6. Performance-Check
- ✅ RAM (mindestens 4GB, empfohlen 8GB)
- ✅ Verfügbarer Speicherplatz
- ✅ Grafikkarte erkannt
- ✅ Nvidia-Treiber (falls Nvidia-Karte)

## Was kann es automatisch beheben?

1. **Visual C++ Runtimes installieren** (mit Bestätigung)
2. **Problematische Plugins entfernen** (mit Bestätigung)

## Was sollte es noch können? (Zukünftige Verbesserungen)

- [ ] Wine-Registry-Tweaks automatisch anwenden
- [ ] GPU-Beschleunigung automatisch deaktivieren
- [ ] DLL-Overrides automatisch setzen
- [ ] Icon-Probleme automatisch beheben
- [ ] Desktop-Entry-Probleme automatisch beheben

## Verwendung

```bash
./troubleshoot.sh
```

Das Tool läuft automatisch durch alle Checks und zeigt eine Zusammenfassung am Ende.

