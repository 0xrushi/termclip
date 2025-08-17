# termclip

Cross-platform terminal clipboard helper with OSC 52 support for Arch Linux.

## Installation

### From AUR (recommended)
```bash
yay -S termclip
# or
paru -S termclip
# or
git clone https://aur.archlinux.org/termclip.git
cd termclip
makepkg -si
```

### Manual build
```bash
git clone https://github.com/0xrushi/termclip
cd termclip/packages/arch
makepkg -si
```

## Dependencies

- **python>=3.8** (required)
- **xclip** (optional) - for X11 clipboard support
- **xsel** (optional) - alternative X11 clipboard support  
- **wl-clipboard** (optional) - for Wayland clipboard support

Install optional dependencies:
```bash
# For X11 users
sudo pacman -S xclip

# For Wayland users  
sudo pacman -S wl-clipboard

# Install both if you switch between X11/Wayland
sudo pacman -S xclip wl-clipboard
```

## Usage

```bash
# Copy text to clipboard
echo "hello world" | termclip
cat file.txt | termclip

# Paste from clipboard
termclip --paste

# Force OSC 52 mode (useful over SSH)
TERMCLIP_FORCE_OSC52=1 cat file.txt | termclip
```

## Features

- Native clipboard integration (xclip/xsel/wl-copy)
- OSC 52 escape sequences for SSH/remote use
- tmux and screen multiplexer pass-through
- Works in Wayland and X11 environments
- Zero configuration required

## Troubleshooting

### No clipboard support
If you get "no clipboard method worked", install the appropriate clipboard tool:

- **X11**: `sudo pacman -S xclip` or `sudo pacman -S xsel`
- **Wayland**: `sudo pacman -S wl-clipboard`

### OSC 52 in SSH
For remote clipboard access over SSH, ensure your terminal supports OSC 52:
- Alacritty ✓
- kitty ✓  
- GNOME Terminal ✓
- Windows Terminal ✓
- iTerm2 ✓
