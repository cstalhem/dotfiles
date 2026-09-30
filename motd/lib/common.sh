#!/bin/bash

#
# common.sh - Rendering helpers for the MOTD dashboard
# Part of custom MOTD dashboard
#
# This file is sourced by 10-dashboard, not executed directly. It knows how
# to draw rows, markers and alerts; it knows nothing about where data comes
# from. See README.md for the layout rules these helpers implement.
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

# Defined with $'...' so each holds a real ESC byte and renders through plain
# printf '%s' -- no output path needs echo -e / printf '%b', which would also
# interpret backslashes appearing in data.
readonly RED=$'\e[31m'
readonly YELLOW=$'\e[33m'
readonly BOLD=$'\e[1m'
readonly DIM=$'\e[2m'
readonly RESET=$'\e[0m'

# ==============================================================================
# Layout Constants
# ==============================================================================

readonly WIDTH=60        # No line may exceed this
readonly GUTTER=34       # Right-hand slots and the used/total figures start here
readonly LEFT_LABEL=7    # "load   " -- label field of left slots and bar rows
readonly RIGHT_LABEL=8   # "tailnet " -- label field of right slots
readonly BAR_WIDTH=15

# Precomputed character runs, so rows slice strings instead of spawning
# subprocesses (built once at source time)
printf -v _run '%*s' "$BAR_WIDTH" ''
readonly BAR_FILLED="${_run// /█}"
readonly BAR_EMPTY="${_run// /░}"
printf -v _run '%*s' "$WIDTH" ''
readonly RULE="${_run// /─}"
unset _run

# ==============================================================================
# Status: every value is "ok", "warn" or "crit"
# ==============================================================================

# Classify an integer against thresholds
# Usage: level <value> <warn_at> <crit_at>
level() {
    if [ "$1" -ge "$3" ]; then
        echo crit
    elif [ "$1" -ge "$2" ]; then
        echo warn
    else
        echo ok
    fi
}

# Print the one-column status marker: ✗ (crit), ! (warn) or a blank (ok).
# Markers always sit in a fixed column so problems can be found by scanning
# that column, with or without colour.
marker() {
    case "$1" in
        crit) printf '%s✗%s' "$RED" "$RESET" ;;
        warn) printf '%s!%s' "$YELLOW" "$RESET" ;;
        *)    printf ' ' ;;
    esac
}

# Print text in its status colour (healthy values use the default colour)
paint() {
    case "$1" in
        crit) printf '%s%s%s' "$RED" "$2" "$RESET" ;;
        warn) printf '%s%s%s' "$YELLOW" "$2" "$RESET" ;;
        *)    printf '%s' "$2" ;;
    esac
}

# ==============================================================================
# Rows
# ==============================================================================

# Print a row of one or two label/value slots
# Usage: pair_row <status> <label> <value> [<status> <label> <value>]
# The left marker sits in column 0, the right marker in column GUTTER-2 and
# the right label at GUTTER. Values are measured as plain text and truncated
# to their slot's budget; colour is applied only at output time.
pair_row() {
    local ls=$1 ll=$2 lv=$3 rs=$4 rl=$5 rv=$6
    local left_max=$((GUTTER - 2 - 1 - 2 - LEFT_LABEL)) # marker+space, 1 gap
    local right_max=$((WIDTH - GUTTER - RIGHT_LABEL))

    lv="${lv:0:left_max}"
    marker "$ls"
    printf ' %-*s' "$LEFT_LABEL" "$ll"
    paint "$ls" "$lv"

    if [ -n "$rl" ]; then
        rv="${rv:0:right_max}"
        printf '%*s' $((GUTTER - 2 - 2 - LEFT_LABEL - ${#lv})) ''
        marker "$rs"
        printf ' %-*s' "$RIGHT_LABEL" "$rl"
        paint "$rs" "$rv"
    fi
    printf '\n'
}

# Print a usage bar row: marker, label, bar, percentage, used / total
# Usage: bar_row <status> <label> <percent> <used_bytes> <total_bytes>
# Output: ✗ media  █████████████░░   90%     4.8 /  5.4 TiB
bar_row() {
    local status=$1 label=$2 percent=$3

    # Clamp so out-of-range input can't produce a malformed slice
    [ "$percent" -lt 0 ] && percent=0
    [ "$percent" -gt 100 ] && percent=100
    local filled=$((percent * BAR_WIDTH / 100))

    local pct
    printf -v pct '  %3d%%' "$percent"

    marker "$status"
    printf ' %-*s' "$LEFT_LABEL" "${label:0:LEFT_LABEL-1}"
    paint "$status" "${BAR_FILLED:0:filled}"
    printf '%s%s%s' "$DIM" "${BAR_EMPTY:0:BAR_WIDTH-filled}" "$RESET"
    paint "$status" "$pct"
    printf '    %s\n' "$(size_pair "$4" "$5")"
}

# Format "used / total unit", both in the unit that suits the total
# Usage: size_pair <used_bytes> <total_bytes>
# Output: "  6.9 / 15.5 GiB" or "  4.8 /  5.4 TiB"
size_pair() {
    awk -v u="$1" -v t="$2" '
        function fmt(x) { return x < 100 ? sprintf("%.1f", x) : sprintf("%d", x + 0.5) }
        BEGIN {
            d = 1024 ^ 3; unit = "GiB"
            if (t / d >= 1000) { d = 1024 ^ 4; unit = "TiB" }
            printf "%4s / %4s %s", fmt(u / d), fmt(t / d), unit
        }'
}

# Print the full-width horizontal rule
rule() {
    printf '%s\n' "$RULE"
}

# ==============================================================================
# Alerts
# ==============================================================================

CRIT_ALERTS=()
WARN_ALERTS=()

# Queue an alert line; all crit alerts print before all warn alerts
# Usage: alert <crit|warn> <text>
alert() {
    local text=$2
    local max=$((WIDTH - 2))
    [ "${#text}" -gt "$max" ] && text="${text:0:max-1}…"

    if [ "$1" = crit ]; then
        CRIT_ALERTS+=("$text")
    else
        WARN_ALERTS+=("$text")
    fi
}

# Print the alert block (a rule, then crit and warn lines), or nothing at all
# when there are no alerts
print_alerts() {
    [ $((${#CRIT_ALERTS[@]} + ${#WARN_ALERTS[@]})) -eq 0 ] && return

    rule
    local text
    for text in "${CRIT_ALERTS[@]}"; do
        marker crit; printf ' '; paint crit "$text"; printf '\n'
    done
    for text in "${WARN_ALERTS[@]}"; do
        marker warn; printf ' '; paint warn "$text"; printf '\n'
    done
}

# ==============================================================================
# Utilities
# ==============================================================================

# Join arguments with ", "
# Usage: join_list <item>...
join_list() {
    local out
    printf -v out '%s, ' "$@"
    printf '%s' "${out%, }"
}

# Check if a command exists
# Usage: command_exists <command>
command_exists() {
    command -v "$1" &>/dev/null
}
