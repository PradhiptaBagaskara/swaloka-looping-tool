# Build Single-File Portable Windows Executable
# Creates a self-extracting EXE that runs without installation

param(
    [string]$Version = ""
)

Write-Host "🔨 Building Single-File Portable Windows Executable..." -ForegroundColor Cyan

# Get version from pubspec.yaml if not provided
if ([string]::IsNullOrEmpty($Version)) {
    $Version = (Get-Content "pubspec.yaml" | Select-String "version:" | ForEach-Object { $_.ToString().Split(' ')[1].Split('+')[0] })
}

Write-Host "📦 Version: $Version" -ForegroundColor Green

$APP_NAME = "Swaloka-Looping-Tool"
$BUILD_DIR = "build/windows/x64/runner/Release"
$TEMP_DIR = "build/portable_temp"
$OUTPUT_NAME = "$APP_NAME-$Version-windows-portable.exe"

# Step 1: Build Flutter Windows app
Write-Host "`n📦 Building Flutter Windows app..." -ForegroundColor Cyan
flutter build windows --release

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Flutter build failed!" -ForegroundColor Red
    exit 1
}

# Step 2: Create temporary directory and copy files
Write-Host "`n📁 Preparing files..." -ForegroundColor Cyan
if (Test-Path $TEMP_DIR) {
    Remove-Item -Path $TEMP_DIR -Recurse -Force
}
New-Item -ItemType Directory -Path $TEMP_DIR -Force | Out-Null

# Copy all application files
Copy-Item -Path "$BUILD_DIR/*" -Destination $TEMP_DIR -Recurse -Force

# Create README
@"
Swaloka Looping Tool - Portable Single-File Version
====================================================

FIRST RUN:
----------
1. Make sure FFmpeg is installed:
   - Using Chocolatey: choco install ffmpeg
   - Using Scoop: scoop install ffmpeg
   - Or download from: https://www.gyan.dev/ffmpeg/builds/

2. This executable will extract files to a temporary location and run.
   All your projects and settings are saved separately.

FEATURES:
---------
- Single executable file - easy to share and distribute
- Run from anywhere (USB drive, network drive, etc.)
- No installation or admin rights required
- Automatic cleanup on exit

REQUIREMENTS:
-------------
- Windows 10/11 (64-bit)
- FFmpeg (install separately)
- VC++ Redistributable (usually already installed)

For more info: https://github.com/pradhiptabagaskara/swaloka-looping-tool
"@ | Out-File -FilePath "$TEMP_DIR/README.txt" -Encoding UTF8

# Step 3: Download 7-Zip SFX module if not exists
Write-Host "`n🔧 Checking for 7-Zip SFX module..." -ForegroundColor Cyan
$SFX_MODULE = "7zSD.sfx"

if (-not (Test-Path $SFX_MODULE)) {
    Write-Host "📥 Downloading 7-Zip SFX module..." -ForegroundColor Yellow

    # Download 7-Zip Extra (contains SFX modules)
    $7Z_EXTRA_URL = "https://www.7-zip.org/a/7z2408-extra.7z"
    $7Z_EXTRA_FILE = "7z-extra.7z"

    try {
        Invoke-WebRequest -Uri $7Z_EXTRA_URL -OutFile $7Z_EXTRA_FILE

        # Extract SFX module using 7z (if available) or expand
        if (Get-Command 7z -ErrorAction SilentlyContinue) {
            & 7z e $7Z_EXTRA_FILE "7zSD.sfx" -y
        } else {
            Write-Host "⚠️  7-Zip not found. Trying alternative method..." -ForegroundColor Yellow
            # Try using Expand-Archive or other methods
            # For now, we'll use a pre-downloaded SFX
            Write-Host "❌ Please install 7-Zip first: https://www.7-zip.org/" -ForegroundColor Red
            exit 1
        }

        Remove-Item $7Z_EXTRA_FILE -Force
    } catch {
        Write-Host "❌ Failed to download SFX module: $_" -ForegroundColor Red
        exit 1
    }
}

# Step 4: Create 7z archive
Write-Host "`n📦 Creating archive..." -ForegroundColor Cyan
$ARCHIVE_FILE = "$TEMP_DIR.7z"

if (Test-Path $ARCHIVE_FILE) {
    Remove-Item $ARCHIVE_FILE -Force
}

# Check if 7z is available
if (-not (Get-Command 7z -ErrorAction SilentlyContinue)) {
    Write-Host "❌ 7-Zip command line tool not found!" -ForegroundColor Red
    Write-Host "   Please install 7-Zip: https://www.7-zip.org/" -ForegroundColor Yellow
    Write-Host "   Or use Chocolatey: choco install 7zip" -ForegroundColor Yellow
    exit 1
}

# Create archive with maximum compression
& 7z a -t7z -mx=9 $ARCHIVE_FILE "$TEMP_DIR/*"

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to create archive!" -ForegroundColor Red
    exit 1
}

# Step 5: Create SFX configuration
Write-Host "`n📝 Creating SFX configuration..." -ForegroundColor Cyan
$CONFIG_FILE = "windows/sfx_config.txt"

# Step 6: Combine SFX module + config + archive = Single EXE
Write-Host "`n🎁 Building single-file executable..." -ForegroundColor Cyan

# Create output directory
New-Item -ItemType Directory -Path "build/portable" -Force | Out-Null

# Combine: SFX module + config + archive = portable EXE
$OUTPUT_PATH = "build/portable/$OUTPUT_NAME"

# Use copy /b on Windows to combine binary files
cmd /c "copy /b `"$SFX_MODULE`" + `"$CONFIG_FILE`" + `"$ARCHIVE_FILE`" `"$OUTPUT_PATH`""

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to create portable executable!" -ForegroundColor Red
    exit 1
}

# Step 7: Cleanup
Write-Host "`n🧹 Cleaning up..." -ForegroundColor Cyan
Remove-Item -Path $TEMP_DIR -Recurse -Force
Remove-Item -Path $ARCHIVE_FILE -Force

# Get file size
$FileSize = (Get-Item $OUTPUT_PATH).Length / 1MB
$FileSizeStr = "{0:N2} MB" -f $FileSize

Write-Host "`n✅ Single-file portable executable created successfully!" -ForegroundColor Green
Write-Host "📦 Location: $OUTPUT_PATH" -ForegroundColor Cyan
Write-Host "📊 Size: $FileSizeStr" -ForegroundColor Cyan
Write-Host ""
Write-Host "To test it:" -ForegroundColor Yellow
Write-Host "  ./$OUTPUT_PATH" -ForegroundColor White
Write-Host ""
Write-Host "To distribute:" -ForegroundColor Yellow
Write-Host "  1. Upload the .exe file" -ForegroundColor White
Write-Host "  2. Users just double-click to run - no installation needed!" -ForegroundColor White
Write-Host ""
Write-Host "Note: First run will extract files and may take a few seconds." -ForegroundColor Gray
