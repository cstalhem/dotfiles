# MOTD Dashboard

A custom SSH login MOTD (Message of the Day) for a home server running Ubuntu. It replaces Ubuntu's stock MOTD scripts with a single compact panel.

## Table of Contents

- [Design Principles](#design-principles)
- [Examples](#examples)
- [Layout](#layout)
- [Markers and Colour](#markers-and-colour)
- [Panel Rows](#panel-rows)
- [Alerts](#alerts)
- [Coverage of Ubuntu's Stock MOTD](#coverage-of-ubuntus-stock-motd)
- [Configuration](#configuration)
- [Files](#files)
- [Locale](#locale)
- [Deployment](#deployment)
- [Testing](#testing)

---

## Design Principles

1. **Quiet when healthy, loud when not.** A login banner is read in about two seconds. Its jobs are to answer *which machine am I on?* and *does anything need me?*
2. **Colour is a signal, not decoration.** Healthy values use the terminal's default colour. Only warnings (yellow) and critical values (red) are coloured, so a problem is the only coloured thing on screen.
3. **Readable without colour.** Every coloured value also carries a marker (`!` or `✗`) in a fixed column.
4. **Fixed slots.** Every metric has the same position at every login, so you learn where to look.
5. **Honour the width.** No line exceeds 60 columns. The panel must work in a phone SSH client or a split pane.
6. **Plain Unicode only.** No Nerd Font icons. Box-drawing and block characters, `·`, `✓`, `!` and `✗` exist in every monospace font and render at single width.
7. **Cheap and non-blocking.** Nothing at login may take more than about 2 seconds, even when a network share, Docker or the internet is unreachable. Expensive facts come from stamp files that other tools maintain.

---

## Examples

### A quiet day (12 lines)

```
srv1 · Home Server                                 up 1d 16h
Ubuntu 24.04.5 LTS · Linux 6.8.0-142-generic
────────────────────────────────────────────────────────────
  load   1.04 0.91 0.87 (8c)      temp    72°C
  procs  488                      docker  43 · 21 healthy

  ram    ██████░░░░░░░░░   44%     6.9 / 15.5 GiB
  swap   ███████░░░░░░░░   50%     2.0 /  4.0 GiB
  /      ████░░░░░░░░░░░   30%     127 /  455 GiB
  media  ██████████░░░░░   65%     3.5 /  5.4 TiB

  lan    192.168.0.201            tailnet 100.97.193.76
  wan    78.73.121.212
```

### A typical day

```
srv1 · Home Server                                 up 1d 16h
Ubuntu 24.04.5 LTS · Linux 6.8.0-142-generic
────────────────────────────────────────────────────────────
  load   1.04 0.91 0.87 (8c)      temp    72°C
! procs  488 · 3 zombies          docker  43 · 21 healthy

  ram    ██████░░░░░░░░░   44%     6.9 / 15.5 GiB
  swap   ███████░░░░░░░░   50%     2.0 /  4.0 GiB
  /      ████░░░░░░░░░░░   30%     127 /  455 GiB
✗ media  █████████████░░   90%     4.8 /  5.4 TiB

  lan    192.168.0.201            tailnet 100.97.193.76
  wan    78.73.121.212
────────────────────────────────────────────────────────────
! 7 updates · apt list --upgradable
```

### A bad day

```
srv1 · Home Server                                 up 3h 12m
Ubuntu 24.04.5 LTS · Linux 6.8.0-142-generic
────────────────────────────────────────────────────────────
✗ load   9.84 7.12 4.03 (8c)    ✗ temp    91°C
! procs  512 · 14 zombies       ✗ docker  43 · 2 unhealthy

✗ ram    █████████████░░   93%    14.4 / 15.5 GiB
✗ swap   ████████████░░░   81%     3.2 /  4.0 GiB
! /      ███████████░░░░   76%     346 /  455 GiB
✗ media  ██████████████░   97%     5.3 /  5.4 TiB

  lan    192.168.0.201          ! tailnet not connected
! wan    unable to detect
────────────────────────────────────────────────────────────
✗ unhealthy: traefik, immich-server
✗ 3 security updates · sudo apt upgrade
! reboot required (linux-image-6.8.0-145-generic)
! 3 failed ssh logins (24h) · 192.168.0.12
! 12 other updates · apt list --upgradable
! Ubuntu 26.04 LTS available · do-release-upgrade
```

---

## Layout

| Element | Rule |
|---------|------|
| Width | 60 columns maximum, for every line |
| Row marker | Column 0 |
| Left slot label | Column 2, 7-character field |
| Right slot marker | Column 32 |
| Right slot label / used-total figures | Column 34 (`GUTTER`). Right-hand slots and the bars' used/total figures share this vertical line |
| Right slot label field | 8 characters |
| Left slot value budget | 22 characters (truncated beyond) |
| Right slot value budget | 18 characters (truncated beyond) |
| Bar | 15 characters, `█` filled, `░` empty (dim), no brackets |
| Alert text budget | 58 characters, truncated with `…` |

The order of the output, top to bottom:

1. **Header.** Bold hostname, nickname and uptime on line 1. OS and kernel (dim) on line 2. Then a rule.
2. **Slot rows.** `load | temp` and `procs | docker`.
3. A blank line, then **bar rows**: `ram`, `swap` (hidden if there is no swap) and each configured mount.
4. A blank line, then **network rows**: `lan | tailnet` and `wan`.
5. **Alert block.** A rule, then the alerts. The whole block is omitted when there are no alerts.

A value that doesn't fit its slot's budget gets its own row. Paired slots are for short values only.

Sizes are binary units (GiB, or TiB when the total is at least 1000 GiB). Values below 100 are shown with one decimal, larger values as integers.

---

## Markers and Colour

| Status | Marker | Colour | Meaning |
|--------|--------|--------|---------|
| ok | *(blank)* | Default | Nothing to do |
| warn | `!` | Yellow | Worth knowing, or approaching a limit |
| crit | `✗` | Red | Needs attention |

The marker and the slot's value (or the bar and its percentage) take the status colour. Labels always stay in the default colour, so rows remain readable. Reading down column 0 shows every problem on screen.

Other colours: the hostname is bold, the OS line and the empty part of bars are dim. Nothing else is styled.

---

## Panel Rows

| Row | Value | Source | Warn | Crit |
|-----|-------|--------|------|------|
| `load` | 1, 5 and 15-minute load, core count | `/proc/loadavg`, `nproc` | 5-min load per core ≥ 0.70 | ≥ 1.00 |
| `temp` | Hottest thermal zone | `/sys/class/thermal/thermal_zone*/temp` (same as landscape-sysinfo) | ≥ 80 °C | ≥ 90 °C |
| `procs` | Process count, plus zombies if any | `ps -eo stat=` (processes, not threads) | Any zombie | – |
| `docker` | Running containers · healthy count, or · unhealthy count | `docker ps -a` (2s timeout) | – | Any unhealthy or restarting, or daemon not responding |
| `ram` | Used / total | `/proc/meminfo`, used = `MemTotal − MemAvailable` | ≥ 70% | ≥ 85% |
| `swap` | Used / total | `/proc/meminfo` | ≥ 50%, **only while RAM is warn or worse** | ≥ 75%, same condition |
| mounts | Used / size | `df -B1` (2s timeout) | ≥ 70% | ≥ 85% |
| `lan` | Source address of the default route | `ip route get 1.1.1.1`, fallback `hostname -I` | Not detected | – |
| `tailnet` | Tailscale IPv4 | `tailscale ip -4`. The slot is hidden if Tailscale isn't installed | Not connected | – |
| `wan` | Public IP | `ipinfo.io`, cached | Not detected | – |

Notes:

- **Load** is judged on the 5-minute average, because the 1-minute average spikes from the login itself.
- **Swap** in use is normal on Linux (idle pages get moved out), so swap is only judged when RAM is under pressure.
- **Disk percentage** matches GNU `df`'s `Use%` exactly: `used / (used + available)`. That excludes the blocks reserved for root, and it is rounded up. The used/total figures use the filesystem's full size, as `df -h` does. The two therefore differ by the roughly 5% ext4 root reservation, which is intentional.
- **Unreachable mounts.** A configured mount that doesn't answer within 2 seconds shows `! <label> unreachable` instead of a bar. `df` is read through `read -t`, not `timeout`: a process blocked in the kernel on a dead CIFS/NFS share ignores signals, but `read -t` returns anyway and leaves the stuck `df` behind without waiting for it.
- **Docker.** Containers that exited with code 0 are finished jobs, not failures. Only non-zero exits and `dead` containers are reported (as alerts).
- **Public IP cache.** The cache is `/run/motd-public-ip`, with a TTL of 15 minutes. It lives in `/run` (root-owned tmpfs) rather than world-writable `/tmp`, so no unprivileged user can plant text that root then prints into the login banner. The cost is one fresh fetch after each reboot. A response that isn't an IP address, such as a captive portal page, is discarded.

---

## Alerts

Alerts are for **events and facts that have no slot**. A problem that has a slot lights up in place; an alert is only added when the slot can't say enough, for example which containers are unhealthy.

All crit alerts print before all warn alerts. Within each group they appear in this order:

| # | Alert | Level | Source |
|---|-------|-------|--------|
| 1 | `unhealthy: <names>` | crit | `docker ps` |
| 2 | `restarting: <names>` | crit | `docker ps` |
| 3 | `N security updates · sudo apt upgrade` | crit | Stamp: `/var/lib/update-notifier/updates-available` |
| 4 | `<mount> is N% full · used / size` | crit | Any local filesystem (ext2/3/4, xfs, btrfs, zfs, vfat) **not** shown as a bar, at ≥ 85% |
| 5 | `reboot required (<package>)` | warn | `/var/run/reboot-required`, `.pkgs` |
| 6 | `N failed ssh logins (24h) · <sources>` | warn | `journalctl -u ssh`, one per connection sshd gave up on |
| 7 | `N users logged in: <users>` | warn | `who`, when more than one distinct user is logged in |
| 8 | `exited with error: <names>` | warn | `docker ps` |
| 9 | `N (other) updates · apt list --upgradable` | warn | Stamp: `updates-available` |
| 10 | `update list is N days old · sudo apt update` | warn | `updates-available` stamp older than 7 days, meaning the apt timer is broken and the counts are stale |
| 11 | `N updates kept back by unattended-upgrades` | warn | `/var/lib/unattended-upgrades/kept-back` |
| 12 | `<device> will be checked for errors at next reboot` | warn | Helper: `update-motd-fsck-at-reboot` (root only) |
| 13 | fwupd's notice | warn | `/run/motd.d/85-fwupd` |
| 14 | HWE end-of-life notice | warn | Helper: `update-motd-hwe-eol` (only while its stamp is under a day old) |
| 15 | `Ubuntu <version> available · do-release-upgrade` | warn | Helper: `release-upgrade-motd` (root only) |

**Failed logins.** The box is only reachable over the LAN and Tailscale, so any failed login comes from inside the network and is worth seeing. There is no fail2ban. A failure is counted from the line sshd logs when it gives up on a connection (`Connection closed by` / `Disconnected from` / `Disconnecting` + `authenticating user` / `invalid user`), which gives one count per failed connection regardless of the auth method. Aborting a passphrase prompt also produces such a line, and is counted.

### Producers and presenters

Ubuntu separates **producers** (apt hooks, timers and daemons that write stamp files) from **presenters** (the scripts in `/etc/update-motd.d` that print them). This dashboard replaces the presenters and keeps the producers:

- **Stamps read directly** where an independent producer keeps them fresh:
  - updates, written by the `99update-notifier` apt hook after every `apt update`
  - reboot-required, written by package postinst scripts
  - kept-back, written by unattended-upgrades
  - fwupd, written by fwupd
- **Helpers called and their output reformatted** where the stock presenter refreshes its own stamp when it runs: release upgrade, fsck and HWE. Reading those stamps directly would let the alerts go stale once the stock scripts are disabled. The stock scripts' guards are kept, such as root-only and the HWE stamp age.

No `apt` command ever runs at login.

---

## Coverage of Ubuntu's Stock MOTD

| Stock data point | Here |
|------------------|------|
| OS, kernel | Header |
| System load, temperature, processes, zombies | Slots |
| Memory, swap, usage of `/` | Bars |
| Any filesystem ≥ 85% | Alert #4 (and bars for configured mounts) |
| IPv4 per interface | `lan` (plus `tailnet`, `wan`) |
| Users logged in | Alert #7, only when it isn't just you |
| Updates, security updates, stale update list | Alerts #3, #9, #10 |
| Release upgrade, reboot, fsck, HWE, fwupd, unattended-upgrades | Alerts |
| Last login, mail | Unchanged: printed by sshd / `pam_mail`, not by MOTD scripts |
| *Deliberately dropped:* architecture, "as of" timestamp, IPv6, help links, motd-news, ESM/Pro status, Landscape link, overlayroot | – |

---

## Configuration

At the top of `10-dashboard`:

| Variable | Description | Example |
|----------|-------------|---------|
| `NICKNAME` | Display name in the header | `"Home Server"` |
| `MOUNT_POINTS` | Mounts shown as bars | `("/" "/mnt/media_data")` |
| `MOUNT_LABELS` | Bar labels, at most 6 characters. Falls back to the (truncated) path | `(["/mnt/media_data"]="media")` |
| `PUBLIC_IP_CACHE_FILE`, `PUBLIC_IP_CACHE_TTL` | Public IP cache | `/run/motd-public-ip`, `900` |

---

## Files

```
motd/
├── lib/
│   └── common.sh     # Rendering helpers: markers, rows, bars, alerts (sourced)
├── 10-dashboard      # Data collection and layout
└── README.md
```

This is a single script rather than one script per section. The alert block collects facts from every part of the panel and prints them ordered by severity, and that needs all the data in one process. `common.sh` knows how to draw; `10-dashboard` knows where data comes from.

---

## Locale

`common.sh` exports `LANG=C.UTF-8` and `LC_ALL=C.UTF-8` before anything else runs. This is load-bearing, not cosmetic. Bash substring expansion (`${var:0:n}`) and `${#var}` are character-based only in a UTF-8 locale; outside one they are byte-based, which slices the multi-byte characters (`─`, `█`, `·`) mid-character. `C.UTF-8` is used because it is built into glibc on Ubuntu 22.04+ and needs no `locale-gen`, unlike `en_US.UTF-8`.

---

## Deployment

`run_onchange_after_install-motd.sh.tmpl` at the repository root deploys the dashboard. It only renders on `srv1`, and it re-runs whenever `10-dashboard` or `common.sh` changes (their hashes are embedded in the script). It:

1. Moves every entry in `/etc/update-motd.d` that isn't part of this dashboard (the stock Ubuntu scripts) into `/etc/update-motd.d.original`. Moving is used rather than `chmod -x`, because dpkg doesn't recreate a conffile the admin has deleted, but it can restore a conffile's mode when a package upgrade ships a new version.
2. Removes files from earlier versions of this dashboard (`00-header` and `10-system-health`, identified by their "Part of custom MOTD dashboard" header).
3. Installs `10-dashboard` (755) and `lib/common.sh` (644), owned by root.

The `motd/` folder is listed in `.chezmoiignore`, so chezmoi doesn't also copy it into the home directory.

To restore the stock MOTD, move the scripts in `/etc/update-motd.d.original` back.

### Permissions

- `10-dashboard`: `root:root`, `755`
- `lib/common.sh`: `root:root`, `644` (sourced, never executed; `run-parts` ignores directories)

---

## Testing

```bash
# Render as root, exactly as at login
sudo /etc/update-motd.d/10-dashboard

# Run everything pam_motd runs
sudo run-parts --lsbsysinit /etc/update-motd.d/

# Check the width rule (strip colour, print over-long lines)
sudo /etc/update-motd.d/10-dashboard | sed 's/\x1b\[[0-9;]*m//g' | awk 'length > 60'
```

Running as a normal user works too, but skips the root-only helpers (release upgrade, fsck) and can't write the public IP cache.
