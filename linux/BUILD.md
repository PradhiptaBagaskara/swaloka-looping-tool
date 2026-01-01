# Building Linux Packages

This guide explains how to build Linux packages for Swaloka Looping Tool.

## Prerequisites

```bash
# Install build dependencies
sudo apt-get update
sudo apt-get install -y \
  clang \
  cmake \
  ninja-build \
  pkg-config \
  libgtk-3-dev \
  libfuse2 \
  wget
```

## Build Methods

### Option 1: AppImage (Single File - Recommended)

**What is AppImage?**
- Single executable file (like `.exe` on Windows)
- Runs on any Linux distribution
- No installation required
- Users just need to `chmod +x` and run

**Build AppImage:**

```bash
# Using the script
./scripts/build_appimage.sh

# Or manually specify version
./scripts/build_appimage.sh 3.5.2
```

**Output:** `build/appimage/Swaloka-Looping-Tool-X.X.X-x86_64.AppImage`

**Test it:**
```bash
chmod +x build/appimage/Swaloka-Looping-Tool-*.AppImage
./build/appimage/Swaloka-Looping-Tool-*.AppImage
```

### Option 2: tar.gz Archive

**What is tar.gz?**
- Compressed archive with all files
- Requires extraction before use
- More traditional Linux distribution method

**Build tar.gz:**

```bash
# Build Flutter app
flutter build linux --release

# Create archive
cd build/linux/x64/release/bundle
tar -czf Swaloka-Looping-Tool-$(grep 'version:' ../../../../../pubspec.yaml | awk '{print $2}' | cut -d'+' -f1)-linux-x64.tar.gz *
```

**Test it:**
```bash
# Extract
tar -xzf Swaloka-Looping-Tool-*-linux-x64.tar.gz

# Run
chmod +x swaloka_looping_tool
./swaloka_looping_tool
```

## Distribution Comparison

| Method | Single File | Universal | Desktop Integration | Size |
|--------|-------------|-----------|-------------------|------|
| **AppImage** | ✅ Yes | ✅ Works everywhere | ⚠️ Manual | ~50-80MB |
| **tar.gz** | ❌ No (folder) | ✅ Works everywhere | ⚠️ Manual | ~40-60MB |
| **Snap** | ✅ Yes | ⚠️ Ubuntu-focused | ✅ Automatic | ~50-80MB |
| **Flatpak** | ✅ Yes | ✅ Most distros | ✅ Automatic | ~50-100MB |

**Recommendation:** Use **AppImage** for:
- Easy distribution
- No installation required
- Works on any Linux distro
- Similar user experience to Windows/macOS

## GitHub Actions

When you push a version tag, GitHub Actions will automatically:

1. Build Linux AppImage (single file)
2. Build Linux tar.gz archive (alternative)
3. Upload both to GitHub Releases

**Example release files:**
```
Swaloka-Looping-Tool-3.5.2-macos.zip
Swaloka-Looping-Tool-3.5.2-windows-installer.exe
Swaloka-Looping-Tool-3.5.2-x86_64.AppImage          ← Single file!
Swaloka-Looping-Tool-3.5.2-linux-x64.tar.gz         ← Alternative
```

## User Instructions

**AppImage (Easiest):**
```bash
# 1. Download the .AppImage file
# 2. Make it executable
chmod +x Swaloka-Looping-Tool-*.AppImage

# 3. Run it!
./Swaloka-Looping-Tool-*.AppImage
```

**tar.gz:**
```bash
# 1. Download and extract
tar -xzf Swaloka-Looping-Tool-*-linux-x64.tar.gz

# 2. Run
cd bundle
chmod +x swaloka_looping_tool
./swaloka_looping_tool
```

## Troubleshooting

### AppImage won't run

**Error:** "cannot mount"
```bash
# Install FUSE
sudo apt install libfuse2
```

**Error:** Permission denied
```bash
chmod +x file.AppImage
```

### Missing GTK libraries

```bash
# Ubuntu/Debian
sudo apt install libgtk-3-0

# Fedora
sudo dnf install gtk3

# Arch Linux
sudo pacman -S gtk3
```

### Check what's missing

```bash
# For AppImage - extract and check
./file.AppImage --appimage-extract
ldd squashfs-root/usr/bin/swaloka_looping_tool

# For tar.gz bundle
ldd swaloka_looping_tool
```

## Future Considerations

### Snap Package
- Better desktop integration
- Automatic updates
- Requires Snapcraft account and store approval
- More restrictive sandbox

### Flatpak Package
- Best desktop integration
- Automatic updates via Flathub
- Requires Flatpak manifest
- More work to set up

**Current approach (AppImage)** is the best balance of:
- ✅ Easy distribution
- ✅ Universal compatibility
- ✅ No approval/accounts needed
- ✅ Similar to macOS/Windows experience
