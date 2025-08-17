# termclip

A cross-platform terminal clipboard utility that works with native clipboard tools and OSC 52 escape sequences.

## Features

- **Native clipboard integration** on macOS (pbcopy/pbpaste), Windows (clip/PowerShell), and Linux (xclip/xsel/wl-copy)
- **OSC 52 escape sequences** for SSH/remote clipboard access
- **tmux and screen pass-through** for multiplexer environments
- **Pipe-friendly design** for shell workflows
- **Zero external dependencies** beyond Python 3.8+

## Installation

### Windows (winget)
```cmd
winget install termclip
```

### WSL/Ubuntu/Debian
```bash
curl -fsSL https://raw.githubusercontent.com/0xrushi/termclip/main/packages/wsl/install.sh | bash
```

### Arch Linux
```bash
# From AUR (when published)
yay -S termclip

# Manual build
git clone https://github.com/0xrushi/termclip
cd termclip/packages/arch
makepkg -si
```

### macOS (Homebrew)
```bash
# From tap (when published)
brew tap 0xrushi/termclip
brew install termclip

# Direct install
brew install https://raw.githubusercontent.com/0xrushi/termclip/main/packages/homebrew/termclip.rb
```

### Manual Installation
```bash
# Download and install
curl -fsSL https://raw.githubusercontent.com/0xrushi/termclip/main/termclip.py -o termclip
chmod +x termclip
sudo mv termclip /usr/local/bin/
```

## Usage

```bash
# Copy text to clipboard
echo "hello world" | termclip
cat file.txt | termclip

# Paste from clipboard (local only)
termclip --paste

# Force OSC 52 mode (useful over SSH)
TERMCLIP_FORCE_OSC52=1 cat file.txt | termclip

# Force native clipboard tools
TERMCLIP_FORCE_NATIVE=1 cat file.txt | termclip

# Configure OSC 52 payload size limit (default: 75000)
TERMCLIP_OSC52_MAX_B64=100000 cat large-file.txt | termclip
```

## How it works

termclip automatically detects your environment and chooses the best clipboard method:

1. **Native tools** (preferred):
   - macOS: `pbcopy`/`pbpaste`
   - Windows: `clip` or PowerShell `Set-Clipboard`
   - Linux: `xclip`, `xsel`, or `wl-copy` (depending on X11/Wayland)

2. **OSC 52 escape sequences** (fallback):
   - Sends clipboard data directly to terminal
   - Works over SSH connections
   - Supports tmux and screen pass-through
   - Compatible with modern terminals

## Terminal Compatibility

OSC 52 sequences work with:
- ✅ Alacritty
- ✅ kitty
- ✅ GNOME Terminal
- ✅ Windows Terminal  
- ✅ iTerm2
- ✅ Terminal.app (macOS)
- ✅ Visual Studio Code integrated terminal
- ✅ Most modern terminal emulators

## SSH Usage

termclip works great over SSH connections:

```bash
# On remote server
echo "data from server" | termclip

# The text appears in your local clipboard!
```

This works because termclip sends OSC 52 sequences through the SSH connection to your local terminal.

## Package Development

This repository includes packaging for multiple platforms:

- **Windows**: winget manifests in `packages/winget/`
- **WSL/Linux**: installation script in `packages/wsl/`
- **Arch Linux**: PKGBUILD in `packages/arch/`
- **macOS**: Homebrew formula in `packages/homebrew/`

### Building releases

```bash
# Build all packages
./scripts/build-release.sh

# Test packages locally
./scripts/test-packages.sh
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test on multiple platforms
5. Submit a pull request

## License

MIT License - see LICENSE file for details.

## Troubleshooting

### "no clipboard method worked"
- **Linux**: Install `xclip`, `xsel`, or `wl-clipboard`
- **Windows**: Ensure PowerShell is available
- **macOS**: Should work out of the box

### OSC 52 not working
- Verify your terminal supports OSC 52
- Try a different terminal emulator
- Check if you're in a multiplexer (tmux/screen)

### SSH clipboard not working
- Ensure your local terminal supports OSC 52
- Try `TERMCLIP_FORCE_OSC52=1` to force OSC 52 mode
- Check that SSH doesn't strip escape sequences
