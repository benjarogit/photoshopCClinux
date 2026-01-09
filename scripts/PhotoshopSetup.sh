#!/usr/bin/env bash
################################################################################
# Photoshop CC Linux Installer - Installation Script
#
# Description:
#   Handles the complete installation process of Adobe Photoshop CC on Linux
#   including Wine configuration, dependency installation, registry tweaks,
#   and performance optimizations for stable operation.
#
# Author:       benjarogit
# Repository:   https://github.com/benjarogit/photoshopCClinux
# License:      GPL-3.0
# Copyright:    (c) 2024 benjarogit
#
# Based on:     photoshopCClinux by Gictorbit
#               https://github.com/Gictorbit/photoshopCClinux
################################################################################

# CRITICAL: Enable robust error handling
set -eu
(set -o pipefail 2>/dev/null) || true

# CRITICAL: Trap for CTRL+C (INT) and other signals - MUST be set at the very beginning
# Also needed in subprocesses (winetricks, wine, etc.)
cleanup_on_interrupt() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "Installation abgebrochen durch Benutzer (STRG+C)"
    echo "═══════════════════════════════════════════════════════════════"
    # Log error if LOG_FILE is available
    if [ -n "${LOG_FILE:-}" ] && [ -f "${LOG_FILE:-}" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Installation abgebrochen durch Benutzer (STRG+C)" >> "${LOG_FILE}"
    fi
    exit 130
}
trap cleanup_on_interrupt INT TERM HUP

# Locale/UTF-8 for DE/EN (with check for existing locale)
# CRITICAL: Check if locale exists (Alpine often only has C.UTF-8)
if command -v locale >/dev/null 2>&1; then
    # Fix grep warnings: Use -F for fixed strings or escape properly
    if locale -a 2>/dev/null | grep -qF "de_DE.utf8" || locale -a 2>/dev/null | grep -qF "de_DE.UTF-8" || locale -a 2>/dev/null | grep -qF "de_DE"; then
        export LANG="${LANG:-de_DE.UTF-8}"
    elif locale -a 2>/dev/null | grep -qF "C.utf8" || locale -a 2>/dev/null | grep -qF "C.UTF-8"; then
        export LANG="${LANG:-C.UTF-8}"
    else
        export LANG="${LANG:-C}"
    fi
else
    # Fallback if locale not available
    export LANG="${LANG:-C.UTF-8}"
fi
export LC_ALL="${LC_ALL:-$LANG}"

# ============================================================================
# @function init_environment
# @description Initialize all environment variables in a centralized location
# @return 0 on success, 1 on error
# ============================================================================
init_environment() {
    # CRITICAL: Prevent source hijacking - always use absolute path
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    export SCRIPT_DIR  # Export for sharedFuncs.sh::launcher()
    
    # CRITICAL: PATH hijacking check
    if [[ ":$PATH:" == *":.:"* ]] || [[ "$PATH" == .:* ]] || [[ "$PATH" == *:. ]]; then
        export PATH="/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin"
    fi
    
    # Get project root directory (parent of scripts/)
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
    export PROJECT_ROOT
    
    # Setup log directory
    LOG_DIR="$PROJECT_ROOT/logs"
    mkdir -p "$LOG_DIR"
    
    # Delete old logs before creating new ones
    if [ -d "$LOG_DIR" ]; then
        rm -f "$LOG_DIR"/*.log 2>/dev/null
    fi
    
    # Generate timestamp once to ensure both logs have matching timestamps
    # Format: "Log: 09.12.25 06:36 Uhr"
    TIMESTAMP=$(date +%d.%m.%y\ %H:%M\ Uhr)
    LOG_FILE="$LOG_DIR/Log: ${TIMESTAMP}.log"
    ERROR_LOG="$LOG_DIR/Log: ${TIMESTAMP}_errors.log"
    
    # DEBUG MODE: Debug log file for runtime tracking - stored in logs/ directory with other logs
    DEBUG_LOG="$LOG_DIR/Log: ${TIMESTAMP}_debug.log"
    
    # Export all logging variables for sharedFuncs.sh
    export LOG_FILE
    export ERROR_LOG
    export LOG_DIR
    export TIMESTAMP
    export DEBUG_LOG
}

# Initialize environment first
init_environment

# Source i18n module for internationalization
source "$SCRIPT_DIR/i18n.sh"

# Source security module for validation and sanitization
source "$SCRIPT_DIR/security.sh"

# Source checkpoint module for rollback support
source "$SCRIPT_DIR/checkpoint.sh"

# Source update module for version checking
source "$SCRIPT_DIR/update.sh"

# Source shared functions after environment is initialized
source "$SCRIPT_DIR/sharedFuncs.sh"
source "$SCRIPT_DIR/output.sh"
source "$SCRIPT_DIR/system.sh"

# Setup comprehensive logging - ALL output will be logged
# This function sets up automatic logging of all stdout/stderr
setup_comprehensive_logging() {
    log_debug "Comprehensive logging enabled - all output will be automatically logged"
}
debug_log() {
    local location="$1"
    local message="$2"
    local data="$3"
    local hypothesis_id="${4:-}"
    local timestamp=$(date +%s%3N 2>/dev/null || date +%s000)
    local session_id="debug-session-$(date +%s)"
    local run_id="${RUN_ID:-run1}"
    echo "{\"id\":\"log_${timestamp}_$$\",\"timestamp\":${timestamp},\"location\":\"${location}\",\"message\":\"${message}\",\"data\":${data},\"sessionId\":\"${session_id}\",\"runId\":\"${run_id}\",\"hypothesisId\":\"${hypothesis_id}\"}" >> "$DEBUG_LOG" 2>/dev/null || true
}

# ANSI Color codes (compatible with setup.sh)
# Check if terminal supports colors
if [ -t 1 ] && [ "$TERM" != "dumb" ]; then
    C_RESET="\033[0m"
    C_CYAN="\033[0;36;1m"
    C_MAGENTA="\033[0;35;1m"
    C_BLUE="\033[0;34;1m"
    C_YELLOW="\033[0;33;1m"
    C_WHITE="\033[0;37;1m"
    C_GREEN="\033[0;32;1m"
    C_GRAY="\033[0;37m"
    C_RED="\033[1;31m"
else
    # No colors for dumb terminals
    C_RESET=""
    C_CYAN=""
    C_MAGENTA=""
    C_BLUE=""
    C_YELLOW=""
    C_WHITE=""
    C_GREEN=""
    C_GRAY=""
    C_RED=""
fi

# Spinner function for long-running processes
spinner() {
    local pid=$1
    local message="${2:-}"
    local spinstr='|/-\'
    local temp
    
    # Show message if provided
    if [ -n "$message" ]; then
        echo -ne "${C_YELLOW}$message${C_RESET} "
    fi
    
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        temp=${spinstr#?}
        printf "${C_CYAN}[%c]${C_RESET}" "$spinstr"
        local old_IFS="${IFS:-}"
        IFS=
        spinstr=$temp${spinstr%"$temp"}
        IFS="$old_IFS"
        sleep 0.1
        printf "\b\b\b"
    done
    printf "   \b\b\b"
    echo ""
}

# Run command with spinner in background
run_with_spinner() {
    local message="$1"
    shift
    local cmd="$*"
    
    # CRITICAL: Export environment variables before running command
    # This ensures winetricks uses the correct Wine binary and WINEPREFIX
    # CRITICAL: Use arrays instead of eval for security
    # Build environment variables array
    local env_array=()
    if [ -n "${WINEPREFIX:-}" ]; then
        env_array+=("WINEPREFIX=$WINEPREFIX")
    fi
    if [ -n "${WINEARCH:-}" ]; then
        env_array+=("WINEARCH=$WINEARCH")
    fi
    if [ -n "${PROTON_PATH:-}" ]; then
        env_array+=("PROTON_PATH=$PROTON_PATH")
    fi
    if [ -n "${PROTON_VERB:-}" ]; then
        env_array+=("PROTON_VERB=$PROTON_VERB")
    fi
    
    # CRITICAL: Validate command before execution if security::safe_eval available
    if type security::safe_eval >/dev/null 2>&1; then
        if ! security::safe_eval "$cmd" "wine" "winetricks"; then
            log_error "Unsafe command detected: $cmd"
            return 1
        fi
    fi
    
    # Run command in background with environment variables and capture PID
    # Use env command with array instead of eval
    if [ ${#env_array[@]} -gt 0 ]; then
        env "${env_array[@]}" bash -c "$cmd" >> "$LOG_FILE" 2>&1 &
    else
        bash -c "$cmd" >> "$LOG_FILE" 2>&1 &
    fi
    local pid=$!
    
    # Show spinner while command runs
    spinner $pid "$message"
    
    # Wait for command to finish and get exit code
    wait $pid
    return $?
}

# ============================================================================
# @function run_with_spinner_and_retry
# @description Run command with spinner and retry mechanism
# @param $1 Message to display
# @param $2 Command to execute
# @param $3 Optional: Max retries (default: 2)
# @param $4 Optional: Retry delay in seconds (default: 5)
# @return 0 on success, 1 if all retries failed
# ============================================================================
run_with_spinner_and_retry() {
    local message="$1"
    local cmd="$2"
    local max_retries="${3:-2}"
    local retry_delay="${4:-5}"
    local attempt=1
    
    while [ $attempt -le $max_retries ]; do
        if run_with_spinner "$message" "$cmd"; then
            return 0
        fi
        
        if [ $attempt -lt $max_retries ]; then
            log::debug "Command failed (attempt $attempt/$max_retries), retrying in ${retry_delay}s: $cmd"
            sleep "$retry_delay"
        fi
        
        attempt=$((attempt + 1))
    done
    
    log::warning "Command failed after $max_retries attempts: $cmd"
    return 1
}

# ============================================================================
# Unified Logging System with Namespace Pattern
# ============================================================================
# @namespace log
# @description Unified logging system with consistent interface
# All log functions follow the pattern: log::<level> "message"
# ============================================================================

# ============================================================================
# @function log::success
# @description Log success message (green, shown to user)
# @param $* Success message(s)
# @return 0 (always succeeds)
# ============================================================================
log::success() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local message="$*"
    echo "[$timestamp] SUCCESS: $message" >> "$LOG_FILE"
    echo -e "${C_GREEN}$message${C_RESET}"
}

# ============================================================================
# @function log::info
# @description Log info message (cyan, shown to user)
# @param $* Info message(s)
# @return 0 (always succeeds)
# ============================================================================
log::info() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local message="$*"
    echo "[$timestamp] INFO: $message" >> "$LOG_FILE"
    echo -e "${C_CYAN}INFO: $message${C_RESET}"
}

# ============================================================================
# @function log::warning
# @description Log warning message (yellow, shown to user)
# @param $* Warning message(s)
# @return 0 (always succeeds)
# ============================================================================
log::warning() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local message="$*"
    echo "[$timestamp] WARNING: $message" >> "$LOG_FILE"
    echo -e "${C_YELLOW}WARNING: $message${C_RESET}"
}

# ============================================================================
# @function log::error
# @description Log error message (red, shown to user, also to error log)
# @param $* Error message(s)
# @return 0 (always succeeds, does not exit)
# ============================================================================
log::error() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local message="$*"
    echo "[$timestamp] ERROR: $message" >> "$LOG_FILE"
    echo "[$timestamp] ERROR: $message" >> "$ERROR_LOG"
    echo -e "${C_RED}ERROR: $message${C_RESET}"
}

# ============================================================================
# @function log::debug
# @description Log debug message (only to log file, not shown to user)
# @param $* Debug message(s)
# @return 0 (always succeeds)
# ============================================================================
log::debug() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local message="$*"
    echo "[$timestamp] DEBUG: $message" >> "$LOG_FILE"
}

# ============================================================================
# @function log::prompt
# @description Log user prompt (shown to user and logged)
# @param $* Prompt message(s)
# @return 0 (always succeeds)
# ============================================================================
log::prompt() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local message="$*"
    echo "[$timestamp] PROMPT: $message" | tee -a "$LOG_FILE"
}

# ============================================================================
# @function log::input
# @description Log user input (logged only)
# @param $* Input message(s)
# @return 0 (always succeeds)
# ============================================================================
log::input() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local message="$*"
    echo "[$timestamp] USER_INPUT: $message" | tee -a "$LOG_FILE"
}

# ============================================================================
# DEPRECATED: Legacy logging functions for backward compatibility
# These will be removed in a future version. Use log::* functions instead.
# ============================================================================
log() {
    log::success "$@"
}

log_error() {
    log::error "$@"
}

log_warning() {
    log::warning "$@"
}

log_info() {
    log::info "$@"
}

log_debug() {
    log::debug "$@"
}

log_prompt() {
    log::prompt "$@"
}

log_input() {
    log::input "$@"
}

# Wrapper for read that logs input
read_with_log() {
    local prompt="$1"
    local var_name="$2"
    # CRITICAL: Reset IFS after read
    local old_IFS="${IFS:-}"
    log_prompt "$prompt"
    # shellcheck disable=SC2162,SC2086
    IFS= read -r -p "$prompt" ${var_name?}
    log_input "${!var_name}"
    # CRITICAL: Reset IFS
    IFS="$old_IFS"
}

# Note: All echo statements should also call log() for comprehensive logging
# This ensures everything is logged to the log file

log_command() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local cmd_args="$*"
    echo "[$timestamp] EXEC: $cmd_args" >> "$LOG_FILE"
    local output
    output=$("$@" 2>&1)
    local exit_code=$?
    if [ -n "$output" ]; then
        echo "$output" | while IFS= read -r line; do
            echo "[$timestamp] OUTPUT: $line" >> "$LOG_FILE"
        done
    fi
    return $exit_code
}

# Log all environment variables relevant to Wine/Proton
log_environment() {
    log_debug "=== Environment Variables ==="
    log_debug "PATH: $PATH"
    log_debug "WINEPREFIX: ${WINEPREFIX:-not set}"
    log_debug "WINEARCH: ${WINEARCH:-not set}"
    log_debug "PROTON_PATH: ${PROTON_PATH:-not set}"
    log_debug "PROTON_VERB: ${PROTON_VERB:-not set}"
    log_debug "SCR_PATH: ${SCR_PATH:-not set}"
    log_debug "WINE_PREFIX: ${WINE_PREFIX:-not set}"
    log_debug "RESOURCES_PATH: ${RESOURCES_PATH:-not set}"
    log_debug "CACHE_PATH: ${CACHE_PATH:-not set}"
    log_debug "LANG: ${LANG:-not set}"
    log_debug "LANG_CODE: ${LANG_CODE:-not set}"
    log_debug "=== End Environment Variables ==="
}

# Log system information (with timeout protection to prevent hanging)
log_system_info() {
    log_debug "=== System Information ==="
    log_debug "OS: $(uname -a 2>&1)"
    
    local distro=$(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d'"' -f2 || echo 'unknown')
    log_debug "Distribution: $distro"
    
    # Wine version with timeout
    if command -v timeout &>/dev/null; then
        local wine_ver=$(timeout 2 wine --version 2>&1 || echo 'timeout or error')
    else
        local wine_ver=$(wine --version 2>&1 || echo 'not found')
    fi
    log_debug "Wine version: $wine_ver"
    
    # Winetricks version - this can hang, so we use a safer approach
    log_debug "Winetricks: checking..."
    if command -v winetricks &>/dev/null; then
        # Try to get version quickly, but don't wait forever
        if command -v timeout &>/dev/null; then
            local winetricks_ver=$(timeout 1 winetricks --version 2>&1 | head -1 || echo 'timeout')
        else
            # Fallback: just check if it exists
            local winetricks_ver="installed (version check skipped)"
        fi
    else
        local winetricks_ver="not found"
    fi
    log_debug "Winetricks: $winetricks_ver"
    
    # Proton GE check - DON'T call proton-ge --version as it starts Steam!
    if command -v proton-ge &>/dev/null; then
        # Just check if the command exists, don't run it (it starts Steam)
        log_debug "Proton GE: installed (system-wide, version check skipped to avoid Steam)"
    else
        log_debug "Proton GE: not found"
    fi
    
    log_debug "Available Wine binaries:"
    which -a wine 2>/dev/null | while IFS= read -r wine_path; do
        if [ -n "$wine_path" ]; then
            log_debug "  - $wine_path"
        fi
    done
    log_debug "=== End System Information ==="
}

# Detect system language
LANG_CODE="${LANG:0:2}"
if [ "$LANG_CODE" != "de" ]; then
    LANG_CODE="en"
fi

# Detect system distribution for recommendations
detect_system() {
    if [ -f /etc/os-release ]; then
        # shellcheck source=/dev/null
        . /etc/os-release
        echo "${ID:-unknown}"
    elif [ -f /etc/arch-release ]; then
        echo "arch"
    else
        echo "unknown"
    fi
}

# Check if Proton GE can be installed via package manager
check_proton_ge_installable() {
    local system=$(detect_system)
    
    case "$system" in
        arch|manjaro|cachyos|endeavouros)
            # Arch-based: Check for AUR helper
            if command -v yay &> /dev/null || command -v paru &> /dev/null || command -v pacman &> /dev/null; then
                return 0
            fi
            ;;
        debian|ubuntu|pop)
            # Debian-based: Check for apt
            if command -v apt &> /dev/null; then
                return 0
            fi
            ;;
        fedora|rhel|centos)
            # RPM-based: Check for dnf/yum
            if command -v dnf &> /dev/null || command -v yum &> /dev/null; then
                return 0
            fi
            ;;
    esac
    
    return 1
}

# Detect all available Wine/Proton versions
# Returns: array of options with priority (System Proton GE > Wine > others)
# NOTE: Proton GE from Steam directory is SKIPPED because it starts Steam
detect_all_wine_versions() {
    local options=()
    local descriptions=()
    local paths=()
    local index=1
    local system=$(detect_system)
    local recommended_index=1
    local proton_found=0  # Flag to track if any Proton GE was found
    
    # SKIP: Proton GE (Steam directory) - NOT USED for desktop apps
    # Reason: It starts Steam when winecfg/wine is called, which breaks the installation
    # We only use system-wide Proton GE (installed via package manager)
    
    # Priority 1: System-wide Proton GE (if installed via package manager)
    # This is the BEST option for desktop applications
    # NOTE: DON'T call proton-ge --version as it starts Steam!
    if command -v proton-ge &> /dev/null; then
        # Just check if command exists, don't call it (it starts Steam)
        local version="system"
        log_debug "Proton GE (system) gefunden - verwende ohne Version-Check (verhindert Steam-Start)"
        options+=("$index")
        local recommended_text=$(i18n::get "recommended")
        local compatibility_text=$(i18n::get "best_compatibility")
        descriptions+=("Proton GE (system): $version ⭐ $recommended_text - $compatibility_text")
        paths+=("system")
        recommended_index=$index
        proton_found=1
        ((index++))
    fi
    
    # Priority 3: Standard Wine
    if command -v wine &> /dev/null; then
        local version=$(wine --version 2>/dev/null | head -1 || echo "unknown")
        options+=("$index")
        local fallback_text=$(i18n::get "fallback")
        if [ $proton_found -eq 1 ]; then
            local proton_recommended=$(i18n::get "proton_ge_recommended_fallback")
            descriptions+=("Standard Wine: $version ($fallback_text - $proton_recommended)")
        else
            descriptions+=("Standard Wine: $version ($fallback_text)")
        fi
        paths+=("wine")
        ((index++))
    fi
    
    # Priority 4: Wine Staging (if available)
    if command -v wine-staging &> /dev/null; then
        local version=$(wine-staging --version 2>/dev/null | head -1 || echo "unknown")
        options+=("$index")
        local alternative_text=$(i18n::get "wine_staging_alternative")
        descriptions+=("Wine Staging: $version ($alternative_text)")
        paths+=("wine-staging")
        ((index++))
    fi
    
    # Store recommended index
    WINE_RECOMMENDED=$recommended_index
    
    # Return via global arrays (bash limitation)
    WINE_OPTIONS=("${options[@]}")
    WINE_DESCRIPTIONS=("${descriptions[@]}")
    WINE_PATHS=("${paths[@]}")
    
    return ${#options[@]}
}

# ============================================================================
# @function handle_wine_method_parameter
# @description Handle WINE_METHOD command line parameter (--wine-standard/--proton-ge)
# @return Selected option index (1-based) if found, empty string if not set or not found
# ============================================================================
handle_wine_method_parameter() {
    # Check if WINE_METHOD is set via command line parameter (skip interactive menu)
    # CRITICAL: Export WINE_METHOD so it's available in all scopes
    export WINE_METHOD="${WINE_METHOD:-}"
    if [ -z "$WINE_METHOD" ]; then
        echo ""  # No parameter set
        return 1
    fi
    
    # CRITICAL: Redirect all log output to stderr to prevent it from being captured
    # This function returns only the index via stdout
    log "Wine-Methode wurde per Parameter gesetzt: $WINE_METHOD" >&2
    log_debug "Wine-Methode Parameter: $WINE_METHOD" >&2
    debug_log "PhotoshopSetup.sh:484" "WINE_METHOD set via parameter" "{\"WINE_METHOD\":\"${WINE_METHOD}\"}" "H1" >&2
    
    local skip_text=$(i18n::get "skipping_interactive_selection")
    local wine_method_display=$([ "$WINE_METHOD" = "wine" ] && echo "Wine Standard" || echo "Proton GE")
    log "$skip_text: $wine_method_display" >&2
    
    # Find the matching option index
    local found=0
    local index=1
    local selected_index=""
    for path in "${WINE_PATHS[@]}"; do
        if [ "$WINE_METHOD" = "proton" ] && [ "$path" = "system" ]; then
            selected_index=$index
            found=1
            log_debug "Proton GE gefunden bei Index $index" >&2
            break
        elif [ "$WINE_METHOD" = "wine" ] && [ "$path" = "wine" ]; then
            selected_index=$index
            found=1
            log_debug "Wine Standard gefunden bei Index $index" >&2
            break
        fi
        ((index++))
    done
    
    if [ $found -eq 0 ]; then
        log_error "Angeforderte Wine-Methode '$WINE_METHOD' nicht gefunden!" >&2
        local error_msg=$(i18n::get "wine_method_not_found")
        error "$(printf "$error_msg" "$WINE_METHOD")" >&2
        echo ""  # Not found, fall through to interactive menu
        return 1
    else
        # Use the found selection and skip menu
        log "Verwende automatisch ausgewählte Option: $selected_index" >&2
        echo "$selected_index"  # Return selected index (ONLY this goes to stdout)
        return 0  # Successfully handled
    fi
}

# ============================================================================
# @function check_proton_ge_availability
# @description Check if Proton GE is available in WINE_PATHS
# @return 0 if Proton GE is available, 1 if not
# ============================================================================
check_proton_ge_availability() {
    for path in "${WINE_PATHS[@]}"; do
        # Only system-wide Proton GE is used (not Steam Proton)
        if [ "$path" = "system" ]; then
            return 0  # Found
        fi
    done
    return 1  # Not found
}

# ============================================================================
# @function find_proton_ge_path
# @description Find Proton GE installation path (manual > AUR > system paths)
# @return Proton GE path if found, empty string if not found
# ============================================================================
find_proton_ge_path() {
    local proton_ge_path=""
    
    # PRIORITÄT 1: Manuell installiert (universell für alle Linux-Distributionen)
    local possible_manual_paths=(
        "$HOME/.local/share/proton-ge/current"
        "$HOME/.local/share/proton-ge"
        "$HOME/.proton-ge/current"
        "$HOME/.proton-ge"
        "/usr/local/share/proton-ge/current"
        "/usr/local/share/proton-ge"
        "/opt/proton-ge/current"
        "/opt/proton-ge"
    )
    
    for path in "${possible_manual_paths[@]}"; do
        # Prüfe ob es ein Symlink ist (current -> version)
        local real_path="$path"
        if [ -L "$path" ]; then
            real_path=$(readlink -f "$path" 2>/dev/null || echo "$path")
        fi
        
        if [ -d "$real_path" ] && [ -f "$real_path/files/bin/wine" ]; then
            # Prüfe dass es NICHT im Steam-Verzeichnis ist
            if [[ ! "$real_path" =~ steam ]]; then
                proton_ge_path="$real_path"
                log_debug "Proton GE (manuell) gefunden: $proton_ge_path"
                break
            fi
        fi
    done
    
    # PRIORITÄT 2: AUR-Paket (nur wenn nicht Steam-Verzeichnis)
    if [ -z "$proton_ge_path" ] && command -v pacman &>/dev/null; then
        local proton_ge_pkg_path=$(pacman -Ql proton-ge-custom-bin 2>/dev/null | grep "files/bin/wine$" | head -1 | awk '{print $2}' | xargs dirname | xargs dirname | xargs dirname)
        if [ -n "$proton_ge_pkg_path" ] && [ -d "$proton_ge_pkg_path" ] && [ -f "$proton_ge_pkg_path/files/bin/wine" ]; then
            # Only use if NOT in Steam directory (Steam paths start Steam)
            if [[ ! "$proton_ge_pkg_path" =~ steam ]]; then
                # CRITICAL: Validate that path is safe
                if [[ ! "$proton_ge_pkg_path" =~ ^/tmp|^/var/tmp|^/dev/shm|^/proc ]]; then
                    proton_ge_path="$proton_ge_pkg_path"
                    log_debug "Proton GE (AUR-Paket) gefunden: $proton_ge_path"
                else
                    log_debug "Proton GE Pfad in unsicherem Verzeichnis, überspringe: $proton_ge_pkg_path"
                fi
            fi
        fi
    fi
    
    # PRIORITÄT 3: Standard-System-Pfade (falls vorhanden)
    if [ -z "$proton_ge_path" ]; then
        if [ -d "/usr/share/proton-ge" ] && [ -f "/usr/share/proton-ge/files/bin/wine" ]; then
            proton_ge_path="/usr/share/proton-ge"
        fi
    fi
    
    echo "$proton_ge_path"
}

# ============================================================================
# @function validate_and_configure_proton_ge
# @description Validate Proton GE path and configure environment (PATH, PROTON_PATH)
# @param proton_ge_path - Path to Proton GE installation
# @return 0 on success, 1 on failure
# ============================================================================
validate_and_configure_proton_ge() {
    local proton_ge_path="$1"
    
    if [ -z "$proton_ge_path" ] || [ ! -f "$proton_ge_path/files/bin/wine" ]; then
        return 1
    fi
    
    # CRITICAL: Prevent PATH manipulation - validate proton_ge_path
    # Check that path is not in unsafe directories
    if [[ "$proton_ge_path" =~ ^/tmp|^/var/tmp|^/dev/shm|^/proc ]]; then
        log_error "Proton GE path is in unsafe directory (security risk): $proton_ge_path"
        log "Using standard Wine instead of unsafe Proton GE path"
        return 1
    fi
    
    # CRITICAL: Additional validation - check that wine binary is real
    if [ ! -x "$proton_ge_path/files/bin/wine" ] || [ -L "$proton_ge_path/files/bin/wine" ]; then
        log_error "Proton GE wine binary is not safe (symlink or not executable): $proton_ge_path/files/bin/wine"
        log "Using standard Wine instead of unsafe Proton GE"
        return 1
    fi
    
    # CRITICAL: Extend PATH, but ensure no . in PATH
    local safe_path="$proton_ge_path/files/bin"
    # Remove . from PATH if present
    local clean_path=$(echo "$PATH" | tr ':' '\n' | grep -v '^\.$' | grep -v '^$' | tr '\n' ':' | sed 's/:$//')
    export PATH="$safe_path:${clean_path:-/usr/local/bin:/usr/bin:/bin}"
    export PROTON_PATH="$proton_ge_path"
    export PROTON_VERB=1
    log "✓ Proton GE (system) konfiguriert: $proton_ge_path"
    log_debug "Proton GE Wine-Binary: $proton_ge_path/files/bin/wine"
    
    return 0
}

# ============================================================================
# @function install_proton_ge_auto
# @description Automatically install Proton GE (AUR or manual download)
# @return Installation path if successful, empty string if failed
# ============================================================================
install_proton_ge_auto() {
    local install_success=0
    local proton_ge_install_path=""
    
    # Show installation message
    log_warning "$(i18n::get "proton_ge_path_not_found")"
    log "${C_YELLOW}→${C_RESET} ${C_CYAN}$(i18n::get "starting_proton_ge_installation")${C_RESET}"
    echo ""
    echo -e "${C_CYAN}═══════════════════════════════════════════════════════════════${C_RESET}"
    echo -e "${C_CYAN}           $(i18n::get "proton_ge_installing_now")${C_RESET}"
    echo -e "${C_CYAN}═══════════════════════════════════════════════════════════════${C_RESET}"
    echo ""
    
    # OPTION 1: Try AUR package (Arch-based)
    if command -v yay &> /dev/null || command -v paru &> /dev/null; then
        local aur_helper=""
        if command -v yay &> /dev/null; then
            aur_helper="yay"
        else
            aur_helper="paru"
        fi
        
        local aur_text=$(i18n::get "trying_aur_installation")
        show_message "${C_YELLOW}  →${C_RESET} ${C_CYAN}$(printf "$aur_text" "$aur_helper")${C_RESET}"
        # Use --noconfirm to avoid hanging on user prompts
        log_command $aur_helper -S --noconfirm proton-ge-custom-bin
        if [ $? -eq 0 ]; then
            # Check installation path
            local installed_path=$(pacman -Ql proton-ge-custom-bin 2>/dev/null | grep "files/bin/wine$" | head -1 | awk '{print $2}' | xargs dirname | xargs dirname | xargs dirname)
            if [ -n "$installed_path" ] && [ -d "$installed_path" ]; then
                if [[ "$installed_path" =~ steam ]]; then
                    log "⚠ AUR-Paket installiert in Steam-Verzeichnis - versuche manuelle Installation"
                    install_success=0
                else
                    log "${C_GREEN}✓${C_RESET} ${C_CYAN}Proton GE system-weit installiert: $installed_path${C_RESET}"
                    show_message "${C_GREEN}✓${C_RESET} ${C_CYAN}Proton GE system-weit installiert${C_RESET}"
                    install_success=1
                    proton_ge_install_path="$installed_path"
                fi
            fi
        fi
    fi
    
    # OPTION 2: Manual installation (universal for all Linux distributions)
    if [ $install_success -eq 0 ]; then
        show_message "${C_YELLOW}  →${C_RESET} ${C_CYAN}$(i18n::get "installing_proton_ge_manually")${C_RESET}"
        
        # Determine installation path (system-wide, not Steam)
        local install_base=""
        if [ -w "/usr/local/share" ]; then
            install_base="/usr/local/share/proton-ge"
        elif [ -w "$HOME/.local/share" ]; then
            install_base="$HOME/.local/share/proton-ge"
        else
            install_base="$HOME/.proton-ge"
        fi
        
        log "  → Installationspfad: $install_base"
        mkdir -p "$install_base" 2>/dev/null || {
            log_error "Konnte Installationsverzeichnis nicht erstellen: $install_base"
            install_success=0
        }
        
        if [ -d "$install_base" ]; then
            # Download latest Proton GE version from GitHub
            show_message "${C_YELLOW}  →${C_RESET} ${C_CYAN}$(i18n::get "downloading_latest_proton_ge")${C_RESET}"
            
            # GitHub API: Get latest release version
            local latest_version=$(curl -s https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | head -1)
            
            if [ -z "$latest_version" ]; then
                latest_version="GE-Proton10-26"  # Fallback version
                log "  ⚠ Konnte neueste Version nicht ermitteln, verwende Fallback: $latest_version"
            else
                log "  → Neueste Version gefunden: $latest_version"
            fi
            
            # Download URL
            local download_url="https://github.com/GloriousEggroll/proton-ge-custom/releases/download/${latest_version}/${latest_version}.tar.gz"
            local download_file="$install_base/${latest_version}.tar.gz"
            
            # CRITICAL: Download URL validation
            local download_ok=0
            if [[ "$download_url" =~ ^https://(www\.)?github\.com ]]; then
                log_debug "Download von: $download_url"
                show_message "${C_YELLOW}  →${C_RESET} ${C_CYAN}$(i18n::get "downloading")${C_RESET}"
                
                # Download with progress
                if command -v wget &> /dev/null; then
                    wget -q --show-progress -O "$download_file" "$download_url" 2>&1 | tee -a "$LOG_FILE"
                    [ $? -eq 0 ] && [ -f "$download_file" ] && download_ok=1
                elif command -v curl &> /dev/null; then
                    curl -L --progress-bar -o "$download_file" "$download_url" 2>&1 | tee -a "$LOG_FILE"
                    [ $? -eq 0 ] && [ -f "$download_file" ] && download_ok=1
                else
                    log_error "wget oder curl nicht gefunden - Download nicht möglich"
                fi
            fi
            
            if [ $download_ok -eq 1 ] && [ -f "$download_file" ]; then
                # Extract
                show_message "${C_YELLOW}  →${C_RESET} ${C_CYAN}$(i18n::get "extracting_proton_ge")${C_RESET}"
                tar -xzf "$download_file" -C "$install_base" 2>&1 | tee -a "$LOG_FILE"
                if [ $? -eq 0 ]; then
                    # Check if installation successful
                    local extracted_dir="$install_base/${latest_version}"
                    if [ -d "$extracted_dir" ] && [ -f "$extracted_dir/files/bin/wine" ]; then
                        log "${C_GREEN}✓${C_RESET} ${C_CYAN}Proton GE manuell installiert: $extracted_dir${C_RESET}"
                        show_message "${C_GREEN}✓${C_RESET} ${C_CYAN}Proton GE system-weit installiert${C_RESET}"
                        install_success=1
                        proton_ge_install_path="$extracted_dir"
                        
                        # Create symlink for easier access
                        if [ -d "$install_base" ]; then
                            ln -sfn "$extracted_dir" "$install_base/current" 2>/dev/null || true
                        fi
                    else
                        log_error "Installation unvollständig - wine-Binary nicht gefunden"
                        install_success=0
                    fi
                else
                    log_error "Entpacken fehlgeschlagen"
                    install_success=0
                fi
                
                # Delete download file
                rm -f "$download_file" 2>/dev/null || true
            else
                install_success=0
            fi
        fi
    fi
    
    # Return installation path if successful
    if [ $install_success -eq 1 ] && [ -n "$proton_ge_install_path" ]; then
        echo "$proton_ge_install_path"
        return 0
    else
        echo ""
        return 1
    fi
}

# Prompt user if they want to install Proton GE
# Returns: 0 if user wants to install, 1 if not
prompt_install_proton_ge() {
    local system="$1"
    
    log ""
    log "═══════════════════════════════════════════════════════════════"
    log "           $(i18n::get "important_select_wine_version")"
    log "═══════════════════════════════════════════════════════════════"
    log ""
    log "ℹ System erkannt: $system"
    log ""
    log "Für Photoshop gibt es zwei Möglichkeiten:"
    log ""
    log "  1. PROTON GE (EMPFOHLEN)"
    log "     → Bessere Kompatibilität, weniger Fehler"
    log "     → Wird jetzt automatisch installiert (ca. 2-5 Minuten)"
    log ""
    log "  2. STANDARD WINE (Fallback)"
    log "     → Bereits installiert, funktioniert meist auch"
    log "     → Installation startet sofort"
    log ""
    log "═══════════════════════════════════════════════════════════════"
    log ""
    log "Was möchtest du tun?"
    log ""
    log "   [J] Ja - Proton GE installieren (EMPFOHLEN für beste Ergebnisse)"
    log "   [N] Nein - Mit Standard-Wine fortfahren (schneller, aber weniger optimal)"
    log ""
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "           $(i18n::get "important_select_wine_version")"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "ℹ System erkannt: $system"
    echo ""
    echo "Für Photoshop gibt es zwei Möglichkeiten:"
    echo ""
    echo "  1. PROTON GE (EMPFOHLEN)"
    echo "     → Bessere Kompatibilität, weniger Fehler"
    echo "     → Wird jetzt automatisch installiert (ca. 2-5 Minuten)"
    echo ""
    echo "  2. STANDARD WINE (Fallback)"
    echo "     → Bereits installiert, funktioniert meist auch"
    echo "     → Installation startet sofort"
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "Was möchtest du tun?"
    echo ""
    echo "   [J] Ja - Proton GE installieren (EMPFOHLEN für beste Ergebnisse)"
    echo "   [N] Nein - Mit Standard-Wine fortfahren (schneller, aber weniger optimal)"
    echo ""
    log_prompt "Deine Wahl [J/n]: "
    IFS= read -r -p "Deine Wahl [J/n]: " install_proton
    log_input "$install_proton"
    
    if [[ "$install_proton" =~ ^[JjYy]$ ]] || [ -z "$install_proton" ]; then
        return 0  # User wants to install
    else
        return 1  # User wants to use standard Wine
    fi
}

# Install Proton GE interactively with all steps
# Returns: 0 on success, 1 on failure
install_proton_ge_interactive() {
    log ""
    log "═══════════════════════════════════════════════════════════════"
    log "           Proton GE wird jetzt installiert"
    log "═══════════════════════════════════════════════════════════════"
    log ""
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "           Proton GE wird jetzt installiert"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    
    # Step 1: Check if Wine is installed
    log "SCHRITT 1/2: Prüfe ob Wine installiert ist..."
    echo "SCHRITT 1/2: Prüfe ob Wine installiert ist..."
    echo ""
    if ! command -v wine &> /dev/null; then
        log "⚠ Wine fehlt noch - wird jetzt installiert..."
        log "   (Wine wird für die Photoshop-Komponenten benötigt)"
        echo "⚠ Wine fehlt noch - wird jetzt installiert..."
        echo "   (Wine wird für die Photoshop-Komponenten benötigt)"
        echo ""
        if command -v pacman &> /dev/null; then
            log_command sudo pacman -S wine
        else
            log "   Bitte installiere Wine manuell für deine Distribution"
            echo "   Bitte installiere Wine manuell für deine Distribution"
            log_prompt "Drücke Enter, wenn Wine installiert wurde: "
            IFS= read -r -p "Drücke Enter, wenn Wine installiert wurde: " wait_wine
            log_input "$wait_wine"
        fi
        log ""
        echo ""
    else
        log "✓ Wine ist bereits installiert"
        echo "✓ Wine ist bereits installiert"
        echo ""
    fi
    
    # Step 2: Install Proton GE
    log "SCHRITT 2/2: Installiere Proton GE system-weit (unabhängig von Steam)..."
    log "   (Dies kann 2-5 Minuten dauern - bitte warten...)"
    log "   → WICHTIG: Proton GE wird system-weit installiert, NICHT in Steam-Verzeichnis"
    echo "SCHRITT 2/2: Installiere Proton GE system-weit (unabhängig von Steam)..."
    echo "   (Dies kann 2-5 Minuten dauern - bitte warten...)"
    echo "   → WICHTIG: System-weite Installation, NICHT in Steam-Verzeichnis"
    echo ""
    
    local install_success=0
    local proton_ge_install_path=""
    
    # OPTION 1: Try AUR package (Arch-based)
    if command -v yay &> /dev/null || command -v paru &> /dev/null; then
        local aur_helper=""
        if command -v yay &> /dev/null; then
            aur_helper="yay"
        else
            aur_helper="paru"
        fi
        
        log "  → Versuche Installation über AUR ($aur_helper)..."
        log_command $aur_helper -S --noconfirm proton-ge-custom-bin
        if [ $? -eq 0 ]; then
            local proton_ge_path=$(pacman -Ql proton-ge-custom-bin 2>/dev/null | grep "files/bin/wine$" | head -1 | awk '{print $2}' | xargs dirname | xargs dirname | xargs dirname)
            if [ -n "$proton_ge_path" ] && [ -d "$proton_ge_path" ]; then
                if [[ "$proton_ge_path" =~ steam ]]; then
                    log "⚠ AUR-Paket installiert in Steam-Verzeichnis - überspringe"
                    log "   → Installiere Proton GE manuell system-weit..."
                    install_success=0
                else
                    log "✓ Proton GE system-weit installiert: $proton_ge_path"
                    echo "✓ Proton GE system-weit installiert"
                    install_success=1
                    proton_ge_install_path="$proton_ge_path"
                fi
            fi
        fi
    fi
    
    # OPTION 2: Manual installation (universal for all Linux distributions)
    if [ $install_success -eq 0 ]; then
        log "  → Installiere Proton GE manuell system-weit..."
        echo "  → Installiere Proton GE manuell system-weit..."
        
        local install_base=""
        if [ -w "/usr/local/share" ]; then
            install_base="/usr/local/share/proton-ge"
        elif [ -w "$HOME/.local/share" ]; then
            install_base="$HOME/.local/share/proton-ge"
        else
            install_base="$HOME/.proton-ge"
        fi
        
        log "  → Installationspfad: $install_base"
        
        mkdir -p "$install_base" 2>/dev/null || {
            log_error "Konnte Installationsverzeichnis nicht erstellen: $install_base"
            install_success=0
        }
        
        if [ -d "$install_base" ]; then
            log "  → Lade neueste Proton GE Version herunter..."
            echo "  → Lade neueste Proton GE Version herunter..."
            
            local latest_version=$(curl -s https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | head -1)
            
            if [ -z "$latest_version" ]; then
                latest_version="GE-Proton10-26"
                log "  ⚠ Konnte neueste Version nicht ermitteln, verwende Fallback: $latest_version"
            else
                log "  → Neueste Version gefunden: $latest_version"
            fi
            
            local download_url="https://github.com/GloriousEggroll/proton-ge-custom/releases/download/${latest_version}/${latest_version}.tar.gz"
            local download_file="$install_base/${latest_version}.tar.gz"
            
            # URL validation
            local download_ok=0
            if [[ "$download_url" =~ ^https:// ]] && [[ "$download_url" =~ ^https://(www\.)?github\.com ]]; then
                log "  → Download von: $download_url"
                echo "  → Download läuft..."
                
                if command -v wget &> /dev/null; then
                    wget -q --show-progress -O "$download_file" "$download_url" 2>&1 | tee -a "$LOG_FILE"
                    if [ $? -eq 0 ] && [ -f "$download_file" ]; then
                        download_ok=1
                    else
                        log_error "Download fehlgeschlagen"
                    fi
                elif command -v curl &> /dev/null; then
                    curl -L --progress-bar -o "$download_file" "$download_url" 2>&1 | tee -a "$LOG_FILE"
                    if [ $? -eq 0 ] && [ -f "$download_file" ]; then
                        download_ok=1
                    else
                        log_error "Download fehlgeschlagen"
                    fi
                else
                    log_error "wget oder curl nicht gefunden - Download nicht möglich"
                fi
            else
                log_error "Ungültige Download-URL: $download_url"
            fi
            
            if [ $download_ok -eq 1 ] && [ -f "$download_file" ]; then
                log "  → Entpacke Proton GE..."
                echo "  → Entpacke Proton GE..."
                tar -xzf "$download_file" -C "$install_base" 2>&1 | tee -a "$LOG_FILE"
                if [ $? -eq 0 ]; then
                    local extracted_dir="$install_base/${latest_version}"
                    if [ -d "$extracted_dir" ] && [ -f "$extracted_dir/files/bin/wine" ]; then
                        log "✓ Proton GE manuell installiert: $extracted_dir"
                        echo "✓ Proton GE system-weit installiert"
                        install_success=1
                        proton_ge_install_path="$extracted_dir"
                        
                        if [ -d "$install_base" ]; then
                            ln -sfn "$extracted_dir" "$install_base/current" 2>/dev/null || true
                        fi
                    else
                        log_error "Installation unvollständig - wine-Binary nicht gefunden"
                        install_success=0
                    fi
                else
                    log_error "Entpacken fehlgeschlagen"
                    install_success=0
                fi
                
                rm -f "$download_file" 2>/dev/null || true
            else
                install_success=0
            fi
        fi
    fi
    
    # Handle installation result
    if [ $install_success -eq 0 ]; then
        log "⚠ Automatische Installation fehlgeschlagen"
        echo ""
        echo "⚠ Automatische Proton GE Installation fehlgeschlagen"
        echo ""
        echo "$(i18n::get "you_can_install_proton_ge_manually")"
        echo "  1. Lade von: https://github.com/GloriousEggroll/proton-ge-custom/releases"
        echo "  2. Entpacke nach: $HOME/.local/share/proton-ge/"
        echo "  3. Oder verwende Standard-Wine (funktioniert auch)"
        echo ""
        log_prompt "   [J] Ja - Mit Standard-Wine fortfahren  [N] Nein - Abbrechen [J/n]: "
        IFS= read -r -p "   [J] Ja - Mit Standard-Wine fortfahren  [N] Nein - Abbrechen [J/n]: " continue_with_wine
        log_input "$continue_with_wine"
        
        if [[ "$continue_with_wine" =~ ^[Nn]$ ]]; then
            log_error "Installation abgebrochen"
            error "$(i18n::get "installation_cancelled")"
            return 1
        fi
        return 2  # User wants to continue with standard Wine
    fi
    
    # Success - re-detect versions
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "           ✓ Proton GE erfolgreich installiert!"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "Jetzt stehen dir mehrere Optionen zur Verfügung:"
    echo "   → Du kannst zwischen Proton GE und Standard-Wine wählen"
    echo ""
    echo "Suche verfügbare Versionen..."
    echo ""
    
    detect_all_wine_versions
    
    return 0  # Success
}

# Handle the case when only one Wine option is available
# Returns: selection number or empty string
# Show interactive menu for Wine/Proton selection
# Returns: selected option number via echo
show_wine_selection_menu() {
    local system="$1"
    local has_proton="$2"
    
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "           $(i18n::get "select_wine_proton_version")"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    
    # Show system detection
    echo "$(i18n::get "system_detected" "$system")"
    if [ "$system" = "cachyos" ] || [ "$system" = "arch" ] || [ "$system" = "manjaro" ]; then
        echo "$(i18n::get "proton_recommended_arch")"
        if [ $has_proton -eq 0 ]; then
            echo ""
            echo "$(i18n::get "proton_not_found_warning")"
            echo "$(i18n::get "install_proton_yay")"
            echo "$(i18n::get "install_proton_paru")"
            echo ""
        fi
    fi
    echo ""
    
    # Display options
    for i in "${!WINE_OPTIONS[@]}"; do
        local opt_num="${WINE_OPTIONS[$i]}"
        local desc="${WINE_DESCRIPTIONS[$i]}"
        echo "  [$opt_num] $desc"
    done
    
    echo ""
    
    # Get user selection with recommended default
    local default_choice=$WINE_RECOMMENDED
    local valid_options=$(IFS=,; echo "${WINE_OPTIONS[*]}")
    local selection=""
    
    while true; do
        IFS= read -r -p "$(i18n::get "choose_option_wine" "$valid_options" "$default_choice") " selection
        
        # Default to recommended option
        if [ -z "$selection" ]; then
            selection=$default_choice
        fi
        
        # Validate selection - check if it exists in WINE_OPTIONS array
        local is_valid=0
        if [[ "$selection" =~ ^[0-9]+$ ]]; then
            for opt in "${WINE_OPTIONS[@]}"; do
                if [ "$opt" = "$selection" ]; then
                    is_valid=1
                    break
                fi
            done
        fi
        
        if [ $is_valid -eq 1 ]; then
            break
        else
            echo "$(i18n::get "invalid_selection" "$valid_options")"
        fi
    done
    
    echo "$selection"
}

# Find index of selected Wine option
# Returns: index via echo, -1 if not found
find_selected_wine_index() {
    local selection="$1"
    local selected_index=-1
    
    for i in "${!WINE_OPTIONS[@]}"; do
        if [ "${WINE_OPTIONS[$i]}" = "$selection" ]; then
            selected_index=$i
            break
        fi
    done
    
    echo "$selected_index"
}

# Configure Wine environment based on selected path
configure_selected_wine() {
    local selected_path="$1"
    local selected_desc="$2"
    
    # Display selection result (structured, clean - only log details)
    log "Ausgewählte Version: $selected_desc"
    log "Pfad: $selected_path"
    
    # Configure environment based on selection
    # NOTE: Proton GE from Steam directory is no longer used (it starts Steam)
    if [ "$selected_path" = "system" ]; then
        # System-wide Proton GE - find the actual path
        local proton_ge_path
        proton_ge_path=$(find_proton_ge_path)
        
        if [ -n "$proton_ge_path" ] && [ -f "$proton_ge_path/files/bin/wine" ]; then
            # CRITICAL: Validate path before using
            if security::validate_path "$proton_ge_path" "configure_selected_wine"; then
                export PROTON_PATH="$proton_ge_path"
                export PROTON_VERB="runinprefix"
                log "✓ Proton GE (system) konfiguriert: $proton_ge_path"
            else
                log "Using standard Wine instead of unsafe Proton GE path"
                export PROTON_PATH=""
            fi
        else
            log "Proton GE path not found, using standard Wine"
            export PROTON_PATH=""
        fi
    else
        # Standard Wine or Wine Staging
        export PROTON_PATH=""
        log "✓ Standard-Wine konfiguriert"
    fi
}

handle_single_wine_option() {
    local system="$1"
    local has_proton="$2"
    
    local selection=1
    
    # Skip prompt if WINE_METHOD is already set
    if [ -n "$WINE_METHOD" ]; then
        log_debug "WINE_METHOD bereits gesetzt ($WINE_METHOD) - überspringe Proton GE Abfrage"
        debug_log "PhotoshopSetup.sh:527" "WINE_METHOD check - skipping prompt" "{\"WINE_METHOD\":\"${WINE_METHOD}\",\"count\":1}" "H1"
        echo "$selection"
        return 0
    fi
    
    # If no Proton GE and on Arch-based system, offer to install
    if [ $has_proton -eq 0 ] && ([ "$system" = "cachyos" ] || [ "$system" = "arch" ] || [ "$system" = "manjaro" ]); then
        if prompt_install_proton_ge "$system"; then
            local install_result
            install_proton_ge_interactive
            install_result=$?
            
            if [ $install_result -eq 1 ]; then
                # Installation cancelled
                return 1
            elif [ $install_result -eq 2 ]; then
                # User wants to use standard Wine
                selection=1
                echo ""
                echo "→ Verwende Standard-Wine..."
                echo ""
                echo "$selection"
                return 0
            fi
            
            # Installation successful - find Proton GE
            local proton_index=-1
            for i in "${!WINE_PATHS[@]}"; do
                if [ "${WINE_PATHS[$i]}" = "system" ]; then
                    proton_index=$i
                    break
                fi
            done
            
            if [ $proton_index -ge 0 ]; then
                selection="${WINE_OPTIONS[$proton_index]}"
                echo "✓ Verwende automatisch: ${WINE_DESCRIPTIONS[$proton_index]}"
                echo ""
                echo "→ Installation wird jetzt automatisch fortgesetzt..."
                echo ""
            else
                selection=1
                echo "✓ Verwende: ${WINE_DESCRIPTIONS[0]}"
                echo ""
                echo "→ Installation wird jetzt automatisch fortgesetzt..."
                echo ""
            fi
        else
            # User chose standard Wine
            echo ""
            echo "═══════════════════════════════════════════════════════════════"
            echo "           Installation mit Standard-Wine"
            echo "═══════════════════════════════════════════════════════════════"
            echo ""
            echo "Verwende: ${WINE_DESCRIPTIONS[0]}"
            echo ""
            echo "ℹ Hinweis: Standard-Wine funktioniert meist auch,"
            echo "   aber Proton GE bietet bessere Kompatibilität."
            echo "   Du kannst später jederzeit auf Proton GE umsteigen."
            echo ""
            selection=1
        fi
    fi
    
    echo "$selection"
    return 0
}

# Interactive selection of Wine/Proton version
select_wine_version() {
    log_debug "=== select_wine_version() gestartet ==="
    local count=0
    local system=$(detect_system)
    log_debug "System erkannt: $system"
    local selection=""  # Declare at function start
    
    log_debug "Rufe detect_all_wine_versions() auf..."
    detect_all_wine_versions
    count=$?
    log_debug "detect_all_wine_versions() zurückgegeben: $count Optionen gefunden"
    
    if [ $count -eq 0 ]; then
        log_error "Keine Wine/Proton-Version gefunden!"
        error "$(i18n::get "no_wine_proton_found")"
        return 1
    fi
    
    # Handle command line parameter (--wine-standard/--proton-ge)
    local param_selection
    param_selection=$(handle_wine_method_parameter)
    if [ -n "$param_selection" ]; then
        selection="$param_selection"
        # Parameter was handled successfully, selection is set
        # Continue to setup_wine_environment with the selected option
    fi
    
    # Check if no Proton GE found (only Wine available) - show warning
    local has_proton=0
    for path in "${WINE_PATHS[@]}"; do
        # Only system-wide Proton GE is used (not Steam Proton)
        if [ "$path" = "system" ]; then
            has_proton=1
            break
        fi
    done
    
    # If only one option available, use it automatically (no menu)
    # BUT: Skip if selection is already set via command line parameter
    if [ $count -eq 1 ] && [ -z "$selection" ]; then
        local single_selection
        single_selection=$(handle_single_wine_option "$system" "$has_proton")
        if [ $? -ne 0 ]; then
            return 1  # User cancelled
        fi
        selection="$single_selection"
        
        # If selection is empty (after Proton GE installation), jump to menu
        if [ -z "$selection" ]; then
            # Re-detect to get updated count
            detect_all_wine_versions
            count=$?
        fi
    fi
    
    # If count > 1 AND selection is empty, show menu
    # If selection is already set (after auto-install), skip menu
    if [ $count -gt 1 ] && [ -z "$selection" ]; then
        selection=$(show_wine_selection_menu "$system" "$has_proton")
    fi
    
    # Find selected option index
    local selected_index
    log_debug "DEBUG: selection='$selection'"
    log_debug "DEBUG: WINE_OPTIONS=(${WINE_OPTIONS[*]})"
    log_debug "DEBUG: WINE_PATHS=(${WINE_PATHS[*]})"
    selected_index=$(find_selected_wine_index "$selection")
    log_debug "DEBUG: selected_index=$selected_index"
    
    if [ "$selected_index" = "-1" ]; then
        log_error "DEBUG: Selection '$selection' not found in WINE_OPTIONS=(${WINE_OPTIONS[*]})"
        error "$(i18n::get "selection_not_found")"
        return 1
    fi
    
    # Setup selected version
    local selected_path="${WINE_PATHS[$selected_index]}"
    local selected_desc="${WINE_DESCRIPTIONS[$selected_index]}"
    
    # Configure environment based on selection
    configure_selected_wine "$selected_path" "$selected_desc"
    
    return 0
}

# Setup Wine environment (wrapper for compatibility)
setup_wine_environment() {
    select_wine_version
}

# Localized messages - now using i18n::get instead of MSG_* variables

function main() {
    # CRITICAL: Trap for CTRL+C (INT) and other signals
    trap 'echo ""; echo "Installation abgebrochen durch Benutzer (STRG+C)"; log_error "Installation abgebrochen durch Benutzer (STRG+C)"; exit 130' INT TERM HUP
    
    # Check for updates in background (non-blocking)
    # Use type instead of command -v for namespace functions (::)
    if type update::check_async >/dev/null 2>&1; then
        update::check_async
    fi
    # Enable comprehensive logging - ALL output will be logged automatically
    setup_comprehensive_logging

    # CRITICAL: Set PS_VERSION early, before it's used
    # Will be set again later in install_photoshopSE(), but needed here for main()
    PS_VERSION=$(detect_photoshop_version)
    PS_INSTALL_PATH=$(get_photoshop_install_path "$PS_VERSION")
    PS_PREFS_PATH=$(get_photoshop_prefs_path "$PS_VERSION")
    
    # Start logging immediately with comprehensive system info
    # Write header to log file (not to console)
    echo "" >> "$LOG_FILE"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ═══════════════════════════════════════════════════════════" >> "$LOG_FILE"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Adobe Photoshop CC Linux Installer - Installation gestartet" >> "$LOG_FILE"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ═══════════════════════════════════════════════════════════" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
    
    # Show installation header (modern style)
    output::header "$(i18n::get "photoshop_installer")"
    
    if [ "${DEBUG:-0}" = "1" ]; then
        output::log_path "Log file" "$LOG_FILE"
        output::log_path "Debug log" "$DEBUG_LOG"
    fi
    echo ""
    
    # System checks (compact display)
    output::step "$(i18n::get "checking_system_requirements")"
    output::substep "$(i18n::get "system_architecture")"
    is64 >/dev/null 2>&1 || true
    
    # Package checks (compact display)
    output::substep "$(i18n::get "required_packages")"
    package_installed wine >/dev/null 2>&1 || package_installed wine
    package_installed md5sum >/dev/null 2>&1 || package_installed md5sum
    package_installed winetricks >/dev/null 2>&1 || package_installed winetricks
    echo "" >> "$LOG_FILE"
    
    # Setup Wine environment - interactive selection
    # This will show a menu and ask the user to choose
    output::step "$(i18n::get "wine_proton_selection")"
    log_debug "Rufe setup_wine_environment() auf..."
    log_environment
    if ! setup_wine_environment; then
        log_error "setup_wine_environment() fehlgeschlagen!"
        error "$(i18n::get "proton_ge_not_found")"
        exit 1
    fi
    log_debug "setup_wine_environment() erfolgreich abgeschlossen"
    log_environment
    
    # Confirm selection
    # CRITICAL: Initialize PROTON_PATH if not set (for set -u)
    export PROTON_PATH="${PROTON_PATH:-}"
    if [ -n "$PROTON_PATH" ] && [ "$PROTON_PATH" != "system" ]; then
        show_message "${C_GREEN}✓${C_RESET} ${C_CYAN}$(i18n::get "using_proton_ge")${C_RESET}"
        log "Proton GE aktiviert: $PROTON_PATH"
    elif [ "$PROTON_PATH" = "system" ]; then
        show_message "${C_GREEN}✓${C_RESET} ${C_CYAN}$(i18n::get "using_proton_ge_system")${C_RESET}"
        log "Proton GE (system) aktiviert"
    else
        show_message "${C_GREEN}✓${C_RESET} ${C_CYAN}$(i18n::get "using_standard_wine")${C_RESET}"
        log "Standard-Wine aktiviert"
    fi
    log ""
    
    # Rest of main() function continues...
    # (The rest of the function should be from the correct main() at line 2299)
}

# Setup Wine environment (wrapper for compatibility)
setup_wine_environment() {
    select_wine_version
}

# Localized messages - now using i18n::get instead of MSG_* variables

# Detect Photoshop version from installer files or directory structure
# Uses multiple methods: pev/peres tool, directory structure, or file metadata
detect_photoshop_version() {
    local installer_dir="$PROJECT_ROOT/photoshop"
    local version=""  # Start empty, detect properly
    local setup_exe="$installer_dir/Set-up.exe"
    
    if [ ! -f "$setup_exe" ]; then
        log_debug "detect_photoshop_version: Set-up.exe not found, using default CC 2019"
        echo "CC 2019"
        return 0
    fi
    
    # METHOD 1: Check XML files FIRST (MOST RELIABLE for Adobe installers)
    # Driver.xml contains <Name>Photoshop 2021</Name> and <CodexVersion>22.0</CodexVersion>
    # This is the most reliable method for Adobe installers
    log_debug "detect_photoshop_version: METHOD 1 - checking XML files (most reliable)"
    if [ -f "$installer_dir/products/Driver.xml" ]; then
        log_debug "detect_photoshop_version: checking Driver.xml"
        local name_line=$(grep -iE "<Name>.*Photoshop.*</Name>" "$installer_dir/products/Driver.xml" 2>/dev/null | head -1)
        log_debug "detect_photoshop_version: found Name line: $name_line"
        if [ -n "$name_line" ]; then
            if echo "$name_line" | grep -qiE "2022"; then
                version="2022"
                log_debug "detect_photoshop_version: METHOD 1 detected 2022 from Driver.xml Name"
            elif echo "$name_line" | grep -qiE "2021"; then
                version="2021"
                log_debug "detect_photoshop_version: METHOD 1 detected 2021 from Driver.xml Name"
            elif echo "$name_line" | grep -qiE "CC 2019|2019"; then
                version="CC 2019"
                log_debug "detect_photoshop_version: METHOD 1 detected CC 2019 from Driver.xml Name"
            fi
        fi
        # Also check CodexVersion/BaseVersion (22.0 = 2021, 23.0 = 2022, 20.x = CC 2019)
        if [ -z "$version" ]; then
            local codex_version=$(grep -iE "<CodexVersion>|<BaseVersion>" "$installer_dir/products/Driver.xml" 2>/dev/null | grep -oE "[0-9]+\.[0-9]+" | head -1)
            log_debug "detect_photoshop_version: found CodexVersion/BaseVersion: $codex_version"
            if [ -n "$codex_version" ]; then
                local major_ver=$(echo "$codex_version" | cut -d. -f1)
                if [ "$major_ver" -ge 23 ]; then
                    version="2022"
                    log_debug "detect_photoshop_version: METHOD 1 detected 2022 from CodexVersion $codex_version"
                elif [ "$major_ver" -ge 22 ]; then
                    version="2021"
                    log_debug "detect_photoshop_version: METHOD 1 detected 2021 from CodexVersion $codex_version"
                elif [ "$major_ver" -ge 20 ]; then
                    version="CC 2019"
                    log_debug "detect_photoshop_version: METHOD 1 detected CC 2019 from CodexVersion $codex_version"
                fi
            fi
        fi
    fi
    
    # METHOD 2: Try to extract version from EXE using multiple tools
    # Based on: https://askubuntu.com/questions/23454/how-to-view-a-pe-exe-dll-file-version-information
    # and https://superuser.com/questions/1159092/getting-info-about-windows-executables-on-a-linux-system
    if [ -z "$version" ]; then
        # Try peres first (lightweight)
        if command -v peres >/dev/null 2>&1; then
            local exe_version=$(peres -v "$setup_exe" 2>/dev/null | awk '{print $3}' | head -1)
            log_debug "detect_photoshop_version: peres found version: $exe_version"
            if [ -n "$exe_version" ] && [[ "$exe_version" =~ ^[0-9] ]]; then
                local major_version=$(echo "$exe_version" | cut -d. -f1)
                log_debug "detect_photoshop_version: major_version=$major_version"
                if [ "$major_version" -ge 23 ]; then
                    version="2022"
                elif [ "$major_version" -ge 22 ]; then
                    version="2021"
                elif [ "$major_version" -ge 20 ]; then
                    version="CC 2019"
                fi
                log_debug "detect_photoshop_version: METHOD 2 (peres) detected: $version"
            fi
        # Try ExifTool (more comprehensive, shows Product Version)
        # See: https://superuser.com/questions/1159092/getting-info-about-windows-executables-on-a-linux-system
        elif command -v exiftool >/dev/null 2>&1; then
            log_debug "detect_photoshop_version: trying ExifTool"
            local product_version=$(exiftool "$setup_exe" 2>/dev/null | grep -iE "Product Version|File Version" | head -1 | grep -oE "[0-9]+\.[0-9]+" | head -1)
            log_debug "detect_photoshop_version: ExifTool found version: $product_version"
            if [ -n "$product_version" ]; then
                local major_version=$(echo "$product_version" | cut -d. -f1)
                if [ "$major_version" -ge 23 ]; then
                    version="2022"
                elif [ "$major_version" -ge 22 ]; then
                    version="2021"
                elif [ "$major_version" -ge 20 ]; then
                    version="CC 2019"
                fi
                log_debug "detect_photoshop_version: METHOD 2 (ExifTool) detected: $version"
            fi
        # Try pev as fallback
        elif command -v pev >/dev/null 2>&1; then
            log_debug "detect_photoshop_version: trying pev"
            local exe_version=$(pev "$setup_exe" 2>/dev/null | grep -iE "version" | head -1 | grep -oE "[0-9]+\.[0-9]+\.[0-9]+" | head -1)
            log_debug "detect_photoshop_version: pev found version: $exe_version"
            if [ -n "$exe_version" ]; then
                local major_version=$(echo "$exe_version" | cut -d. -f1)
                if [ "$major_version" -ge 23 ]; then
                    version="2022"
                elif [ "$major_version" -ge 22 ]; then
                    version="2021"
                elif [ "$major_version" -ge 20 ]; then
                    version="CC 2019"
                fi
                log_debug "detect_photoshop_version: METHOD 2 (pev) detected: $version"
            fi
        else
            log_debug "detect_photoshop_version: peres/ExifTool/pev not found, trying other methods"
        fi
    fi
    
    # METHOD 3: Check directory structure in installer
    if [ -z "$version" ]; then
        log_debug "detect_photoshop_version: METHOD 3 - checking directory structure"
        # Check for version-specific directories in root
        for dir in "$installer_dir"/Adobe\ Photoshop*; do
            if [ -d "$dir" ]; then
                local dirname=$(basename "$dir")
                log_debug "detect_photoshop_version: found directory: $dirname"
                if [[ "$dirname" =~ "2022" ]]; then
                    version="2022"
                    log_debug "detect_photoshop_version: METHOD 3 detected 2022 from directory"
                    break
                elif [[ "$dirname" =~ "2021" ]]; then
                    version="2021"
                    log_debug "detect_photoshop_version: METHOD 3 detected 2021 from directory"
                    break
                elif [[ "$dirname" =~ "CC 2019" ]] || [[ "$dirname" =~ "2019" ]]; then
                    if [ -z "$version" ]; then
                        version="CC 2019"
                        log_debug "detect_photoshop_version: METHOD 3 detected CC 2019 from directory"
                    fi
                    break
                fi
            fi
        done
        
        # Also check in packages and products subdirectories
        if [ -z "$version" ] || [ "$version" = "CC 2019" ]; then
            for subdir in "$installer_dir/packages" "$installer_dir/products"; do
                if [ -d "$subdir" ]; then
                    for dir in "$subdir"/*; do
                        if [ -d "$dir" ]; then
                            local dirname=$(basename "$dir")
                            log_debug "detect_photoshop_version: found subdirectory: $dirname"
                            if [[ "$dirname" =~ "2022" ]] || [[ "$dirname" =~ "23\." ]]; then
                                version="2022"
                                log_debug "detect_photoshop_version: METHOD 3 detected 2022 from subdirectory"
                                break 2
                            elif [[ "$dirname" =~ "2021" ]] || [[ "$dirname" =~ "22\." ]]; then
                                version="2021"
                                log_debug "detect_photoshop_version: METHOD 3 detected 2021 from subdirectory"
                                break 2
                            elif [[ "$dirname" =~ "CC 2019" ]] || [[ "$dirname" =~ "2019" ]] || [[ "$dirname" =~ "20\." ]]; then
                                if [ -z "$version" ]; then
                                    version="CC 2019"
                                    log_debug "detect_photoshop_version: METHOD 3 detected CC 2019 from subdirectory"
                                fi
                            fi
                        fi
                    done
                fi
            done
        fi
    fi
    
    # METHOD 4: Try to extract version from strings in EXE (fallback)
    if [ -z "$version" ] || [ "$version" = "CC 2019" ]; then
        if command -v strings >/dev/null 2>&1; then
            log_debug "detect_photoshop_version: METHOD 3 - checking strings in EXE"
            # Try multiple patterns to find version
            local version_string=$(strings "$setup_exe" 2>/dev/null | grep -iE "(photoshop|adobe).*(202[12]|22\.|23\.|20\.|CC 2019|2019)" | head -5)
            log_debug "detect_photoshop_version: found version strings: $version_string"
            if [ -n "$version_string" ]; then
                # Check for 2022 first (most specific)
                if echo "$version_string" | grep -qiE "2022|23\."; then
                    version="2022"
                    log_debug "detect_photoshop_version: METHOD 3 detected 2022"
                # Check for 2021 (v22.x)
                elif echo "$version_string" | grep -qiE "2021|22\."; then
                    version="2021"
                    log_debug "detect_photoshop_version: METHOD 3 detected 2021"
                # Check for CC 2019 (v20.x)
                elif echo "$version_string" | grep -qiE "CC 2019|2019|20\."; then
                    if [ -z "$version" ]; then
                        version="CC 2019"
                        log_debug "detect_photoshop_version: METHOD 3 detected CC 2019"
                    fi
                fi
            fi
        fi
    fi
    
    # METHOD 5: Check for version in any files in installer directory
    if [ -z "$version" ] || [ "$version" = "CC 2019" ]; then
        log_debug "detect_photoshop_version: METHOD 5 - checking files in installer directory"
        for file in "$installer_dir"/*; do
            if [ -f "$file" ]; then
                local filename=$(basename "$file")
                if [[ "$filename" =~ "2022" ]]; then
                    version="2022"
                    log_debug "detect_photoshop_version: METHOD 5 detected 2022 from file: $filename"
                    break
                elif [[ "$filename" =~ "2021" ]]; then
                    version="2021"
                    log_debug "detect_photoshop_version: METHOD 5 detected 2021 from file: $filename"
                    break
                fi
            fi
        done
    fi
    
    # Fallback to CC 2019 if nothing detected
    if [ -z "$version" ]; then
        version="CC 2019"
        log_debug "detect_photoshop_version: No version detected, using default CC 2019"
    fi
    
    log_debug "detect_photoshop_version: FINAL RESULT: $version"
    echo "$version"
}

# Get Photoshop installation path based on version
get_photoshop_install_path() {
    local version="${1:-CC 2019}"
    local wine_prefix="${WINE_PREFIX:-$SCR_PATH/prefix}"
    local user="${USER:-$(id -un)}"
    
    # Convert version to path format
    if [[ "$version" =~ "CC 2019" ]]; then
        echo "$wine_prefix/drive_c/Program Files/Adobe/Adobe Photoshop CC 2019"
    elif [[ "$version" =~ "2021" ]]; then
        echo "$wine_prefix/drive_c/Program Files/Adobe/Adobe Photoshop 2021"
    elif [[ "$version" =~ "2022" ]]; then
        echo "$wine_prefix/drive_c/Program Files/Adobe/Adobe Photoshop 2022"
    else
        # Fallback to CC 2019 path
        echo "$wine_prefix/drive_c/Program Files/Adobe/Adobe Photoshop CC 2019"
    fi
}

# Get Photoshop preferences path based on version
get_photoshop_prefs_path() {
    local version="${1:-CC 2019}"
    local wine_prefix="${WINE_PREFIX:-$SCR_PATH/prefix}"
    local user="${USER:-$(id -un)}"
    
    # Convert version to preferences path format
    if [[ "$version" =~ "CC 2019" ]]; then
        echo "$wine_prefix/drive_c/users/$user/AppData/Roaming/Adobe/Adobe Photoshop CC 2019"
    elif [[ "$version" =~ "2021" ]]; then
        echo "$wine_prefix/drive_c/users/$user/AppData/Roaming/Adobe/Adobe Photoshop 2021"
    elif [[ "$version" =~ "2022" ]]; then
        echo "$wine_prefix/drive_c/users/$user/AppData/Roaming/Adobe/Adobe Photoshop 2022"
    else
        # Fallback to CC 2019 path
        echo "$wine_prefix/drive_c/users/$user/AppData/Roaming/Adobe/Adobe Photoshop CC 2019"
    fi
}

function main() {
    # CRITICAL: Trap for CTRL+C (INT) and other signals
    trap 'echo ""; echo "Installation abgebrochen durch Benutzer (STRG+C)"; log_error "Installation abgebrochen durch Benutzer (STRG+C)"; exit 130' INT TERM HUP
    
    # Check for updates in background (non-blocking)
    # Use type instead of command -v for namespace functions (::)
    if type update::check_async >/dev/null 2>&1; then
        update::check_async
    fi
    
    # Enable comprehensive logging - ALL output will be logged automatically
    setup_comprehensive_logging
    
    # CRITICAL: Set PS_VERSION early, before it's used
    # Will be set again later in install_photoshopSE(), but needed here for main()
    PS_VERSION=$(detect_photoshop_version)
    PS_INSTALL_PATH=$(get_photoshop_install_path "$PS_VERSION")
    PS_PREFS_PATH=$(get_photoshop_prefs_path "$PS_VERSION")
    
    # Start logging immediately with comprehensive system info
    # Write header to log file (not to console)
    echo "" >> "$LOG_FILE"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ═══════════════════════════════════════════════════════════" >> "$LOG_FILE"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Photoshop Installation gestartet: $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Log-Datei: $LOG_FILE" >> "$LOG_FILE"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Error-Log: $ERROR_LOG" >> "$LOG_FILE"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Debug-Log: $DEBUG_LOG" >> "$LOG_FILE"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ═══════════════════════════════════════════════════════════" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
    
    # Show system information (modern, beautiful display)
    if type system::get_info >/dev/null 2>&1; then
        output::section "System Information"
        output::info "$(system::get_info)"
    fi
    
    # Show installation header (modern style)
    output::section "Photoshop CC Linux Installation"
    
    # Show log paths in clean format (just filename, not full path)
    if [ "${DEBUG:-0}" = "1" ]; then
        output::log_path "Log file" "$LOG_FILE"
        output::log_path "Debug log" "$DEBUG_LOG"
    fi
    echo ""
    
    # Log comprehensive system information (to file only)
    log_system_info
    echo "" >> "$LOG_FILE"
    
    log_debug "=== Script Initialization ==="
    log_debug "SCRIPT_DIR: $SCRIPT_DIR"
    log_debug "PROJECT_ROOT: $PROJECT_ROOT"
    log_debug "LOG_DIR: $LOG_DIR"
    log_debug "LOG_FILE: $LOG_FILE"
    log_debug "ERROR_LOG: $ERROR_LOG"
    log_debug "=== End Script Initialization ==="
    echo "" >> "$LOG_FILE"
    
    # Create directories (silent, only log)
    mkdir -p $SCR_PATH
    log_debug "SCR_PATH erstellt: $SCR_PATH"
    mkdir -p $CACHE_PATH
    log_debug "CACHE_PATH erstellt: $CACHE_PATH"
    echo "" >> "$LOG_FILE"
    
    setup_log "================| script executed |================"
    log_debug "setup_log aufgerufen"

    # System checks (compact display)
    output::step "$(i18n::get "checking_system_requirements")"
    output::substep "$(i18n::get "system_architecture")"
    is64 >/dev/null 2>&1 || true
    log_debug "is64 Prüfung abgeschlossen"

    # Package checks (compact display)
    output::substep "$(i18n::get "required_packages")"
    package_installed wine >/dev/null 2>&1 || package_installed wine
    package_installed md5sum >/dev/null 2>&1 || package_installed md5sum
    package_installed winetricks >/dev/null 2>&1 || package_installed winetricks
    echo "" >> "$LOG_FILE"

    # Setup Wine environment - interactive selection
    # This will show a menu and ask the user to choose
    output::step "$(i18n::get "wine_proton_selection")"
    log_debug "Rufe setup_wine_environment() auf..."
    log_environment
    if ! setup_wine_environment; then
        log_error "setup_wine_environment() fehlgeschlagen!"
        error "$(i18n::get "proton_ge_not_found")"
        exit 1
    fi
    log_debug "setup_wine_environment() erfolgreich abgeschlossen"
    log_environment
    
    # Confirm selection
    # CRITICAL: Initialize PROTON_PATH if not set (for set -u)
    export PROTON_PATH="${PROTON_PATH:-}"
    if [ -n "$PROTON_PATH" ] && [ "$PROTON_PATH" != "system" ]; then
        show_message "${C_GREEN}✓${C_RESET} ${C_CYAN}$(i18n::get "using_proton_ge")${C_RESET}"
        log "Proton GE aktiviert: $PROTON_PATH"
    elif [ "$PROTON_PATH" = "system" ]; then
        show_message "${C_GREEN}✓${C_RESET} ${C_CYAN}$(i18n::get "using_proton_ge_system")${C_RESET}"
        log "Proton GE (system) aktiviert"
    else
        show_message "${C_GREEN}✓${C_RESET} ${C_CYAN}$(i18n::get "using_standard_wine")${C_RESET}"
        log "Standard-Wine aktiviert"
    fi
    log ""

    RESOURCES_PATH="$SCR_PATH/resources"
    WINE_PREFIX="$SCR_PATH/prefix"
    
    #create new wine prefix for photoshop
    rmdir_if_exist $WINE_PREFIX
    
    # CRITICAL: Kill any existing wineserver that might be using the wrong Wine binary
    # This prevents "version mismatch" errors when switching between Wine Standard and Proton GE
    if command -v wineserver >/dev/null 2>&1; then
        wineserver -k 2>/dev/null || true
        # Wait for wineserver to fully terminate (polling instead of fixed sleep)
        wait::for_process "$(pgrep wineserver 2>/dev/null || echo "")" 5 0.2 2>/dev/null || true
    fi
    
    # CRITICAL: Set WINEARCH BEFORE export_var (required for 64-bit prefix initialization)
    export WINEARCH=win64
    # #region agent log
    debug_log "PhotoshopSetup.sh:1958" "WINEARCH set before export_var" "{\"WINEARCH\":\"${WINEARCH}\",\"WINE_PREFIX\":\"${WINE_PREFIX}\"}" "H2"
    # #endregion
    
    #export necessary variable for wine
    export_var
    
    # Ensure we use the correct wine/winecfg (from selected Proton GE or standard Wine)
    # The PATH should already be set by select_wine_version(), but we verify it here
    local wine_binary=$(command -v wine 2>/dev/null || echo "wine")
    local winecfg_binary=$(command -v winecfg 2>/dev/null || echo "winecfg")
    # Log only (not shown to user - too technical)
    log_debug "Verwende Wine-Binary: $wine_binary"
    log_debug "Verwende Winecfg-Binary: $winecfg_binary"
    log_debug "Aktueller PATH: $PATH"
    
    #config wine prefix and install mono and gecko automatic
    output::step "$(i18n::get "configuring_wine_prefix")"
    if [ "$LANG_CODE" = "de" ]; then
        output::substep "$(i18n::get "create_prefix_dir")"
        output::warning "WICHTIG: Es öffnet sich gleich ein Fenster!"
        output::substep "Bitte klicke einfach auf 'OK' - Mono und Gecko werden automatisch installiert."
        echo ""
        # Brief pause for user to read message (not waiting for anything specific)
        sleep 1
    else
        output::substep "Creating Wine prefix directory..."
        output::warning "IMPORTANT: A window will open shortly!"
        output::substep "Please just click 'OK' - Mono and Gecko will be installed automatically."
        echo ""
        # Brief pause for user to read message (not waiting for anything specific)
        sleep 1
    fi
    
    # CRITICAL: Create prefix directory before initializing (wineboot needs it to exist)
    # #region agent log
    debug_log "PhotoshopSetup.sh:1967" "Before prefix directory creation" "{\"WINE_PREFIX\":\"${WINE_PREFIX}\",\"wine_binary\":\"${wine_binary}\"}" "H2"
    # #endregion
    mkdir -p "$WINE_PREFIX" || error "Cannot create Wine prefix directory: $WINE_PREFIX"
    
    # CRITICAL: Set WINEARCH before exporting variables (required for 64-bit prefix)
    export WINEARCH=win64
    # #region agent log
    debug_log "PhotoshopSetup.sh:1970" "WINEARCH set" "{\"WINEARCH\":\"${WINEARCH}\",\"WINE_PREFIX\":\"${WINE_PREFIX}\"}" "H2"
    # #endregion
    
    # CRITICAL: Suppress Wine warnings to reduce log noise
    # WINEDEBUG=-all suppresses all warnings, but we keep errors visible
    # This reduces the 202x 64-bit/WOW64 warnings significantly
    export WINEDEBUG=-all,+err
    
    # ============================================================================
    # Wine 10.x Detection and Workarounds (GitHub Issue - Wine 10.20 WOW64)
    # ============================================================================
    local wine_version_output=$("$wine_binary" --version 2>/dev/null | head -1)
    local wine_major=$(echo "$wine_version_output" | grep -oP '(?<=wine-)[\d]+' | head -1)
    local is_wine_10=0
    local wineboot_timeout=30
    local wait_timeout=30
    
    if [ -n "$wine_major" ] && [ "$wine_major" -ge 10 ]; then
        is_wine_10=1
        # Wine 10.x needs significantly more time (tested: ~27s for user.reg to appear + buffer)
        wineboot_timeout=90
        wait_timeout=90
        
        log_debug "Wine 10.x detected ($wine_version_output) - using extended timeouts (wineboot=${wineboot_timeout}s, wait=${wait_timeout}s)"
        
        # Wine 10.x specific warnings
        if [ "$LANG_CODE" = "de" ]; then
            output::warning "Wine 10.x erkannt - Erweiterte Initialisierung (bis zu 90s)"
            output::substep "Wine 10.x benötigt mehr Zeit für Prefix-Initialisierung..."
        else
            output::warning "Wine 10.x detected - Extended initialization (up to 90s)"
            output::substep "Wine 10.x requires more time for prefix initialization..."
        fi
        echo ""
        
        # Suppress WOW64 errors for Wine 10.x
        export WINEDEBUG=-all,fixme-all,err-environ
    fi
    # ============================================================================
    
    # CRITICAL: Initialize Wine prefix properly
    # Use wineboot -i for initial creation, -u for update
    log_debug "Initializing Wine prefix with wineboot (timeout: ${wineboot_timeout}s)..."
    # #region agent log
    debug_log "PhotoshopSetup.sh:1975" "Before wineboot -i" "{\"WINE_PREFIX\":\"${WINE_PREFIX}\",\"WINEARCH\":\"${WINEARCH}\"}" "H2"
    # #endregion
    # CRITICAL: Initialize Wine prefix with wineboot -i (initial creation)
    # Use timeout to prevent hanging (wineboot can hang in some cases)
    local wineboot_success=false
    if command -v timeout >/dev/null 2>&1; then
        # Use timeout to prevent hanging (30s for Wine <10, 90s for Wine 10.x)
        if timeout $wineboot_timeout "$wine_binary" wineboot -i 2>> "$SCR_PATH/wine-error.log"; then
            wineboot_success=true
        else
            local wineboot_exit=$?
            if [ $wineboot_exit -eq 124 ]; then
                log_warning "wineboot -i timed out after ${wineboot_timeout} seconds, trying wineboot -u..."
            else
                log_warning "wineboot -i failed (exit code: $wineboot_exit), trying wineboot -u..."
            fi
        fi
    else
        # No timeout available, try wineboot -i directly
        if "$wine_binary" wineboot -i 2>> "$SCR_PATH/wine-error.log"; then
            wineboot_success=true
        else
            log_warning "wineboot -i failed, trying wineboot -u..."
        fi
    fi
    
    # Fallback: Try wineboot -u if -i failed
    if [ "$wineboot_success" = false ]; then
        if command -v timeout >/dev/null 2>&1; then
            timeout $wineboot_timeout "$wine_binary" wineboot -u 2>> "$SCR_PATH/wine-error.log" || {
                log_warning "wineboot -u also failed, but continuing..."
            }
        else
            "$wine_binary" wineboot -u 2>> "$SCR_PATH/wine-error.log" || {
                log_warning "wineboot -u also failed, but continuing..."
            }
        fi
    fi
    
    # Wait for prefix initialization (polling instead of fixed sleep)
    # CRITICAL: Wine 10.x can take 60+ seconds - wineboot returns before files are written
    # Use robust polling that checks for stable file size (not just existence)
    log_debug "Waiting for Wine prefix initialization (timeout: ${wait_timeout}s, polling with stability check)..."
    
    if wait::for_wine_prefix "$WINE_PREFIX" $wait_timeout 0.5; then
        log_debug "Wine prefix initialization completed successfully"
    else
        # Final check: user.reg might have been created after timeout (wineboot can be slow)
        # Only show warning if user.reg really doesn't exist after all attempts
        if [ -f "$WINE_PREFIX/user.reg" ] && [ -s "$WINE_PREFIX/user.reg" ]; then
            log_debug "Wine prefix initialized (user.reg exists and is not empty, but wait timed out - wineboot was just slow)"
        elif [ -f "$WINE_PREFIX/user.reg" ]; then
            log_warning "Wine prefix user.reg exists but is empty - prefix may not be fully initialized"
        else
            # Only show warning if user.reg really doesn't exist after 30 seconds
            # This is a real problem, not just a timing issue
            log_warning "Wine prefix initialization may not be complete (user.reg not found after 30s), but continuing..."
            log_debug "This might be normal if wineboot is very slow. Will retry after winecfg."
        fi
    fi
    
    # BEST PRACTICE: Disable Wine Desktop Integration to prevent .lnk files and incorrect desktop entries
    # This prevents Wine from automatically creating desktop shortcuts during installation
    # Registry key: [Software\\Wine\\Explorer\\Desktop] "Enable"="N"
    # #region agent log
    debug_log "PhotoshopSetup.sh:2024" "Disabling Wine Desktop Integration" "{\"WINE_PREFIX\":\"${WINE_PREFIX}\"}" "H4"
    # #endregion
    wine reg add "HKEY_CURRENT_USER\\Software\\Wine\\Explorer\\Desktop" /v "Enable" /t REG_SZ /d "N" /f >> "$LOG_FILE" 2>&1 || true
    log_debug "Wine Desktop Integration disabled (prevents .lnk files and incorrect desktop entries)"
    
    # Now run winecfg to configure the prefix
    "$winecfg_binary" 2>> "$SCR_PATH/wine-error.log"
    local winecfg_exit=$?
    
    # Wait for winecfg to complete and user.reg to be created (polling instead of sleep)
    # CRITICAL: Use same timeout as for initial wineboot (Wine 10.x needs time)
    local winecfg_wait_timeout=$wait_timeout  # Use same as above (30s or 90s for Wine 10.x)
    
    if ! wait::for_wine_prefix "$WINE_PREFIX" $winecfg_wait_timeout 0.5; then
        log_debug "user.reg not found after winecfg (wineboot might be slow), trying wineboot -u again..."
        # #region agent log
        debug_log "PhotoshopSetup.sh:1995" "user.reg not found - retrying wineboot -u" "{\"WINE_PREFIX\":\"${WINE_PREFIX}\"}" "H2"
        # #endregion
        "$wine_binary" wineboot -u 2>> "$SCR_PATH/wine-error.log" || true
        # Wait for user.reg after wineboot retry (give it more time)
        if ! wait::for_wine_prefix "$WINE_PREFIX" $winecfg_wait_timeout 0.5; then
            # Final check: user.reg might exist now
            if [ -f "$WINE_PREFIX/user.reg" ] && [ -s "$WINE_PREFIX/user.reg" ]; then
                log_debug "user.reg created after retry (wineboot was just slow)"
            else
                # #region agent log
                debug_log "PhotoshopSetup.sh:1998" "After wineboot -u retry - user.reg still not found" "{\"user_reg_exists\":$([ -f "$WINE_PREFIX/user.reg" ] && echo "true" || echo "false")}" "H2"
                # #endregion
                log_warning "user.reg still not found after retry - this might indicate a real problem"
            fi
        fi
    fi
    
    if [ $winecfg_exit -eq 0 ] && [ -f "$WINE_PREFIX/user.reg" ]; then
        # Create checkpoint after successful prefix initialization
        checkpoint::create "wine_prefix_initialized"
        
        if [ "$LANG_CODE" = "de" ]; then
            show_message "${C_GREEN}✓${C_RESET} ${C_CYAN}$(i18n::get "prefix_configured")${C_RESET}"
        else
            show_message "${C_GREEN}✓${C_RESET} ${C_CYAN}Prefix configured...${C_RESET}"
        fi
        # Wait for prefix to be fully ready (polling instead of fixed sleep)
        wait::for_wine_prefix "$WINE_PREFIX" 5 0.5 2>/dev/null || true
    elif [ -f "$WINE_PREFIX/user.reg" ]; then
        # Prefix exists even if winecfg had warnings
        if [ "$LANG_CODE" = "de" ]; then
            show_message "${C_GREEN}✓${C_RESET} ${C_CYAN}$(i18n::get "prefix_configured")${C_RESET}"
        else
            show_message "${C_GREEN}✓${C_RESET} ${C_CYAN}Prefix configured...${C_RESET}"
        fi
        # Wait for prefix to be fully ready (polling instead of fixed sleep)
        wait::for_wine_prefix "$WINE_PREFIX" 5 0.5 2>/dev/null || true
    else
        error "Prefix initialization failed - user.reg not created. Check wine-error.log for details."
    fi
    
    if [ -f "$WINE_PREFIX/user.reg" ]; then
        #add dark mod
        set_dark_mod
    else
        error "user.reg Not Found after initialization :("
    fi
   
    #create resources directory 
    rmdir_if_exist $RESOURCES_PATH

    # Install Wine components using extracted function
    install_wine_components
    
    # Workaround für bekannte Wine-Probleme (GitHub Issue #34)
    log "${C_YELLOW}→${C_RESET} ${C_CYAN}$(i18n::get "msg_dll")${C_RESET}"
    # Filter out Wine warnings - output to log only
    winetricks -q dxvk_async=disabled d3d11=native 2>&1 | grep -vE "warning:.*64-bit|warning:.*wow64|Executing|Using winetricks|------------------------------------------------------" >> "$LOG_FILE" 2>&1
    
    # CRITICAL: Ensure d3d11.dll override is set (required for Photoshop 2021+)
    # winetricks may not always set this correctly, so we set it explicitly
    log "${C_YELLOW}  →${C_RESET} ${C_GRAY}Setze d3d11.dll Override (erforderlich für Photoshop 2021+)...${C_RESET}"
    wine reg add "HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides" /v d3d11 /t REG_SZ /d "native,builtin" /f >> "$LOG_FILE" 2>&1 || log "  ⚠ d3d11 Override konnte nicht gesetzt werden"
    log "${C_GREEN}  ✓${C_RESET} ${C_CYAN}d3d11.dll Override gesetzt${C_RESET}"
    
    # Zusätzliche Performance & Rendering Fixes
    show_message "${C_YELLOW}→${C_RESET} ${C_CYAN}$(i18n::get "configuring_registry")${C_RESET}"
    log "${C_CYAN}Konfiguriere Wine-Registry...${C_RESET}"
    
    # Enable CSMT for better performance (Command Stream Multi-Threading)
    log "  - CSMT aktivieren"
    wine reg add "HKEY_CURRENT_USER\\Software\\Wine\\Direct3D" /v csmt /t REG_DWORD /d 1 /f >> "$LOG_FILE" 2>&1 || true
    
    # Disable shader cache to avoid corruption (Issue #206 - Black Screen)
    wine reg add "HKEY_CURRENT_USER\\Software\\Wine\\Direct3D" /v shader_backend /t REG_SZ /d glsl /f 2>/dev/null || true
    
    # Force DirectDraw renderer (helps with screen update issues - Issue #161)
    wine reg add "HKEY_CURRENT_USER\\Software\\Wine\\Direct3D" /v DirectDrawRenderer /t REG_SZ /d opengl /f 2>/dev/null || true
    
    # Disable vertical sync for better responsiveness
    wine reg add "HKEY_CURRENT_USER\\Software\\Wine\\Direct3D" /v StrictDrawOrdering /t REG_SZ /d disabled /f 2>/dev/null || true
    
    # Fix UI scaling issues (Issue #56)
    show_message "${C_YELLOW}→${C_RESET} ${C_CYAN}$(i18n::get "configuring_dpi")${C_RESET}"
    wine reg add "HKEY_CURRENT_USER\\Control Panel\\Desktop" /v LogPixels /t REG_DWORD /d 96 /f >> "$LOG_FILE" 2>&1 || true
    wine reg add "HKEY_CURRENT_USER\\Software\\Wine\\Fonts" /v Smoothing /t REG_DWORD /d 2 /f >> "$LOG_FILE" 2>&1 || true
    
    # BEST PRACTICE: Additional Registry Tweaks from Internet (Performance & Compatibility)
    log "  → Setze zusätzliche Registry-Tweaks für bessere Performance..."
    
    # VideoMemorySize: Set GPU memory size (helps with rendering performance)
    # Default: 0 (auto-detect), but setting it explicitly can help
    # 2048 MB is a good default for most systems
    wine reg add "HKEY_CURRENT_USER\\Software\\Wine\\Direct3D" /v VideoMemorySize /t REG_DWORD /d 2048 /f >> "$LOG_FILE" 2>&1 || true
    log "    ✓ VideoMemorySize gesetzt (2048 MB)"
    
    # WindowManagerManaged: Better window management (prevents window issues)
    wine reg add "HKEY_CURRENT_USER\\Software\\Wine\\X11 Driver" /v WindowManagerManaged /t REG_SZ /d "Y" /f >> "$LOG_FILE" 2>&1 || true
    log "    ✓ WindowManagerManaged aktiviert"
    
    # WindowManagerDecorated: Keep window decorations (better integration)
    wine reg add "HKEY_CURRENT_USER\\Software\\Wine\\X11 Driver" /v WindowManagerDecorated /t REG_SZ /d "Y" /f >> "$LOG_FILE" 2>&1 || true
    log "    ✓ WindowManagerDecorated aktiviert"
    
    # FontSmoothing: Already set via winetricks fontsmooth=rgb, but ensure it's in registry
    wine reg add "HKEY_CURRENT_USER\\Software\\Wine\\Fonts" /v FontSmoothing /t REG_DWORD /d 2 /f >> "$LOG_FILE" 2>&1 || true
    log "    ✓ FontSmoothing bestätigt"
    
    # CRITICAL: Set Windows version explicitly to Windows 10 again
    # (winetricks installations can reset the version, especially IE8)
    log "${C_YELLOW}  →${C_RESET} ${C_GRAY}Stelle sicher, dass Windows-Version auf Windows 10 gesetzt ist (vor Adobe Installer)...${C_RESET}"
    winetricks -q win10 2>&1 | grep -vE "warning:.*64-bit|warning:.*wow64|Executing|Using winetricks|------------------------------------------------------" >> "$LOG_FILE" 2>&1 || log_debug "win10 konnte nicht gesetzt werden"
    
    #install photoshop
    install_photoshopSE
    
    replacement

    if [ -d $RESOURCES_PATH ];then
        log "$(i18n::get "deleting_resources_folder")"
        # CRITICAL: Use safe_remove for security
        if type filesystem::safe_remove >/dev/null 2>&1; then
            filesystem::safe_remove "$RESOURCES_PATH" "PhotoshopSetup" || log_error "Löschen von $RESOURCES_PATH fehlgeschlagen"
        else
            # Fallback if filesystem::safe_remove not available
            if [ -z "$RESOURCES_PATH" ]; then
                log_error "RESOURCES_PATH is empty - skipping deletion"
            elif [ "$RESOURCES_PATH" = "/" ]; then
                log_error "RESOURCES_PATH ist root - überspringe Löschung (Sicherheit)"
            elif [ ! -e "$RESOURCES_PATH" ]; then
                log_debug "RESOURCES_PATH existiert nicht: $RESOURCES_PATH"
            elif [ -d "$RESOURCES_PATH" ]; then
                # CRITICAL: Use safe_remove for security
                if type filesystem::safe_remove >/dev/null 2>&1; then
                    filesystem::safe_remove "$RESOURCES_PATH" "PhotoshopSetup" || log_error "Löschen von $RESOURCES_PATH fehlgeschlagen"
                else
                    # Fallback: validate before rm -rf
                    if [ -z "$RESOURCES_PATH" ] || [ "$RESOURCES_PATH" = "/" ] || [ "$RESOURCES_PATH" = "/root" ]; then
                        log_error "Unsichere RESOURCES_PATH: $RESOURCES_PATH"
                    else
                        rm -rf "$RESOURCES_PATH" || log_error "Löschen von $RESOURCES_PATH fehlgeschlagen"
                    fi
                fi
            else
                log_error "RESOURCES_PATH ist kein Verzeichnis: $RESOURCES_PATH"
            fi
        fi
    else
        error "resources folder Not Found"
    fi

    launcher
    
    # CRITICAL: Ask user if they want to start Photoshop now (after launcher completes)
    echo ""
    output::section "$(i18n::get "start_photoshop_question")"
    local start_photoshop=false
    local start_prompt="$(i18n::get "start_photoshop_prompt")"
    log_prompt "$start_prompt"
    IFS= read -r -p "$start_prompt" start_response
    log_input "$start_response"
    
    # Default to yes if empty (Enter pressed)
    if [ -z "$start_response" ] || [[ "$start_response" =~ ^[JjYy]$ ]]; then
        start_photoshop=true
    fi
    
    if [ "$start_photoshop" = true ]; then
        echo ""
        output::step "$(i18n::get "starting_photoshop")"
        log "Starte Photoshop automatisch nach Installation..."
        
        # Start Photoshop in background (non-blocking)
        if [ -f "$SCR_PATH/launcher/launcher.sh" ]; then
            bash "$SCR_PATH/launcher/launcher.sh" >/dev/null 2>&1 &
            local ps_pid=$!
            log "Photoshop gestartet (PID: $ps_pid)"
            output::success "$(i18n::get "photoshop_starting")"
        else
            output::error "$(i18n::get "launcher_not_found" "$SCR_PATH/launcher/launcher.sh")"
        fi
    else
        output::info "$(i18n::get "photoshop_not_auto_start")"
    fi
    
    # BEST PRACTICE: Final cleanup - Correct any Wine-generated desktop entries created during installation
    # With Desktop Integration disabled, there should be minimal entries, but we correct any that exist
    # #region agent log
    debug_log "PhotoshopSetup.sh:2303" "Final cleanup - correcting Wine desktop entries" "{}" "H4"
    # #endregion
    
    # Function to correct Wine desktop entries (reuse from sharedFuncs.sh logic)
    # BEST PRACTICE: Correct entries instead of deleting - cleaner approach
    correct_wine_entry_final() {
        local entry="$1"
        if [ ! -f "$entry" ]; then
            return 1
        fi
        # Fix grep warnings: Use separate grep calls or fix escaping
        if grep -q "WINEPREFIX=" "$entry" 2>/dev/null || grep -q "wine.*Photoshop.exe" "$entry" 2>/dev/null || grep -q "'C:\\\\" "$entry" 2>/dev/null || grep -q "Exec=env.*wine" "$entry" 2>/dev/null; then
            local launcher_script_path="$SCR_PATH/launcher/launcher.sh"
            local launch_icon="$SCR_PATH/launcher/AdobePhotoshop-icon.png"
            # #region agent log
            debug_log "PhotoshopSetup.sh:2312" "Correcting Wine desktop entry" "{\"entry\":\"${entry}\",\"launcher\":\"${launcher_script_path}\",\"icon\":\"${launch_icon}\"}" "H4"
            # #endregion
            cp "$entry" "${entry}.bak" 2>/dev/null || true
            sed -i "s|^Exec=.*|Exec=${launcher_script_path} %F|g" "$entry" 2>/dev/null || true
            if [ -f "$launch_icon" ]; then
                sed -i "s|^Icon=.*|Icon=${launch_icon}|g" "$entry" 2>/dev/null || true
            fi
            sed -i "s|^Name=.*|Name=Photoshop|g" "$entry" 2>/dev/null || true
            rm -f "${entry}.bak" 2>/dev/null || true
            # #region agent log
            debug_log "PhotoshopSetup.sh:2322" "Wine desktop entry corrected" "{\"entry\":\"${entry}\",\"icon_set\":$(grep -q "Icon=" "$entry" 2>/dev/null && echo "true" || echo "false")}" "H4"
            # #endregion
            return 0
        fi
        return 1
    }
    
    # Correct Wine desktop entries in applications directory
    local wine_apps_dir="$HOME/.local/share/applications/wine"
    if [ -d "$wine_apps_dir" ]; then
        find "$wine_apps_dir" -type f \( -name "*Photoshop*" -o -name "*photoshop*" -o -name "*Adobe*" \) 2>/dev/null | while IFS= read -r entry; do
            correct_wine_entry_final "$entry" && log_debug "Corrected Wine entry: $entry" || true
        done
    fi
    
    # Remove .lnk files (Windows shortcuts - unusable on Linux) and correct desktop entries
    local desktop_dirs=("$HOME/Desktop" "$HOME/Schreibtisch" "$HOME/desktop" "$HOME/schreibtisch")
    for desktop_dir in "${desktop_dirs[@]}"; do
        if [ -d "$desktop_dir" ]; then
            # Remove .lnk files (Windows shortcuts)
            find "$desktop_dir" -maxdepth 1 -type f -name "*.lnk" 2>/dev/null | while IFS= read -r lnk_file; do
                if [ -f "$lnk_file" ]; then
                    # #region agent log
                    debug_log "PhotoshopSetup.sh:2330" "Removing .lnk file (Windows shortcut)" "{\"lnk_file\":\"${lnk_file}\"}" "H4"
                    # #endregion
                    rm -f "$lnk_file" 2>/dev/null || true
                fi
            done
            # Correct Wine-generated desktop entries
            find "$desktop_dir" -maxdepth 1 -type f \( -name "*Photoshop*.desktop" -o -name "*Adobe*.desktop" \) ! -name "photoshop.desktop" 2>/dev/null | while IFS= read -r entry; do
                if correct_wine_entry_final "$entry"; then
                    # Rename to photoshop.desktop if corrected
                    if [ "$(basename "$entry")" != "photoshop.desktop" ]; then
                        mv "$entry" "$desktop_dir/photoshop.desktop" 2>/dev/null || true
                    fi
                    # #region agent log
                    debug_log "PhotoshopSetup.sh:2342" "Corrected Wine desktop entry on desktop" "{\"entry\":\"${entry}\"}" "H4"
                    # #endregion
                fi
            done
        fi
    done
    
    # Update desktop database one final time
    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
    fi
    if command -v kbuildsycoca4 >/dev/null 2>&1; then
        kbuildsycoca4 --noincremental 2>/dev/null || true
    fi
    
    output::warning "$(i18n::get "first_start_may_take_while")"
    output::success "$(i18n::get "installation_completed")"
}

function replacement() {
    # Replacement component ist optional für die lokale Installation
    # Diese Dateien werden normalerweise nur für UI-Icons benötigt
    log "${C_GRAY}Überspringe replacement component (optional für lokale Installation)...${C_RESET}"
    
    # Verwende dynamischen Pfad basierend auf erkannte Version
    local destpath="$PS_INSTALL_PATH/Resources"
    if [ ! -d "$destpath" ]; then
        show_message "${C_YELLOW}→${C_RESET} ${C_GRAY}Photoshop Resources-Pfad noch nicht vorhanden, wird später erstellt...${C_RESET}"
    fi
    
    unset destpath
}

# ============================================================================
# @function install_wine_components
# @description Install Wine components required for Photoshop (VC++, fonts, XML, dotnet48)
# @return 0 on success, 1 on error
# ============================================================================
install_wine_components() {
    # Install Wine components
    # Based on GitHub Issues #23, #45, #67: Minimal, stable components
    show_message "$(i18n::get "msg_install_components")"
    show_message "\033[1;33m$(i18n::get "msg_wait")\e[0m"
    
    # Setze Windows-Version basierend auf erkannte Photoshop-Version
    # OPTIMIERUNG: Neuere Versionen (2021+) funktionieren besser mit Windows 10
    # Photoshop funktioniert auch mit Windows 10 (bessere Kompatibilität)
        show_message "${C_YELLOW}→${C_RESET} ${C_CYAN}$(i18n::get "msg_set_win10")${C_RESET}"
    
    # Für alle Versionen verwende Windows 10 (beste Kompatibilität)
    # KRITISCH: PS_VERSION mit ${PS_VERSION:-} schützen (kann noch nicht gesetzt sein)
    if [[ "${PS_VERSION:-}" =~ "2021" ]] || [[ "${PS_VERSION:-}" =~ "2022" ]]; then
        log "${C_YELLOW}  →${C_RESET} ${C_GRAY}Verwende Windows 10 (empfohlen für ${PS_VERSION:-unknown})${C_RESET}"
    else
        log "${C_YELLOW}  →${C_RESET} ${C_GRAY}Verwende Windows 10${C_RESET}"
    fi
    
    # CRITICAL: Use winetricks with spinner and ensure it uses the correct Wine binary
    # winetricks automatically uses the Wine binary from PATH (which should be Proton GE if selected)
    # CRITICAL: WINEPREFIX should already be set by export_var(), but run_with_spinner will ensure it
    # CRITICAL: Add timeout to prevent hanging (winetricks can hang on version mismatch)
    log_debug "Setting Windows version to Windows 10 via winetricks..."
    log_debug "WINEPREFIX: ${WINEPREFIX:-not set}"
    log_debug "Wine binary: $(command -v wine 2>/dev/null || echo 'not found')"
    
    # CRITICAL: Ensure wineserver is killed before winetricks (prevents version mismatch)
    if command -v wineserver >/dev/null 2>&1; then
        log_debug "Killing wineserver before winetricks..."
        wineserver -k 2>/dev/null || true
        # Wait for wineserver to fully terminate (polling instead of fixed sleep)
        wait::for_process "$(pgrep wineserver 2>/dev/null || echo "")" 5 0.2 2>/dev/null || true
    fi
    
    # Use retry mechanism for robust winetricks execution
    # CRITICAL: Output is filtered by retry::simple (warnings suppressed, only logged)
    local win10_cmd
    if command -v timeout >/dev/null 2>&1; then
        win10_cmd="timeout 60 winetricks -q win10"
    else
        win10_cmd="winetricks -q win10"
    fi
    
    if retry::simple "$win10_cmd" 2 5; then
        log_debug "Windows version set to Windows 10 successfully"
    else
        log_warning "winetricks -q win10 failed after retries, continuing anyway"
    fi
    
    # Core components: Install VC++ Runtimes (2010, 2012, 2013, 2015)
    # Use winetricks (standard method, proven and reliable)
    output::spinner_line "$(i18n::get "installing_vc_runtimes")"
    
    # CRITICAL: winetricks output to log file only (prevents blocking and spam)
    # Filter out Wine warnings - they're not useful for the user
    winetricks -q vcrun2010 vcrun2012 vcrun2013 vcrun2015 2>&1 | grep -vE "warning:.*64-bit|warning:.*wow64|Executing|Using winetricks|------------------------------------------------------" >> "$LOG_FILE" 2>&1 &
    local winetricks_pid=$!
    
    # Use spinner for long operation (simpler and more reliable)
    spinner $winetricks_pid
    wait $winetricks_pid
    local winetricks_exit_code=$?
    echo ""
    
    if [ $winetricks_exit_code -eq 0 ]; then
        # Create checkpoint after successful Wine components installation
        checkpoint::create "wine_components_installed"
        
        output::success "$(i18n::get "vc_runtimes_installed")"
    else
        if [ "$LANG_CODE" = "de" ]; then
            output::warning "$(i18n::get "vc_runtimes_failed" "$winetricks_exit_code")"
        else
            output::warning "Visual C++ Runtimes installation failed (Exit code: $winetricks_exit_code) - installation may still work"
        fi
    fi
    
    if [ "$LANG_CODE" = "de" ]; then
        output::spinner_line "$(i18n::get "installing_fonts_libs")"
    else
        output::spinner_line "Installing fonts and libraries..."
    fi
    
    # Filter out Wine warnings - output to log only
    winetricks -q atmlib corefonts fontsmooth=rgb 2>&1 | grep -vE "warning:.*64-bit|warning:.*wow64|Executing|Using winetricks|------------------------------------------------------" >> "$LOG_FILE" 2>&1 &
    local fonts_pid=$!
    spinner $fonts_pid
    wait $fonts_pid
    echo ""
    
    if [ "$LANG_CODE" = "de" ]; then
        output::spinner_line "$(i18n::get "installing_xml_gdi")"
    else
        output::spinner_line "Installing XML and GDI+ components..."
    fi
    # Filter out Wine warnings - output to log only
    winetricks -q msxml3 msxml6 gdiplus 2>&1 | grep -vE "warning:.*64-bit|warning:.*wow64|Executing|Using winetricks|------------------------------------------------------" >> "$LOG_FILE" 2>&1 &
    local xml_pid=$!
    spinner $xml_pid
    wait $xml_pid
    echo ""
    
    # OPTIMIZATION: For newer versions (2021+) additional components
    # CRITICAL: Protect PS_VERSION with ${PS_VERSION:-}
    # dotnet48 wird NUR für neuere Photoshop-Versionen (2021, 2022) benötigt, NICHT für CC 2019
    if [[ "${PS_VERSION:-}" =~ "2021" ]] || [[ "${PS_VERSION:-}" =~ "2022" ]]; then
        local component_msg=$(i18n::get "installing_additional_components")
        output::step "$(printf "$component_msg" "${PS_VERSION:-unknown}")"
        
        # dotnet48 wird für neuere Photoshop-Versionen benötigt
        # #region agent log
        debug_log "PhotoshopSetup.sh:2176" "Before dotnet48 installation" "{\"PS_VERSION\":\"${PS_VERSION:-unknown}\",\"WINEPREFIX\":\"${WINEPREFIX:-}\"}" "H3"
        # #endregion
        
        if [ "$LANG_CODE" = "de" ]; then
            output::warning "⚠ .NET Framework 4.8 Installation kann 15-30 Minuten dauern!"
            echo ""
            echo "  ${C_CYAN}→${C_RESET} Dies ist normal - .NET Framework ist sehr groß (~200MB)"
            echo "  ${C_CYAN}→${C_RESET} Du kannst die Installation abbrechen (STRG+C) und später manuell installieren:"
            echo "     ${C_GRAY}WINEPREFIX=~/.photoshopCCV19/prefix winetricks dotnet48${C_RESET}"
            echo ""
            read -p "$(echo -e "${C_YELLOW}Fortfahren mit .NET Framework Installation? [J/n]:${C_RESET} ") " dotnet_continue
            if [[ "$dotnet_continue" =~ ^[Nn]$ ]]; then
                log_warning ".NET Framework Installation übersprungen (vom Benutzer abgebrochen)"
                if [ "$LANG_CODE" = "de" ]; then
                    output::warning ".NET Framework Installation übersprungen - kann später manuell installiert werden"
                else
                    output::warning ".NET Framework installation skipped - can be installed manually later"
                fi
                return 0  # Skip dotnet installation
            fi
            echo ""
            output::spinner_line "$(i18n::get "installing_dotnet")"
        else
            output::warning "⚠ .NET Framework 4.8 installation can take 15-30 minutes!"
            echo ""
            echo "  ${C_CYAN}→${C_RESET} This is normal - .NET Framework is very large (~200MB)"
            echo "  ${C_CYAN}→${C_RESET} You can cancel (CTRL+C) and install manually later:"
            echo "     ${C_GRAY}WINEPREFIX=~/.photoshopCCV19/prefix winetricks dotnet48${C_RESET}"
            echo ""
            read -p "$(echo -e "${C_YELLOW}Continue with .NET Framework installation? [Y/n]:${C_RESET} ") " dotnet_continue
            if [[ "$dotnet_continue" =~ ^[Nn]$ ]]; then
                log_warning ".NET Framework installation skipped (user cancelled)"
                output::warning ".NET Framework installation skipped - can be installed manually later"
                return 0  # Skip dotnet installation
            fi
            echo ""
            output::spinner_line "Installing .NET Framework 4.8 (takes 15-30 minutes)..."
        fi
        
        # Filter out Wine warnings - output to log only
        # CRITICAL: .NET Framework 4.8 can take 10-30 minutes, so we add timeout protection
        winetricks -q dotnet48 2>&1 | grep -vE "warning:.*64-bit|warning:.*wow64|Executing|Using winetricks|------------------------------------------------------" >> "$LOG_FILE" 2>&1 &
        local dotnet_pid=$!
        # #region agent log
        debug_log "PhotoshopSetup.sh:2178" "dotnet48 started in background" "{\"dotnet_pid\":${dotnet_pid}}" "H3"
        # #endregion
        
        # Use spinner for long operation with timeout (max 30 minutes)
        # Show periodic feedback that it's still running (every 2 minutes)
        local timeout_seconds=1800  # 30 minutes
        local elapsed=0
        local check_interval=120  # Check every 2 minutes
        
        while kill -0 $dotnet_pid 2>/dev/null && [ $elapsed -lt $timeout_seconds ]; do
            sleep $check_interval
            elapsed=$((elapsed + check_interval))
            
            # Show progress every 2 minutes
            local minutes=$((elapsed / 60))
            if [ "$LANG_CODE" = "de" ]; then
                echo -e "\r${C_YELLOW}  ⏳ Läuft seit ${minutes} Minuten... (kann bis zu 30 Minuten dauern)${C_RESET}    "
            else
                echo -e "\r${C_YELLOW}  ⏳ Running for ${minutes} minutes... (can take up to 30 minutes)${C_RESET}    "
            fi
        done
        
        # Check if process is still running
        if kill -0 $dotnet_pid 2>/dev/null; then
            # Timeout reached - kill process
            log_warning ".NET Framework installation timed out after 30 minutes"
            kill $dotnet_pid 2>/dev/null
            wait $dotnet_pid 2>/dev/null
            local dotnet_exit=124  # Timeout exit code
        else
            # Process finished normally
            wait $dotnet_pid
            local dotnet_exit=$?
        fi
        echo ""
        
        # #region agent log
        debug_log "PhotoshopSetup.sh:2181" "dotnet48 installation completed" "{\"dotnet_exit\":${dotnet_exit},\"dotnet_pid\":${dotnet_pid}}" "H3"
        # #endregion
        if [ $dotnet_exit -eq 0 ]; then
            if [ "$LANG_CODE" = "de" ]; then
                output::success "$(i18n::get "dotnet_installed")"
            else
                output::success ".NET Framework 4.8 installed successfully"
            fi
        else
            if [ "$LANG_CODE" = "de" ]; then
                output::warning "$(i18n::get "dotnet_failed")"
            else
                output::warning ".NET Framework 4.8 installation failed (optional)"
            fi
        fi
        
        # vcrun2019 für neuere Versionen (optional, nur für 2021/2022)
        if [ "$LANG_CODE" = "de" ]; then
            output::spinner_line "$(i18n::get "installing_vc2019")"
        else
            output::spinner_line "Installing Visual C++ 2019 Runtime (optional)..."
        fi
        winetricks -q vcrun2019 >> "$LOG_FILE" 2>&1 &
        local vcrun_pid=$!
        spinner $vcrun_pid
        wait $vcrun_pid
        local vcrun_exit=$?
        echo ""
        if [ $vcrun_exit -eq 0 ]; then
            if [ "$LANG_CODE" = "de" ]; then
                output::success "$(i18n::get "vc2019_installed")"
            else
                output::success "Visual C++ 2019 Runtime installed successfully"
            fi
        else
            if [ "$LANG_CODE" = "de" ]; then
                output::warning "$(i18n::get "vc2019_failed")"
            else
                output::warning "Visual C++ 2019 Runtime installation failed (optional)"
            fi
        fi
    fi
}

# ============================================================================
# @function configure_ie_engine
# @description Configure IE engine for Adobe Installer (IE8, DLL-Overrides, Registry-Tweaks)
# @return 0 on success, 1 on error
# ============================================================================
configure_ie_engine() {
    # Erklärung welche Wine-Version verwendet wird
    if [ -n "$PROTON_PATH" ] && [ "$PROTON_PATH" != "" ]; then
        if [ "$PROTON_PATH" = "system" ]; then
            log "ℹ Verwende: Proton GE (system) für Installer UND Photoshop"
        else
            log "ℹ Verwende: Proton GE ($PROTON_PATH) für Installer UND Photoshop"
        fi
        log ""
        log "⚠ WICHTIG: Der Adobe Installer verwendet eine IE-Engine, die in"
        log "   Wine/Proton nicht vollständig funktioniert. Falls Buttons nicht"
        log "   reagieren, ist das ein bekanntes Problem (nicht dein Fehler!)."
        log ""
    else
        log "ℹ Verwende: Standard-Wine für Installer UND Photoshop"
        log ""
    fi
    
    # Workaround für "Weiter"-Button Problem: Setze DLL-Overrides für IE-Engine
    # Adobe Installer verwendet IE-Engine (mshtml.dll), die in Wine/Proton nicht vollständig funktioniert
    # BEST PRACTICE: IE8 installieren + umfassende DLL-Overrides für maximale Kompatibilität
    log "Konfiguriere IE-Engine für Adobe Installer (Best Practice)..."
    log ""
    
    # IE8 Installation (STANDARD - immer installieren für beste Kompatibilität)
    if [ "$LANG_CODE" = "de" ]; then
        output::spinner_line "$(i18n::get "installing_ie8")"
    else
        output::spinner_line "Installing IE8 (takes 5-10 minutes)..."
    fi
    
    # CRITICAL: Redirect winetricks output to log only (prevents spam)
    # Filter out Wine warnings - output to log only
    winetricks -q ie8 2>&1 | grep -vE "warning:.*64-bit|warning:.*wow64|Executing|Using winetricks|------------------------------------------------------" >> "$LOG_FILE" 2>&1 &
    local ie8_pid=$!
    spinner $ie8_pid
    wait $ie8_pid
    local ie8_exit_code=$?
    
    if [ $ie8_exit_code -eq 0 ]; then
        output::success "$(i18n::get "ie8_installed_success")"
        # CRITICAL: IE8 resets Windows version to win7 - must be set back to win10!
        log_debug "Setze Windows-Version erneut auf Windows 10 (IE8 hat sie auf win7 zurückgesetzt)..."
        winetricks -q win10 2>&1 | grep -vE "warning:.*64-bit|warning:.*wow64|Executing|Using winetricks|------------------------------------------------------" >> "$LOG_FILE" 2>&1 || log_debug "win10 konnte nicht erneut gesetzt werden"
        log_debug "Windows 10 erneut gesetzt"
    else
        output::warning "$(i18n::get "ie8_install_failed")"
    fi
    
    output::substep "$(i18n::get "setting_dll_overrides")"
    
    # Best Practice: native,builtin (versuche native zuerst, dann builtin als Fallback)
    # For critical IE components we use native,builtin
    wine reg add "HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides" /v mshtml /t REG_SZ /d "native,builtin" /f >> "$LOG_FILE" 2>&1 || true
    wine reg add "HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides" /v jscript /t REG_SZ /d "native,builtin" /f >> "$LOG_FILE" 2>&1 || true
    wine reg add "HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides" /v vbscript /t REG_SZ /d "native,builtin" /f >> "$LOG_FILE" 2>&1 || true
    wine reg add "HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides" /v urlmon /t REG_SZ /d "native,builtin" /f >> "$LOG_FILE" 2>&1 || true
    wine reg add "HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides" /v wininet /t REG_SZ /d "native,builtin" /f >> "$LOG_FILE" 2>&1 || true
    wine reg add "HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides" /v shdocvw /t REG_SZ /d "native,builtin" /f >> "$LOG_FILE" 2>&1 || true
    wine reg add "HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides" /v ieframe /t REG_SZ /d "native,builtin" /f >> "$LOG_FILE" 2>&1 || true
    wine reg add "HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides" /v actxprxy /t REG_SZ /d "native,builtin" /f >> "$LOG_FILE" 2>&1 || true
    wine reg add "HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides" /v browseui /t REG_SZ /d "native,builtin" /f >> "$LOG_FILE" 2>&1 || true
    # Dxtrans.dll und msimtf.dll - für JavaScript/IE-Engine (verhindert viele Fehler im Log)
    wine reg add "HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides" /v dxtrans /t REG_SZ /d "native,builtin" /f >> "$LOG_FILE" 2>&1 || true
    wine reg add "HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides" /v msimtf /t REG_SZ /d "native,builtin" /f >> "$LOG_FILE" 2>&1 || true
    
    # Fix for DLL-Forward-Fehler: shlwapi.ShellMessageBoxW
    # This fixes the "find_forwarded_export function not found" errors
    log_debug "Setze shlwapi.dll Override (behebt DLL-Forward-Fehler)..."
    wine reg add "HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides" /v shlwapi /t REG_SZ /d "native,builtin" /f >> "$LOG_FILE" 2>&1 || true
    wine reg add "HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides" /v shell32 /t REG_SZ /d "native,builtin" /f >> "$LOG_FILE" 2>&1 || true
    
    # Zusätzliche Registry-Tweaks für bessere IE-Kompatibilität
    log_debug "Setze Registry-Tweaks für IE-Kompatibilität..."
    wine reg add "HKEY_CURRENT_USER\\Software\\Microsoft\\Internet Explorer\\Main" /v "DisableScriptDebugger" /t REG_SZ /d "yes" /f >> "$LOG_FILE" 2>&1 || true
    wine reg add "HKEY_CURRENT_USER\\Software\\Microsoft\\Internet Explorer\\Main" /v "DisableFirstRunCustomize" /t REG_SZ /d "1" /f >> "$LOG_FILE" 2>&1 || true
    
    # Show important notice about Adobe Installer button issues (only once, clean format)
    output::box "$(i18n::get "important_next_button")"
}

# ============================================================================
# @function run_photoshop_installer
# @description Run Adobe Photoshop installer and handle exit codes
# @return 0 on success, 1 on error
# ============================================================================
run_photoshop_installer() {
    # Adobe Installer: Output only to log files, not to terminal (reduces spam)
    # Use PIPESTATUS[0] to capture wine's exit code, not tee's
    log_debug "Starte Adobe Installer (Set-up.exe)..."
    wine "$RESOURCES_PATH/photoshop/Set-up.exe" >> "$LOG_FILE" 2>&1 | tee -a "$SCR_PATH/wine-error.log" >/dev/null
    
    local install_status=${PIPESTATUS[0]}
    
    log_debug "Installation beendet mit Exit-Code: $install_status"
    
    if [ $install_status -eq 0 ]; then
        output::success "$(i18n::get "photoshop_install_completed")"
        log "$(i18n::get "msg_complete")"
    else
        output::warning "$(i18n::get "install_exit_code" "$install_status")"
        log_error "FEHLER: Installation mit Exit-Code $install_status beendet"
    fi
    
    return $install_status
}

# ============================================================================
# @function configure_photoshop
# @description Configure Photoshop after installation (remove plugins, disable GPU, etc.)
# @return 0 on success, 1 on error
# ============================================================================
configure_photoshop() {
    # Versuche problematische Plugins zu entfernen (falls vorhanden)
    output::step "$(i18n::get "configuring_photoshop")"
    log_debug "$(i18n::get "msg_search_plugins")"
    
    # Mögliche Installationspfade (dynamisch basierend auf erkannte Version)
    local possible_paths=(
        "$PS_INSTALL_PATH"
        "$WINE_PREFIX/drive_c/Program Files/Adobe/Adobe Photoshop CC 2021"
        "$WINE_PREFIX/drive_c/Program Files/Adobe/Adobe Photoshop CC 2019"
        "$WINE_PREFIX/drive_c/Program Files/Adobe/Adobe Photoshop 2022"
        "$WINE_PREFIX/drive_c/Program Files/Adobe/Adobe Photoshop 2021"
        "$WINE_PREFIX/drive_c/Program Files/Adobe/Adobe Photoshop CC 2018"
        "$WINE_PREFIX/drive_c/users/$USER/PhotoshopSE"
    )
    
    # After installation, check which version was actually installed
    local actual_version=""
    for ps_path in "${possible_paths[@]}"; do
        if [ -d "$ps_path" ]; then
            show_message "$(i18n::get "msg_found_in") $ps_path"
            
            # Detect actual installed version from directory name
            local dirname
            dirname=$(basename "$ps_path")
            if [[ "$dirname" =~ "2022" ]]; then
                actual_version="2022"
            elif [[ "$dirname" =~ "2021" ]]; then
                actual_version="2021"
            elif [[ "$dirname" =~ "CC 2019" ]] || [[ "$dirname" =~ "2019" ]]; then
                actual_version="CC 2019"
            fi
            
            # Update PS_VERSION if different from detected
            if [ -n "$actual_version" ] && [ "$actual_version" != "$PS_VERSION" ]; then
                log_info "$(i18n::get "actual_version_info" "$actual_version" "$PS_VERSION")"
                else
                    log_info "Actually installed version: $actual_version (previously detected: $PS_VERSION)"
                fi
                PS_VERSION="$actual_version"
                PS_INSTALL_PATH=$(get_photoshop_install_path "$PS_VERSION")
                PS_PREFS_PATH=$(get_photoshop_prefs_path "$PS_VERSION")
            fi
            
            # Entferne problematische Plugins (GitHub Issues #12, #56, #78)
            # JavaScript-Extensions (CEP) funktionieren nicht richtig in Wine/Proton
            local problematic_plugins=(
                "$ps_path/Required/Plug-ins/Spaces/Adobe Spaces Helper.exe"
                "$ps_path/Required/CEP/extensions/com.adobe.DesignLibraryPanel.html"
                "$ps_path/Required/Plug-ins/Extensions/ScriptingSupport.8li"
                # JavaScript-Extension "Startseite" (Homepage) - verursacht Fehler
                "$ps_path/Required/CEP/extensions/com.adobe.HomePagePanel.html"
                "$ps_path/Required/CEP/extensions/com.adobe.HomePagePanel"
            )
            
            for plugin in "${problematic_plugins[@]}"; do
                if [ -f "$plugin" ]; then
                    log_debug "$(i18n::get "msg_remove_plugin") $(basename "$plugin")"
                    rm "$plugin" 2>/dev/null
                fi
            done
            
            # GPU-Probleme vermeiden (GitHub Issue #45)
            output::substep "$(i18n::get "disabling_gpu")"
            # Verwende dynamischen Prefs-Pfad basierend auf erkannte Version
            local prefs_file="$PS_PREFS_PATH/Adobe Photoshop $PS_VERSION Prefs.psp"
            # Fallback für CC 2019 Format
            if [ ! -d "$(dirname "$prefs_file")" ]; then
                prefs_file="$PS_PREFS_PATH/Adobe Photoshop CC 2019 Prefs.psp"
            fi
            local prefs_dir
            prefs_dir=$(dirname "$prefs_file")
            
            if [ ! -d "$prefs_dir" ]; then
                mkdir -p "$prefs_dir"
            fi
            
            # Erstelle Prefs-Datei mit GPU-Deaktivierung
            # Diese Einstellungen verhindern GPU-Treiber-Warnungen
            cat > "$prefs_file" << 'EOF'
useOpenCL 0
useGraphicsProcessor 0
GPUAcceleration 0
EOF
            
            # BEST PRACTICE: Create PSUserConfig.txt with GPUForce 1 (Internet-Tipp)
            # This can help with GPU-related issues in some cases
            # Path: AppData/Roaming/Adobe/Adobe Photoshop [VERSION]/Adobe Photoshop [VERSION] Settings/PSUserConfig.txt
            local ps_user_config_dir="$PS_PREFS_PATH/Adobe Photoshop $PS_VERSION Settings"
            if [ ! -d "$ps_user_config_dir" ]; then
                # Fallback for CC 2019 format
                ps_user_config_dir="$PS_PREFS_PATH/Adobe Photoshop CC 2019 Settings"
            fi
            
            if [ ! -d "$ps_user_config_dir" ]; then
                mkdir -p "$ps_user_config_dir"
            fi
            
            local ps_user_config_file="$ps_user_config_dir/PSUserConfig.txt"
            if [ -f "$ps_user_config_file" ]; then
                # Backup existing file
                cp "$ps_user_config_file" "${ps_user_config_file}.bak" 2>/dev/null || true
            fi
            
            # Create PSUserConfig.txt with GPUForce 1 (Internet best practice)
            # This can help force GPU usage if needed, or disable it if GPUForce 0
            # We set it to 1 as a workaround for some GPU issues (can be changed by user)
            cat > "$ps_user_config_file" << 'EOF'
# GPUForce 1 - Force GPU usage (can help with some GPU-related issues)
# Set to 0 to disable GPU completely
GPUForce 1
EOF
            log "  → PSUserConfig.txt erstellt mit GPUForce 1 (Internet Best Practice)"
            
            # Zusätzlich: Deaktiviere GPU in Registry für bessere Kompatibilität
            log "  → Setze Registry-Einstellungen für GPU-Deaktivierung..."
            wine reg add "HKEY_CURRENT_USER\\Software\\Adobe\\Photoshop\\Settings" /v "GPUAcceleration" /t REG_DWORD /d 0 /f >> "$LOG_FILE" 2>&1 || true
            wine reg add "HKEY_CURRENT_USER\\Software\\Adobe\\Photoshop\\Settings" /v "useOpenCL" /t REG_DWORD /d 0 /f >> "$LOG_FILE" 2>&1 || true
            wine reg add "HKEY_CURRENT_USER\\Software\\Adobe\\Photoshop\\Settings" /v "useGraphicsProcessor" /t REG_DWORD /d 0 /f >> "$LOG_FILE" 2>&1 || true
            
            # PNG Save Fix (Issue #209): Installiere zusätzliche GDI+ Komponenten
            output::substep "$(i18n::get "installing_png_export")"
            winetricks -q gdiplus_winxp 2>&1 | grep -vE "warning:.*64-bit|warning:.*wow64|Executing|Using winetricks|------------------------------------------------------" >> "$LOG_FILE" 2>&1 || true
            
            break
    done
}

function install_photoshopSE() {
    # Detect Photoshop version
    PS_VERSION=$(detect_photoshop_version)
    PS_INSTALL_PATH=$(get_photoshop_install_path "$PS_VERSION")
    PS_PREFS_PATH=$(get_photoshop_prefs_path "$PS_VERSION")
    
    # Clean section header
    output::section "$(i18n::get "photoshop_installation_section")"
    
    # Log detailed info (not shown to user)
    log_debug "Photoshop Installation gestartet: $(date '+%Y-%m-%d %H:%M:%S')"
    log_debug "Erkannte Version: $PS_VERSION"
    log_debug "Installations-Pfad: $PS_INSTALL_PATH"
    log_debug "Log-Datei: $LOG_FILE"
    
    # Show version to user (clean format)
    output::info "$(i18n::get "detected_version" "$PS_VERSION")"
    echo ""
    
    # Verwende das lokale Adobe Photoshop Installationspaket
    # Use project root directory (already determined at top of script)
    local local_installer="$PROJECT_ROOT/photoshop/Set-up.exe"
    
    if [ ! -f "$local_installer" ]; then
        if [ "$LANG_CODE" = "de" ]; then
            error "$(i18n::get "local_installer_not_found" "$local_installer")
Bitte kopiere die Photoshop-Installationsdateien nach: $PROJECT_ROOT/photoshop/"
        else
            error "Local Photoshop installation package not found: $local_installer
Please copy Photoshop installation files to: $PROJECT_ROOT/photoshop/"
        fi
    fi
    
    log_debug "$(i18n::get "msg_ps_found")"
    log_debug "$(i18n::get "msg_copy")"
    
    # Kopiere das komplette photoshop Verzeichnis in resources
    cp -r "$(dirname "$local_installer")" "$RESOURCES_PATH/"
    
    echo "===============| Adobe Photoshop $PS_VERSION |===============" >> "$SCR_PATH/wine-error.log"
    output::step "$(i18n::get "starting_installer")"
    
    # Show important installation hints in a clean box
    output::box "$(i18n::get "important_installer_choice")"
    
    # Starte den Adobe Installer (mit Logging)
    log_debug "Starte Adobe Photoshop Setup..."
    log_debug "Installer: $RESOURCES_PATH/photoshop/Set-up.exe"
    
    # Configure IE engine for Adobe Installer
    configure_ie_engine
    
    # Run Adobe Photoshop installer
    run_photoshop_installer
    local install_status=$?
    
    # Configure Photoshop after installation
    configure_photoshop
    
    notify-send "Photoshop CC" "Photoshop Installation abgeschlossen" -i "photoshop" 2>/dev/null || true
    log "Adobe Photoshop $PS_VERSION installiert..."
    
    # Create checkpoint after successful installation
    checkpoint::create "photoshop_installed"
    
    # CRITICAL: Save paths including Wine version info (PROTON_PATH) for uninstaller
    # This must be called AFTER PROTON_PATH is set (which happens in select_wine_version)
    save_paths
    
    # Cleanup checkpoints after successful installation
    checkpoint::cleanup
    
    # CRITICAL: Call finish_installation to show completion message and ask if user wants to start Photoshop
    finish_installation
    
    unset local_installer install_status possible_paths
}

# Parse command line arguments for Wine method selection
# Extract our custom parameters BEFORE check_arg (which uses getopts)
# NOTE: Logging is not yet initialized here, so we can't use log_debug
WINE_METHOD=""  # Empty = interactive selection, "wine" = Wine Standard, "proton" = Proton GE
filtered_args=()
for arg in "$@"; do
    case "$arg" in
        --wine-standard)
            WINE_METHOD="wine"
            # Don't add to filtered_args - check_arg doesn't know about this
            ;;
        --proton-ge)
            WINE_METHOD="proton"
            # Don't add to filtered_args - check_arg doesn't know about this
            ;;
        *)
            # Keep all other arguments for check_arg
            filtered_args+=("$arg")
            ;;
    esac
done

# Export WINE_METHOD so it's available in all functions
export WINE_METHOD

# Call check_arg with filtered arguments (without --wine-standard/--proton-ge)
check_arg "${filtered_args[@]}"
# NOTE: save_paths() is called at the END of installation (after PROTON_PATH is set)
main




