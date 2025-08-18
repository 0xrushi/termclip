# Windows Installation

## Quick Install (PowerShell - Recommended)

**Run as Administrator or regular user:**
```powershell
irm https://raw.githubusercontent.com/0xrushi/termclip/main/packages/windows/install.ps1 | iex
```

## Alternative Install (Command Prompt)

```cmd
curl -fsSL https://raw.githubusercontent.com/0xrushi/termclip/main/packages/windows/install.bat -o install.bat && install.bat
```

## Manual Install

### Option 1: PowerShell Script

1. **Download the installer:**
   ```powershell
   Invoke-WebRequest -Uri "https://raw.githubusercontent.com/0xrushi/termclip/main/packages/windows/install.ps1" -OutFile "install.ps1"
   ```

2. **Run the installer:**
   ```powershell
   .\install.ps1
   ```

### Option 2: Batch Script

1. **Download the installer:**
   ```cmd
   curl -O https://raw.githubusercontent.com/0xrushi/termclip/main/packages/windows/install.bat
   ```

2. **Run the installer:**
   ```cmd
   install.bat
   ```

## What it does

- Checks if Python is installed (shows download link if missing)
- Downloads `termclip.py` to `%USERPROFILE%\.local\bin\`
- Creates `termclip.bat` wrapper script
- Adds the installation directory to your user PATH
- Tests the installation

## Requirements

- **Windows 10** (1803+) or **Windows 11**
- **Python 3.6+** (must be pre-installed)
- **curl** (built into Windows 10 1803+)

## Install Python First

If Python is not installed:

1. **Download Python:** https://www.python.org/downloads/
2. **Important:** Check "Add Python to PATH" during installation
3. **Verify:** Open Command Prompt and run `python --version`

## Usage

```cmd
# Copy to clipboard
echo hello world | termclip

# Paste from clipboard  
termclip --paste

# Show version
termclip --version
```

## Windows-specific features

- **OSC 52 support** for modern terminals (Windows Terminal, etc.)
- **PowerShell clipboard** fallback (`Set-Clipboard`/`Get-Clipboard`)
- **Command Prompt compatibility** via batch wrapper
- **Automatic PATH management**

## Recommended terminals

- **Windows Terminal** (best OSC 52 support)
- **PowerShell 7+**
- **Visual Studio Code integrated terminal**

## Troubleshooting

### "termclip is not recognized"
- Restart your command prompt/PowerShell
- Check if `%USERPROFILE%\.local\bin` is in your PATH

### Python not found
- Install Python from https://www.python.org/downloads/
- Make sure "Add Python to PATH" was checked during installation
- Restart command prompt after Python installation

### Permission errors
- Run PowerShell as Administrator
- Or use the `-Force` parameter: `.\install.ps1 -Force`

## Uninstall

```cmd
# Remove files
rmdir /s "%USERPROFILE%\.local\bin"

# Remove from PATH (manual)
# Go to System Properties > Environment Variables
# Edit user PATH and remove the termclip directory
```