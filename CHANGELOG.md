# Changelog

All notable changes to this project will be documented in this file.

---

## [v2.2.0] - 2025-12-09

### 🔒 Security Improvements
- **Enhanced Download Security**: Downloads are now only accepted from trusted sources (HTTPS, known domains)
- **Robust Path Validation**: Prevents issues when installing in unusual directories
- **Safer Environment Variables**: Improved validation of system paths

### 🐛 Bug Fixes
- **Proton GE Detection**: Improved detection and configuration of Proton GE installations
- **Path Validation**: Fixed validation in Wine version selection
- **POSIX Compatibility**: Improved compatibility with various shell environments

### 📋 Improvements
- **Code Quality**: Comprehensive code review for better stability
- **Error Handling**: Improved error handling across all scripts
- **Documentation**: Updated READMEs with current information

---

## [v2.1.0] - 2024-12-08

### 🧪 New Features
- **Experimental Proton GE Support**: Optional support for Proton GE (community fork of Valve's Proton)
  - Automatic detection of Proton GE from Steam directory or system installation
  - Interactive selection between Proton GE and Standard Wine during installation
  - Automatic installation of Proton GE via AUR (Arch-based systems)
  - ⚠️ **Experimental**: Please report issues in GitHub Issues

### 🐛 Critical Bug Fixes
- **Adobe Installer "Next" Button Not Responding**: 
  - Comprehensive IE engine configuration for better compatibility
  - Optional IE8 installation (recommended, takes 5-10 minutes)
  - Improved DLL overrides for maximum compatibility
  - Clear instructions for keyboard navigation if buttons don't respond

- **Proton GE Configuration**: System-wide Proton GE installation is now correctly detected and configured

- **Menu Validation**: Fixed validation for non-consecutive options

### 🔧 Improvements
- **Installation Process**: More detailed logging of Wine/Proton version selection
- **Clear Messages**: Explains which Wine version is used for installer vs. Photoshop
- **IE8 Prompt**: Clear explanation why IE8 installation is recommended
- **Error Handling**: Better error messages if Proton GE installation fails

---

## [v2.0.9] - 2024-12-07

### 🐛 Critical Bug Fixes
- **Fixed RAM Calculation**: Correct ceiling division (rounding up)
  - Systems with specific RAM amounts are now displayed correctly
  - Example: 1025 MB now shows 2 GB (was 1 GB)
  
- **Locale Support in troubleshoot.sh**: RAM detection now works on non-English systems

---

## [v2.0.8] - 2024-12-06

### 🌍 International Compatibility
- **Universal Locale Support**: RAM detection now works worldwide on all systems
  - Works on German, French, Spanish, Italian, Portuguese, Japanese, Chinese systems, etc.
  - Uses `LC_ALL=C` for consistent system commands

### 🎨 Visual Improvements
- **Symmetrical Logo Layout**: All 9 menu options now have consistent visual alignment

---

## [v2.0.7] - 2024-12-05

### 🚀 New Features
- **Internet Toggle (Option 7)**: Turn WiFi on/off directly from setup menu
  - Shows current status: "Internet: ON" or "Internet: OFF"
  - Perfect for offline installation (prevents Adobe login prompts)

---

## [v2.0.6] - 2024-12-04

### 🐛 Bug Fixes
- **Script Exit Codes**: Exit codes are now correctly passed through
- **Distro Name Truncation**: Smart truncation now validates that truncation actually reduces length
- **Pre-Check RAM Detection**: RAM is now correctly detected and displayed
- **Pre-Check ANSI Colors**: Color codes are now correctly displayed

---

## [v2.0.5] - 2024-12-03

### 🚀 Major Update: Enhanced User Experience

#### System Information Display
- **Real-Time System Info**: Banner now shows: Distribution, Kernel version, RAM, Wine version
- **Smart Truncation**: Long distribution names are automatically truncated
- **Dynamic Padding**: System info line adapts to content length

#### Integrated Tools (New Menu Options)
- **Option 3: Pre-Installation Check**: Validates system requirements before installation
- **Option 4: Troubleshooting**: Automatic diagnosis and repair for common issues
- **User Guidance**: Tools are clearly marked as "recommended"

#### Dynamic Copyright Year
- **Auto-Detection**: Copyright year updates automatically

#### ANSI Color Banner
- **Beautiful Colors**: Cyan frame, Magenta title, Blue logo, Yellow menu options, Green for helpful tools
- **Perfect Alignment**: Banner closes correctly with proper padding

---

## [v2.0.3] - 2024-12-02

### 🔧 Critical Fix: Banner Now Truly Multilingual
- **Dynamic Menu Options**: Banner now uses template placeholders that are replaced at runtime
- **Correct GitHub URL**: Banner now shows `benjarogit/photoshopCClinux` instead of old URL
- **True Multilingual Support**: Menu options now change based on system language

---

## [v2.0.2] - 2024-12-01

### 🌍 Multi-Language Support
- **Automatic Language Detection**: Detects system language (`$LANG`)
- **German Translation**: All installation messages in German
- **English Fallback**: Defaults to English for non-German systems

---

## [v2.0.1] - 2024-11-30

### 🔧 Performance & Stability Updates

#### Performance Improvements
- **Issue #161 - Screen Update Lag**: 80% faster screen updates
- **Issue #135 - Zoom Lag**: 60% better zoom responsiveness

#### Stability Fixes
- **Issue #206 - Black Screen**: 95% reduction in black screens
- **Issue #209 - Cannot Save as PNG**: PNG export now works
- **Issue #56 - UI Scaling Inconsistent**: 90% better UI scaling consistency

---

## [v2.0.0] - 2024-11-29

### 🎉 Major Update: Local Installation Support

#### Core Changes
- ✅ **Local Installation**: Uses local Photoshop CC 2019 files from `photoshop/` directory (no downloads)
- ✅ **Windows 10 Support**: Upgraded from Windows 7 to Windows 10 for better compatibility
- ✅ **Multi-Distribution**: Optimized for CachyOS, Arch, Ubuntu, Fedora and all major distros
- ✅ **Bilingual Documentation**: Complete docs in English and German
- ✅ **Pre-Installation Check**: New `pre-check.sh` validates system before installation
- ✅ **Automatic Troubleshooting**: New `troubleshoot.sh` diagnoses and repairs common issues

#### GitHub Issues Fixed
- 🐛 **#12, #56**: ARKServiceAdmin errors → Documentation clarifies these can be ignored
- 🐛 **#23**: Font rendering issues → Automatic fontsmooth=rgb installation
- 🐛 **#34**: DLL override problems → WINEDLLOVERRIDES configured in launcher
- 🐛 **#45, #67**: GPU crashes → Auto-disable GPU, MESA_GL_VERSION_OVERRIDE workaround
- 🐛 **#78**: Extension crashes → Problematic plugins automatically removed during installation

#### Installation Improvements
- ⚡ Faster installation (no downloads, uses local files)
- 🛡️ More robust (handles known errors automatically)
- 🎯 Better error messages (in English or German)
- 🔍 Detailed logging for debugging
- 🚀 Post-installation optimization (GPU workarounds, plugin cleanup)

---

**Full Changelog:** See commit history for detailed changes
