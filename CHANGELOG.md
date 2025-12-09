# Changelog

All notable changes to this project will be documented in this file.

---

## [v2.2.1] - 2025-12-09

### 🐛 Bug Fixes
- **LANG_CODE initialization**: Fixed "LANG_CODE ist nicht gesetzt" error in setup.sh by initializing LANG_CODE variable before use

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
