#!/usr/bin/env zsh
#
# Enable debug tracing only if DEBUG environment variable is set
[[ -n "$DEBUG" ]] && set -x
# ===================================================================
#  Zsh Disk Guard Plugin with Pac‑Man‑Style Progress Bar
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
#
# Require Zsh 5.0+
if ! is-at-least 5.0; then
    print -P "%B%F{red}Error: zsh-disk-guard requires Zsh >= 5.0%f" >&2
    print -P "%B%F{yellow}You are using Zsh $ZSH_VERSION%f" >&2
    print -P "%F{yellow}Consider an upgrade: https://www.zsh.org/%f" >&2
    return 1
fi
#
# ──────────────────────────────────────────────────────────────────
#  Plugin Initialization (Zsh Plugin Standard)
# ──────────────────────────────────────────────────────────────────
0="${ZERO:-${${0:#$ZSH_ARGZERO}:-${(%):-%N}}}"
0="${${(M)0:#/*}:-$PWD/$0}"

# Allow reload in debug/test mode
if [[ -n "$_zsh_disk_guard_loaded" && -z "$DEBUG" ]]; then
    _zsh_disk_guard_debug "Plugin already loaded, skipping (set DEBUG=1 to force reload)"
    return
fi
typeset -g _zsh_disk_guard_loaded=1
typeset -g ZSH_DISK_GUARD_PLUGIN_DIR="${0:A:h}"
#
# ──────────────────────────────────────────────────────────────────
# Redraw prompt when terminal size changes
# ──────────────────────────────────────────────────────────────────
ZSH_DISK_GUARD_TRAPWINCH() {
  zle && zle -R
}
TRAPWINCH
#
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
#  Helper function
# ──────────────────────────────────────────────────────────────────
_zsh_disk_guard_debug() {
    local LC_ALL=C
    (( ZSH_DISK_GUARD_DEBUG )) && print -P "%F{cyan}DEBUG:%f $*" >&2
}

# ──────────────────────────────────────────────────────────────────
# We want numbers and we don't want commas 'cause they break the game
_zsh_disk_guard_is_number() {
    local LC_ALL=C
    [[ "$1" =~ ^[0-9]+([.][0-9]+)?$ ]]
}
# ============================================================
#  Dynamic batch size
# ============================================================
_zsh_disk_guard_set_batchsize() {
    local LC_ALL=C
    local total_bytes
    total_bytes=$(command du -cb "$@" 2>/dev/null | tail -n1 | awk '{print $1}')

    if (( total_bytes < 100*1024*1024 )); then
      ZSH_DISK_GUARD_BATCHSIZE=50
    elif (( total_bytes < 1*1024*1024*1024 )); then
      ZSH_DISK_GUARD_BATCHSIZE=100
    else
      ZSH_DISK_GUARD_BATCHSIZE=200
    fi

    _zsh_disk_guard_debug "Batch size dynamically set to $ZSH_DISK_GUARD_BATCHSIZE (based on $(($total_bytes / 1024 / 1024)) MiB)"
}
# ──────────────────────────────────────────────────────────────
# df wrapper - portable across GNU/Linux and BSD/macOS
# Arguments:
#   $1 = metric: "pcent", "avail", "size"
#   $2 = mountpoint or path
# Returns:
#   Numeric value (percentage or bytes)
# ──────────────────────────────────────────────────────────────
# Portable df wrapper for usage, available, size, or mountpoint
# Arguments:
#   $1 = metric: "pcent", "avail", "size", "mountpoint"
#   $2 = path
# Returns:
#   Numeric value (bytes or percentage) or mountpoint path
# ──────────────────────────────────────────────────────────────
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
# ──────────────────────────────────────────────────────────────────
#
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
    mountpoint=$(zsh_disk_guard_df mountpoint "$target")
    _zsh_disk_guard_debug "Mountpoint: '$mountpoint'"

    [[ -z "$mountpoint" ]] && { _zsh_disk_guard_debug "Mountpoint empty, aborting"; return 0; }

    _zsh_disk_guard_debug "Checking usage of: $mountpoint"
    local usage
    usage=$(zsh_disk_guard_df pcent "$mountpoint")
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
    # Successfully completed
    echo "✅ Disk guard check passed for $mountpoint." >&2
    echo "📦 Total data size: $(_zsh_disk_guard_format_size $total_size)" >&2

    return 0
}

_zsh_disk_guard_progress_bar() {
  local LC_ALL=C
  local current=$1
  local len=$2
  local COLUMNS
  COLUMNS=$(tput cols)
  local LINES
  LINES=$(tput lines)

  local GREEN=$'\e[0;32;40m'
  local BROWN=$'\e[0;33;40m'
  local YELLOW=$'\e[1;33;40m'
  local RED=$'\e[0;31;40m'
  local NC=$'\e[0m'                # reset color

  local pm_char1="${YELLOW}C${NC}"    # this is one of two characters for the animation
  local pm_char2="${YELLOW}c${NC}"    # this is the second character for the animation
  local bar_char1="${BROWN}.${NC}"    # this character apears behind Pac-Man
  local bar_char2="${GREEN}o${NC}"    # this character is eaten by Pac-Man
#  local bar_char2="${GREEN}$·${NC}"    # you can also try middle-dot
#  local bar_char2="${GREEN}$( printf $'\u00B7' )${NC}"    # with UTF-8 code -> ·

  local perc_done=$((current * 100 / len))

  local suffix
        suffix=$(printf ' %d / %d (%d%%)' "$current" "$len" "$perc_done")
  local length=$(( COLUMNS - 2 - ${#suffix} ))
    (( length < 0 )) && length=0

  local num_bars=$((perc_done * length / 100))

  local pos=$((num_bars - 1))
    (( pos < 0 )) && pos=0

  local perc_color
    if (( perc_done < 31 )); then
          perc_color=${RED}
    elif (( perc_done < 61 )); then
          perc_color=${YELLOW}
    else
          perc_color=${GREEN}
    fi
# progress bar
    bar='['
    local i
    for ((i = 0; i < length; i++)); do
      if (( i < pos )); then
          bar+=$bar_char1 # behind Pac-Man
      elif (( i == pos && perc_done < 100 )); then
      # Pac-Man
          (( i % 2 == 0 )) && bar+=$pm_char1 || bar+=$pm_char2
      else
          bar+=$bar_char2 # in front of Pac-Man
      fi
    done
    bar+=']'
    printf '\e[s' # save the cursor position
      printf '\e[%d;1H' "$LINES"  #  -> bottom row, first column  (1-based!)
        printf '%s %s/%s %s%s%%%s' "$bar" "$current" "$len" "$perc_color" "$perc_done" "$NC"
      printf '\e[K' #  clear the line
    printf '\e[u' #  restores the cursor to the last saved position
}

# ──────────────────────────────────────────────────────────────────
#  Command Wrappers
# ──────────────────────────────────────────────────────────────────

_zsh_disk_guard_cp() {
    # Save and disable xtrace to prevent variable assignment output
    local xtrace_was_set=0
    [[ $- == *x* ]] && xtrace_was_set=1
    set +x

    local LC_ALL=C
    (( ZSH_DISK_GUARD_ENABLED )) || { command cp "$@"; return $?; }

    local args=("$@")
    local target="${args[-1]}"
    local sources=("${args[@]:0:-1}")

    _zsh_disk_guard_verify "$target" "${sources[@]}" || return 1

    local total_files=${#sources[@]}
    local file_idx=0

    _zsh_disk_guard_init_term

    # Disable job control messages temporarily
    setopt LOCAL_OPTIONS NO_NOTIFY NO_MONITOR

    for source in "${sources[@]}"; do
        (( file_idx++ ))

        # Show current file being processed (only once)
        printf '→ %s\n' "${source:t}"

        # Get source file size (suppress trace output)
        local source_size=$(set +x; [[ -f "$source" ]] && (command stat -c%s "$source" 2>/dev/null || command stat -f%z "$source" 2>/dev/null || echo 0) || echo 0)

        local target_file="$target/${source:t}"

        # Start cp in background
        command cp "$source" "$target" &
        local cp_pid=$!

        # Monitor copy progress by checking destination file size
        if (( source_size > 0 )); then
            while kill -0 $cp_pid 2>/dev/null; do
                if [[ -f "$target_file" ]]; then
                    # Get size without any trace output
                    local cur_size=$(set +x; command stat -c%s "$target_file" 2>/dev/null || command stat -f%z "$target_file" 2>/dev/null || echo 0)

                    # Calculate progress: (completed_files * 100 + current_file_percent) / total_files
                    local cur_file_pct=$((cur_size * 100 / source_size))
                    (( cur_file_pct > 100 )) && cur_file_pct=100

                    local tot_pct=$(( (file_idx - 1) * 100 + cur_file_pct ))
                    local overall_pct=$(( tot_pct / total_files ))

                    # Show progress as if we're processing "overall_pct" out of 100
                    _zsh_disk_guard_progress_bar $overall_pct 100
                else
                    # File doesn't exist yet
                    _zsh_disk_guard_progress_bar $((file_idx - 1)) $total_files
                fi
                sleep 0.1
            done
        else
            # Unknown size, just show file count progress
            while kill -0 $cp_pid 2>/dev/null; do
                _zsh_disk_guard_progress_bar $file_idx $total_files
                sleep 0.2
            done
        fi

        # Wait for cp to complete and get exit status
        wait $cp_pid
        local cp_status=$?

        # Final update for this file
        _zsh_disk_guard_progress_bar $(( file_idx * 100 / total_files )) 100

        # Check if cp failed
        if (( cp_status != 0 )); then
            _zsh_disk_guard_deinit_term
            # Restore xtrace if it was set
            (( xtrace_was_set )) && set -x
            return $cp_status
        fi
    done

    # Ensure 100% at the end
    _zsh_disk_guard_progress_bar 100 100

    _zsh_disk_guard_deinit_term

    # Restore xtrace if it was set
    (( xtrace_was_set )) && set -x

    return 0
}

_zsh_disk_guard_mv() {
    local LC_ALL=C
    (( ZSH_DISK_GUARD_ENABLED )) || { command mv "$@"; return $?; }

    local args=("$@")
    local target="${args[-1]}"
    local sources=("${args[@]:0:-1}")

    _zsh_disk_guard_verify "$target" "${sources[@]}" || return 1

    local total_files=${#sources[@]}
    local file_idx=0

    _zsh_disk_guard_init_term

    for source in "${sources[@]}"; do
        (( file_idx++ ))

        # Show current file being processed
        printf '→ %s\n' "${source:t}"

        # Get source file size for progress calculation
        local source_size
        if [[ -f "$source" ]]; then
            source_size=$(command stat -c%s "$source" 2>/dev/null || command stat -f%z "$source" 2>/dev/null || echo 0)
        else
            source_size=0
        fi

        local target_file="$target/${source:t}"

        # Start mv in background
        command mv "$source" "$target" &
        local mv_pid=$!

        # Monitor move progress
        if (( source_size > 0 )); then
            while kill -0 $mv_pid 2>/dev/null; do
                if [[ -f "$target_file" ]]; then
                    local cur_size
                    cur_size=$(command stat -c%s "$target_file" 2>/dev/null || command stat -f%z "$target_file" 2>/dev/null || echo 0)

                    local cur_file_pct=$((cur_size * 100 / source_size))
                    (( cur_file_pct > 100 )) && cur_file_pct=100

                    local tot_pct=$(( (file_idx - 1) * 100 + cur_file_pct ))
                    local overall_pct=$(( tot_pct / total_files ))

                    _zsh_disk_guard_progress_bar $overall_pct 100
                else
                    _zsh_disk_guard_progress_bar $((file_idx - 1)) $total_files
                fi
                sleep 0.1
            done
        else
            while kill -0 $mv_pid 2>/dev/null; do
                _zsh_disk_guard_progress_bar $file_idx $total_files
                sleep 0.2
            done
        fi

        wait $mv_pid
        local mv_status=$?

        _zsh_disk_guard_progress_bar $(( file_idx * 100 / total_files )) 100

        if (( mv_status != 0 )); then
            _zsh_disk_guard_deinit_term
            return $mv_status
        fi
    done

    _zsh_disk_guard_progress_bar 100 100
    _zsh_disk_guard_deinit_term

    return 0
}

_zsh_disk_guard_rsync() {
    local LC_ALL=C
    (( ZSH_DISK_GUARD_ENABLED )) || { command rsync "$@"; return $?; }

    local args=("$@")
    local target="${args[-1]}"
    local sources=("${args[@]:0:-1}")

    # Remote target?
    if [[ "$target" == *:* ]]; then
        _zsh_disk_guard_debug "Remote target → skip check"
        command rsync "$@"
        return $?
    fi

    # Option-like target?
    if [[ "$target" == -* ]]; then
        _zsh_disk_guard_debug "Option detected → skip check"
        command rsync "$@"
        return $?
    fi

    # Unclear target?
    if [[ ! -e "$target" && "$target" != */* ]]; then
        _zsh_disk_guard_debug "Unclear target → skip check"
        command rsync "$@"
        return $?
    fi

    _zsh_disk_guard_verify "$target" "${sources[@]}" || return 1
    command rsync "$@"
    return $?
}

# initialise terminal
_zsh_disk_guard_init_term() {
    local COLUMNS
    COLUMNS=$(tput cols)
    local LINES
    LINES=$(tput lines)

    printf '\n' # ensure we have space for the progress bar
      printf '\e[s' # save the cursor location
        printf '\e[%d;%dr' 1 "$((LINES -1))" # set the scrollable region (margin)
      printf '\e[u' #  restore the cursor location
    printf '\e[1A' # move cursor up
    tput civis # make cursor invisible
}

_zsh_disk_guard_deinit_term() {
  local COLUMNS
  COLUMNS=$(tput cols)
  local LINES
  LINES=$(tput lines)

    printf '\e[s' # save the cursor location
      printf '\e[%d;%dr' 1 "$LINES" # reset the scrollable region (margin)
        printf '\e[%d;%dH' "$LINES" 1 # move cursor to bottom line
      printf '\e[0K' #  clear the line
    printf '\e[u' #  reset the cursor location
    tput cnorm # make cursor visible
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

    if (( ZSH_DISK_GUARD_ENABLED )); then
        enabled_status="%F{green}Yes%f"
    else
        enabled_status="%F{red}No%f"
    fi

    if (( ZSH_DISK_GUARD_DEBUG )); then
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
    unfunction zsh_disk_guard_df 2>/dev/null

    # Unset variables
    unset ZSH_DISK_GUARD_{THRESHOLD,DEEP_THRESHOLD,DEBUG,ENABLED,COMMANDS,BATCHSIZE}
    unset _zsh_disk_guard_loaded ZSH_DISK_GUARD_PLUGIN_DIR

    print -P "%F{green}✓%f Disk guard plugin unloaded successfully"
}

# Note: Call 'zsh_disk_guard_plugin_unload' to unload this plugin manually
