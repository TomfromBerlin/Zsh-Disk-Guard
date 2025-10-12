#!/usr/bin/env zsh
#
# ===================================================================
#  Zsh Disk Guard Plugin
#  Intelligent disk space monitoring for write operations
#
#  Author: Tom from Berlin
#  License: MIT
#  Repository: https://github.com/TomfromBerlin/zsh-disk-guard
# ===================================================================

# ──────────────────────────────────────────────────────────────────
#  Version Check
# ──────────────────────────────────────────────────────────────────

# Load version comparison function
if ! autoload -Uz is-at-least 2>/dev/null; then
    print -P "%F{red}Error: Cannot load is-at-least function%f" >&2
    return 1
fi

# Require Zsh 5.0+
if ! is-at-least 5.0; then
    print -P "%B%F{red}Error: zsh-disk-guard requires Zsh >= 5.0%f" >&2
    print -P "%B%F{yellow}You are using Zsh $ZSH_VERSION%f" >&2
    print -P "%F{yellow}Consider an upgrade: https://www.zsh.org/%f" >&2
    return 1
fi

# ──────────────────────────────────────────────────────────────────
#  Plugin Initialization (Zsh Plugin Standard)
# ──────────────────────────────────────────────────────────────────

0="${ZERO:-${${0:#$ZSH_ARGZERO}:-${(%):-%N}}}"
0="${${(M)0:#/*}:-$PWD/$0}"

[[ -n "$_zsh_disk_guard_loaded" ]] && return
typeset -g _zsh_disk_guard_loaded=1
typeset -g ZSH_DISK_GUARD_PLUGIN_DIR="${0:A:h}"

# ──────────────────────────────────────────────────────────────────
#  Configuration
# ──────────────────────────────────────────────────────────────────

# Disk usage threshold (percentage)
: ${ZSH_DISK_GUARD_THRESHOLD:=80}

# Size threshold for deep checking (bytes)
: ${ZSH_DISK_GUARD_DEEP_THRESHOLD:=$((100 * 1024 * 1024))}  # 100 MiB

# Enable debug output
: ${ZSH_DISK_GUARD_DEBUG:=0}

# Enable/disable the plugin
: ${ZSH_DISK_GUARD_ENABLED:=1}

# Commands to wrap (space-separated)
: ${ZSH_DISK_GUARD_COMMANDS:="cp mv rsync"}

# ──────────────────────────────────────────────────────────────────
#  Internal Functions
# ──────────────────────────────────────────────────────────────────

_zsh_disk_guard_debug() {
    local LC_ALL=C
    [[ "$ZSH_DISK_GUARD_DEBUG" == "1" ]] && print -P "%F{cyan}DEBUG:%f $*" >&2
}

# ──────────────────────────────────────────────────────────────
# df wrapper - portable across GNU/Linux and BSD/macOS
# Arguments:
#   $1 = metric: "pcent", "avail", "size"
#   $2 = mountpoint or path
# Returns:
#   Numeric value (percentage or bytes)
# ──────────────────────────────────────────────────────────────
# ──────────────────────────────────────────────────────────────
# Portable df wrapper for usage, available, size, or mountpoint
# Arguments:
#   $1 = metric: "pcent", "avail", "size", "mountpoint"
#   $2 = path
# Returns:
#   Numeric value (bytes or percentage) or mountpoint path
# ──────────────────────────────────────────────────────────────

_zsh_disk_guard_is_number() {
    [[ "$1" =~ ^[0-9]+([.][0-9]+)?$ ]]
}

zsh_disk_guard_df() {
    local LC_ALL=C
    local metric=$1
    local target=$2
    local is_gnu=0
    local result

    # Detect GNU df
    if command df --help 2>&1 | grep -q -- '--output'; then
        is_gnu=1
    fi

    if (( is_gnu )); then
        case $metric in
            pcent)
                result=$(command df --output=pcent "$target" 2>/dev/null | tail -n1 | tr -d ' %')
                ;;
            avail)
                result=$(command df --output=avail "$target" 2>/dev/null | tail -n1 | tr -d ".,")
                result=$((result * 1024))
                ;;
            size)
                result=$(command df --output=size "$target" 2>/dev/null | tail -n1 | tr -d ".,")
                result=$((result * 1024))
                ;;
            mountpoint)
                result=$(command df --output=target "$target" 2>/dev/null | tail -n1 | tr -d ".,")
                ;;
            *)
                echo "Unknown metric: $metric" >&2
                return 1
                ;;
        esac
    else
        # BSD/macOS fallback
        local line
        line=$(command df -k "$target" 2>/dev/null | tail -1)
        case $metric in
            pcent)
                result=$(echo "$line" | awk '{print int($5)}')
                ;;
            avail)
                result=$(echo "$line" | awk '{print $4 * 1024}')
                ;;
            size)
                result=$(echo "$line" | awk '{print $2 * 1024}')
                ;;
            mountpoint)
                # 6th column on BSD df: mountpoint
                result=$(echo "$line" | awk '{print $6}')
                ;;
            *)
                echo "Unknown metric: $metric" >&2
                return 1
                ;;
        esac
    fi

    echo $result
    return 0
}

# --- Quick size ---
_zsh_disk_guard_quick_size() {
    local LC_ALL=C
    local total=0
    local item size

    for item in "$@"; do
        [[ "$item" == -* ]] && continue
        [[ ! -e "$item" ]] && continue

        if [[ -f "$item" ]]; then
            size=$(command stat -c%s "$item" 2>/dev/null || command stat -f%z "$item" 2>/dev/null || echo 0)
            [[ "$size" =~ ^[0-9]+$ ]] || size=0
            (( total += size ))
        elif [[ -d "$item" ]]; then
            return 1  # Needs deep check
        fi
    done

    echo $total
    return 0
}

# --- Deep size ---
_zsh_disk_guard_deep_size() {
    local LC_ALL=C
    local total=0
    local item size

    for item in "$@"; do
        [[ "$item" == -* ]] && continue
        [[ ! -e "$item" ]] && continue

        if [[ -f "$item" ]]; then
            size=$(command stat -c%s "$item" 2>/dev/null || command stat -f%z "$item" 2>/dev/null || echo 0)
        elif [[ -d "$item" ]]; then
            size=$(command du -sb "$item" 2>/dev/null | cut -f1 || echo 0)
        else
            size=0
        fi
        [[ "$size" =~ ^[0-9]+$ ]] || size=0
        (( total += size ))
    done

    echo $total
}

# --- Format size ---
_zsh_disk_guard_format_size() {
    local LC_ALL=C
    local bytes=$1
    local gib rem_gib mib rem_mib kib

    [[ "$bytes" =~ ^[0-9]+$ ]] || { echo "n/a"; return 1; }

    (( gib = bytes / 1073741824 ))
    (( rem_gib = (bytes % 1073741824) / 107374182 ))

    if (( gib > 0 )); then
        echo "${gib}.${rem_gib} GiB"
        return 0
    fi

    (( mib = bytes / 1048576 ))
    (( rem_mib = (bytes % 1048576) / 104857 ))

    if (( mib > 0 )); then
        echo "${mib}.${rem_mib} MiB"
        return 0
    fi

    (( kib = bytes / 1024 ))
    if (( kib > 0 )); then
        echo "${kib} KiB"
        return 0
    fi

    echo "${bytes} Bytes"
}

# --- Verify ---
_zsh_disk_guard_verify() {
    local LC_ALL=C
    local target="$1"
    shift
    local sources=("$@")

    _zsh_disk_guard_debug "Checking target: $target"
    [[ -z "$target" ]] && return 0

    target=${target:a}
    _zsh_disk_guard_debug "Resolved target: $target"

    if [[ ! -d "$target" ]]; then
        _zsh_disk_guard_debug "Not a directory, extracting path..."
        if [[ $target == */* ]]; then
            target=${target%/*}
            [[ -z "$target" ]] && target=/
        else
            target=.
        fi
        _zsh_disk_guard_debug "Extracted to: $target"
    fi

    _zsh_disk_guard_debug "Getting mountpoint for: $target"
    local mountpoint
    mountpoint=$(command df --output=target "$target" 2>/dev/null | tail -n1 | tr -d ".,")
    _zsh_disk_guard_debug "Mountpoint: '$mountpoint'"

    [[ -z "$mountpoint" ]] && { _zsh_disk_guard_debug "Mountpoint empty, aborting"; return 0; }

    _zsh_disk_guard_debug "Checking usage of: $mountpoint"
    local usage
    usage=$(command df --output=pcent "$mountpoint" 2>/dev/null | tail -n1 | tr -d ' %')
    _zsh_disk_guard_debug "Raw usage: '$usage'"

    [[ "$usage" =~ ^[0-9]+$ ]] || { _zsh_disk_guard_debug "Usage not numeric, aborting"; return 0; }

    _zsh_disk_guard_debug "Parsed usage: ${usage}% (threshold: ${ZSH_DISK_GUARD_THRESHOLD}%)"

    local estimated_size needs_deep_check=0 total_size available total_space after_write usage_after

    estimated_size=$(_zsh_disk_guard_quick_size "${sources[@]}")
    [[ $? -ne 0 ]] && { needs_deep_check=1; _zsh_disk_guard_debug "Directory detected → deep check required"; }

    if (( needs_deep_check == 0 )); then
        _zsh_disk_guard_debug "Quick check: $(_zsh_disk_guard_format_size $estimated_size)"
        if (( estimated_size < ZSH_DISK_GUARD_DEEP_THRESHOLD )); then
            if (( usage >= ZSH_DISK_GUARD_THRESHOLD )); then
                echo "⚠️  Warning: Partition $mountpoint is ${usage}% full!" >&2
                if [[ -o interactive || -t 0 ]]; then
                    read -q "REPLY?Continue anyway? [y/N] "
                    echo
                    [[ "$REPLY" != [Yy] ]] && return 1
                else
                    return 1
                fi
            fi
            return 0
        fi
        total_size=$estimated_size
    else
        _zsh_disk_guard_debug "Running deep check for ${(j:,:)sources}"
        total_size=$(_zsh_disk_guard_deep_size "${sources[@]}")
    fi

    [[ "$total_size" =~ ^[0-9]+$ ]] || total_size=0
    _zsh_disk_guard_debug "Total size: $(_zsh_disk_guard_format_size $total_size)"

    available=$(zsh_disk_guard_df avail "$mountpoint")
    [[ "$available" =~ ^[0-9]+$ ]] || available=0
    (( available *= 1024 ))

    if (( total_size > available )); then
        echo "❌ ERROR: Not enough disk space on $mountpoint!" >&2
        echo "   Required: $(_zsh_disk_guard_format_size $total_size)" >&2
        echo "   Available: $(_zsh_disk_guard_format_size $available)" >&2
        echo "   Missing: $(_zsh_disk_guard_format_size $((total_size - available)))" >&2
        return 1
    else
        echo "   Required: $(_zsh_disk_guard_format_size $total_size)" >&2
        echo "   Available: $(_zsh_disk_guard_format_size $available)" >&2
    fi

    total_space=$(zsh_disk_guard_df size "$mountpoint")
    [[ "$total_space" =~ ^[0-9]+$ ]] || total_space=0
    (( total_space *= 1024 ))

    if (( total_space > 0 )); then
        (( after_write = total_space - available + total_size ))
        (( usage_after = after_write * 100 / total_space ))
    else
        _zsh_disk_guard_debug "Invalid total_space, skipping calculation."
        return 0
    fi

    if (( usage_after >= ZSH_DISK_GUARD_THRESHOLD )); then
        echo "⚠️  Warning: Partition $mountpoint will be ${usage_after}% full!" >&2
        echo "   Current: ${usage}%" >&2
        echo "   After write: ${usage_after}%" >&2
        echo "   Data size: $(_zsh_disk_guard_format_size $total_size)" >&2

        if [[ -o interactive ]]; then
            read -q "REPLY?Continue anyway? [y/N] "
            echo
            [[ "$REPLY" != [Yy] ]] && return 1
        else
            return 1
        fi
    fi

    # Erfolgreich abgeschlossen
    echo "✅ Disk guard check passed for $mountpoint." >&2
    echo "📦 Total data size: $(_zsh_disk_guard_format_size $total_size)" >&2

    return 0
}

# ──────────────────────────────────────────────────────────────────
#  Command Wrappers
# ──────────────────────────────────────────────────────────────────

_zsh_disk_guard_cp() {
    local LC_ALL=C
    [[ "$ZSH_DISK_GUARD_ENABLED" != "1" ]] && { command cp "$@"; return }

    local args=("$@")
    local target="${args[-1]}"
    local sources=("${args[@]:0:-1}")

    _zsh_disk_guard_verify "$target" "${sources[@]}" || return 1
    command cp "$@"
}

_zsh_disk_guard_mv() {
    local LC_ALL=C
    [[ "$ZSH_DISK_GUARD_ENABLED" != "1" ]] && { command mv "$@"; return }

    local args=("$@")
    local target="${args[-1]}"
    local sources=("${args[@]:0:-1}")

    _zsh_disk_guard_verify "$target" "${sources[@]}" || return 1
    command mv "$@"
}

_zsh_disk_guard_rsync() {
    local LC_ALL=C
    [[ "$ZSH_DISK_GUARD_ENABLED" != "1" ]] && { command rsync "$@"; return }

    local args=("$@")
    local target="${args[-1]}"
    local sources=("${args[@]:0:-1}")

    # Remote target?
    if [[ "$target" == *:* ]]; then
        _zsh_disk_guard_debug "Remote target → skip check"
        command rsync "$@"
        return
    fi

    # Option-like target?
    if [[ "$target" == -* ]]; then
        _zsh_disk_guard_debug "Option detected → skip check"
        command rsync "$@"
        return
    fi

    # Unclear target?
    if [[ ! -e "$target" && "$target" != */* ]]; then
        _zsh_disk_guard_debug "Unclear target → skip check"
        command rsync "$@"
        return
    fi

    _zsh_disk_guard_verify "$target" "${sources[@]}" || return 1
    command rsync "$@"
}

# ──────────────────────────────────────────────────────────────────
#  Plugin Management
# ──────────────────────────────────────────────────────────────────

zsh-disk-guard-enable() {
    ZSH_DISK_GUARD_ENABLED=1
    echo "✓ Disk guard enabled"
}

zsh-disk-guard-disable() {
    ZSH_DISK_GUARD_ENABLED=0
    echo "✓ Disk guard disabled"
}

zsh-disk-guard-status() {
    local enabled_status debug_status

    if [[ "$ZSH_DISK_GUARD_ENABLED" == "1" ]]; then
        enabled_status="%F{green}Yes%f"
    else
        enabled_status="%F{red}No%f"
    fi

    if [[ "$ZSH_DISK_GUARD_DEBUG" == "1" ]]; then
        debug_status="%F{green}On%f"
    else
        debug_status="%F{red}Off%f"
    fi

    print -P "%F{blue}═══ Zsh Disk Guard Status ═══%f"
    print -P "  Enabled: ${enabled_status}"
    print -P "  Threshold: %F{yellow}${ZSH_DISK_GUARD_THRESHOLD}%%%f"
    print -P "  Deep check threshold: $(_zsh_disk_guard_format_size $ZSH_DISK_GUARD_DEEP_THRESHOLD)"
    print -P "  Debug: ${debug_status}"
    print -P "  Wrapped commands: %F{cyan}${ZSH_DISK_GUARD_COMMANDS}%f"
}

# ──────────────────────────────────────────────────────────────────
#  Installation
# ──────────────────────────────────────────────────────────────────

# Create aliases only for implemented wrappers
for cmd in ${(z)ZSH_DISK_GUARD_COMMANDS}; do
    # Check if wrapper function exists
    if (( $+functions[_zsh_disk_guard_${cmd}] )); then
        unalias $cmd 2>/dev/null
        alias $cmd="_zsh_disk_guard_${cmd}"
    else
        print -P "%F{yellow}Warning: No wrapper for '${cmd}' - skipping%f" >&2
    fi
done

# Cleanup on unload
if [[ -n "$ZSH_EVAL_CONTEXT" ]]; then
    # Support for plugin managers
    :
fi

# Cleanup on unload (for plugin managers that support it)
# ──────────────────────────────────────────────────────────────────
#  Cleanup Function
# ──────────────────────────────────────────────────────────────────

zsh_disk_guard_plugin_unload() {
    # Remove aliases
    for cmd in ${(z)ZSH_DISK_GUARD_COMMANDS}; do
        unalias $cmd 2>/dev/null
    done

    # Unset functions
    unfunction -m '_zsh_disk_guard_*' 2>/dev/null
    unfunction -m 'zsh-disk-guard-*' 2>/dev/null
    unfunction zsh_disk_guard_plugin_unload 2>/dev/null

    # Unset variables
    unset ZSH_DISK_GUARD_{THRESHOLD,DEEP_THRESHOLD,DEBUG,ENABLED,COMMANDS}
    unset _zsh_disk_guard_loaded ZSH_DISK_GUARD_PLUGIN_DIR
    _zsh_disk_guard_debug "Plugin unloaded successfully."
}

# Note: Call 'zsh_disk_guard_plugin_unload' to unload this plugin manually
