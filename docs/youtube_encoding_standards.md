# YouTube Recommended Upload Encoding Standards

This document outlines YouTube's recommended encoding settings for uploaded videos, based on the official YouTube documentation: https://support.google.com/youtube/answer/1722171?hl=en

## Implementation Status

### Video Tools - "Konversi Resolusi" Feature
✅ **FULLY IMPLEMENTED**: All YouTube specifications are applied in the Resolution Conversion feature

### Video Merger
✅ **Stream Copy Mode**: For video merging (no re-encoding) - preserves source quality

## Container Format

### MP4 (Recommended)
- **Container**: MP4
- **Fast Start**: Enable for faster streaming
- **Implementation**: `-movflags +faststart` (implemented)

```dart
// Current implementation in FFmpegService
await FFmpegService.run([
  // ... other parameters
  '-movflags', '+faststart',
  outputPath,
]);
```

## Audio Codec

### Recommended Settings
- **Codec**: AAC-LC (Advanced Audio Coding - Low Complexity)
- **Sample Rate**: 48kHz (recommended) or 44.1kHz
- **Channels**: Stereo (2 channels)
- **Bitrate**: 384 kbps (recommended for high quality)

### FFmpeg Implementation
```bash
# YouTube recommended (AAC at 384kbps, 48kHz)
ffmpeg -i input.mp4 -c:a aac -b:a 384k -ar 48000 -ac 2 output.mp4
```

### Current Implementation Status
✅ **Fully Implemented**: AAC codec at 384kbps, 48kHz, stereo

## Video Codec

### H.264 Specifications
- **Codec**: H.264 (AVC)
- **Profile**: High Profile
- **Progressive Scan**: Yes (no interlacing)
- **B-Frames**: 2 consecutive B-frames
- **GOP Structure**: Closed GOP
- **GOP Size**: Half the frame rate (e.g., 30fps → GOP=15)
- **CABAC**: Enabled (Context-Adaptive Binary Arithmetic Coding)
- **Color Space**: BT.709 (for SDR content)
- **Chroma Subsampling**: 4:2:0
- **Bitrate Control**: Variable bitrate (CRF + maxrate + bufsize)

### FFmpeg Implementation (libx264)
```bash
# YouTube-optimized H.264 encoding
ffmpeg -hwaccel auto -i input.mp4 \
  -c:v libx264 \
  -profile:v high \
  -preset slow \
  -crf 21 \
  -maxrate 8000k \
  -bufsize 16000k \
  -g 30 \                    # GOP size = 60fps / 2
  -bf 2 \                    # 2 consecutive B-frames (YouTube spec)
  -flags +cgop \             # Closed GOP (YouTube spec)
  -coder 1 \                 # CABAC enabled
  -pix_fmt yuv420p \         # 4:2:0 chroma subsampling
  -colorspace bt709 \
  -color_primaries bt709 \
  -color_trc bt709 \
  -color_range tv \
  -c:a aac \
  -b:a 384k \
  -ar 48000 \
  -ac 2 \
  -movflags +faststart \
  output.mp4
```

### Hardware Encoder Support

The application supports hardware-accelerated encoding with the following encoders:

| Encoder | Platform | Implementation Status |
|---------|----------|----------------------|
| **libx264** | All (CPU) | ✅ Full YouTube specs |
| **h264_videotoolbox** | macOS | ✅ Full YouTube specs |
| **h264_nvenc** | Windows/Linux (NVIDIA) | ✅ Full YouTube specs |
| **h264_amf** | Windows (AMD) | ✅ Full YouTube specs |
| **h264_qsv** | Intel QuickSync | ✅ Full YouTube specs |
| **h264_vaapi** | Linux | ✅ Full YouTube specs |

All hardware encoders implement:
- `-profile:v high` (High Profile)
- `-bf 2` (2 consecutive B-frames)
- `-g ${fps/2}` (GOP size = half frame rate)
- `-strict_gop` / `-gop_mode strict` (Closed GOP, where supported)
- Variable bitrate control

### Hardware-Accelerated Decoding
All encoding operations use `-hwaccel auto` for hardware-accelerated decoding, reducing CPU usage and improving performance.

### Current Implementation Status
✅ **Fully Implemented**: YouTube-optimized re-encoding in "Konversi Resolusi" feature
✅ **Stream Copy Mode**: For video merging (no re-encoding)

## Bitrate Guidelines

### Resolution vs Bitrate Table

| Resolution | Aspect Ratio | Standard Bitrate (30fps) | High Bitrate (60fps) | CRF Setting |
|------------|--------------|-------------------------|---------------------|-------------|
| 2160p (4K) | 16:9 | 35 Mbps | 53 Mbps (35 × 1.5) | 18 (slow) |
| 1440p (2K) | 16:9 | 16 Mbps | 24 Mbps (16 × 1.5) | 20 (slow) |
| 1080p (FHD) | 16:9 | 8 Mbps | 12 Mbps (8 × 1.5) | 21 (slow) |
| 720p (HD) | 16:9 | 5 Mbps | 7.5 Mbps (5 × 1.5) | 22 (slow) |
| 480p (SD) | 16:9 or 4:3 | 2.5 Mbps | 4 Mbps (2.5 × 1.5) | 23 (medium) |
| 360p | 16:9 or 4:3 | 1 Mbps | 1.5 Mbps (1 × 1.5) | 24 (medium) |
| 240p | 16:9 or 4:3 | 0.5 Mbps | 0.75 Mbps (0.5 × 1.5) | 24 (medium) |

### Implementation Notes
- **60fps multiplier**: 1.5× the standard bitrate
- **VBR Mode**: Constrained VBR using CRF + maxrate + bufsize
- **Bufsize**: 2× the target bitrate
- **Preset**: Quality-focused (slow for 720p+, medium for lower resolutions)

### Bitrate Calculation in Code
```dart
final bitrateMultiplier = fps >= 50 ? 1.5 : 1.0;

switch (height) {
  case >= 2160: // 4K
    return (preset: 'slow', crf: 18, bitrate: 35.0 * bitrateMultiplier);
  case >= 1440: // 2K
    return (preset: 'slow', crf: 20, bitrate: 16.0 * bitrateMultiplier);
  case >= 1080: // 1080p
    return (preset: 'slow', crf: 21, bitrate: 8.0 * bitrateMultiplier);
  case >= 720: // 720p
    return (preset: 'slow', crf: 22, bitrate: 5.0 * bitrateMultiplier);
  case >= 480: // 480p
    return (preset: 'medium', crf: 23, bitrate: 2.5 * bitrateMultiplier);
  default: // Lower
    return (preset: 'medium', crf: 24, bitrate: 1.0 * bitrateMultiplier);
}
```

## Frame Rate

- **Recommended**: Same as source (don't convert if unnecessary)
- **Common frame rates**: 24fps, 25fps, 30fps, 48fps, 50fps, 60fps
- **GOP Size**: Calculated as `fps / 2`
  - 24fps → GOP=12
  - 25fps → GOP=12
  - 30fps → GOP=15
  - 50fps → GOP=25
  - 60fps → GOP=30

## Color Space

### BT.709 (SDR - Standard Dynamic Range)
- **Primary**: BT.709
- **Transfer Characteristic**: BT.709
- **Matrix Coefficients**: BT.709
- **Color Range**: TV (limited range 16-235)
- **Chroma Sampling**: 4:2:0

### FFmpeg Color Metadata
```bash
-colorspace bt709
-color_primaries bt709
-color_trc bt709
-color_range tv
-pix_fmt yuv420p
```

### HDR Support
YouTube also supports HDR content with these color spaces:
- **HDR10**: BT.2020 with PQ transfer
- **HLG**: BT.2020 with HLG transfer

Note: Current implementation focuses on SDR (BT.709) content.

## Global Encoder Settings

### Encoder Selection
The application uses a centralized encoder setting stored in `FFmpegService.hwAccelEncoder`:
- Auto-detects available hardware encoders on startup
- Falls back to `libx264` (CPU) if no hardware encoder available
- User can override in Settings or Video Tools page

### Available Encoders
1. **libx264** - CPU encoding (fallback, works everywhere)
2. **h264_videotoolbox** - macOS hardware acceleration
3. **h264_nvenc** - NVIDIA GPU encoding
4. **h264_amf** - AMD GPU encoding
5. **h264_qsv** - Intel QuickSync
6. **h264_vaapi** - Linux VAAPI

### Decoding
All encoding operations use `-hwaccel auto` for hardware-accelerated decoding, which:
- Reduces CPU usage
- Improves performance
- Works with all encoder types

## FFmpeg Command Examples

### YouTube-Optimized Encoding (Current Implementation)
```bash
# libx264 (CPU) - 1080p @ 30fps
ffmpeg -hwaccel auto -i input.mp4 \
  -c:v libx264 \
  -profile:v high \
  -preset slow \
  -crf 21 \
  -maxrate 8000k \
  -bufsize 16000k \
  -g 15 \
  -bf 2 \
  -flags +cgop \
  -coder 1 \
  -pix_fmt yuv420p \
  -colorspace bt709 \
  -color_primaries bt709 \
  -color_trc bt709 \
  -color_range tv \
  -c:a aac \
  -b:a 384k \
  -ar 48000 \
  -ac 2 \
  -movflags +faststart \
  output.mp4

# NVIDIA NVENC - 1080p @ 60fps
ffmpeg -hwaccel auto -i input.mp4 \
  -c:v h264_nvenc \
  -rc vbr \
  -cq 21 \
  -b:v 12000k \
  -maxrate 14400k \
  -bufsize 24000k \
  -profile:v high \
  -bf 2 \
  -g 30 \
  -strict_gop \
  -preset p4 \
  -pix_fmt yuv420p \
  -colorspace bt709 \
  -color_primaries bt709 \
  -color_trc bt709 \
  -color_range tv \
  -c:a aac \
  -b:a 384k \
  -ar 48000 \
  -ac 2 \
  -movflags +faststart \
  output.mp4
```

### Stream Copy (Video Merger - No Re-encode)
```bash
# Video merger preserves source quality
ffmpeg \
  -stream_loop -1 \
  -i background.mp4 \
  -i audio.m4a \
  -map 0:v \
  -map 1:a \
  -c:v copy \
  -c:a copy \
  -shortest \
  -movflags +faststart \
  output.mp4
```

## References

- [YouTube Recommended Upload Encoding Settings](https://support.google.com/youtube/answer/1722171?hl=en)
- [FFmpeg H.264 Encoding Guide](https://trac.ffmpeg.org/wiki/Encode/H.264)
- [YouTube Live Streaming Specs](https://support.google.com/youtube/answer/2853702)

## Implementation Notes

### YouTube Specifications Compliance

#### Fully Implemented ✅
All of the following YouTube specifications are implemented in the "Konversi Resolusi" (Resolution Conversion) feature:

1. **Progressive Scan** - No interlacing (default)
2. **High Profile** - `-profile:v high`
3. **2 Consecutive B-Frames** - `-bf 2`
4. **Closed GOP** - `-flags +cgop` (libx264) / `-strict_gop` (nvenc) / `-gop_mode strict` (qsv)
5. **GOP Size** - Calculated as `fps / 2`
6. **CABAC** - `-coder 1` (libx264, default for hardware encoders)
7. **Variable Bitrate** - CRF + maxrate + bufsize (constrained VBR)
8. **4:2:0 Chroma Subsampling** - `format=yuv420p` in video filter
9. **BT.709 Color Space** - Full metadata including color_range tv
10. **Audio** - AAC at 384kbps, 48kHz, stereo

### When to Use Each Mode

#### YouTube-Optimized Re-encoding ("Konversi Resolusi")
Use when:
1. Converting video to a different resolution
2. Changing frame rate
3. Source video has non-standard codec (ProRes, DNxHD, etc.)
4. Source video has excessively high bitrate
5. Preparing for YouTube upload with optimal settings
6. Need to ensure compatibility with YouTube's processing pipeline

#### Stream Copy (Video Merger)
Use when:
1. Source video is already H.264/AAC in MP4 container
2. Processing speed is priority
3. Want to preserve original quality
4. Doing simple editing operations (merge, trim, intro insertion)
5. No resolution/frame rate changes needed

### Design Philosophy

The application provides two complementary approaches:

1. **Quality Preservation** (Video Merger)
   - Uses stream copy to avoid generation loss
   - Preserves original codec settings
   - Fastest processing
   - Ideal for merging videos already in YouTube-friendly format

2. **YouTube Optimization** (Resolution Conversion)
   - Re-encodes with YouTube specifications
   - Ensures compatibility with YouTube's processing
   - Optimized bitrate/quality balance
   - Supports all major hardware encoders

### Conclusion

The application now fully supports YouTube's recommended encoding standards while maintaining the efficiency of stream copy for simple operations. Users can choose the appropriate mode based on their specific needs:

- **Video Merger**: For fast, lossless video concatenation
- **Resolution Conversion**: For YouTube-optimized output with full control over resolution, frame rate, and encoder settings
