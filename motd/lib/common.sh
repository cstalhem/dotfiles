#!/bin/bash

#
# common.sh - Shared functions and variables for MOTD scripts
# Part of custom MOTD dashboard
#
# This file is sourced by all MOTD scripts, not executed directly.
#

# ==============================================================================
# Colors
# ==============================================================================

readonly RED='\e[31m'
readonly GREEN='\e[32m'
readonly YELLOW='\e[33m'
readonly BLUE='\e[34m'
readonly CYAN='\e[36m'
readonly WHITE='\e[1;37m'
readonly BOLD='\e[1m'
readonly DIM='\e[2m'
readonly RESET='\e[0m'

# ==============================================================================
# Layout Constants
# ==============================================================================

readonly WIDTH=60
readonly INDENT="   "
readonly INDENT2="      "
readonly INDENT3="         "
readonly LABEL_WIDTH=20

# ==============================================================================
# Status Icons (Nerd Font)
# ==============================================================================

readonly ICON_OK=$''                 # nf-fa-check
readonly ICON_WARN=$''               # nf-fa-warning
readonly ICON_ERROR=$''              # nf-fa-times_circle
readonly ICON_STOPPED=$''            # nf-oct-circle_slash
readonly ICON_REFRESH=$''            # nf-fa-refresh

# ==============================================================================
# Section Icons (Nerd Font)
# ==============================================================================

readonly ICON_HEALTH=$'󰗶'             # nf-md-heart_pulse
readonly ICON_UPDATES=$'󰏖'            # nf-md-package_variant
readonly ICON_DOCKER=$'󰡨'             # nf-md-docker
readonly ICON_USERS=$''              # nf-fa-users

# ==============================================================================
# Detail Icons (Nerd Font)
# ==============================================================================

readonly ICON_CLOCK=$''              # nf-fa-clock_o
readonly ICON_MEMORY=$'󰍛'             # nf-md-memory
readonly ICON_DISK=$'󰋊'               # nf-md-harddisk
readonly ICON_NETWORK=$'󰲝'            # nf-md-network
readonly ICON_REBOOT=$'󰜉'             # nf-md-restart
readonly ICON_UPGRADE=$''            # nf-fa-arrow_circle_o_up
readonly ICON_CONTAINER=$''          # nf-oct-container
readonly ICON_USER=$''               # nf-fa-user
readonly ICON_BAN=$''                # nf-fa-ban
readonly ICON_HISTORY=$''            # nf-fa-history
readonly ICON_SECURITY=$''           # nf-fa-shield

# ==============================================================================
# Functions
# ==============================================================================

# Generate a progress bar with color based on percentage
# Usage: progress_bar <percentage>
# Output: [██████████░░░░░]  62%
progress_bar() {
    local percent=$1
    local width=15
    local filled=$((percent * width / 100))
    local empty=$((width - filled))

    # Determine color based on percentage
    local color
    if [ "$percent" -ge 85 ]; then
        color="$RED"
    elif [ "$percent" -ge 70 ]; then
        color="$YELLOW"
    else
        color="$GREEN"
    fi

    # Build the bar
    local bar="${color}["
    bar+=$(printf '%*s' "$filled" '' | tr ' ' '█')
    bar+=$(printf '%*s' "$empty" '' | tr ' ' '░')
    bar+="]${RESET}"

    printf "%s %3d%%" "$bar" "$percent"
}

# Print section separator with icon and title
# Usage: print_section_header "ICON" "TITLE"
print_section_header() {
    local icon="$1"
    local title="$2"
    echo ""
    printf '%s\n' "$(printf '─%.0s' $(seq 1 $WIDTH))"
    echo -e "${WHITE}${icon}  ${title}${RESET}"
    echo ""
}

# Print a label: value line with consistent alignment
# Usage: print_line "Label:" "value" [indent]
# Default indent is INDENT (3 spaces)
print_line() {
    local label="$1"
    local value="$2"
    local indent="${3:-$INDENT}"
    printf "%s${DIM}%-${LABEL_WIDTH}s${RESET} %s\n" "$indent" "$label" "$value"
}

# Print horizontal separator line
# Usage: print_separator
print_separator() {
    printf '%s\n' "$(printf '─%.0s' $(seq 1 $WIDTH))"
}

# Get status color based on percentage thresholds
# Usage: get_status_color <percentage> [warn_threshold] [crit_threshold]
# Default thresholds: warn=70, crit=85
get_status_color() {
    local percent=$1
    local warn_threshold=${2:-70}
    local crit_threshold=${3:-85}

    if [ "$percent" -ge "$crit_threshold" ]; then
        echo "$RED"
    elif [ "$percent" -ge "$warn_threshold" ]; then
        echo "$YELLOW"
    else
        echo "$GREEN"
    fi
}

# Get status icon based on percentage thresholds
# Usage: get_status_icon <percentage> [warn_threshold] [crit_threshold]
# Default thresholds: warn=70, crit=85
get_status_icon() {
    local percent=$1
    local warn_threshold=${2:-70}
    local crit_threshold=${3:-85}

    if [ "$percent" -ge "$crit_threshold" ]; then
        echo "$ICON_ERROR"
    elif [ "$percent" -ge "$warn_threshold" ]; then
        echo "$ICON_WARN"
    else
        echo "$ICON_OK"
    fi
}

# Format bytes to human readable format (GB)
# Usage: bytes_to_gb <bytes>
bytes_to_gb() {
    local bytes=$1
    awk "BEGIN {printf \"%.1f\", $bytes / 1024 / 1024 / 1024}"
}

# Check if a command exists
# Usage: command_exists <command>
command_exists() {
    command -v "$1" &>/dev/null
}
