#!/bin/bash

#
# common.sh - Shared functions and variables for MOTD scripts
# Part of custom MOTD dashboard
#
# This file is sourced by all MOTD scripts, not executed directly.
#

# ==============================================================================
# Locale (ensure UTF-8 for Unicode characters)
# ==============================================================================

# Bash substring expansion and ${#var} are character-based only in a UTF-8
# locale; otherwise they're byte-based, which splits the 3-byte box-drawing
# characters mid-character. C.UTF-8 is built into glibc on Ubuntu 22.04+, so
# it needs no locale-gen, unlike en_US.UTF-8 which is frequently not
# generated on a headless server.
export LANG=C.UTF-8
export LC_ALL=C.UTF-8

# ==============================================================================
# Colors
# ==============================================================================

readonly RED=$'\e[31m'
readonly GREEN=$'\e[32m'
readonly YELLOW=$'\e[33m'
readonly BLUE=$'\e[34m'
readonly CYAN=$'\e[36m'
readonly WHITE=$'\e[1;37m'
readonly BOLD=$'\e[1m'
readonly DIM=$'\e[2m'
readonly RESET=$'\e[0m'

# ==============================================================================
# Layout Constants
# ==============================================================================

readonly WIDTH=60
readonly INDENT="   "
readonly INDENT2="      "
readonly INDENT3="         "
readonly LABEL_WIDTH=20

# Progress bar width and precomputed fill/empty character runs (avoids
# spawning subprocesses in progress_bar; built once at source time)
readonly PROGRESS_BAR_WIDTH=15
printf -v _pb_fill '%*s' "$PROGRESS_BAR_WIDTH" ''
readonly PROGRESS_BAR_FILLED_CHARS="${_pb_fill// /█}"
printf -v _pb_empty '%*s' "$PROGRESS_BAR_WIDTH" ''
readonly PROGRESS_BAR_EMPTY_CHARS="${_pb_empty// /░}"
unset _pb_fill _pb_empty

# Precomputed horizontal separator line (WIDTH '─' characters)
printf -v _sep '%*s' "$WIDTH" ''
readonly SEPARATOR_LINE="${_sep// /─}"
unset _sep

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
# Usage: progress_bar <percentage> [warn_threshold] [crit_threshold]
# Default thresholds: warn=70, crit=85
# Output: [██████████░░░░░]  62%
progress_bar() {
    local percent=$1
    local warn_threshold=${2:-70}
    local crit_threshold=${3:-85}

    # Clamp percent into 0..100 so out-of-range input can't produce a
    # malformed slice or a negative empty count
    [ "$percent" -lt 0 ] && percent=0
    [ "$percent" -gt 100 ] && percent=100

    local filled=$((percent * PROGRESS_BAR_WIDTH / 100))
    local empty=$((PROGRESS_BAR_WIDTH - filled))

    # Determine color based on percentage
    local color
    if [ "$percent" -ge "$crit_threshold" ]; then
        color="$RED"
    elif [ "$percent" -ge "$warn_threshold" ]; then
        color="$YELLOW"
    else
        color="$GREEN"
    fi

    # Build the bar
    local bar="${color}["
    bar+="${PROGRESS_BAR_FILLED_CHARS:0:filled}"
    bar+="${PROGRESS_BAR_EMPTY_CHARS:0:empty}"
    bar+="]${RESET}"

    printf "%s %3d%%" "$bar" "$percent"
}

# Print section separator with icon and title
# Usage: print_section_header "ICON" "TITLE"
print_section_header() {
    local icon="$1"
    local title="$2"
    echo ""
    printf '%s\n' "$SEPARATOR_LINE"
    echo "${WHITE}${icon}  ${title}${RESET}"
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
    printf '%s\n' "$SEPARATOR_LINE"
}

# Print a box's top border with a bracketed, optionally colored label
# Usage: box_top_border "<label>" [color]
# Renders "┌─[ <label> ]───...───┐" at exactly WIDTH columns. <label> is
# measured as plain text and truncated if it would overflow the border;
# color is applied only when writing the label, never counted toward width.
box_top_border() {
    local label="$1"
    local color="$2"
    local max_label=$((WIDTH - 7)) # "┌─[ " + " ]" + "┐" = 7 non-label chars

    [ "${#label}" -gt "$max_label" ] && label="${label:0:max_label}"

    local colored_label="$label"
    [ -n "$color" ] && colored_label="${color}${label}${RESET}"

    local dashes="${SEPARATOR_LINE:0:$((max_label - ${#label}))}"

    printf '┌─[ %s ]%s┐\n' "$colored_label" "$dashes"
}

# Print a box's bottom border
# Usage: box_bottom_border
box_bottom_border() {
    printf '└%s┘\n' "${SEPARATOR_LINE:0:$((WIDTH - 2))}"
}

# Print a box content line, padded to exactly WIDTH columns
# Usage: box_line "<text>" [color]
# <text> is measured as plain text (no ANSI) and truncated if it would
# overflow the box; color is applied only on output, never counted toward
# width. Call with no text for a blank line.
box_line() {
    local text="$1"
    local color="$2"
    local box_pad=5
    local max_text=$((WIDTH - 2 - box_pad)) # both borders + left inner padding

    [ "${#text}" -gt "$max_text" ] && text="${text:0:max_text}"

    local colored_text="$text"
    [ -n "$color" ] && colored_text="${color}${text}${RESET}"

    local right_pad=$((WIDTH - 2 - box_pad - ${#text}))
    printf '│%*s%s%*s│\n' "$box_pad" '' "$colored_text" "$right_pad" ''
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
