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
| nf-oct-circle_slash | `\uf81e` | Stopped/Inactive |
| nf-fa-refresh | `\uf021` | Updates/Refresh |
| nf-fa-shield | `\uf132` | Security |

#### Section Icons

| Icon Name | Codepoint | Section |
|-----------|-----------|---------|
| nf-md-heart_pulse | `\udb81\udc8d` | System Health section header |
| nf-md-package_variant | `\udb81\udcbe` | Updates section header |
| nf-md-docker | `\udb81\ude4b` | Docker section header |
| nf-fa-users | `\uf0c0` | Users section header |

#### Subsection/Detail Icons

| Icon Name | Codepoint | Usage |
|-----------|-----------|-------|
| nf-fa-clock_o | `\uf017` | Uptime & Load subsection |
| nf-md-memory | `\udb81\udc98` | Memory subsection |
| nf-md-harddisk | `\udb80\udeca` | Storage subsection |
| nf-md-network | `\udb81\udc8d` | Network subsection |
| nf-fa-reboot / nf-md-restart | `\udb81\udcb5` | Reboot required |
| nf-fa-arrow_circle_o_up | `\uf062` | Upgrade available |
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
# Generate a progress bar
# Usage: progress_bar <percentage>
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
```

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
    local width=60
    echo ""
    printf '%s\n' "$(printf '─%.0s' $(seq 1 $width))"
    echo -e "${WHITE}${icon}  ${title}${RESET}"
    echo ""
}
```

### Shared Functions

A common functions file can be sourced by all scripts.

```bash
# /etc/update-motd.d/00-common (sourced, not executed)

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

# Progress bar function
progress_bar() {
    local percent=$1
    local width=15
    local filled=$((percent * width / 100))
    local empty=$((width - filled))
    
    local color
    if [ "$percent" -ge 85 ]; then
        color="$RED"
    elif [ "$percent" -ge 70 ]; then
        color="$YELLOW"
    else
        color="$GREEN"
    fi
    
    local bar="${color}["
    bar+=$(printf '%*s' "$filled" '' | tr ' ' '█')
    bar+=$(printf '%*s' "$empty" '' | tr ' ' '░')
    bar+="]${RESET}"
    
    printf "%s %3d%%" "$bar" "$percent"
}

# Section header function
print_section_header() {
    local icon="$1"
    local title="$2"
    echo ""
    printf '%s\n' "$(printf '─%.0s' $(seq 1 $WIDTH))"
    echo -e "${WHITE}${icon}  ${title}${RESET}"
    echo ""
}

# Print a label: value line with consistent alignment
# Usage: print_line "Label:" "value" [indent_level]
print_line() {
    local label="$1"
    local value="$2"
    local indent="${3:-$INDENT}"
    printf "%s${DIM}%-18s${RESET} %s\n" "$indent" "$label" "$value"
}
```

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

Hostname obtained via: `$(hostname -f 2>/dev/null || hostname)`
Short hostname for border: `$(hostname -s)`

#### Display Format

```
┌─[ srv1 ]────────────────────────────────────────────────┐
│                                                         │
│       Docker Host                                      │
│       Ubuntu 24.04.1 LTS  •  6.8.0-49-generic          │
│                                                         │
└─────────────────────────────────────────────────────────┘
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

- `lsb_release` command (usually pre-installed on Ubuntu)

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
───────────────────────────────────────────────────────────
󰗶  SYSTEM HEALTH

     Reboot required (kernel update)

     UPTIME & LOAD                           [  Healthy ]
      System uptime:      25 days 9 hours
      Load average:       0.42 (1m)  0.38 (5m)  0.35 (15m)
      Processes:          243 active

    󰍛 MEMORY
      RAM                 [██████████░░░░░]  62%     10.8 / 16 GB
      Swap                [░░░░░░░░░░░░░░░]   0%      0.0 / 4 GB

    󰋊 STORAGE
      /                   [██░░░░░░░░░░░░░]  31%     65.8 / 438 GB
       /mnt/media_data   [██████████████░]  89%    801.2 / 900 GB

    󰲝 NETWORK
      Local IP:           192.168.1.10               
      Tailnet IP:         100.123.12.321             
      Public IP:          81.234.56.78
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
- Cache public IP if possible (slow to fetch)
- If any IP unavailable, show fallback message in yellow

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
| Unhealthy > 0 | Show count in red with nf-fa-times_circle, list container names |
| Stopped > 0 | Show count in yellow |
| Healthy > 0 | Show count in green with nf-fa-check |
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

   Active sessions:            2
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