## Code Review: 20-updates MOTD Script

Overall this is a solid implementation that follows the dashboard spec well. However, there are a few issues that should be addressed before merging.

---

### 🔴 Critical: Broken regex patterns with double-escaped backslashes

**Location:** Lines 66, 89

The regex patterns use incorrectly escaped backslashes that won't match digits:

```bash
# Line 66 - get_upgrade_version()
version=$(echo "$output" | grep -oP '\\d+\\.\\d+')

# Line 89 - get_security_count()
count=$(grep -i "security" "$updates_file" | grep -Eo '\\d+' | head -n1)
```

**Problems:**
- `grep -P '\\d+'` looks for literal `\d` (backslash + 'd'), not digits
- `grep -E '\\d+'` is even worse — ERE doesn't support `\d` at all, so it matches literal `\d`

**Suggested fix:** Use POSIX character classes for portability:
```bash
# Line 66
version=$(echo "$output" | grep -Eo '[0-9]+\.[0-9]+')

# Line 89
count=$(grep -i "security" "$updates_file" | grep -Eo '[0-9]+' | head -n1)
```

---

### 🟡 Medium: Fallback `print_line` function doesn't match `common.sh`

**Location:** Lines 41-45

The fallback implementation differs from `common.sh:115-120`:

```bash
# Current fallback (in 20-updates)
print_line() {
    local label="$1"
    local value="$2"
    local indent="${3:-$INDENT}"
    printf "%s${label} %s\n" "$indent" "$value"
}
```

**Problems:**
- Missing `DIM` styling for labels
- Missing `LABEL_WIDTH` alignment (20 chars)
- Missing `RESET` after label

**Suggested fix:**
```bash
print_line() {
    local label="$1"
    local value="$2"
    local indent="${3:-$INDENT}"
    printf "%s${DIM}%-20s${RESET} %s\n" "$indent" "$label" "$value"
}
```

---

### 🟡 Medium: Missing `DIM` and `LABEL_WIDTH` in fallback definitions

**Location:** Lines 14-27

The fallback block defines colors but omits `DIM` and `LABEL_WIDTH` which are used by `common.sh`.

**Suggested fix:** Add to the fallback definitions:
```bash
DIM='\e[2m'
LABEL_WIDTH=20
```

---

### 🟢 Minor: Missing color reset on package updates line

**Location:** Line 145

The main updates line may inherit color from previous output.

**Current:**
```bash
echo -e "${INDENT}${ICON_UPDATES} ${update_count} package updates available"
```

**Suggested fix:**
```bash
echo -e "${INDENT}${RESET}${ICON_UPDATES} ${update_count} package updates available"
```

---

### ✅ What looks good

- Proper sourcing of `common.sh` with fallback handling
- Follows the modular structure of other MOTD scripts
- Data collection before output section
- Sensible bounds check: `if [ "$security_count" -gt "$update_count" ]`
- Correct `shellcheck source=/dev/null` directive
- Matches the spec's conditional display logic
