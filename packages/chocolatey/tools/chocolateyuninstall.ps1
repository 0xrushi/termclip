$ErrorActionPreference = 'Stop'

$packageName = 'termclip'

# Remove shim
Uninstall-BinFile -Name 'termclip'

Write-Host "termclip uninstalled successfully!" -ForegroundColor Green