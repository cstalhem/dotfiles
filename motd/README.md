# MOTD Dashboard Requirements

This document defines the requirements for a custom SSH login MOTD (Message of the Day) dashboard for a home server running Ubuntu.

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Global Standards](#global-standards)
  - [Layout and Dimensions](#layout-and-dimensions)
  - [Color Palette](#color-palette)
  - [Nerd Font Icons](#nerd-font-icons)
  - [Progress Bar Standard](#progress-bar-standard)
  - [Box Drawing Characters](#box-drawing-characters)
  - [Shared Functions](#shared-functions)
  - [Locale](#locale)
- [Section Specifications](#section-specifications)
  - [00-header](#00-header)
  - [10-system-health](#10-system-health)
  - [20-updates](#20-updates)
  - [30-docker](#30-docker)
  - [40-users](#40-users)
- [Deployment](#deployment)

---

## Architecture Overview

### File Structure

Each section is implemented as an independent executable bash script in `/etc/update-motd.d/`. Scripts are numbered to control execution order.

| File | Section | Description |
|------|---------|-------------|
| `00-header` | Header | Box with nickname, hostname, OS info |
| `10-system-health` | System Health | Uptime, load, memory, storage, network |
| `20-updates` | Updates | Available apt package updates |
| `30-docker` | Docker | Container status overview |
| `40-users` | Users & Logins | Sessions, failed logins, recent activity |

### Design Principles

1. **Modularity**: Each section is independent and can be enabled/disabled by adding/removing execute permissions
2. **Fail-safe**: If a section fails, it should not prevent other sections from displaying
3. **Performance**: Scripts should execute quickly to avoid slowing down SSH login
4. **Consistency**: Fixed width, consistent indentation, aligned columns throughout
5. **Information density**: Show what matters, hide what doesn't (conditional display)

---

## Global Standards

### Layout and Dimensions

| Property | Value | Notes |
|----------|-------|-------|
| Total width | 60 characters | All sections respect this width |
| Indent level 1 | 3 spaces | Main content indent |
| Indent level 2 | 6 spaces | Sub-items |
| Indent level 3 | 9 spaces | Detail items |
| Label column | 20 characters | For aligned label: value pairs |
| Progress bar width | 15 characters | Inside brackets |

### Color Palette

All scripts should use these standardized ANSI color codes for consistency.

| Purpose | Color | ANSI Code | Escape Sequence | Usage |
|---------|-------|-----------|-----------------|-------|
| Reset | - | 0 | `\e[0m` | Reset to default after colored text |
| Normal text | Default | 0 | `\e[0m` | Regular information |
| Bold | - | 1 | `\e[1m` | Emphasis |
| Dim | Gray | 2 | `\e[2m` | Labels, hints, less important info |
| Section headers | Bold White | 1;37 | `\e[1;37m` | Section titles (e.g., "SYSTEM HEALTH") |
| OK/Success | Green | 32 | `\e[32m` | Healthy values, checkmarks |
| Warning | Yellow | 33 | `\e[33m` | Approaching thresholds |
| Critical/Error | Red | 31 | `\e[31m` | Problems needing attention |
| Accent/Highlight | Cyan | 36 | `\e[36m` | IPs, hostnames, container names |
| Accent Alt | Blue | 34 | `\e[34m` | Secondary accent |

#### Bash Color Variables

```bash
# Colors
readonly RED='\e[31m'
readonly GREEN='\e[32m'
readonly YELLOW='\e[33m'
readonly BLUE='\e[34m'
readonly CYAN='\e[36m'
readonly WHITE='\e[1;37m'
readonly BOLD='\e[1m'
readonly DIM='\e[2m'
readonly RESET='\e[0m'
```

### Nerd Font Icons

Scripts use Nerd Font icons for visual indicators. Icons are defined by their Nerd Font name for documentation clarity.

#### Status Icons

| Icon Name | Codepoint | Usage |
|-----------|-----------|-------|
| nf-fa-check | `\uf00c` | OK/Healthy status |
| nf-fa-warning | `\uf071` | Warning state |
| nf-fa-times_circle | `\uf05c` | Error/Critical state |
| nf-oct-circle_slash | `\uf468` | Stopped/Inactive |
| nf-fa-refresh | `\uf021` | Updates/Refresh |
| nf-fa-shield | `\uf132` | Security |

#### Section Icons

| Icon Name | Codepoint | Section |
|-----------|-----------|---------|
| nf-md-heart_pulse | `\udb81\uddf6` | System Health section header |
| nf-md-package_variant | `\udb80\udfd6` | Updates section header |
| nf-md-docker | `\udb82\udc68` | Docker section header |
| nf-fa-users | `\uf0c0` | Users section header |

#### Subsection/Detail Icons

| Icon Name | Codepoint | Usage |
|-----------|-----------|-------|
| nf-fa-clock_o | `\uf017` | Uptime & Load subsection |
| nf-md-memory | `\udb80\udf5b` | Memory subsection |
| nf-md-harddisk | `\udb80\udeca` | Storage subsection |
| nf-md-network | `\udb83\udc9d` | Network subsection |
| nf-fa-reboot / nf-md-restart | `\udb81\udf09` | Reboot required |
| nf-fa-arrow_circle_o_up | `\uf01b` | Upgrade available |
| nf-oct-container | `\uf4b7` | Container |
| nf-fa-user | `\uf007` | User/Session |
| nf-fa-ban | `\uf05e` | Failed login |
| nf-fa-history | `\uf1da` | Recent activity |

#### Bash Icon Variables

```bash
# Status Icons
readonly ICON_OK=$''                 # nf-fa-check
readonly ICON_WARN=$''               # nf-fa-warning
readonly ICON_ERROR=$''              # nf-fa-times_circle
readonly ICON_STOPPED=$''            # nf-oct-circle_slash
readonly ICON_REFRESH=$''            # nf-fa-refresh

# Section Icons
readonly ICON_HEALTH=$'󰗶'             # nf-md-heart_pulse
readonly ICON_UPDATES=$'󰏖'            # nf-md-package_variant
readonly ICON_DOCKER=$'󰡨'             # nf-md-docker
readonly ICON_USERS=$''              # nf-fa-users

# Detail Icons
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
```

### Progress Bar Standard

Progress bars provide a visual representation of resource usage.

#### Appearance

```
[██████████░░░░░]  62%
```

- Total width: 15 characters (inside brackets)
- Filled character: `█` (U+2588 FULL BLOCK)
- Empty character: `░` (U+2591 LIGHT SHADE)
- Brackets: `[` and `]`
- Percentage displayed after bar, right-aligned (3 chars)

#### Color Rules for Progress Bars

| Percentage | Color | Meaning |
|------------|-------|---------|
| 0-69% | Green | Normal/OK |
| 70-84% | Yellow | Warning |
| 85-100% | Red | Critical |

#### Bash Function

```bash
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
```

`PROGRESS_BAR_WIDTH`, `PROGRESS_BAR_FILLED_CHARS`, and `PROGRESS_BAR_EMPTY_CHARS` are precomputed constants (see [Shared Functions](#shared-functions)) so the function slices pre-built strings instead of spawning `printf`/`tr` subshells on every call.

### Box Drawing Characters

Consistent box drawing characters used throughout.

| Character | Unicode | Name | Usage |
|-----------|---------|------|-------|
| `─` | U+2500 | Box horizontal | Horizontal lines |
| `│` | U+2502 | Box vertical | Vertical borders |
| `┌` | U+250C | Box down and right | Top-left corner |
| `┐` | U+2510 | Box down and left | Top-right corner |
| `└` | U+2514 | Box up and right | Bottom-left corner |
| `┘` | U+2518 | Box up and left | Bottom-right corner |
| `[` | - | Bracket | Header hostname wrapper |
| `]` | - | Bracket | Header hostname wrapper |

#### Section Separator

```bash
# Print section separator with icon and title
# Usage: print_section_header "ICON" "TITLE"
print_section_header() {
    local icon="$1"
    local title="$2"
    echo ""
    printf '%s\n' "$SEPARATOR_LINE"
    echo -e "${WHITE}${icon}  ${title}${RESET}"
    echo ""
}
```

`SEPARATOR_LINE` is a precomputed constant (`WIDTH` `─` characters, see [Shared Functions](#shared-functions)) rather than a `seq`/`printf` subshell built on every call.

### Shared Functions

A common functions file (`lib/common.sh`, deployed to `/etc/update-motd.d/lib/common.sh`) is sourced by all scripts.

```bash
# /etc/update-motd.d/lib/common.sh (sourced, not executed)

# Colors
readonly RED='\e[31m'
readonly GREEN='\e[32m'
readonly YELLOW='\e[33m'
readonly BLUE='\e[34m'
readonly CYAN='\e[36m'
readonly WHITE='\e[1;37m'
readonly BOLD='\e[1m'
readonly DIM='\e[2m'
readonly RESET='\e[0m'

# Layout
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

    printf '┌─[ %b ]%s┐\n' "$colored_label" "$dashes"
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
    printf '│%*s%b%*s│\n' "$box_pad" '' "$colored_text" "$right_pad" ''
}
```

Key behavior for `box_top_border`, `box_line`, and `box_bottom_border`: text is always measured as *plain* text (before any color codes are applied) and truncated on overflow, while color is applied only at output time and never counted toward width. This guarantees a box renders at exactly `WIDTH` columns regardless of how long (or short) the label/value text is.

### Locale

`common.sh` exports the locale before anything else runs:

```bash
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
```

This is load-bearing, not cosmetic. Bash substring expansion (`${var:0:n}`) and `${#var}` are character-based only in a UTF-8 locale; outside one they are byte-based, which slices the 3-byte box-drawing characters (`─`, `│`, `┌`, etc.) mid-character and produces mojibake in the borders. `C.UTF-8` is used (rather than `en_US.UTF-8`) because it is built into glibc on Ubuntu 22.04+ and needs no `locale-gen`, whereas `en_US.UTF-8` is frequently not generated on a headless server.

---

## Section Specifications

### 00-header

#### Purpose

Display server identity in a compact, visually distinct box. Creates clear visual separation from previous terminal content.

#### Content

1. **Box with hostname**: Short hostname in top border
2. **Nickname**: Display name for the server (e.g., "Docker Host")
3. **OS Information**: Distribution and kernel version on one line

#### Configuration

| Variable | Description | Example |
|----------|-------------|---------|
| `NICKNAME` | Display name shown in box | `"Docker Host"` |

Hostname obtained via: `$(hostname -s 2>/dev/null || hostname)`. `-s` (short hostname) is used rather than `-f` (FQDN) because `-f` triggers a resolver lookup that can block SSH login when DNS is slow or unreachable.

#### Display Format

```
┌─[ srv1 ]─────────────────────────────────────────────────┐
│                                                          │
│     Docker Host                                          │
│     Ubuntu 24.04.1 LTS  •  6.8.0-49-generic              │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

#### Layout Specifications

| Element | Specification |
|---------|---------------|
| Box width | 60 characters (including borders) |
| Inner padding | 5 spaces from left border to text |
| Hostname in border | Surrounded by `[ ]`, positioned after `┌─` |
| Nickname | Bold cyan |
| OS line | Dim; distro and kernel separated by ` • ` |

#### Colors

| Element | Color |
|---------|-------|
| Box borders | Default |
| Hostname in border | Cyan |
| Nickname | Bold Cyan |
| OS info line | Dim |

#### Dependencies

- None beyond `/etc/os-release`, which the script sources directly (no `lsb_release` call). `$PRETTY_NAME` is read from it; if unset or missing, `OS_INFO` falls back to `"Unknown OS"`.

---

### 10-system-health

#### Purpose

Comprehensive system health overview including reboot status, resource utilization, storage, and network information.

#### Content

1. **Reboot Required Alert** (conditional): Only shown if reboot needed
2. **Uptime & Load**: System uptime, load averages with health badge
3. **Memory**: RAM and Swap usage with progress bars
4. **Storage**: Configured mount points with progress bars
5. **Network**: Local IP, Tailscale IP, Public IP

#### Configuration

| Variable | Description | Example |
|----------|-------------|---------|
| `MOUNT_POINTS` | Array of mount points to monitor | `("/" "/mnt/media_data")` |
| `MOUNT_LABELS` | Associative array of labels | `(["/"]="/" ["/mnt/media_data"]="/mnt/media_data")` |

##### Initial Mount Configuration

| Mount Point | Label |
|-------------|-------|
| `/` | `/` |
| `/mnt/media_data` | `/mnt/media_data` |

#### Display Format

```
────────────────────────────────────────────────────────────
󰗶  SYSTEM HEALTH

   󰜉 Reboot required (kernel update)

    UPTIME & LOAD                          [  Healthy ]
      System uptime:       25 days 9 hours
      Load average:        0.42 (1m)  0.38 (5m)  0.35 (15m)
      Processes:           4 running / 243 total

   󰍛 MEMORY
      RAM                  [█████████░░░░░░]  62%     10.8 / 16.0 GB
      Swap                 [░░░░░░░░░░░░░░░]   0%     0.0 / 4.0 GB

   󰋊 STORAGE
      /                    [████░░░░░░░░░░░]  31%    65.8 / 438.0 GB
       /mnt/media_data      [█████████████░░]  89%    801.2 / 900.0 GB

   󰲝 NETWORK
      Local IP:            192.168.1.10
      Tailnet IP:          100.123.12.321   Connected
      Public IP:           81.234.56.78
```

#### Subsection: Reboot Required

| Condition | Display |
|-----------|---------|
| Reboot required | Show: `{ICON_WARN} Reboot required (reason)` in yellow |
| No reboot needed | Hide this line entirely |

Detection: Check for `/var/run/reboot-required` file. Reason from `/var/run/reboot-required.pkgs`.

#### Subsection: Uptime & Load

##### Health Badge

| Load per Core | Badge | Color |
|---------------|-------|-------|
| < 0.70 | `[ {ICON_OK} Healthy ]` | Green |
| 0.70 - 0.99 | `[ {ICON_WARN} Elevated ]` | Yellow |
| ≥ 1.00 | `[ {ICON_ERROR} High ]` | Red |

Load per core = 1-minute load / number of CPU cores (from `nproc`).

##### Data Sources

| Metric | Source |
|--------|--------|
| Uptime | `/proc/uptime` parsed to days/hours |
| Load | `/proc/loadavg` |
| CPU cores | `nproc` |
| Processes | Fourth field of `/proc/loadavg` |

#### Subsection: Memory

| Metric | Warning (Yellow) | Critical (Red) |
|--------|------------------|----------------|
| RAM % | ≥ 70% | ≥ 85% |
| Swap % | ≥ 50% | ≥ 75% |

Format: `[progress_bar] XX%    USED / TOTAL GB`

Data source: `/proc/meminfo` or `free -b`

#### Subsection: Storage

| Metric | Warning (Yellow) | Critical (Red) |
|--------|------------------|----------------|
| Disk % | ≥ 70% | ≥ 85% |

Format: `MOUNT_LABEL    [progress_bar] XX%    USED / TOTAL GB`

Display rules:
- Show all configured mount points
- Skip mount points that don't exist
- Warning icon (nf-fa-warning) prepended to label if ≥ 70%
- Values right-aligned

Percentage definition: matches GNU `df`'s `Use%` exactly — `used / (used + available)`, i.e. it **excludes** the blocks `df` reserves for root, rounded **up** (ceiling), not truncated. The displayed `USED / TOTAL GB` figures still use `Size` (the filesystem's full block count, including the root-reserved blocks) as the total — exactly what `df -h` itself displays. The two denominators differ by the ~5% ext4 root reservation, so the displayed percentage and the displayed `USED / TOTAL` ratio will not exactly agree by naive division; this is intentional and matches `df`'s own behavior.

Data source: `df -B1` for byte-accurate values

#### Subsection: Network

| Item | Source | Fallback |
|------|--------|----------|
| Local IP | `ip route get 1.1.1.1 \| grep -oP 'src \K[\d.]+'` | `hostname -I \| awk '{print $1}'` |
| Tailnet IP | `tailscale ip -4 2>/dev/null` | Show `Not connected` in yellow |
| Public IP | `curl -s --max-time 2 ipinfo.io/ip` | Show `Unable to detect` in yellow |

Display rules:
- IPs shown in cyan
- Show `{ICON_OK} Connected` next to IP for Local and Tailnet
- Public IP is cached to avoid a network call on every login (slow to fetch)
- If any IP unavailable, show fallback message in yellow

Public IP cache: file `/run/motd-public-ip`, TTL 900 seconds (15 minutes). If the cache file exists and is younger than the TTL, its contents are printed directly instead of calling out to `ipinfo.io`.

The cache lives in `/run` rather than `/tmp` deliberately: the MOTD script runs as root, and `/run` is root-owned tmpfs. `/tmp` is world-writable, so a world-writable cache location would let an unprivileged local user plant the file's contents, which root would then print, unverified, into the login banner. The tradeoff is that `/run` is tmpfs, so the cache is lost on every reboot (acceptable, since the first login after reboot simply pays the fetch cost once).

---

### 20-updates

#### Purpose

Show available system updates with special attention to security updates and Ubuntu version upgrades.

#### Content

1. **Ubuntu Upgrade Available** (conditional): Only if new Ubuntu version available
2. **Update Summary**: Count of available updates broken down by type
3. **Recent Packages**: Names of a few packages with updates
4. **Command Hints**: How to view and install updates (only when updates available)

#### Display Format

##### When updates available:

```
───────────────────────────────────────────────────────────
󰏖  UPDATES

    Ubuntu 24.10 available for upgrade

   󰏖 23 package updates available
       5 security updates
      󰏖 18 standard updates

   Most recent packages: docker-ce, tailscale, libgnu-4

   To view updates:
      Security only:     apt list --upgradable | grep -i security
      All updates:       apt list --upgradable

   Install all updates:  sudo apt update && sudo apt upgrade
```

##### When no updates available:

```
───────────────────────────────────────────────────────────
󰏖  UPDATES

    System is up to date
```

#### Display Rules

| Condition | Behavior |
|-----------|----------|
| Ubuntu upgrade available | Show upgrade line with nf-fa-arrow_up icon, yellow |
| Security updates > 0 | Show security count with nf-fa-shield icon, red |
| Standard updates > 0 | Show count, yellow if > 0 |
| No updates | Show "System is up to date" with nf-fa-check icon, green |
| Updates available | Show recent packages (up to 3) and command hints |
| No updates | Hide command hints |

#### Data Sources

| Metric | Source |
|--------|--------|
| Ubuntu upgrade | `/var/lib/update-notifier/release-upgrade-available` or `do-release-upgrade -c` |
| Update count | `apt-get -s upgrade 2>/dev/null \| grep -c "^Inst"` |
| Security count | Parse from `/var/lib/update-notifier/updates-available` or filter apt output |
| Package names | `apt list --upgradable 2>/dev/null \| tail -n +2 \| cut -d'/' -f1 \| head -3` |

---

### 30-docker

#### Purpose

Overview of Docker container fleet with health status breakdown.

#### Content

1. **Container Counts**: Running and stopped totals
2. **Health Breakdown**: Healthy, unhealthy, no healthcheck counts
3. **Unhealthy List** (conditional): Names of unhealthy containers

#### Display Format

##### With unhealthy containers:

```
───────────────────────────────────────────────────────────
󰡨 DOCKER

   Containers
      Running:            28
      Stopped:             3
      
      Health status:
         Healthy:         19  
         Unhealthy:        1
      No healthcheck:     11
      
      Unhealthy:
         portainer, traefik, pihole
```

##### All healthy, no issues:

```
───────────────────────────────────────────────────────────
󰡨 DOCKER

   Containers
      Running:            28
      Stopped:             0
      
      Health status:
         Healthy:         19  
      No healthcheck:      9
```

##### Docker not running

```
───────────────────────────────────────────────────────────
󰡨 DOCKER

    Docker not running
```

#### Container State Definitions

| State | Definition |
|-------|------------|
| Running | Container is up, regardless of health status |
| Stopped | Container is exited/stopped |
| Healthy | Running + healthcheck passing |
| Unhealthy | Running + healthcheck failing |
| No healthcheck | Running + no healthcheck defined |

Relationship: `Running = Healthy + Unhealthy + No healthcheck`

#### Display Rules

| Condition | Behavior |
|-----------|----------|
| Stopped > 0 | Show count in yellow |
| Healthy > 0 | Show count in green with nf-fa-check |
| Unhealthy > 0 | Show count in red with nf-fa-times_circle, list container names |
| Docker not running | Show error: "Docker daemon not running" in red |

#### Unhealthy Container List

- Show all unhealthy container names
- Names in cyan
- Comma-separated on single line
- Wrap to next line if exceeds width (60 chars)
- Indented under "Unhealthy:" label

#### Data Sources

```bash
# Check Docker running
docker info &>/dev/null

# Total containers
docker ps -a --format '{{.ID}}' | wc -l

# Running containers
docker ps --format '{{.ID}}' | wc -l

# Stopped containers
docker ps -a --filter "status=exited" --format '{{.ID}}' | wc -l

# Healthy containers
docker ps --filter "health=healthy" --format '{{.ID}}' | wc -l

# Unhealthy containers
docker ps --filter "health=unhealthy" --format '{{.Names}}'

# Containers with no healthcheck (running minus healthy minus unhealthy)
# Or: docker inspect with health check filtering
```

---

### 40-users

#### Purpose

Security-focused view of current sessions, failed login attempts, and recent login activity.

#### Content

1. **Active Sessions**: Currently logged in users with details
2. **Failed Logins** (conditional): Failed attempts in last 24h from fail2ban
3. **Recent Activity**: Last 5 login sessions

#### Display Format

##### With failed logins:

```
───────────────────────────────────────────────────────────
 USERS & LOGINS

   Active sessions:            1
         calle @ 192.168.1.50     Mon Dec 16 14:22

     Failed logins (24h):        3 attempts
         root (x2)                203.0.113.42
         admin (x1)               198.51.100.23

     Recent activity:
         admin                    Mon Dec 16 14:23  →  present
         admin                    Mon Dec 16 09:15  →  12:33  (3h 18m)
         backup                   Sun Dec 15 02:00  →  02:15  (15m)
```

##### No failed logins:

```
───────────────────────────────────────────────────────────
 USERS & LOGINS

   Active sessions:               2
         calle @ 192.168.1.50     Mon Dec 16 14:22
         admin @ console          Mon Dec 16 08:00

   Recent activity:
         admin                    Mon Dec 16 14:23  →  present
         calle                    Mon Dec 16 09:15  →  12:33  (3h 18m)
         backup                   Sun Dec 15 02:00  →  02:15  (15m)
```

#### Subsection: Active Sessions

Format: `USERNAME @ SOURCE     DATETIME`

| Element | Color |
|---------|-------|
| Username | Cyan (yellow if root) |
| Source (IP/tty) | Dim |
| Datetime | Dim |

Data source: `who`

#### Subsection: Failed Logins (Conditional)

Only displayed if failed login count > 0.

| Condition | Display |
|-----------|---------|
| Failed logins > 0 | Show with nf-fa-ban icon, yellow header |
| Failed logins = 0 | Hide entire subsection |

Format: Grouped by username with count, showing source IP

Data source: fail2ban logs
- Primary: `fail2ban-client status sshd`
- Fallback: Parse `/var/log/fail2ban.log`
- Alternative: Parse `/var/log/auth.log` for "Failed password"

#### Subsection: Recent Activity

Show last 5 login sessions (configurable).

Format: `USERNAME     DATETIME_START  →  DATETIME_END  (DURATION)`

| State | End Time Display |
|-------|------------------|
| Still logged in | `present` |
| Logged out | End time + duration |

| Element | Color |
|---------|-------|
| Username | Cyan (yellow if root) |
| Times | Default |
| Duration | Dim |

Data source: `last -n 5 -w`

---

## Deployment

### chezmoi Integration

The MOTD scripts are stored in the chezmoi source directory and deployed via a run script.

#### Source Structure

```
~/.local/share/chezmoi/
├── motd/
│   ├── lib/
│   │   └── common.sh         # Shared functions, colors, icons
│   ├── 00-header
│   ├── 10-system-health
│   ├── 20-updates
│   ├── 30-docker
│   └── 40-users
└── run_onchange_after_install-motd.sh.tmpl
```

#### Deployment Script Features

The `run_onchange_after_install-motd.sh.tmpl` script:

1. Only runs on Linux (skips macOS)
2. Creates one-time backup of original scripts to `/etc/update-motd.d.original`
3. Disables default Ubuntu MOTD scripts (removes execute permission)
4. Copies custom scripts to `/etc/update-motd.d/`
5. Sets correct ownership (root:root) and permissions (755)
6. Re-runs when any motd script content changes (via hash comment)

#### Scripts to Disable

Remove execute permission from these default scripts:

- `00-header`
- `10-help-text`
- `50-landscape-sysinfo`
- `50-motd-news`
- `85-fwupd`
- `90-updates-available`
- `91-contract-ua-esm-status`
- `91-release-upgrade`
- `92-unattended-upgrades`
- `95-hwe-eol`
- `97-overlayroot`
- `98-fsck-at-reboot`
- `98-reboot-required`

### Dependencies

| Package | Purpose | Install Command |
|---------|---------|-----------------|
| `fail2ban` | Failed login tracking | `sudo apt install fail2ban` |
| `curl` | Public IP detection | Usually pre-installed |
| `tailscale` | Tailscale IP (optional) | Via Tailscale install script |

### Testing

```bash
# Test a single script
sudo /etc/update-motd.d/00-header

# Test all MOTD scripts in order
sudo run-parts /etc/update-motd.d/

# Force refresh on next SSH login
sudo rm /var/run/motd.dynamic
```

### Permissions

All scripts in `/etc/update-motd.d/` must have:

- Owner: `root:root`
- Permissions: `755` (rwxr-xr-x)

---

## Future Enhancements

Potential additions for later versions:

1. **Temperature monitoring**: CPU/disk temperatures if sensors available
2. **Service status**: Check status of critical systemd services
3. **Backup status**: Last backup time from backup service
4. **SSL certificate expiry**: Days until certificates expire
5. **ZFS pool status**: If using ZFS, show pool health
6. **Fail2ban summary**: Total bans, currently banned IPs