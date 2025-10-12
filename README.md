<p align="left">
  <img src="https://img.shields.io/badge/Zsh%20Plugin-zsh--disk--guard-blue?style=plastic">
  <img src="https://img.shields.io/badge/zsh-%E2%89%A55.0-blue?style=plastic">
  <img src="https://img.shields.io/badge/platform-Linux%20%7C%20macOS%20%7C%20BSD-lightgrey?style=plastic">
  <img src="https://img.shields.io/badge/license-MIT-green?style=plastic">
  <img src="https://img.shields.io/github/stars/TomfromBerlin/zsh-disk-guard?style=plastic">
  <img src="https://img.shields.io/github/downloads/TomfromBerlin/zsh-disk-guard/total?style=plastic&labelColor=grey&color=blue">
</p>

<!--
![GitHub Downloads (all assets, all releases)](https://img.shields.io/github/downloads/TomfromBerlin/zsh-disk-guard/total?style=plastic&labelColor=grey&color=blue)
-->

# Zsh Disk Guard Plugin

🛡️ Intelligent disk space monitoring for write operations in Zsh

## 💡 Features

- ⚡ **Smart Performance**: Staged checking based on data size
- 🎯 **Predictive**: Checks if there's enough space *before* writing
- 🔧 **Configurable**: Adjust thresholds and behavior
- 🚀 **Zero Overhead**: Minimal checks for small files
- 📦 **Plugin Manager Ready**: Works with oh-my-zsh, zinit, antigen, etc.

## Why This Plugin?

- ✅ With: Predictive warnings, safe operations, peace of mind
- ❌ Without: Disk full errors mid-copy, wasted time, corrupted files


## 📝 Requirements

<details><summary>**Zsh 5.0+** (released 2012)</summary>
The version is checked when the plugin is loaded. If the version is too low, the plugin will not load. To manually check, run the following command at the command line:
   
  ```zsh
  echo $ZSH_VERSION
  ```
  
Upgrade: See [zsh.org](https://www.zsh.org/)
 </details>
 
<details><summary>Standard Unix tools</summary>

- df: Displays the free disk space. Only mounted partitions are displayed.
- stat: Used here to display the file system status instead of the file status
- du: Displays the used disk space.

</details>

## 🛠️ Install
<details><summary> ← click here</summary>

Add to your `.zshrc`:

### ZSH Unplugged (my recommendation)

```zsh
# (Do not use the following 15 lines along with other plugin managers!)
# ZSH UNPLUGGED start
# <------------------>
# where do you want to store your plugins?
ZPLUGINDIR=$HOME/.config/zsh/plugins
# <------------------>
# get zsh_unplugged and store it with your other plugins and source it
if [[ ! -d $ZPLUGINDIR/zsh_unplugged ]]; then
  git clone --quiet https://github.com/mattmc3/zsh_unplugged $ZPLUGINDIR/zsh_unplugged
fi
source $ZPLUGINDIR/zsh_unplugged/zsh_unplugged.zsh
# <------------------>
# extend fpath and load zsh-defer
fpath+=($ZPLUGINDIR/zsh-defer)
autoload -Uz zsh-defer
# <------------------>
# make list of the Zsh plugins you use
repos=(
  # ... your other plugins ...
  TomfromBerlin/zsh-disk-guard
)
```

other plugin manager and frameworks:

### Antigen

add to your .zshrc:

```zsh
antigen bundle TomfromBerlin/zsh-disk-guard
```

### Oh-My-Zsh

Enter the following command on the command line and confirm with Return

```zsh
git clone https://github.com/TomfromBerlin/zsh-disk-guard ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-disk-guard
```

then add to your .zshrc:

```zsh
plugins=(... zsh-disk-guard)
```

### Zinit

add to your .zshrc:

```zsh
zinit light TomfromBerlin/zsh-disk-guard
```

You can load the plugin with any other plugin manager.

⚠️ **Regardless which pluginmanager you use, the plugin may interfere with other plugins that monitor disk operations or use the wrapped commands (*cp*, *mv*, *rsync*). ⚠️**

### manual call via the command line

```zsh
git clone https://github.com/TomfromBerlin/zsh-disk-guard ~/.config/zsh/plugins/zsh-disk-guard
source ~/.config/zsh/plugins/zsh-disk-guard/zsh-disk-guard.plugin.zsh
```

</details>

## 🧹 Uninstall

<details><summary> ← click here</summary>

Simply remove from your plugin list and restart Zsh.

### Temporary Disable

```zsh

zsh-disk-guard-disable

```

### To completely remove:

```zsh

zsh_disk_guard_plugin_unload
rm -rf ~/.config/zsh/plugins/zsh-disk-guard

```

</details>

## How It Works

### 📋 Two-Stage Checking

The plugin performs a quick or deep disk check depending on the data size before write operations.

- #### Quick Check (files <100 MiB):

  - Uses stat only (fast)
  - Warns if disk >80% full
  - No size calculation

- #### Deep Check (≥100 MiB or directories):

  - Calculates actual size with du
  - Verifies available space
  - Prevents failed operations

- #### Smart Skipping
  
  - Automatically skips checks for:
    - Remote targets (rsync user@host:/path)
    - Options ending with - (rsync -av files -n)
    - Unclear syntax

### Performance

|Scenario|Overhead|Check Type|
|-|-|-|
| cp small.txt /tmp | ~1ms | Usage only |
| cp file.iso /backup (5 GiB) | ~3ms | Full check |
| cp -r directory/ /tmp| Variable | Full check with du |

## ⚙️ Configure

This plugin should be ready to use right out of the box and requires no further configuration. However, you can adjust some settings to suit your needs.

<details><summary> ← click here for more</summary>

```zsh

Set these before loading the plugin:

# set disk usage warning threshold to 90% (default: 80%)
export ZSH_DISK_GUARD_THRESHOLD=90

# set deep check threshold to 500 MiB (default: 100 MiB)
export ZSH_DISK_GUARD_DEEP_THRESHOLD=$((500 * 1024 * 1024))

# Enable debug output (default: 0)
export ZSH_DISK_GUARD_DEBUG=1

# disable plugin (default: 1)
export ZSH_DISK_GUARD_ENABLED=0

# commands to wrap (default: "cp mv rsync")
# If you want to change the default (mot recommended), further adjustments are necessary
export ZSH_DISK_GUARD_COMMANDS="cp mv rsync"

```
</details>

## 🖥️ Usage

Since this is a plugin, manual execution is neither necessary nor useful. The plugin reacts to certain triggers and executes the corresponding actions automatically. The active status of the plugin is usually only noticed when the available disk space falls below the given threshold. The plugin's status can be checked via the command line. For more information, see the "Control" section.

<details><summary> ← Click here to view an output sample</summary>

```zsh

# Automatically checked
cp large-file.iso /backup/
# ⚠️  Warning: Partition /backup is 85% full!
# Continue anyway? [y/N]

# Prevents write if not enough space
mv bigdata/ /mnt/small-disk/
# ❌ ERROR: Not enough disk space on /mnt/small-disk!
#    Required: 5 GiB
#    Available: 3 GiB
#    Missing: 2048 MiB

# Smart: skips remote targets
rsync -av files/ user@remote:/backup/  # No local check

```
</details>

## 💻 Control

```zsh
zsh-disk-guard-status    # Shows current configuration
```

```zsh
zsh-disk-guard-disable   # Temporarily disable
```

```zsh
zsh-disk-guard-enable    # Re-enable
```


# 💬 Contribute
Issues and PRs welcome at github.com/TomfromBerlin/zsh-disk-guard

License: MIT

Author: Tom (from Berlin)

_Memo to self: They'll download this plugin again and not leave a single comment. Yes, not even a tiny star. But at least my code is traveling around the world._
