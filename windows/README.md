# Windows Build Files

This directory contains Windows-specific build configuration and setup scripts for Swaloka Looping Tool.

## Files Overview

### Build Configuration

- **`CMakeLists.txt`** - CMake configuration for Windows build
- **`installer_script.iss`** - Inno Setup installer configuration
- **`runner/`** - Windows runner application source code

### FFmpeg Installation Scripts

- **`setup_ffmpeg.ps1`** - PowerShell script for automated FFmpeg installation
- **`setup_ffmpeg.bat`** - Batch wrapper for easy double-click installation
- **`FFMPEG_SETUP.md`** - Comprehensive FFmpeg setup guide for Windows users

## Using the FFmpeg Installer

### For End Users

The installer scripts are bundled with the Windows installer and can be used post-installation:

1. Navigate to installation folder (e.g., `C:\Program Files\Swaloka Looping Tool`)
2. Right-click `setup_ffmpeg.bat` → "Run as administrator"
3. Follow prompts

### For Developers

You can include these scripts in your development workflow:

#### Testing the PowerShell Script

```powershell
# Run from the windows directory
powershell -ExecutionPolicy Bypass -File setup_ffmpeg.ps1 -AddToSystemPath

# Custom installation path
powershell -ExecutionPolicy Bypass -File setup_ffmpeg.ps1 -InstallPath "D:\Tools\ffmpeg" -AddToSystemPath

# Silent installation (no progress output)
powershell -ExecutionPolicy Bypass -File setup_ffmpeg.ps1 -Silent -AddToSystemPath
```

#### PowerShell Script Parameters

- **`-InstallPath`** (string): Installation directory (default: `C:\ffmpeg`)
- **`-AddToSystemPath`** (switch): Add to System PATH instead of User PATH (requires admin)
- **`-Silent`** (switch): Suppress progress output

#### Testing the Batch Script

```batch
REM Double-click setup_ffmpeg.bat or run from command prompt
setup_ffmpeg.bat
```

## Building the Installer

### Prerequisites

1. Install [Inno Setup](https://jrsoftware.org/isinfo.php)
2. Build Flutter app:
   ```bash
   flutter build windows --release
   ```

### Optional: Bundle VC++ Redistributable

1. Download from: https://aka.ms/vs/17/release/vc_redist.x64.exe
2. Place in `windows/` directory
3. Installer will include it automatically

### Compile Installer

1. Open `installer_script.iss` in Inno Setup Compiler
2. Click "Compile" (or press Ctrl+F9)
3. Installer will be created in parent directory

### Installer Features

The installer includes:

- ✅ Swaloka application files
- ✅ Desktop shortcut (optional)
- ✅ VC++ Redistributable detection and installation
- ✅ FFmpeg installation option (checkbox during installation)
- ✅ FFmpeg setup scripts included for post-installation

## FFmpeg Installation During Setup

The installer includes an **optional** FFmpeg installation task:

1. **During installation**, user can check "Install FFmpeg" checkbox
2. If checked, installer runs `setup_ffmpeg.ps1` automatically
3. If FFmpeg already installed, installation is skipped
4. Scripts remain in installation folder for future use

### How It Works

1. Installer detects if FFmpeg is already in PATH
2. If not found and task is selected:
   - Runs PowerShell script with elevated privileges
   - Downloads FFmpeg from gyan.dev
   - Extracts to `C:\ffmpeg`
   - Adds to System PATH
3. Bundled scripts remain available in app folder

## Development Notes

### PATH Handling

The Flutter app (`FFmpegService`) automatically checks these paths on Windows:

```dart
final extraPaths = [
  r'C:\ffmpeg\bin',
  r'C:\Program Files\ffmpeg\bin',
  r'C:\Program Files (x86)\ffmpeg\bin',
];
```

This means even if PATH isn't set, the app will find FFmpeg in standard locations.

### Testing FFmpeg Integration

```powershell
# Install to standard location
setup_ffmpeg.ps1 -InstallPath "C:\ffmpeg"

# Run Flutter app in debug mode
flutter run -d windows

# App should detect FFmpeg automatically
```

### Updating FFmpeg Download URL

The PowerShell script downloads from:
```
https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip
```

This always points to the latest release. To use a specific version:

1. Visit https://www.gyan.dev/ffmpeg/builds/release-builds/
2. Copy URL for specific version
3. Update `$FFmpegDownloadUrl` in `setup_ffmpeg.ps1`

## Troubleshooting Build Issues

### Inno Setup Compilation Errors

**Error: Cannot find source file**

- Ensure Flutter build completed: Check `build/windows/x64/runner/Release/`
- Paths in `.iss` file are relative to the script location

**Error: Cannot find vc_redist.x64.exe**

- This file is optional (see `skipifsourcedoesntexist` flag)
- Download from Microsoft if you want to bundle it

### PowerShell Script Issues

**Error: Execution policy**

- Use `-ExecutionPolicy Bypass` flag
- Or set permanently: `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser`

**Error: Download failed**

- Check internet connection
- Verify gyan.dev is accessible
- Try manual download and update script with local path

## Contributing

When modifying Windows installer/setup scripts:

1. Test on clean Windows VM
2. Test with and without admin privileges
3. Test with FFmpeg already installed
4. Test without internet connection (should fail gracefully)
5. Update this README with any changes

## Resources

- [Inno Setup Documentation](https://jrsoftware.org/ishelp/)
- [Flutter Windows Desktop](https://docs.flutter.dev/platform-integration/windows/building)
- [FFmpeg Windows Builds](https://www.gyan.dev/ffmpeg/builds/)
- [PowerShell Documentation](https://docs.microsoft.com/powershell/)
