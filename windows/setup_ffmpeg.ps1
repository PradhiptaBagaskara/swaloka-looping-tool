# PowerShell script to download and install FFmpeg on Windows
# This script downloads FFmpeg, extracts it, and adds it to the system PATH

param(
    [string]$InstallPath = "C:\ffmpeg",
    [switch]$AddToSystemPath = $false,
    [switch]$Silent = $false
)

$ErrorActionPreference = "Stop"

# FFmpeg download URL (using gyan.dev builds - most popular Windows FFmpeg provider)
$FFmpegDownloadUrl = "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip"
$TempZipPath = "$env:TEMP\ffmpeg.zip"

function Write-Log {
    param([string]$Message, [string]$Type = "Info")

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Type) {
        "Success" { "Green" }
        "Warning" { "Yellow" }
        "Error" { "Red" }
        default { "White" }
    }

    if (-not $Silent) {
        Write-Host "[$timestamp] $Message" -ForegroundColor $color
    }
}

function Test-AdminPrivileges {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Download-FFmpeg {
    Write-Log "Downloading FFmpeg from $FFmpegDownloadUrl..."
    Write-Log "This may take 2-3 minutes depending on your internet speed..." -Type "Warning"

    try {
        # Use .NET WebClient for better progress reporting
        $webClient = New-Object System.Net.WebClient

        if (-not $Silent) {
            # Add progress callback
            $webClient.DownloadProgressChanged += {
                param($sender, $e)
                $progressBar = "=" * [Math]::Floor($e.ProgressPercentage / 2)
                $spaces = " " * (50 - [Math]::Floor($e.ProgressPercentage / 2))
                Write-Host "`r[$progressBar$spaces] $($e.ProgressPercentage)% " -NoNewline -ForegroundColor Cyan
            }
        }

        $webClient.DownloadFile($FFmpegDownloadUrl, $TempZipPath)
        $webClient.Dispose()

        if (-not $Silent) {
            Write-Host "" # New line after progress bar
        }
        Write-Log "Download completed successfully." -Type "Success"
        return $true
    }
    catch {
        Write-Log "Failed to download FFmpeg: $_" -Type "Error"
        return $false
    }
}

function Extract-FFmpeg {
    Write-Log "Extracting FFmpeg to $InstallPath..."
    Write-Log "Please wait, this may take a minute..." -Type "Warning"

    try {
        # Create installation directory if it doesn't exist
        if (-not (Test-Path $InstallPath)) {
            New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
        }

        # Extract ZIP file
        Add-Type -AssemblyName System.IO.Compression.FileSystem

        # Open the ZIP archive
        $zip = [System.IO.Compression.ZipFile]::OpenRead($TempZipPath)

        # Find the bin folder in the archive (it's usually in a subfolder like ffmpeg-x.x.x-essentials_build/bin)
        $binEntries = $zip.Entries | Where-Object { $_.FullName -like "*/bin/*" -and $_.Name -ne "" }

        if ($binEntries.Count -eq 0) {
            throw "Could not find bin folder in FFmpeg archive"
        }

        # Extract bin folder contents
        $binPath = Join-Path $InstallPath "bin"
        if (-not (Test-Path $binPath)) {
            New-Item -ItemType Directory -Path $binPath -Force | Out-Null
        }

        $total = $binEntries.Count
        $current = 0

        foreach ($entry in $binEntries) {
            $current++
            $destinationPath = Join-Path $binPath $entry.Name

            if (-not $Silent) {
                $percent = [Math]::Floor(($current / $total) * 100)
                $progressBar = "=" * [Math]::Floor($percent / 2)
                $spaces = " " * (50 - [Math]::Floor($percent / 2))
                Write-Host "`rExtracting: [$progressBar$spaces] $percent% ($current/$total files) " -NoNewline -ForegroundColor Yellow
            }

            [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $destinationPath, $true)
        }

        $zip.Dispose()

        if (-not $Silent) {
            Write-Host "" # New line after progress bar
        }

        # Verify extraction
        $ffmpegExe = Join-Path $binPath "ffmpeg.exe"
        if (Test-Path $ffmpegExe) {
            Write-Log "FFmpeg extracted successfully to: $binPath" -Type "Success"
            return $binPath
        }
        else {
            throw "FFmpeg.exe not found after extraction"
        }
    }
    catch {
        Write-Log "Failed to extract FFmpeg: $_" -Type "Error"
        return $null
    }
    finally {
        # Clean up downloaded ZIP
        if (Test-Path $TempZipPath) {
            Remove-Item $TempZipPath -Force -ErrorAction SilentlyContinue
        }
    }
}

function Add-ToPath {
    param([string]$PathToAdd)

    $isAdmin = Test-AdminPrivileges

    if ($AddToSystemPath -and -not $isAdmin) {
        Write-Log "Warning: Cannot add to System PATH without administrator privileges." -Type "Warning"
        Write-Log "Adding to User PATH instead..." -Type "Warning"
    }

    $scope = if ($AddToSystemPath -and $isAdmin) { "Machine" } else { "User" }
    $pathVar = [Environment]::GetEnvironmentVariable("Path", $scope)

    # Check if path already exists
    $paths = $pathVar -split ";" | Where-Object { $_ -ne "" }
    if ($paths -contains $PathToAdd) {
        Write-Log "Path already exists in $scope PATH: $PathToAdd" -Type "Warning"
        return $true
    }

    try {
        Write-Log "Adding to $scope PATH: $PathToAdd"
        $newPath = "$pathVar;$PathToAdd"
        [Environment]::SetEnvironmentVariable("Path", $newPath, $scope)

        # Also update current session
        $env:Path = "$env:Path;$PathToAdd"

        Write-Log "Successfully added to $scope PATH" -Type "Success"
        return $true
    }
    catch {
        Write-Log "Failed to add to PATH: $_" -Type "Error"
        return $false
    }
}

function Test-FFmpegInstallation {
    param([string]$BinPath)

    Write-Log "Verifying FFmpeg installation..."

    try {
        # Test if ffmpeg.exe works
        $ffmpegExe = Join-Path $BinPath "ffmpeg.exe"
        $output = & $ffmpegExe -version 2>&1 | Out-String

        if ($output -match "ffmpeg version (\S+)") {
            $version = $matches[1]
            Write-Log "FFmpeg $version is working correctly!" -Type "Success"
            return $true
        }
        else {
            throw "Could not determine FFmpeg version"
        }
    }
    catch {
        Write-Log "FFmpeg verification failed: $_" -Type "Error"
        return $false
    }
}

# Main script execution
function Main {
    Write-Log "=== FFmpeg Installation Script for Windows ===" -Type "Success"
    Write-Log ""

    # Check if FFmpeg is already installed
    try {
        $existingVersion = & ffmpeg -version 2>&1 | Select-String "ffmpeg version" | Select-Object -First 1
        if ($existingVersion) {
            Write-Log "FFmpeg is already installed and available in PATH:" -Type "Success"
            Write-Log "$existingVersion" -Type "Success"
            Write-Log ""
            Write-Log "If you want to reinstall, please remove the existing installation first."
            return 0
        }
    }
    catch {
        # FFmpeg not found in PATH, continue with installation
    }

    Write-Log "Installation directory: $InstallPath"
    Write-Log "Add to PATH: $(if ($AddToSystemPath) { 'System PATH' } else { 'User PATH' })"
    Write-Log ""

    # Check for admin privileges if needed
    if ($AddToSystemPath) {
        $isAdmin = Test-AdminPrivileges
        if (-not $isAdmin) {
            Write-Log "Warning: System PATH modification requested but not running as Administrator." -Type "Warning"
            Write-Log "Will add to User PATH instead." -Type "Warning"
            Write-Log ""
        }
    }

    # Download FFmpeg
    if (-not (Download-FFmpeg)) {
        Write-Log "Installation failed during download." -Type "Error"
        return 1
    }

    # Extract FFmpeg
    $binPath = Extract-FFmpeg
    if (-not $binPath) {
        Write-Log "Installation failed during extraction." -Type "Error"
        return 1
    }

    # Add to PATH
    if (-not (Add-ToPath -PathToAdd $binPath)) {
        Write-Log "Installation succeeded but PATH update failed." -Type "Warning"
        Write-Log "Please manually add '$binPath' to your PATH environment variable." -Type "Warning"
        return 2
    }

    # Verify installation
    if (-not (Test-FFmpegInstallation -BinPath $binPath)) {
        Write-Log "Installation completed but verification failed." -Type "Warning"
        return 2
    }

    Write-Log ""
    Write-Log "=== Installation Complete ===" -Type "Success"
    Write-Log "FFmpeg has been installed to: $InstallPath" -Type "Success"
    Write-Log ""
    Write-Log "IMPORTANT: You may need to restart your terminal or computer" -Type "Warning"
    Write-Log "for the PATH changes to take effect." -Type "Warning"
    Write-Log ""
    Write-Log "To verify the installation after restart, run: ffmpeg -version" -Type "Success"

    return 0
}

# Run main function and exit with its return code
exit (Main)
