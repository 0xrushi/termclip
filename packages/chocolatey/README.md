# Windows Installation via Chocolatey

## Super Easy Install

```cmd
choco install termclip
```

That's it! No Python management, no PATH configuration, no manual downloads.

## Requirements

- **Chocolatey** package manager
- **Python 3.6+** (automatically installed as dependency)

## Install Chocolatey First

If you don't have Chocolatey:

```powershell
# Run as Administrator
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
```

## Usage

```cmd
# Copy to clipboard
echo hello world | termclip

# Paste from clipboard
termclip --paste

# Show version
termclip --version
```

## Managing the installation

```cmd
# Update to latest version
choco upgrade termclip

# Uninstall
choco uninstall termclip

# Get info
choco info termclip
```

## Benefits of Chocolatey

✅ **Automatic dependency management** - Python installed automatically  
✅ **No PATH configuration** - Works immediately  
✅ **Easy updates** - `choco upgrade termclip`  
✅ **Clean uninstall** - `choco uninstall termclip`  
✅ **System-wide installation** - Available for all users  
✅ **Version management** - Pin versions, rollback, etc.  

## Publishing to Chocolatey Community

This package can be submitted to the [Chocolatey Community Repository](https://community.chocolatey.org/) for public distribution.

### Steps to publish:
1. Test the package locally
2. Submit to Chocolatey moderation queue
3. Once approved, users can install with `choco install termclip`

## Testing locally

```cmd
# Build package
choco pack

# Install locally
choco install termclip -s .

# Test
termclip --version

# Uninstall
choco uninstall termclip
```