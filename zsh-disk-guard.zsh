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
# ──────────────────────────────────────────────────────────────────
# "You can lead a horse to water, but you can't make it read warnings."
#                                               — Ancient IT Wisdom
<<<<<<< Updated upstream
# ──────────────────────────────────────────────────────────────────
#  Version Check
# ──────────────────────────────────────────────────────────────────
=======
# ──────────────────────────────────────────────────────────────────
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
>>>>>>> Stashed changes
# Require Zsh 5.0+
autoload -Uz is-at-least
if ! is-at-least 5.0; then
    gdbus call --session \
    --dest=org.freedesktop.Notifications \
    --object-path=/org/freedesktop/Notifications \
    --method=org.freedesktop.Notifications.Notify \
    "" 0 "" "zramdisk Plugin Message" "Unsupported Zsh version $ZSH_VERSION. Expecting Zsh 5.0+! The plugin zramdisk was not loaded." \
    '[]' '{"urgency": <1>}' 30000
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
<<<<<<< Updated upstream
# ──────────────────────────────────────────────────────────────────
# Redraw prompt when terminal size changes
# ──────────────────────────────────────────────────────────────────
ZSH_DISK_GUARD_TRAPWINCH() {
  zle && zle -R
}
TRAPWINCH
#
=======
>>>>>>> Stashed changes
# ──────────────────────────────────────────────────────────────────
# Redraw prompt when terminal size changes
# ──────────────────────────────────────────────────────────────────
ZSH_DISK_GUARD_TRAPWINCH() {
  zle && zle -R
}
#
# ──────────────────────────────────────────────────────────────────
#  Configuration defaults
# ──────────────────────────────────────────────────────────────────
# Disk usage threshold (percentage)
: ${ZSH_DISK_GUARD_THRESHOLD:=80}

# Size threshold for deep checking (bytes)
: ${ZSH_DISK_GUARD_SCAN_THRESHOLD:=$((100 * 1024 * 1024))}  # 100 MiB

# Enable debug output
: ${ZSH_DISK_GUARD_DEBUG:=0}

# Enable/disable the plugin
: ${ZSH_DISK_GUARD_ENABLED:=1}

# Commands to wrap (space-separated)
: ${ZSH_DISK_GUARD_COMMANDS:="cp mv rsync"}

# ──────────────────────────────────────────────────────────────────
#  Helper Functions
# ──────────────────────────────────────────────────────────────────

# Debug output function
_zsh_disk_guard_debug() {
    local LC_ALL=C
    (( ZSH_DISK_GUARD_DEBUG )) && print -P "%F{cyan}DEBUG:%f $*" >&2
}

# Check if a string is a valid number
_zsh_disk_guard_is_number() {
    local LC_ALL=C
    [[ "$1" =~ ^[0-9]+([.][0-9]+)?$ ]]
}

# ──────────────────────────────────────────────────────────────────
# Portable df wrapper for usage, available, size, or mountpoint
# Arguments:
#   $1 = metric: "pcent", "avail", "size", "mountpoint"
#   $2 = path
# Returns:
#   Numeric value (bytes or percentage) or mountpoint path
# ──────────────────────────────────────────────────────────────────
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
# Quick size calculation (files only, no directories)
# Returns 1 if directories are found (needs deep check)
# ──────────────────────────────────────────────────────────────────
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

# ──────────────────────────────────────────────────────────────────
# Deep size calculation (includes directories)
# ──────────────────────────────────────────────────────────────────
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

# ──────────────────────────────────────────────────────────────────
# Format size in human-readable format (Bytes, KiB, MiB, GiB)
# ──────────────────────────────────────────────────────────────────
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

# ──────────────────────────────────────────────────────────────────
# Verify disk space availability before write operations
# Arguments:
#   $1 = target path
#   $@ = source files/directories
# Returns:
#   0 if sufficient space, 1 otherwise
# ──────────────────────────────────────────────────────────────────
_zsh_disk_guard_verify() {
    local LC_ALL=C
    local target="$1"
    shift
    local sources=("$@")

    # Color definitions
    local GREEN=$'\e[0;32;40m'
    local CYAN=$'\e[0;36;4m' # underlined
    local YELLOW=$'\e[1;33;40m'
    local RED=$'\e[0;31;40m'
    local NC=$'\e[0m'

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
<<<<<<< Updated upstream
        if (( estimated_size < ZSH_DISK_GUARD_DEEP_THRESHOLD )); then
=======
        if (( estimated_size < ZSH_DISK_GUARD_SCAN_THRESHOLD )); then
>>>>>>> Stashed changes
            if (( usage >= ZSH_DISK_GUARD_THRESHOLD )); then
                printf '\n%s\n' "⚠️  ${RED}Warning${NC}: Partition ${CYAN}$mountpoint${NC} is ${YELLOW}${usage}%${NC} full!" >&2
                if [[ -o interactive || -t 0 ]]; then
                    read -q "REPLY?Continue anyway? [y/N] "
                    echo
                    [[ "$REPLY" != [Yy] ]] && return 1
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

# ──────────────────────────────────────────────────────────────────
# Pac-Man style progress bar
# Arguments:
#   $1 = current progress (0-100)
#   $2 = total (usually 100)
#   $3 = total number of files (for display)
# ──────────────────────────────────────────────────────────────────
_zsh_disk_guard_progress_bar() {
  local LC_ALL=C
  local current=$1
  local total=$2
  local file_count=${3:-0}

  local COLUMNS=$(tput cols)
  local LINES=$(tput lines)

  # Color definitions
  local GREEN=$'\e[0;32;40m'
  local BROWN=$'\e[0;33;40m'
  local YELLOW=$'\e[1;33;40m'
  local RED=$'\e[0;31;40m'
  local NC=$'\e[0m'

  # Pac-Man characters
  local pm_char1="${YELLOW}C${NC}"    # Pac-Man mouth open
  local pm_char2="${YELLOW}c${NC}"    # Pac-Man mouth closed
  local bar_char1="${BROWN}.${NC}"    # Trail behind Pac-Man
  local bar_char2="${GREEN}o${NC}"    # Dots to eat

  local perc_done=$((current * 100 / total))

  # Build suffix: "Files: X (Y%)" instead of redundant "X/Y (Y%)"
  local suffix
  if (( file_count > 0 )); then
    suffix=$(printf ' Files: %d (%d%%)' "$file_count" "$perc_done")
  else
    suffix=$(printf ' %d%% ' "$perc_done")
  fi

  local length=$(( COLUMNS - 2 - ${#suffix} ))
  (( length < 0 )) && length=0

  local num_bars=$((perc_done * length / 100))
  local pos=$((num_bars - 1))
  (( pos < 0 )) && pos=0

  # Color based on percentage (red < 31%, yellow < 61%, green >= 61%)
  local perc_color
  if (( perc_done < 31 )); then
      perc_color=${RED}
  elif (( perc_done < 61 )); then
      perc_color=${YELLOW}
  else
      perc_color=${GREEN}
  fi

  # Build progress bar
  local bar='['
  local i
  for ((i = 0; i < length; i++)); do
    if (( i < pos )); then
        bar+=$bar_char1  # Trail behind Pac-Man
    elif (( i == pos && perc_done < 100 )); then
        # Pac-Man animation (alternates between open/closed mouth)
        (( i % 2 == 0 )) && bar+=$pm_char1 || bar+=$pm_char2
    else
        bar+=$bar_char2  # Dots in front of Pac-Man
    fi
  done
  bar+=']'

  # Display progress bar at bottom of terminal
  printf '\e[s'                    # Save cursor position
  printf '\e[%d;1H' "$LINES"       # Move to bottom row, first column
  printf '%s Files: %d (%s%d%%%s)' "$bar" "$file_count" "$perc_color" "$perc_done" "$NC"
  printf '\e[K'                    # Clear rest of line
  printf '\e[u'                    # Restore cursor position
}

# ──────────────────────────────────────────────────────────────────
# Initialize terminal for progress bar display
# - Creates space for progress bar at bottom
# - Makes cursor invisible
# ──────────────────────────────────────────────────────────────────
_zsh_disk_guard_init_term() {
    local COLUMNS=$(tput cols)
    local LINES=$(tput lines)

    printf '\n'                                # Ensure space for progress bar
    printf '\e[s'                              # Save cursor location
    printf '\e[%d;%dr' 1 "$((LINES -1))"       # Set scrollable region (leave bottom line)
    printf '\e[u'                              # Restore cursor location
    printf '\e[1A'                             # Move cursor up one line
    tput civis                                 # Make cursor invisible
}

# ──────────────────────────────────────────────────────────────────
# Restore terminal to normal state
# - Resets scrollable region
# - Makes cursor visible again
# ──────────────────────────────────────────────────────────────────
_zsh_disk_guard_deinit_term() {
  local COLUMNS=$(tput cols)
  local LINES=$(tput lines)

  printf '\e[s'                          # Save cursor location
  printf '\e[%d;%dr' 1 "$LINES"          # Reset scrollable region
  printf '\e[%d;%dH' "$LINES" 1          # Move to bottom line
  printf '\e[0K'                         # Clear the line
  printf '\e[u'                          # Restore cursor location
  tput cnorm                             # Make cursor visible
}

# ──────────────────────────────────────────────────────────────────
#  Command Wrappers
# ──────────────────────────────────────────────────────────────────

# ──────────────────────────────────────────────────────────────────
# Wrapper for 'cp' command with disk guard and progress bar
# ──────────────────────────────────────────────────────────────────
_zsh_disk_guard_cp() {
    # Save and disable xtrace to prevent variable assignment output
    local xtrace_was_set=0
    [[ $- == *x* ]] && xtrace_was_set=1
    set +x

    # Save REPORTTIME and disable it temporarily (set to very high value)
    local saved_reporttime=${REPORTTIME:-}
    local reporttime_was_set=$+REPORTTIME
    REPORTTIME=999999

    local LC_ALL=C

    # If plugin is disabled, just run normal cp
    (( ZSH_DISK_GUARD_ENABLED )) || { cp "$@"; return $?; }

    local args=("$@")
    local target="${args[-1]}"
    local sources=("${args[@]:0:-1}")

    # Color definitions
    local GREEN=$'\e[0;32;40m'
    local CYAN=$'\e[0;36;1m'
    local YELLOW=$'\e[1;33;40m'
    local RED=$'\e[0;31;40m'
    local NC=$'\e[0m'
<<<<<<< Updated upstream

    # ──────────────────────────────────────────────────────────────
    # Check for missing source files BEFORE any other operation
    # ──────────────────────────────────────────────────────────────
    local missing_files=()
    local existing_sources=()
    
    for source in "${sources[@]}"; do
        if [[ ! -e "$source" ]]; then
            missing_files+=("${source:t}")
        else
            existing_sources+=("$source")
        fi
    done

=======

    # ──────────────────────────────────────────────────────────────
    # Check for missing source files BEFORE any other operation
    # ──────────────────────────────────────────────────────────────
    local missing_files=()
    local existing_sources=()
    
    for source in "${sources[@]}"; do
        if [[ ! -e "$source" ]]; then
            missing_files+=("${source:t}")
        else
            existing_sources+=("$source")
        fi
    done

    # If files are missing, warn user and ask whether to continue
    if (( ${#missing_files[@]} > 0 )); then
        printf '\n%s\n' "⚠️  ${RED}Warning${NC}: ${YELLOW}${#missing_files[@]}${NC} source file(s) ${RED}not found${NC}:" >&2
        for file in "${missing_files[@]}"; do
            printf '   %s %s\n' "❌" "${CYAN}${file}${NC}" >&2
        done
        printf '\n'
        
        if (( ${#existing_sources[@]} > 0 )); then
            read -q "reply?Continue with remaining ${YELLOW}${#existing_sources[@]}${NC} file(s)? [y/N] " </dev/tty
            echo
            if [[ "$reply" != [Yy] ]]; then
                printf '%s\n' "Operation cancelled."
                # Restore settings before returning
                if (( reporttime_was_set )); then
                    REPORTTIME=$saved_reporttime
                else
                    unset REPORTTIME
                fi
                (( xtrace_was_set )) && set -x
                return 1
            fi
        else
            printf '%s\n' "❌ ${RED}Error${NC}: No valid source files found. Operation cancelled." >&2
            # Restore settings before returning
            if (( reporttime_was_set )); then
                REPORTTIME=$saved_reporttime
            else
                unset REPORTTIME
            fi
            (( xtrace_was_set )) && set -x
            return 1
        fi
        
        # Update sources to only include existing files
        sources=("${existing_sources[@]}")
    fi

    # Verify disk space before starting (only for existing files)
    _zsh_disk_guard_verify "$target" "${sources[@]}" || return 1

    local total_files=${#sources[@]}
    local file_idx=0
    local total_bytes_copied=0
    local start_time=$SECONDS

    _zsh_disk_guard_init_term

    # Disable job control messages temporarily
    setopt LOCAL_OPTIONS NO_NOTIFY NO_MONITOR

    for source in "${sources[@]}"; do
        (( file_idx++ ))

        # Get source file size (suppress trace output)
        local source_size=$(set +x; [[ -f "$source" ]] && (command stat -c%s "$source" 2>/dev/null || command stat -f%z "$source" 2>/dev/null || echo 0) || echo 0)

        # Display current file with size
        local size_display=$(_zsh_disk_guard_format_size $source_size)
        printf '\n    → %s (%s)' "${source:t}" "$size_display"

        local target_file="$target/${source:t}"

        # Check if target file exists and prompt for overwrite (interactive mode only)
        if [[ -f "$target_file" ]] && [[ -o interactive ]]; then
            printf '\n%s\n' "⚠️  ${RED}Warning${NC}: ${CYAN}${target_file:t}${NC} already exists in ${CYAN}${args[-1]}${NC}!" >&2
            read -q "reply?    Overwrite ${target_file:t}? [y/N] " </dev/tty
            echo
            if [[ "$reply" != [Yy] ]]; then
                printf '%s\n' "    Skipped: ${source:t}"
                continue
            fi
        fi

        # Start cp in background (with -f to force overwrite after user confirmation)
        command cp -f "$source" "$target" &
        local cp_pid=$!

        # Monitor copy progress by checking destination file size
        if (( source_size > 0 )); then
            while kill -0 $cp_pid 2>/dev/null; do
                if [[ -f "$target_file" ]]; then
                    # Get current size of destination file
                    local cur_size=$(set +x; command stat -c%s "$target_file" 2>/dev/null || command stat -f%z "$target_file" 2>/dev/null || echo 0)

                    # Calculate progress: (completed_files * 100 + current_file_percent) / total_files
                    local cur_file_pct=$((cur_size * 100 / source_size))
                    (( cur_file_pct > 100 )) && cur_file_pct=100

                    local tot_pct=$(( (file_idx - 1) * 100 + cur_file_pct ))
                    local overall_pct=$(( tot_pct / total_files ))

                    # Show progress with file count
                    _zsh_disk_guard_progress_bar $overall_pct 100 $total_files
                else
                    # File doesn't exist yet, show progress for completed files
                    _zsh_disk_guard_progress_bar $((file_idx - 1)) $total_files $total_files
                fi
                sleep 0.1
            done
        else
            # Unknown size or directory, just show file count progress
            while kill -0 $cp_pid 2>/dev/null; do
                _zsh_disk_guard_progress_bar $file_idx $total_files $total_files
                sleep 0.2
            done
        fi

        # Wait for cp to complete and get exit status
        wait $cp_pid
        local cp_status=$?

        # Check if cp failed
        if (( cp_status != 0 )); then
            printf '\n❌ Error copying %s (exit code: %d)\n' "${source:t}" "$cp_status" >&2
            _zsh_disk_guard_deinit_term
            # Restore REPORTTIME settings
            if (( reporttime_was_set )); then
                REPORTTIME=$saved_reporttime
            else
                unset REPORTTIME
            fi
            (( xtrace_was_set )) && set -x
            return $cp_status
        fi

        # Add to total bytes copied
        (( total_bytes_copied += source_size ))

        # Update progress bar for completed file
        _zsh_disk_guard_progress_bar $(( file_idx * 100 / total_files )) 100 $total_files
    done

    # Ensure 100% at the end
    _zsh_disk_guard_progress_bar 100 100 $total_files
    _zsh_disk_guard_deinit_term

    # Calculate elapsed time and format it cleanly
    local elapsed=$((SECONDS - start_time))
    local elapsed_display

    # Convert to integer to avoid floating point issues
    local elapsed_int=${elapsed%.*}

    if (( elapsed_int < 60 )); then
        elapsed_display=$(printf '%ds' "$elapsed_int")
    elif (( elapsed_int < 3600 )); then
        local minutes=$((elapsed_int / 60))
        local seconds=$((elapsed_int % 60))
        elapsed_display=$(printf '%dm %ds' "$minutes" "$seconds")
    else
        local hours=$((elapsed_int / 3600))
        local minutes=$(((elapsed_int % 3600) / 60))
        local seconds=$((elapsed_int % 60))
        elapsed_display=$(printf '%dh %dm %ds' "$hours" "$minutes" "$seconds")
    fi

    # Display success summary
    if [[ $total_bytes_copied = 0 ]]; then
       printf '\n%s\n\n' "ℹ️   Nothing has changed!"
    else
       printf '\n\n✅  Done! Copied %s in %s\n\n' "$(_zsh_disk_guard_format_size $total_bytes_copied)" "$elapsed_display"
    fi

    # Restore REPORTTIME to original state
    if (( reporttime_was_set )); then
        REPORTTIME=$saved_reporttime
    else
        unset REPORTTIME
    fi

    # Restore xtrace if it was set
    (( xtrace_was_set )) && set -x

    return 0
}

# ──────────────────────────────────────────────────────────────────
# Wrapper for 'mv' command with disk guard and progress bar
# ──────────────────────────────────────────────────────────────────
_zsh_disk_guard_mv() {
    # Save and disable xtrace
    local xtrace_was_set=0
    [[ $- == *x* ]] && xtrace_was_set=1
    set +x

    # Save REPORTTIME and disable it temporarily
    local saved_reporttime=${REPORTTIME:-}
    local reporttime_was_set=$+REPORTTIME
    REPORTTIME=999999

    local LC_ALL=C

    # If plugin is disabled, just run normal mv
    (( ZSH_DISK_GUARD_ENABLED )) || { command mv "$@"; return $?; }

    local args=("$@")
    local target="${args[-1]}"
    local sources=("${args[@]:0:-1}")

    # Color definitions
    local GREEN=$'\e[0;32;40m'
    local CYAN=$'\e[0;36;1m'
    local YELLOW=$'\e[1;33;40m'
    local RED=$'\e[0;31;40m'
    local NC=$'\e[0m'

    # ──────────────────────────────────────────────────────────────
    # Check for missing source files BEFORE any other operation
    # ──────────────────────────────────────────────────────────────
    local missing_files=()
    local existing_sources=()
    
    for source in "${sources[@]}"; do
        if [[ ! -e "$source" ]]; then
            missing_files+=("${source:t}")
        else
            existing_sources+=("$source")
        fi
    done

    # If files are missing, warn user and ask whether to continue
    if (( ${#missing_files[@]} > 0 )); then
        printf '\n%s\n' "⚠️  ${RED}Warning${NC}: ${YELLOW}${#missing_files[@]}${NC} source file(s) ${RED}not found${NC}:" >&2
        for file in "${missing_files[@]}"; do
            printf '   %s %s\n' "❌" "${CYAN}${file}${NC}" >&2
        done
        printf '\n'
        
        if (( ${#existing_sources[@]} > 0 )); then
            read -q "reply?Continue with remaining ${YELLOW}${#existing_sources[@]}${NC} file(s)? [y/N] " </dev/tty
            echo
            if [[ "$reply" != [Yy] ]]; then
                printf '%s\n' "Operation cancelled."
                # Restore settings before returning
                if (( reporttime_was_set )); then
                    REPORTTIME=$saved_reporttime
                else
                    unset REPORTTIME
                fi
                (( xtrace_was_set )) && set -x
                return 1
            fi
        else
            printf '%s\n' "❌ ${RED}Error${NC}: No valid source files found. Operation cancelled." >&2
            # Restore settings before returning
            if (( reporttime_was_set )); then
                REPORTTIME=$saved_reporttime
            else
                unset REPORTTIME
            fi
            (( xtrace_was_set )) && set -x
            return 1
        fi
        
        # Update sources to only include existing files
        sources=("${existing_sources[@]}")
    fi

    # Verify disk space before starting (only for existing files)
    _zsh_disk_guard_verify "$target" "${sources[@]}" || return 1

    local total_files=${#sources[@]}
    local file_idx=0
    local total_bytes_moved=0
    local start_time=$SECONDS

    _zsh_disk_guard_init_term

    # Disable job control messages
    setopt LOCAL_OPTIONS NO_NOTIFY NO_MONITOR

    for source in "${sources[@]}"; do
        (( file_idx++ ))

        # Get source file size for progress calculation
        local source_size=$(set +x; [[ -f "$source" ]] && (command stat -c%s "$source" 2>/dev/null || command stat -f%z "$source" 2>/dev/null || echo 0) || echo 0)

        # Display current file with size
        local size_display=$(_zsh_disk_guard_format_size $source_size)
        printf '→ %s (%s)\n' "${source:t}" "$size_display"

        local target_file="$target/${source:t}"

        # Check if target file exists and prompt for overwrite (interactive mode only)
        if [[ -f "$target_file" ]] && [[ -o interactive ]]; then
            printf '\n%s\n' "⚠️  ${RED}Warning${NC}: ${CYAN}${target_file:t}${NC} already exists in ${CYAN}${args[-1]}${NC}!" >&2
            read -q "reply?    Overwrite ${target_file:t}? [y/N] " </dev/tty
            echo
            if [[ "$reply" != [Yy] ]]; then
                printf '%s\n' "    Skipped: ${source:t}"
                continue
            fi
        fi

        # Start mv in background (with -f to force overwrite after user confirmation)
        command mv -f "$source" "$target" &
        local mv_pid=$!

        # Monitor move progress
        if (( source_size > 0 )); then
            while kill -0 $mv_pid 2>/dev/null; do
                if [[ -f "$target_file" ]]; then
                    # Get current size of destination file
                    local cur_size=$(set +x; command stat -c%s "$target_file" 2>/dev/null || command stat -f%z "$target_file" 2>/dev/null || echo 0)

                    # Calculate progress: (completed_files * 100 + current_file_percent) / total_files
                    local cur_file_pct=$((cur_size * 100 / source_size))
                    (( cur_file_pct > 100 )) && cur_file_pct=100

                    local tot_pct=$(( (file_idx - 1) * 100 + cur_file_pct ))
                    local overall_pct=$(( tot_pct / total_files ))

                    # Show progress with file count
                    _zsh_disk_guard_progress_bar $overall_pct 100 $total_files
                else
                    # File doesn't exist yet, show progress for completed files
                    _zsh_disk_guard_progress_bar $((file_idx - 1)) $total_files $total_files
                fi
                sleep 0.1
            done
        else
            # Unknown size or directory, just show file count progress
            while kill -0 $mv_pid 2>/dev/null; do
                _zsh_disk_guard_progress_bar $file_idx $total_files $total_files
                sleep 0.2
            done
        fi

        # Wait for mv to complete and get exit status
        wait $mv_pid
        local mv_status=$?

        # Check if mv failed
        if (( mv_status != 0 )); then
            printf '\n❌ Error moving %s (exit code: %d)\n' "${source:t}" "$mv_status" >&2
            _zsh_disk_guard_deinit_term
            # Restore REPORTTIME settings
            if (( reporttime_was_set )); then
                REPORTTIME=$saved_reporttime
            else
                unset REPORTTIME
            fi
            (( xtrace_was_set )) && set -x
            return $mv_status
        fi

        # Add to total bytes moved
        (( total_bytes_moved += source_size ))

        # Update progress bar for completed file
        _zsh_disk_guard_progress_bar $(( file_idx * 100 / total_files )) 100 $total_files
    done

    # Ensure 100% at the end
    _zsh_disk_guard_progress_bar 100 100 $total_files
    _zsh_disk_guard_deinit_term

    # Calculate elapsed time and format it cleanly
    local elapsed=$((SECONDS - start_time))
    local elapsed_display

    # Convert to integer to avoid floating point issues
    local elapsed_int=${elapsed%.*}

    if (( elapsed_int < 60 )); then
        elapsed_display=$(printf '%ds' "$elapsed_int")
    elif (( elapsed_int < 3600 )); then
        local minutes=$((elapsed_int / 60))
        local seconds=$((elapsed_int % 60))
        elapsed_display=$(printf '%dm %ds' "$minutes" "$seconds")
    else
        local hours=$((elapsed_int / 3600))
        local minutes=$(((elapsed_int % 3600) / 60))
        local seconds=$((elapsed_int % 60))
        elapsed_display=$(printf '%dh %dm %ds' "$hours" "$minutes" "$seconds")
    fi

    # Display success summary
    if [[ $total_bytes_moved = 0 ]]; then
       printf '\n%s\n\n' "ℹ️   Nothing has changed!"
    else
       printf '\n✅ Done! Moved %s in %s\n\n' "$(_zsh_disk_guard_format_size $total_bytes_moved)" "$elapsed_display"
    fi

    # Restore REPORTTIME to original state
    if (( reporttime_was_set )); then
        REPORTTIME=$saved_reporttime
    else
        unset REPORTTIME
    fi

    # Restore xtrace if it was set
    (( xtrace_was_set )) && set -x

    return 0
}

# ──────────────────────────────────────────────────────────────────
# Wrapper for 'rsync' command with disk guard
# Note: rsync has its own progress display, so we don't need one to add
# ──────────────────────────────────────────────────────────────────
_zsh_disk_guard_rsync() {
    local LC_ALL=C
    (( ZSH_DISK_GUARD_ENABLED )) || { command rsync "$@"; return $?; }

    local args=("$@")
    local target="${args[-1]}"
    local sources=("${args[@]:0:-1}")

    # Remote target? Skip check
    if [[ "$target" == *:* ]]; then
        _zsh_disk_guard_debug "Remote target → skip check"
        command rsync "$@"
        return $?
    fi

    # Option-like target? Skip check
    if [[ "$target" == -* ]]; then
        _zsh_disk_guard_debug "Option detected → skip check"
        command rsync "$@"
        return $?
    fi

    # Unclear target? Skip check
    if [[ ! -e "$target" && "$target" != */* ]]; then
        _zsh_disk_guard_debug "Unclear target → skip check"
        command rsync "$@"
        return $?
    fi

    # Verify disk space, then run rsync
    _zsh_disk_guard_verify "$target" "${sources[@]}" || return 1
    command rsync "$@"
    return $?
}

# ──────────────────────────────────────────────────────────────────
=======
    fi

    # Verify disk space before starting (only for existing files)
    _zsh_disk_guard_verify "$target" "${sources[@]}" || return 1

    local total_files=${#sources[@]}
    local file_idx=0
    local total_bytes_moved=0
    local start_time=$SECONDS

    _zsh_disk_guard_init_term

    # Disable job control messages
    setopt LOCAL_OPTIONS NO_NOTIFY NO_MONITOR

    for source in "${sources[@]}"; do
        (( file_idx++ ))

        # Get source file size for progress calculation
        local source_size=$(set +x; [[ -f "$source" ]] && (command stat -c%s "$source" 2>/dev/null || command stat -f%z "$source" 2>/dev/null || echo 0) || echo 0)

        # Display current file with size
        local size_display=$(_zsh_disk_guard_format_size $source_size)
        printf '→ %s (%s)\n' "${source:t}" "$size_display"

        local target_file="$target/${source:t}"

        # Check if target file exists and prompt for overwrite (interactive mode only)
        if [[ -f "$target_file" ]] && [[ -o interactive ]]; then
            printf '\n%s\n' "⚠️  ${RED}Warning${NC}: ${CYAN}${target_file:t}${NC} already exists in ${CYAN}${args[-1]}${NC}!" >&2
            read -q "reply?    Overwrite ${target_file:t}? [y/N] " </dev/tty
            echo
            if [[ "$reply" != [Yy] ]]; then
                printf '%s\n' "    Skipped: ${source:t}"
                continue
            fi
        fi

        # Start mv in background (with -f to force overwrite after user confirmation)
        command mv -f "$source" "$target" &
        local mv_pid=$!

        # Monitor move progress
        if (( source_size > 0 )); then
            while kill -0 $mv_pid 2>/dev/null; do
                if [[ -f "$target_file" ]]; then
                    # Get current size of destination file
                    local cur_size=$(set +x; command stat -c%s "$target_file" 2>/dev/null || command stat -f%z "$target_file" 2>/dev/null || echo 0)

                    # Calculate progress: (completed_files * 100 + current_file_percent) / total_files
                    local cur_file_pct=$((cur_size * 100 / source_size))
                    (( cur_file_pct > 100 )) && cur_file_pct=100

                    local tot_pct=$(( (file_idx - 1) * 100 + cur_file_pct ))
                    local overall_pct=$(( tot_pct / total_files ))

                    # Show progress with file count
                    _zsh_disk_guard_progress_bar $overall_pct 100 $total_files
                else
                    # File doesn't exist yet, show progress for completed files
                    _zsh_disk_guard_progress_bar $((file_idx - 1)) $total_files $total_files
                fi
                sleep 0.1
            done
        else
            # Unknown size or directory, just show file count progress
            while kill -0 $mv_pid 2>/dev/null; do
                _zsh_disk_guard_progress_bar $file_idx $total_files $total_files
                sleep 0.2
            done
        fi

        # Wait for mv to complete and get exit status
        wait $mv_pid
        local mv_status=$?

        # Check if mv failed
        if (( mv_status != 0 )); then
            printf '\n❌ Error moving %s (exit code: %d)\n' "${source:t}" "$mv_status" >&2
            _zsh_disk_guard_deinit_term
            # Restore REPORTTIME settings
            if (( reporttime_was_set )); then
                REPORTTIME=$saved_reporttime
            else
                unset REPORTTIME
            fi
            (( xtrace_was_set )) && set -x
            return $mv_status
        fi

        # Add to total bytes moved
        (( total_bytes_moved += source_size ))

        # Update progress bar for completed file
        _zsh_disk_guard_progress_bar $(( file_idx * 100 / total_files )) 100 $total_files
    done

    # Ensure 100% at the end
    _zsh_disk_guard_progress_bar 100 100 $total_files
    _zsh_disk_guard_deinit_term

    # Calculate elapsed time and format it cleanly
    local elapsed=$((SECONDS - start_time))
    local elapsed_display

    # Convert to integer to avoid floating point issues
    local elapsed_int=${elapsed%.*}

    if (( elapsed_int < 60 )); then
        elapsed_display=$(printf '%ds' "$elapsed_int")
    elif (( elapsed_int < 3600 )); then
        local minutes=$((elapsed_int / 60))
        local seconds=$((elapsed_int % 60))
        elapsed_display=$(printf '%dm %ds' "$minutes" "$seconds")
    else
        local hours=$((elapsed_int / 3600))
        local minutes=$(((elapsed_int % 3600) / 60))
        local seconds=$((elapsed_int % 60))
        elapsed_display=$(printf '%dh %dm %ds' "$hours" "$minutes" "$seconds")
    fi

    # Display success summary
    if [[ $total_bytes_moved = 0 ]]; then
       printf '\n%s\n\n' "ℹ️   Nothing has changed!"
    else
       printf '\n✅ Done! Moved %s in %s\n\n' "$(_zsh_disk_guard_format_size $total_bytes_moved)" "$elapsed_display"
    fi

    # Restore REPORTTIME to original state
    if (( reporttime_was_set )); then
        REPORTTIME=$saved_reporttime
    else
        unset REPORTTIME
    fi

    # Restore xtrace if it was set
    (( xtrace_was_set )) && set -x

    return 0
}

# ──────────────────────────────────────────────────────────────────
# Wrapper for 'rsync' command with disk guard
# Note: rsync has its own progress display, so we don't need one to add
# ──────────────────────────────────────────────────────────────────
_zsh_disk_guard_rsync() {
    local LC_ALL=C
    (( ZSH_DISK_GUARD_ENABLED )) || { command rsync "$@"; return $?; }

    local args=("$@")
    local target="${args[-1]}"
    local sources=("${args[@]:0:-1}")

    # Remote target? Skip check
    if [[ "$target" == *:* ]]; then
        _zsh_disk_guard_debug "Remote target → skip check"
        command rsync "$@"
        return $?
    fi

    # Option-like target? Skip check
    if [[ "$target" == -* ]]; then
        _zsh_disk_guard_debug "Option detected → skip check"
        command rsync "$@"
        return $?
    fi

    # Unclear target? Skip check
    if [[ ! -e "$target" && "$target" != */* ]]; then
        _zsh_disk_guard_debug "Unclear target → skip check"
        command rsync "$@"
        return $?
    fi

    # Verify disk space, then run rsync
    _zsh_disk_guard_verify "$target" "${sources[@]}" || return 1
    command rsync "$@"
    return $?
}

# ──────────────────────────────────────────────────────────────────
>>>>>>> Stashed changes
#  Plugin Management Functions
# ──────────────────────────────────────────────────────────────────

zsh_disk_guard_enable() {
    ZSH_DISK_GUARD_ENABLED=1
    echo "✓ Disk guard enabled"
}

zsh_disk_guard_disable() {
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
    print -P "  Deep check threshold: $(_zsh_disk_guard_format_size $ZSH_DISK_GUARD_SCAN_THRESHOLD)"
    print -P "  Debug: ${debug_status}"
    print -P "  Wrapped commands: %F{cyan}${ZSH_DISK_GUARD_COMMANDS}%f"
}

# ──────────────────────────────────────────────────────────────────
#  Installation - Create aliases for wrapped commands
# ──────────────────────────────────────────────────────────────────

for cmd in ${(z)ZSH_DISK_GUARD_COMMANDS}; do
    # Check if wrapper function exists
    if (( $+functions[_zsh_disk_guard_${cmd}] )); then
        unalias $cmd 2>/dev/null
        alias $cmd="_zsh_disk_guard_${cmd}"
    else
        print -P "%F{yellow}Warning: No wrapper for '${cmd}' - skipping%f" >&2
    fi
done

<<<<<<< Updated upstream
=======
# zsh_disk_guard_threshold() {
# zsh_disk_guard_plugin_unload && export ZSH_DISK_GUARD_THRESHOLD=("$@") && source $ZPLUGINDIR/zsh-disk-guard/zsh-disk-guard.zsh
# }
>>>>>>> Stashed changes
# ──────────────────────────────────────────────────────────────────
#  Cleanup Function - Unload plugin completely
# ──────────────────────────────────────────────────────────────────

zsh_disk_guard_plugin_unload() {
    # Remove aliases (if any)
    if [[ -n "${ZSH_DISK_GUARD_COMMANDS:-}" ]]; then
        for cmd in ${(z)ZSH_DISK_GUARD_COMMANDS}; do
            unalias "$cmd" 2>/dev/null
        done
    fi

    # Unset functions
    unfunction -m '_zsh_disk_guard_*' 2>/dev/null
<<<<<<< Updated upstream
    unfunction -m 'zsh-disk-guard-*' 2>/dev/null
    unfunction zsh_disk_guard_plugin_unload 2>/dev/null
    unfunction zsh_disk_guard_df 2>/dev/null
=======
    unfunction -m 'zsh_disk_guard_*' 2>/dev/null
>>>>>>> Stashed changes

    # Optional: keep plugin dir for reloads
    unset ZSH_DISK_GUARD_{THRESHOLD,DEEP_THRESHOLD,DEBUG,ENABLED,COMMANDS}
<<<<<<< Updated upstream
    unset _zsh_disk_guard_loaded ZSH_DISK_GUARD_PLUGIN_DIR

    print -P "%F{green}✓%f Disk guard plugin unloaded successfully"
=======
    unset _zsh_disk_guard_loaded

    printf '%s\n' "${GREEN}[zsh-disk-guard]${NC} plugin unloaded successfully."
>>>>>>> Stashed changes
}

# ──────────────────────────────────────────────
# Zsh-Disk-Guard: Help & Control Interface
# ──────────────────────────────────────────────
zshdg_help() {
    # Farben lokal halten (kein Leakage in den globalen Namespace)
    local GREEN=$'\e[0;32m'
    local CYAN=$'\e[0;36m'
    local PURPLE=$'\e[0;35m'
    local NC=$'\e[0m' # reset color

    clear 2>/dev/null || printf '\n'

    cat <<_INFO_

 ──────────────────────────────────────────────────────────────────────────────────────────
 ${PURPLE}Zsh-Disk-Guard Control Interface${NC}
 Provides: ${CYAN}status, reload, unload, enable, disable, live config & autocompletion${NC}

 ${GREEN}Usage:${NC}
   zshdg status                    → show plugin status
   zshdg reload                    → reload plugin
   zshdg unload                    → unload plugin
   zshdg enable                    → enable plugin
   zshdg disable                   → disable plugin
   zshdg set threshold 90          → set ZSH_DISK_GUARD_THRESHOLD=90 and reload
   zshdg set scan-threshold 500    → set ZSH_DISK_GUARD_SCAN_THRESHOLD=500 MiB and reload
   zshdg set debug on/off          → toggle debug mode

 ───────────────────────────────────────────────────────────────────────────────────────────
_INFO_

    printf '\n%s\n' " Press any key to return... "
    read -k "? " </dev/tty
    echo
}


if [[ -z $ZSH_DG_INTERFACE_DEFINED ]]; then
    typeset -g ZSH_DG_INTERFACE_DEFINED=1

    zshdg() {

        # Color definitions
        local GREEN=$'\e[0;32;40m'
        local CYAN=$'\e[0;36;1m'
        local YELLOW=$'\e[1;33;40m'
        local RED=$'\e[0;31;40m'
        local NC=$'\e[0m'

        local cmd=$1; shift || true
        local plugin_file="${ZSH_DISK_GUARD_PLUGIN_DIR:-$ZPLUGINDIR/zsh-disk-guard}/zsh-disk-guard.zsh"

        case "$cmd" in
            reload)
                # Unload plugin cleanly if already loaded
                whence -w zsh_disk_guard_plugin_unload &>/dev/null && zsh_disk_guard_plugin_unload 2>/dev/null
                source "$plugin_file"
                printf '%s\n' "${GREEN}[zsh-disk-guard]${NC} plugin reloaded."
                ;;

            unload)
                whence -w zsh_disk_guard_plugin_unload &>/dev/null && zsh_disk-guard_plugin_unload
                ;;

            enable)
                whence -w zsh_disk_guard_enable &>/dev/null && zsh_disk_guard_enable
                ;;

            disable)
                whence -w zsh_disk_guard_disable &>/dev/null && zsh_disk_guard_disable
                ;;

     help|-h|--help)
                whence -w zshdg_help &>/dev/null && zshdg_help
                ;;

            status)
                printf '%s\n' "──────────────────────────────────────────"
                printf '%s\n' "  ${YELLOW}[zsh-disk-guard] Current configuration ${NC}"
                printf '%s\n' "──────────────────────────────────────────"
                printf '  Target Drive Threshold: %s%d%%%s\n' "${CYAN}" "$ZSH_DISK_GUARD_THRESHOLD" "${NC}"
                printf '  Scan threshold: %s\n' "${CYAN}$(_zsh_disk_guard_format_size $ZSH_DISK_GUARD_SCAN_THRESHOLD)${NC}"
                printf '  Debug: %s\n' "${CYAN}${ZSH_DISK_GUARD_DEBUG:-off}${NC}"
                printf '  Plugin enabled: %s\n' "${CYAN}${ZSH_DISK_GUARD_ENABLED:-1}${NC}"
                printf '%s\n' "──────────────────────────────────────────"
                ;;

            set)
                local var=$1 val=$2
                case "$var" in
                     threshold)
                            # Validation for threshold
                            # me: "Nobody would seriously..." Layer 8: "Hold my beer!" 🍺
                            if [[ ! "$val" =~ ^[0-9]+$ ]] || (( val < 1 || val > 100 )); then
                                printf '%s\n' "❌ ${RED}Error${NC}: threshold must be between 1-100"
                                return 1
                            fi
                            # Unload first
                            whence -w zsh_disk_guard_plugin_unload &>/dev/null && zsh_disk_guard_plugin_unload 2>/dev/null
                            # THEN set the variable
                            export ZSH_DISK_GUARD_THRESHOLD="$val"
                            # THEN reload
                            source "$plugin_file"
                            printf '%s\n' "[zsh-disk-guard] Threshold updated to ${CYAN}${val}%${NC}"
                            return 0
                        ;;
                    scan-threshold)
                            # Validation for scan threshold
                            if [[ ! "$val" =~ ^[0-9]+$ ]] || (( val < 1 )); then
                                printf '%s\n%s\n\n' " ❌ ${RED}Error${NC}: Scan threshold must be an integer not less than 1." "           You should enter an appropriate size in Megabytes."
                                return 1
                            fi
                        # Unload first
                            whence -w zsh_disk_guard_plugin_unload &>/dev/null && zsh_disk_guard_plugin_unload 2>/dev/null
                            # THEN set the variable
                            export ZSH_DISK_GUARD_SCAN_THRESHOLD=$((val * 1024 * 1024))
                            # THEN reload
                            source "$plugin_file"
                            printf '%s\n' "${GREEN}[zsh-disk-guard]${NC} Scan Threshold updated to ${CYAN}${val} MB${NC} (${CYAN}$(_zsh_disk_guard_format_size $ZSH_DISK_GUARD_SCAN_THRESHOLD)${NC})"
                            printf '%s\n' "${GREEN}[zsh-disk-guard]${NC} plugin reloaded."
                            return 0

                        ;;
                    debug)
                        [[ "$val" == "on" ]] && export ZSH_DISK_GUARD_DEBUG=1 || unset ZSH_DISK_GUARD_DEBUG
                        ;;
                    *)
                        printf '%s\n' "Unknown setting: $var"
                        return 1
                        ;;
                esac
                printf '%s\n' "[zsh-disk-guard] setting updated: $var = $val"
                zshdg reload
                ;;

            *)
                printf '%s\n' "Enter ${CYAN}zshdg help${CNC} for help"
                ;;
        esac
    }

    # -------------------------
    # Autocompletion for zshdg
    # -------------------------
    _zshdg_completion() {
        local -a actions vars debug_opts
        actions=(reload unload set status)
        vars=(threshold scan-threshold debug)
        debug_opts=(on off)

        if (( CURRENT == 2 )); then
            compadd -a actions
        elif [[ ${words[2]} == set ]]; then
            if (( CURRENT == 3 )); then
                compadd -a vars
            elif (( CURRENT == 4 )); then
                case "${words[3]}" in
                    debug) compadd -a debug_opts ;;
                    *) ;; # for numerical values ​​we leave free input
                esac
            fi
        fi
    }

    compdef _zshdg_completion zshdg
fi
