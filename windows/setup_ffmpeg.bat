@echo off
REM FFmpeg installer wrapper - checks if FFmpeg exists before installing
setlocal

echo ========================================
echo FFmpeg Setup for Swaloka
echo ========================================
echo.

REM Check if FFmpeg is already installed
ffmpeg -version >nul 2>&1
if %errorLevel% == 0 (
    echo FFmpeg is already installed!
    echo.
    ffmpeg -version | findstr "ffmpeg version"
    echo.
    echo No installation needed.
    echo.
    pause
    exit /b 0
)

echo FFmpeg is not installed.
echo.
echo This script will:
echo   1. Download FFmpeg from gyan.dev
echo   2. Install to C:\ffmpeg
echo   3. Add to System PATH
echo.

REM Check for admin privileges
net session >nul 2>&1
if %errorLevel% == 0 (
    echo [OK] Running as Administrator
    set ADMIN_FLAG=-AddToSystemPath
) else (
    echo [!] Not running as Administrator
    echo.
    echo For best results, right-click this file and select "Run as administrator"
    echo Otherwise, FFmpeg will be added to User PATH only.
    echo.
    set ADMIN_FLAG=
)

echo.
set /p CONFIRM="Do you want to install FFmpeg? (Y/N): "
if /i not "%CONFIRM%"=="Y" (
    echo Installation cancelled.
    pause
    exit /b 1
)

echo.
echo Installing FFmpeg...
echo.

REM Run PowerShell script
powershell -ExecutionPolicy Bypass -File "%~dp0setup_ffmpeg.ps1" %ADMIN_FLAG%

set EXIT_CODE=%errorLevel%

echo.
if %EXIT_CODE% == 0 (
    echo.
    echo ========================================
    echo Installation completed successfully!
    echo ========================================
    echo.
    echo IMPORTANT: Restart your terminal/Command Prompt
    echo to use FFmpeg, or restart your computer.
) else (
    echo Installation failed. Exit code: %EXIT_CODE%
)

echo.
pause
exit /b %EXIT_CODE%
