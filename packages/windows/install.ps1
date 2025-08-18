# Windows PowerShell installer for termclip
param(
    [switch]$Force
)

# Colors for output
$Green = "`e[92m"
$Blue = "`e[94m"
$Yellow = "`e[93m"
$Red = "`e[91m"
$Reset = "`e[0m"

function Write-ColorText($text, $color) {
    Write-Host "$color$text$Reset"
}

function Get-LatestVersion {
    try {
        $response = Invoke-RestMethod "https://api.github.com/repos/0xrushi/termclip/tags" -ErrorAction SilentlyContinue
        if ($response -and $response.Count -gt 0) {
            return $response[0].name -replace '^v', ''
        }
    }
    catch {
        # Fallback if API fails
    }
    return "1.0.3"
}

Write-ColorText "Installing termclip for Windows..." $Blue
Write-Host ""

# Check if Python is installed
Write-Host "Checking Python installation..."
try {
    $pythonVersion = python --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-ColorText "✓ Found: $pythonVersion" $Green
        
        # Check Python version (need 3.6+)
        $versionMatch = $pythonVersion -match "Python (\d+)\.(\d+)"
        if ($versionMatch) {
            $major = [int]$matches[1]
            $minor = [int]$matches[2]
            if ($major -lt 3 -or ($major -eq 3 -and $minor -lt 6)) {
                Write-ColorText "⚠ Python 3.6+ recommended, found $pythonVersion" $Yellow
            }
        }
    }
    else {
        throw "Python not found"
    }
}
catch {
    Write-ColorText "❌ Python not found. Please install Python 3.6+ first." $Red
    Write-Host "Download from: https://www.python.org/downloads/"
    Write-Host "Make sure to check 'Add Python to PATH' during installation."
    if (-not $Force) {
        Read-Host "Press Enter to exit"
        exit 1
    }
}

# Set installation directory
$InstallDir = "$env:USERPROFILE\.local\bin"
$ScriptUrl = "https://raw.githubusercontent.com/0xrushi/termclip/main/termclip.py"

# Get version
$Version = Get-LatestVersion
Write-Host "Installing termclip v$Version..."

# Create installation directory
Write-Host "Creating installation directory..."
if (-not (Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
}
Write-ColorText "✓ Created $InstallDir" $Green

# Download script
Write-Host "Downloading termclip..."
try {
    Invoke-WebRequest -Uri $ScriptUrl -OutFile "$InstallDir\termclip.py" -ErrorAction Stop
    Write-ColorText "✓ Downloaded termclip.py" $Green
}
catch {
    Write-ColorText "❌ Failed to download termclip: $($_.Exception.Message)" $Red
    if (-not $Force) {
        Read-Host "Press Enter to exit"
        exit 1
    }
}

# Create batch wrapper
Write-Host "Creating batch wrapper..."
$BatchContent = @"
@echo off
python "$InstallDir\termclip.py" %*
"@
$BatchContent | Out-File -FilePath "$InstallDir\termclip.bat" -Encoding ascii
Write-ColorText "✓ Created termclip.bat wrapper" $Green

# Add to PATH
Write-Host "Configuring PATH..."
$CurrentPath = [Environment]::GetEnvironmentVariable("PATH", "User")
if ($CurrentPath -notlike "*$InstallDir*") {
    Write-Host "Adding $InstallDir to user PATH..."
    
    $NewPath = if ($CurrentPath) { "$CurrentPath;$InstallDir" } else { $InstallDir }
    
    try {
        [Environment]::SetEnvironmentVariable("PATH", $NewPath, "User")
        Write-ColorText "✓ Added to PATH successfully" $Green
        Write-ColorText "Note: Restart your command prompt for PATH changes to take effect" $Yellow
        
        # Update PATH for current session
        $env:PATH += ";$InstallDir"
    }
    catch {
        Write-ColorText "⚠ Failed to update PATH automatically" $Yellow
        Write-Host "Please add $InstallDir to your PATH manually"
    }
}
else {
    Write-ColorText "✓ Directory already in PATH" $Green
}

Write-Host ""
Write-ColorText "🎉 termclip installed successfully!" $Green
Write-Host ""
Write-ColorText "Usage examples:" $Blue
Write-Host "  echo 'hello world' | termclip"
Write-Host "  termclip --paste"
Write-Host "  termclip --version"
Write-Host ""
Write-ColorText "Windows-specific tips:" $Blue
Write-Host "• termclip uses OSC 52 sequences for terminal clipboard"
Write-Host "• Works great with Windows Terminal, PowerShell, and modern terminals"
Write-Host "• For clipboard access in Command Prompt, consider using Windows Terminal"
Write-Host ""

# Test installation
if (Test-Path "$InstallDir\termclip.bat") {
    Write-ColorText "✅ Installation verified!" $Green
    
    # Test version
    try {
        $versionOutput = & "$InstallDir\termclip.bat" --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-ColorText "✅ Version test passed: $versionOutput" $Green
        }
        else {
            Write-ColorText "⚠ Version test failed, but installation completed" $Yellow
        }
    }
    catch {
        Write-ColorText "⚠ Version test failed, but installation completed" $Yellow
    }
}
else {
    Write-ColorText "⚠ Installation completed but termclip.bat not found" $Yellow
}

Write-Host ""
Write-ColorText "To test: echo 'hello' | termclip" $Blue
Write-ColorText "Restart your command prompt if 'termclip' command is not found" $Blue
Write-Host ""

if (-not $Force) {
    Read-Host "Press Enter to exit"
}