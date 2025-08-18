$ErrorActionPreference = 'Stop'

$packageName = 'termclip'
$toolsDir = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
$installDir = Join-Path $env:ChocolateyInstall 'lib\termclip\tools'

# Download termclip.py
$scriptUrl = 'https://raw.githubusercontent.com/0xrushi/termclip/main/termclip.py'
$scriptPath = Join-Path $installDir 'termclip.py'

Write-Host "Downloading termclip.py..." -ForegroundColor Green
try {
    Invoke-WebRequest -Uri $scriptUrl -OutFile $scriptPath -UseBasicParsing
    Write-Host "Downloaded termclip.py successfully" -ForegroundColor Green
} catch {
    throw "Failed to download termclip.py: $($_.Exception.Message)"
}

# Create batch wrapper
$batchContent = @"
@echo off
python "$scriptPath" %*
"@

$batchPath = Join-Path $installDir 'termclip.bat'
$batchContent | Out-File -FilePath $batchPath -Encoding ascii

Write-Host "Created termclip.bat wrapper" -ForegroundColor Green

# Create PowerShell wrapper (for better PowerShell integration)
$psContent = @"
python "$scriptPath" @args
"@

$psPath = Join-Path $installDir 'termclip.ps1'
$psContent | Out-File -FilePath $psPath -Encoding utf8

# Install shims
Install-BinFile -Name 'termclip' -Path $batchPath

Write-Host "termclip installed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Usage:" -ForegroundColor Yellow
Write-Host "  echo 'hello world' | termclip"
Write-Host "  termclip --paste"
Write-Host "  termclip --version"