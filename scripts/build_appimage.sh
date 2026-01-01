#!/bin/bash
set -e

# Build AppImage for Linux
# Usage: ./scripts/build_appimage.sh [version]

VERSION=${1:-$(grep 'version:' pubspec.yaml | awk '{print $2}' | cut -d'+' -f1)}
APP_NAME="Swaloka-Looping-Tool"
BUILD_DIR="build/linux/x64/release/bundle"
APPDIR="AppDir"

echo "🔨 Building AppImage for $APP_NAME v$VERSION..."

# Step 1: Build Flutter Linux app
echo "📦 Building Flutter Linux app..."
flutter build linux --release

# Step 2: Create AppDir structure
echo "📁 Creating AppDir structure..."
rm -rf "$APPDIR"
mkdir -p "$APPDIR/usr/bin"
mkdir -p "$APPDIR/usr/lib"
mkdir -p "$APPDIR/usr/share/applications"
mkdir -p "$APPDIR/usr/share/icons/hicolor/256x256/apps"

# Step 3: Copy application files
echo "📋 Copying application files..."
cp -r "$BUILD_DIR"/* "$APPDIR/usr/bin/"

# Copy libraries
if [ -d "$BUILD_DIR/lib" ]; then
    cp -r "$BUILD_DIR/lib"/* "$APPDIR/usr/lib/" 2>/dev/null || true
fi

# Step 4: Create desktop entry
echo "🖥️  Creating desktop entry..."
cat > "$APPDIR/swaloka_looping_tool.desktop" <<EOF
[Desktop Entry]
Name=Swaloka Looping Tool
Exec=swaloka_looping_tool
Icon=swaloka_looping_tool
Type=Application
Categories=AudioVideo;Video;
Comment=Automate video production with looping backgrounds
Terminal=false
EOF

# Copy to standard location
cp "$APPDIR/swaloka_looping_tool.desktop" "$APPDIR/usr/share/applications/"

# Step 5: Copy icon
echo "🎨 Copying icon..."
if [ -f "assets/logo.png" ]; then
    cp "assets/logo.png" "$APPDIR/swaloka_looping_tool.png"
    cp "assets/logo.png" "$APPDIR/usr/share/icons/hicolor/256x256/apps/swaloka_looping_tool.png"
else
    echo "⚠️  Warning: assets/logo.png not found, using placeholder"
    # Create a simple placeholder
    convert -size 256x256 xc:blue "$APPDIR/swaloka_looping_tool.png" 2>/dev/null || touch "$APPDIR/swaloka_looping_tool.png"
fi

# Step 6: Create AppRun script
echo "📝 Creating AppRun script..."
cat > "$APPDIR/AppRun" <<'EOF'
#!/bin/bash
SELF=$(readlink -f "$0")
HERE=${SELF%/*}
export PATH="${HERE}/usr/bin/:${HERE}/usr/sbin/:${HERE}/usr/games/:${HERE}/bin/:${HERE}/sbin/${PATH:+:$PATH}"
export LD_LIBRARY_PATH="${HERE}/usr/lib/:${HERE}/usr/lib/x86_64-linux-gnu/:${HERE}/lib/:${HERE}/lib/x86_64-linux-gnu/:${HERE}/lib64/${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export XDG_DATA_DIRS="${HERE}/usr/share/${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"
export GDK_PIXBUF_MODULEDIR="${HERE}/usr/lib/x86_64-linux-gnu/gdk-pixbuf-2.0/2.10.0/loaders"
export GDK_PIXBUF_MODULE_FILE="${HERE}/usr/lib/x86_64-linux-gnu/gdk-pixbuf-2.0/2.10.0/loaders.cache"
EXEC="${HERE}/usr/bin/swaloka_looping_tool"
exec "${EXEC}" "$@"
EOF
chmod +x "$APPDIR/AppRun"

# Step 7: Download appimagetool if not exists
echo "🔧 Checking for appimagetool..."
if [ ! -f "appimagetool-x86_64.AppImage" ]; then
    echo "📥 Downloading appimagetool..."
    wget -q "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage"
    chmod +x appimagetool-x86_64.AppImage
fi

# Step 8: Build AppImage
echo "🎁 Building AppImage..."
ARCH=x86_64 ./appimagetool-x86_64.AppImage "$APPDIR" "$APP_NAME-$VERSION-x86_64.AppImage"

# Step 9: Make it executable
chmod +x "$APP_NAME-$VERSION-x86_64.AppImage"

# Step 10: Move to build directory
mkdir -p build/appimage
mv "$APP_NAME-$VERSION-x86_64.AppImage" "build/appimage/"

echo "✅ AppImage created successfully!"
echo "📦 Location: build/appimage/$APP_NAME-$VERSION-x86_64.AppImage"
echo ""
echo "To test it:"
echo "  ./build/appimage/$APP_NAME-$VERSION-x86_64.AppImage"
echo ""
echo "To distribute:"
echo "  1. Upload the .AppImage file"
echo "  2. Users just need to: chmod +x file.AppImage && ./file.AppImage"
