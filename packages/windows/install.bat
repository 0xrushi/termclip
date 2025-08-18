@echo off
setlocal enabledelayedexpansion

:: Colors for output (limited on Windows)
set "GREEN=[92m"
set "BLUE=[94m"
set "YELLOW=[93m"
set "RED=[91m"
set "NC=[0m"

echo %BLUE%Installing termclip for Windows...%NC%
echo.

:: Check if Python is installed
echo Checking Python installation...
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo %RED%Python not found. Please install Python 3.6+ first.%NC%
    echo Download from: https://www.python.org/downloads/
    echo Make sure to check "Add Python to PATH" during installation.
    pause
    exit /b 1
)

:: Get Python version
for /f "tokens=2" %%i in ('python --version 2^>^&1') do set PYTHON_VERSION=%%i
echo %GREEN%Found Python %PYTHON_VERSION%%NC%

:: Check if curl is available (Windows 10 1803+)
curl --version >nul 2>&1
if %errorlevel% neq 0 (
    echo %RED%curl not found. Please install curl or use PowerShell method.%NC%
    pause
    exit /b 1
)

:: Set installation directory
set "INSTALL_DIR=%USERPROFILE%\.local\bin"
set "SCRIPT_URL=https://raw.githubusercontent.com/0xrushi/termclip/main/termclip.py"

:: Get version from GitHub
echo Getting latest version...
for /f "delims=" %%i in ('curl -fsSL "https://api.github.com/repos/0xrushi/termclip/tags" 2^>nul ^| findstr "\"name\"" ^| findstr /n "." ^| findstr "1:"') do (
    set "version_line=%%i"
)
for /f "tokens=2 delims=:" %%i in ("!version_line!") do (
    for /f "tokens=2 delims=v" %%j in ("%%i") do (
        for /f "tokens=1 delims=," %%k in ("%%j") do (
            set "VERSION=%%k"
            set "VERSION=!VERSION:"=!"
        )
    )
)
if "!VERSION!"=="" set "VERSION=1.0.3"

echo Installing termclip v!VERSION!...

:: Create installation directory
echo Creating installation directory...
if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%"
echo %GREEN%Created %INSTALL_DIR%%NC%

:: Download script
echo Downloading termclip...
curl -fsSL "%SCRIPT_URL%" -o "%INSTALL_DIR%\termclip.py"
if %errorlevel% neq 0 (
    echo %RED%Failed to download termclip%NC%
    pause
    exit /b 1
)
echo %GREEN%Downloaded termclip.py%NC%

:: Create batch wrapper
echo Creating batch wrapper...
(
echo @echo off
echo python "%INSTALL_DIR%\termclip.py" %%*
) > "%INSTALL_DIR%\termclip.bat"
echo %GREEN%Created termclip.bat wrapper%NC%

:: Add to PATH if not already there
echo Configuring PATH...
echo !PATH! | findstr /i "%INSTALL_DIR%" >nul
if %errorlevel% neq 0 (
    echo Adding %INSTALL_DIR% to user PATH...
    
    :: Get current user PATH
    for /f "tokens=2*" %%a in ('reg query "HKCU\Environment" /v PATH 2^>nul') do set "CURRENT_PATH=%%b"
    if "!CURRENT_PATH!"=="" set "CURRENT_PATH="
    
    :: Add new directory to PATH
    if "!CURRENT_PATH!"=="" (
        set "NEW_PATH=%INSTALL_DIR%"
    ) else (
        set "NEW_PATH=!CURRENT_PATH!;%INSTALL_DIR%"
    )
    
    :: Update registry
    reg add "HKCU\Environment" /v PATH /t REG_EXPAND_SZ /d "!NEW_PATH!" /f >nul
    if %errorlevel% equ 0 (
        echo %GREEN%Added to PATH successfully%NC%
        echo %YELLOW%Note: Restart your command prompt for PATH changes to take effect%NC%
    ) else (
        echo %YELLOW%Failed to update PATH automatically%NC%
        echo Please add %INSTALL_DIR% to your PATH manually
    )
) else (
    echo %GREEN%Directory already in PATH%NC%
)

echo.
echo %GREEN%termclip installed successfully!%NC%
echo.
echo %BLUE%Usage examples:%NC%
echo   echo hello world ^| termclip
echo   termclip --paste
echo   termclip --version
echo.
echo %BLUE%Windows-specific tips:%NC%
echo • termclip uses OSC 52 sequences for terminal clipboard
echo • Works great with Windows Terminal, PowerShell, and modern terminals
echo • For best results, use a terminal that supports OSC 52
echo.

:: Test installation in current session
set "PATH=%PATH%;%INSTALL_DIR%"
if exist "%INSTALL_DIR%\termclip.bat" (
    echo %GREEN%Installation verified!%NC%
    
    :: Test version
    "%INSTALL_DIR%\termclip.bat" --version 2>nul
    if %errorlevel% equ 0 (
        echo %GREEN%Version test passed%NC%
    ) else (
        echo %YELLOW%Version test failed, but installation completed%NC%
    )
) else (
    echo %YELLOW%Installation completed but termclip.bat not found%NC%
)

echo.
echo %BLUE%To test: echo hello ^| termclip%NC%
echo %BLUE%Restart your command prompt if termclip command is not found%NC%
echo.
pause