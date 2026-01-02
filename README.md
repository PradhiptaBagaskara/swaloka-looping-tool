# 🎬 Swaloka Looping Tool - Free Video Automation Software for Content Creators

> **Automate Your Video Production in Minutes, Not Hours**

[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20macOS%20%7C%20Linux-blue)]()
[![Built with Flutter](https://img.shields.io/badge/Built%20with-Flutter-02569B?logo=flutter)]()
[![FFmpeg](https://img.shields.io/badge/Powered%20by-FFmpeg-green)]()
[![License](https://img.shields.io/badge/license-MIT-green)]()

**Swaloka Looping Tool** is a professional desktop video automation application that helps content creators, podcasters, and video producers automatically merge background videos with multiple audio tracks. Stop wasting hours on manual video editing—automate your entire workflow.

**Perfect for:** Music Channels • Podcasts • Meditation Videos • Audiobooks • Educational Content • Gaming Commentary

---

## 🎯 What Problem Does This Solve?

**Before Swaloka:**
- ⏰ Spend hours manually syncing audio to video
- 😰 Repeat the same editing steps for every video
- 🔄 Manually loop background videos in timeline
- 📦 Process one file at a time

**After Swaloka:**
- ⚡ Batch process unlimited audio files automatically
- 🎬 Auto-loop background videos to match audio length
- 🚀 Generate videos in minutes, not hours
- ✨ Focus on creating content, not editing

---

## ✨ Key Features

### 🎥 **Automatic Video Looping**
Automatically repeats your background video to match the total length of all audio tracks—no manual timeline editing required.

### 🔄 **Batch Audio Processing**
Drop multiple audio files and process them all at once. Perfect for music playlists, podcast seasons, or meditation series.

### 🎨 **Drag & Drop Interface**
Simple, intuitive interface designed for creators, not video editors. No complicated menus or confusing settings.

### ⚡ **Hardware Accelerated**
Leverages FFmpeg and your computer's GPU for lightning-fast video rendering and export.

### 📁 **Project Management**
Save your projects and come back anytime. All your exports, logs, and settings are organized in one place.

### 📊 **Platform-Ready Metadata**
Add title, author, and description directly in the app—embedded in the video file for easy uploading.

### 🔀 **Smart Audio Sequencing**
First loop uses your exact audio order. Additional loops automatically randomize for variety (perfect for long-form content).

### 📊 **Real-Time Progress Tracking**
See exactly what's happening with detailed, hierarchical logs and progress indicators.

---

## 🎯 Perfect For These Content Types

### 🎵 **Music Channel Creators**
Create hour-long music compilations, lofi hip hop streams, or study music videos with a static or animated background.

**Use Case:** Upload 10 songs with one background → Get one ready-to-upload video

### 🎙️ **Podcasters & Audio Creators**
Convert your audio podcasts to video format for video platforms. Add your branded background or visualizer.

**Use Case:** Batch process entire podcast season → Platform-ready videos in minutes

### 🧘 **Meditation & Wellness Content**
Combine calming nature backgrounds with guided meditation, sleep stories, or ambient soundscapes.

**Use Case:** 20 meditation tracks + calming background → Professional meditation video series

### 📚 **Audiobook & Education**
Add visual appeal to audiobooks, lectures, or educational content with relevant background imagery.

**Use Case:** Lecture audio + presentation slides → Engaging educational video

### 🎮 **Gaming Content**
Add commentary or voiceover to gameplay footage efficiently without complex video editing software.

**Use Case:** Gaming footage + multiple commentary tracks → Gaming highlights video

---

## 🚀 Quick Start Guide

### Step 1: Create a Project
Click **"New Project"** and choose a folder. This is where your videos will be saved.

### Step 2: Add Background Video
Drag and drop your background video (MP4, MOV, AVI, MKV supported).

**Ideas:**
- Nature scenes (mountains, ocean, forest)
- Animated visualizers
- Branded graphics
- Slideshow presentations
- Gameplay footage

### Step 3: Add Audio Files
Drag and drop all your audio files (MP3, WAV, M4A, AAC, OGG, FLAC supported).

**The app will:**
- Play them in order (you can reorder)
- Extract audio from video files automatically
- Handle different formats seamlessly

### Step 4: Configure Settings
- **Title:** Your video title (embedded in file metadata)
- **Author:** Your channel or creator name
- **Description:** Optional notes or description
- **Loop Count:** How many times to repeat your audio sequence

### Step 5: Generate Video
Click **"Generate Video"** and let the automation work its magic!

**You'll see:**
- Real-time progress updates
- Detailed processing logs
- FFmpeg command execution
- Completion notifications

### Step 6: Upload & Share
Find your finished video in: `YourProject/outputs/`

Ready to upload to your favorite video platform!

---

## 💻 System Requirements

### ✅ **Supported Platforms**
- **Windows 10/11** (64-bit)
- **macOS 11+** (Intel & Apple Silicon/M1/M2/M3/M4)
- **Linux** (Most distributions)

### 📋 **Requirements**
- **RAM:** 4GB minimum (8GB recommended)
- **Storage:** A few GB for projects and temp files
- **FFmpeg:** Required (app will guide installation)

### ⚡ **Recommended for Best Performance**
- SSD storage for faster rendering
- 8GB+ RAM for large video files
- ~~GPU acceleration (automatically detected)~~ *(Coming soon)*

---

## 🔧 Installation & Setup

### 1️⃣ **Download the App**
Get the latest release for your platform from the [Releases page](https://github.com/pradhiptabagaskara/swaloka-looping-tool/releases)

**Platform-Specific Downloads:**
- **Windows:** `Swaloka-Looping-Tool-X.X.X-windows-installer.exe`
- **macOS:** `Swaloka-Looping-Tool-X.X.X-macos.zip`
- **Linux:** `Swaloka-Looping-Tool-X.X.X-linux-x64.tar.gz`

### 2️⃣ **Install FFmpeg** (Required)

#### **macOS:**
```bash
# Using Homebrew (recommended)
brew install ffmpeg

# Or download from https://evermeet.cx/ffmpeg/
```

#### **Windows:**
```bash
# Using Chocolatey
choco install ffmpeg

# Using Scoop
scoop install ffmpeg

# Or download from https://www.gyan.dev/ffmpeg/builds/
```

#### **Linux:**
```bash
# Ubuntu/Debian
sudo apt update && sudo apt install ffmpeg

# Fedora
sudo dnf install ffmpeg

# Arch Linux
sudo pacman -S ffmpeg
```

**The app will detect if FFmpeg is missing and guide you through installation.**

### 3️⃣ **Extract and Run (Linux)**

**Extract the archive:**
```bash
tar -xzf Swaloka-Looping-Tool-X.X.X-linux-x64.tar.gz
cd bundle
```

**Make executable and run:**
```bash
chmod +x swaloka_looping_tool
./swaloka_looping_tool
```

**Optional: Create desktop entry (for app menu integration):**
```bash
# Create .desktop file
cat > ~/.local/share/applications/swaloka-looping-tool.desktop <<EOF
[Desktop Entry]
Name=Swaloka Looping Tool
Exec=/path/to/bundle/swaloka_looping_tool
Icon=/path/to/bundle/data/flutter_assets/assets/logo.png
Type=Application
Categories=AudioVideo;Video;
EOF

# Update desktop database
update-desktop-database ~/.local/share/applications/
```

### 4️⃣ **First-Time macOS Setup (Important!)**

**⚠️ If the app won't open or crashes immediately:**

macOS security blocks unsigned apps by default. Here's how to open it:

**Method 1: Right-Click to Open (Easiest)**
1. **Right-click** (or Control+click) on the app → Choose **"Open"**
2. Click **"Open"** in the dialog that appears
3. App opens! ✅ (Only needed first time)

**Method 2: System Settings**
1. Try to open the app (it will show security warning)
2. Click **"Done"** (don't move to trash!)
3. Go to **System Settings** → **Privacy & Security**
4. Scroll down, find Swaloka Looping Tool message
5. Click **"Open Anyway"** → Click **"Open"** again
6. Done! Won't see this again ✅

**Why this happens:** The app is not notarized with Apple (requires $99/year developer account). This is normal for open-source software.

---

## 🎓 Video Formats & Codec Support

### 📹 **Supported Video Formats**
- MP4 (recommended for compatibility)
- MOV (Apple QuickTime)
- AVI (Audio Video Interleave)
- MKV (Matroska)
- WebM
- **Note:** Hardware-accelerated video playback powered by MediaKit/libmpv with excellent Linux support

### 🎵 **Supported Audio Formats**
- MP3 (most common)
- WAV (uncompressed)
- M4A (Apple Audio)
- AAC (Advanced Audio Coding)
- OGG (Ogg Vorbis)
- FLAC (lossless compression)

### 📤 **Output Format**
- **Video:** MP4 with H.264 codec (best compatibility)
- **Audio:** AAC at 192kbps (high quality)
- **Platform optimized:** Ready to upload anywhere

---

## 💡 Pro Tips for Best Results

### 🎨 **Background Video Selection**
- **Use high quality:** Your output quality depends on your source
- **Seamless loops:** Choose videos that loop smoothly for best results
- **Resolution:** 1080p or higher recommended for best quality
- **Length:** Any length works—app will auto-loop to match audio

### 🎵 **Audio Organization**
- **File naming:** Use numbers (01_song.mp3, 02_song.mp3) for correct order
- **Consistent quality:** Use similar bitrates for professional results
- **Test first:** Try with 1-2 files before batch processing

### ⚙️ **Performance Optimization**
- **Close other apps:** Free up RAM for faster processing
- **Use SSD storage:** Significantly faster than HDD
- **Temp directory:** App uses project folder (not system temp) for better performance

### 📊 **Project Organization**
- **One project per series:** Keep related videos together
- **Descriptive names:** Name projects clearly for easy management
- **Regular cleanup:** Delete old temp files to save space

---

## 🆚 Why Choose Swaloka Over Alternatives?

| Feature | Swaloka Looping Tool | Professional Video Editors |
|---------|---------------------|---------------------------|
| **Automated Video Looping** | ✅ Built-in | ❌ Manual |
| **Batch Audio Processing** | ✅ Unlimited | ⚠️ Limited/Complex |
| **Learning Curve** | ✅ 5 minutes | ❌ Days/Weeks |
| **Price** | ✅ Free | ❌ Expensive subscriptions |
| **Cross-Platform** | ✅ Win/Mac | ⚠️ Varies |
| **Built for Creators** | ✅ Specialized | ❌ General purpose |
| **Setup Time** | ✅ < 5 min | ❌ Hours |

**Bottom Line:** If you need to automate repetitive video tasks, Swaloka is purpose-built for that. Professional tools are powerful but overkill for automation.

---

## 📖 Common Use Cases & Examples

### Example 1: Lo-Fi Music Channel
**Input:**
- 1 animated background video (10 seconds, loops seamlessly)
- 15 lo-fi hip hop tracks (3-5 minutes each)

**Process:**
- Total audio length: ~60 minutes
- App auto-loops 10-second background 360 times
- Adds metadata for upload

**Output:** 1-hour lo-fi study music video ready for upload

---

### Example 2: Podcast Season
**Input:**
- 1 branded podcast background image/video
- 10 podcast episodes (30-45 minutes each)

**Process:**
- Batch process all episodes at once
- Each gets your branding automatically
- Metadata embedded per episode

**Output:** 10 platform-ready podcast videos

---

### Example 3: Meditation Series
**Input:**
- 1 calming nature video (waves, forest, etc.)
- 20 guided meditation tracks (10-30 minutes each)

**Process:**
- First loop: Original meditation order
- Additional loops: Randomized for variety
- Background loops to match each track length

**Output:** Professional meditation video series

---

## ❓ Frequently Asked Questions

### **Q: How long does video processing take?**
**A:** Depends on video length and hardware. Typically:
- 1-hour video: 1-5 minutes on modern hardware
- 10-minute video: 30 seconds - 1 minute
- Processing is usually 2-10x faster than real-time

### **Q: Will this work with copyrighted music?**
**A:** The tool works with any audio files, but **you are responsible** for having rights to use the content. Always respect copyright laws!

### **Q: Can I cancel processing mid-way?**
**A:** Yes! Close the progress dialog and your project is saved. No data lost.

### **Q: What's the maximum video length?**
**A:** No hard limit. Tested with 10+ hour videos successfully. Limited only by your disk space.

### **Q: Does it compress my video quality?**
**A:** The app uses high-quality H.264 encoding with copy mode when possible (no re-encoding). Output quality matches your input.

### **Q: Where are temporary files stored?**
**A:** In your project's `temp/` folder (not system temp). Automatically cleaned up after successful processing.

### **Q: Can I use this commercially?**
**A:** Yes! The tool is free for personal and commercial use. Just ensure you have rights to your content.

### **Q: Does it work offline?**
**A:** 100% offline! No internet connection required (except for downloading the app and FFmpeg).

### **Q: Can I customize output quality?**
**A:** Currently uses optimized presets for best compatibility. Custom quality settings coming in future updates!

### **Q: How do I reorder audio files?**
**A:** Files are processed in alphabetical order. Use numbering in filenames (01_track.mp3, 02_track.mp3) to control order.

---

## 🐛 Troubleshooting

### FFmpeg Not Found
**Error:** "FFmpeg is not installed"

**Solution:**
1. Install FFmpeg (see Installation section)
2. Restart your terminal/shell
3. Click "Re-check Installation" in the app
4. If still not working, restart the app

### Processing Stuck or Slow
**Issue:** Video processing takes too long

**Solutions:**
- Close other apps to free up RAM
- Check if antivirus is scanning files
- Use SSD storage instead of HDD
- Try a shorter test video first
- Check FFmpeg logs in project folder

### Video Quality Issues
**Issue:** Output video looks compressed

**Solutions:**
- Use high-quality source video
- Ensure source is 1080p or higher
- Check that audio files are high bitrate
- Avoid re-encoding already compressed videos

### App Won't Open or Crashes Immediately (macOS)
**Issue:** macOS security blocks the app or it crashes on launch

**Solution:**
1. **Right-click** the app → Choose **"Open"** (not double-click!)
2. Click **"Open"** in the security dialog
3. If still blocked: System Settings → Privacy & Security → **"Open Anyway"**
4. See [installation section](#-installation--setup) for detailed steps

**Why:** The app is not notarized (requires $99/year Apple developer account). This is normal for free/open-source software.

**Alternative:** If it still crashes, check Console.app for crash logs and report the issue on GitHub.

### App Won't Start (Linux)
**Issue:** Permission denied or missing libraries

**Solutions:**
1. **Make executable:**
   ```bash
   chmod +x swaloka_looping_tool
   ```

2. **Check for missing libraries:**
   ```bash
   ldd swaloka_looping_tool
   ```

3. **Install GTK3 dependencies:**
   ```bash
   # Ubuntu/Debian
   sudo apt install libgtk-3-0 libblkid1 liblzma5

   # Fedora
   sudo dnf install gtk3

   # Arch Linux
   sudo pacman -S gtk3
   ```

4. **Run from terminal** to see error messages:
   ```bash
   ./swaloka_looping_tool
   ```

### Out of Disk Space
**Issue:** "Not enough space" error

**Solutions:**
- Free up disk space (need 2-3x video size)
- Use external drive for projects
- Clean up temp folders in old projects

---

## 🔐 Privacy & Security

- ✅ **100% Offline:** No data sent anywhere
- ✅ **No Telemetry:** We don't track anything
- ✅ **No Accounts:** No registration required
- ✅ **Open Source:** Code is transparent
- ✅ **Your Data Stays Yours:** Everything local

---

## ⚖️ Legal & Copyright Notice

### Important Information

**This tool is provided "as is" for creative purposes.**

**⚠️ You Are Responsible For:**
- Ensuring you have rights to all content you process
- Following platform Terms of Service
- Respecting copyright laws and creator rights
- Obtaining proper licenses for music and media

**✅ What You Can Do:**
- Use your own original content
- Use royalty-free music and videos
- Use content you have permission to use
- Create content under fair use guidelines

**❌ What You Should NOT Do:**
- Upload copyrighted music without permission
- Use others' content without proper licensing
- Violate platform Terms of Service
- Claim others' work as your own

**Disclaimer:** We are not liable for how you use this tool or what content you create. Always respect creators' rights and follow the law.

---

## 🤝 Contributing

We welcome contributions! Whether it's:
- 🐛 Bug reports
- 💡 Feature suggestions
- 📝 Documentation improvements
- 🔧 Code contributions
- 🌍 Translations

See our [Contributing Guide](CONTRIBUTING.md) for details.

---

## 📊 Stats & Metrics

- ⭐ Star this repo if it saves you time!
- 🐛 Report bugs to help improve the tool
- 💬 Join discussions to share ideas
- 📢 Share with fellow creators

---

## 💬 Community & Support

- 🐛 **Bug Reports:** [GitHub Issues](https://github.com/pradhiptabagaskara/swaloka-looping-tool/issues)
- 💡 **Feature Requests:** [GitHub Discussions](https://github.com/pradhiptabagaskara/swaloka-looping-tool/discussions)

---

## ❤️ Built for Creators, By Creators

Swaloka Looping Tool was created because I spent countless hours doing the same repetitive video editing tasks. There had to be a better way.

**The result?** A tool that saves content creators hours of editing time every single week.

**Our Mission:** Make video production accessible to everyone—not just professional editors.

---

## 🙏 Acknowledgments

- **FFmpeg Team** - For the incredible media processing library
- **Flutter Team** - For the cross-platform framework
- **Content Creators** - For feedback and feature suggestions
- **Open Source Community** - For making tools like this possible

---

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

**TL;DR:** Free to use, modify, and distribute. No warranties provided.

---

## ⭐ Star History

If this tool saved you time, please star the repository! ⭐

[![Star History](https://api.star-history.com/svg?repos=pradhiptabagaskara/swaloka-looping-tool&type=Date)](https://star-history.com/#pradhiptabagaskara/swaloka-looping-tool&Date)

---

## 🚀 Get Started Now

**Ready to automate your video production?**

1. [📥 Download Latest Release](https://github.com/pradhiptabagaskara/swaloka-looping-tool/releases)
2. [📖 Read Quick Start Guide](#-quick-start-guide)

---

<div align="center">

### Made with ❤️ for Content Creators

**Stop editing. Start creating.**

[Download Now](https://github.com/pradhiptabagaskara/repo/releases)

---

*Questions? Feedback? Feature ideas? [Let us know!](https://github.com/pradhiptabagaskara/repo/discussions)*

</div>
