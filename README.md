# Nerd Font Rofi Picker

A simple rofi-based picker for nerd font icons. Browse through thousands of icons with fuzzy search and copy them to your clipboard.

## Usage

```bash
./nerd_rofi_picker.sh
```

- Type to search for icons
- Select with Enter to copy to clipboard
- ESC to exit

## Options

```bash
./nerd_rofi_picker.sh --update    # Force update nerd font data
```

## Requirements

- rofi
- wl-copy (Wayland) or xclip (X11)
- A nerd font installed

## How it works

The script uses a git submodule to fetch the latest nerd font data, processes it for better performance, and presents it through rofi with a nice theme. Icons are automatically copied to your clipboard when selected.

Data updates automatically once a week, or you can force an update with the `--update` flag.