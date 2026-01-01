# Building Windows Packages

This guide explains how to build Windows packages for Swaloka Looping Tool.

## Prerequisites

```powershell
# Install required tools
choco install 7zip -y
choco install innosetup -y

# Or manually:
# - 7-Zip: https://www.7-zip.org/
# - Inno Setup: https://jrsoftware.org/isinfo.php
```

## Build Methods

### Option 1: Portable Single-File EXE (Recommended) ⭐

**What is Portable Single-File EXE?**
- Single `.exe` file (like AppImage on Linux)
- Self-extracting archive that auto-runs
- No installation required
- Run from anywhere (USB drive, network, etc.)
- Perfect for users who want zero-setup experience

**Build Portable EXE:**

```powershell
# Using the script
.\scripts\build_windows_portable.ps1

# Or manually specify version
.\scripts\build_windows_portable.ps1 -Version "3.5.2"
```

**Output:** `build/portable/Swaloka-Looping-Tool-X.X.X-windows-portable.exe`

**Test it:**
```powershell
# Just run it - will extract and launch automatically
.\build\portable\Swaloka-Looping-Tool-*.exe
```

**How it works:**
1. User double-clicks the `.exe`
2. 7-Zip SFX extracts files to temp directory
3. App launches automatically
4. Files cleaned up on exit (or cached for faster next launch)

### Option 2: Traditional Installer

**What is Installer?**
- Standard Windows setup wizard
- Installs to Program Files
- Creates Start Menu shortcuts
- Includes VC++ Redistributable
- Uninstall via Control Panel

**Build Installer:**

```powershell
# Build Flutter app
flutter build windows --release

# Build installer with Inno Setup
iscc windows\installer_script.iss
```

**Output:** `Swaloka-Looping-Tool-X.X.X-windows-installer.exe`

**Test it:**
```powershell
# Run installer
.\Swaloka-Looping-Tool-*-windows-installer.exe
```

## Distribution Comparison

| Method | Single File | Installation | Admin Rights | Portability | Updates |
|--------|-------------|--------------|--------------|-------------|---------|
| **Portable EXE** | ✅ Yes | ❌ No | ❌ Not needed | ✅ Excellent | Manual |
| **Installer** | ✅ Yes | ✅ Yes | ⚠️ Recommended | ❌ Fixed location | Manual |

**Recommendation:** Provide **both** options:
- **Portable EXE** for tech-savvy users and portable use cases
- **Installer** for traditional Windows users who prefer standard apps

## GitHub Actions

When you push a version tag, GitHub Actions will automatically:

1. Build Windows portable single-file EXE
2. Build Windows traditional installer
3. Upload both to GitHub Releases

**Example release files:**
```
Swaloka-Looping-Tool-3.5.2-windows-portable.exe      ← ⭐ Single file, no install
Swaloka-Looping-Tool-3.5.2-windows-installer.exe     ← Traditional installer
Swaloka-Looping-Tool-3.5.2-macos.zip
Swaloka-Looping-Tool-3.5.2-x86_64.AppImage
Swaloka-Looping-Tool-3.5.2-linux-x64.tar.gz
```

## Technical Details

### Portable EXE Structure

The portable EXE is a **7-Zip Self-Extracting Archive (SFX)**:

```
Portable.exe = 7zSD.sfx + config.txt + archive.7z
```

**Components:**
1. **7zSD.sfx** - Self-extracting executable stub (~50KB)
2. **config.txt** - SFX configuration (title, auto-run command)
3. **archive.7z** - Compressed app files (~40-60MB)

**SFX Config Example:**
```
;!@Install@!UTF-8!
Title="Swaloka Looping Tool"
BeginPrompt="Swaloka Looping Tool will extract and run."
RunProgram="swaloka_looping_tool.exe"
;!@InstallEnd@!
```

### Size Comparison

| Package Type | Compressed | Extracted | Notes |
|--------------|-----------|-----------|-------|
| Portable EXE | ~45-55MB | ~100-120MB | Self-extracting |
| Installer | ~50-60MB | ~100-120MB | Includes VC++ redist |
| macOS ZIP | ~40-50MB | ~100-110MB | No compression tricks |
| Linux AppImage | ~50-80MB | N/A | Self-contained |

## User Instructions

### Portable EXE (Easiest)

```powershell
# 1. Download the portable .exe file
# 2. Double-click to run - that's it!
.\Swaloka-Looping-Tool-*.exe
```

**First run:** Takes 5-10 seconds to extract files. Subsequent runs are faster.

### Installer (Traditional)

```powershell
# 1. Download the installer
# 2. Run installer
.\Swaloka-Looping-Tool-*-windows-installer.exe

# 3. Follow installation wizard
# 4. Launch from Start Menu
```

## Troubleshooting

### "Windows protected your PC" warning

**Solution:**
1. Click **"More info"**
2. Click **"Run anyway"**
3. This is normal for unsigned apps (code signing costs $$$)

### Portable EXE extraction fails

**Solutions:**
1. Run as administrator (right-click → Run as administrator)
2. Check available disk space (needs ~200MB in TEMP)
3. Disable antivirus temporarily
4. Use the installer version instead

### Antivirus blocks portable EXE

**Why:** Some antivirus software flags self-extracting archives as suspicious.

**Solutions:**
1. Add exception for the file
2. Submit to antivirus for whitelisting
3. Use the installer version (less likely to trigger)
4. Consider code signing (expensive but solves this)

### VC++ Redistributable missing

**Error:** "VCRUNTIME140.dll not found"

**Solution:**
```powershell
# Download and install VC++ Redistributable
# https://aka.ms/vs/17/release/vc_redist.x64.exe

# Or use Chocolatey
choco install vcredist-all -y
```

## Code Signing (Optional)

For production releases, consider **code signing** to avoid security warnings:

**Cost:** $100-400/year for certificate

**Benefits:**
- No "Windows protected your PC" warning
- Builds user trust
- Antivirus software less likely to flag

**Providers:**
- DigiCert
- Sectigo
- SSL.com

**Signing command:**
```powershell
signtool sign /f certificate.pfx /p password /t http://timestamp.digicert.com portable.exe
```

## Future Considerations

### Microsoft Store
- ✅ Better distribution
- ✅ Automatic updates
- ✅ Built-in trust
- ❌ $19 one-time fee
- ❌ Approval process
- ❌ Packaging requirements

### WinGet Package
- ✅ Easy installation via `winget install swaloka-looping-tool`
- ✅ Automatic updates
- ✅ Free
- ⚠️ Requires manifest submission

**Current approach (Portable EXE + Installer)** is the best balance of:
- ✅ Zero cost
- ✅ Full control
- ✅ Easy distribution
- ✅ User choice (portable vs installed)
- ⚠️ Manual security warnings (fixable with code signing)
