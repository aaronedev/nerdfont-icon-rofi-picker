# Nerd Font Rofi Picker

A simple rofi-based picker for Nerd Font icons. Browse thousands of icons,
multi-select, and copy them in various formats (Glyph, Name, Hex, CSS).

## Features

- **Fuzzy Search:** Instantly find icons by name or category.
- **Format Selection:** Copy as Glyph, Class Name, Hex Code, or CSS.
- **Git-less:** Works standalone (auto-downloads data if git/submodules
  missing).
- **Auto-Update:** Updates icon data weekly.

## Installation

**Clone:**

```bash
git clone --recurse-submodules https://github.com/aaronedev/nerdfont-icon-rofi-picker.git
cd nerdfont-icon-rofi-picker
./nerd_rofi_picker.sh
```

**Standalone (No Git):** Just download `nerd_rofi_picker.sh`, `chmod +x` it, and
run. It will fetch the data for you.

## Usage

```bash
./nerd_rofi_picker.sh
```

### Keybindings

| Key              | Action                                   |
| :--------------- | :--------------------------------------- |
| **Enter**        | Copy selected icon(s) (Glyph) and exit   |
| **Alt + n**      | Copy **Name** (e.g., `nf-fa-home`)       |
| **Alt + h**      | Copy **Hex Code** (e.g., `f015`)         |
| **Alt + c**      | Copy **CSS Class** (e.g., `.nf-fa-home`) |
| **Left / Right** | Navigate columns                         |
| **Ctrl + b / f** | Move cursor in search bar                |

## Options

- `--update`: Force update Nerd Font data.
- `--help`: Show help message.

## Requirements

- `rofi`
- `wl-copy` (Wayland) or `xclip` (X11)
- `curl` or `wget` (for auto-download)
- A Nerd Font installed on your system
