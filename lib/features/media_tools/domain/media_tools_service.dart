import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:swaloka_looping_tool/core/services/ffmpeg_service.dart';
import 'package:swaloka_looping_tool/core/services/log_service.dart';
import 'package:swaloka_looping_tool/core/utils/temp_directory_helper.dart';

class MediaToolsService {
  Future<void> extractAudio({
    required String videoPath,
    required String outputPath,
    void Function(LogEntry)? onLog,
  }) async {
    final log = LogEntry.info(
      'Extracting audio from ${p.basename(videoPath)}...',
    );
    onLog?.call(log);

    final codecArgs = _audioCodecArgs(outputPath);

    await FFmpegService.run(
      [
        '-y',
        '-i',
        videoPath,
        '-vn', // No video
        ...codecArgs,
        outputPath,
      ],
      errorMessage: 'Failed to extract audio',
      onLog: log.addSubLog,
    );

    onLog?.call(LogEntry.success('Audio extracted to $outputPath'));
  }

  Future<void> convertAudio({
    required String inputPath,
    required String outputPath,
    void Function(LogEntry)? onLog,
  }) async {
    final log = LogEntry.info('Converting audio ${p.basename(inputPath)}...');
    onLog?.call(log);

    final codecArgs = _audioCodecArgs(outputPath);

    await FFmpegService.run(
      [
        '-y',
        '-i',
        inputPath,
        ...codecArgs,
        outputPath, // FFmpeg infers container from extension, codec is enforced above
      ],
      errorMessage: 'Failed to convert audio',
      onLog: log.addSubLog,
    );

    onLog?.call(LogEntry.success('Audio converted to $outputPath'));
  }

  Future<void> concatAudio({
    required List<String> audioPaths,
    required String outputPath,
    void Function(LogEntry)? onLog,
  }) async {
    final tempDir = await TempDirectoryHelper.create(
      prefix: 'swaloka_tools',
      onLog: onLog,
    );
    final log = LogEntry.info(
      'Concatenating ${audioPaths.length} audio files...',
    );
    onLog?.call(log);

    try {
      final concatListPath = p.join(tempDir.path, 'concat_list.txt');
      final concatContent = audioPaths
          .map((f) => "file '${_formatPathForConcatFile(f)}'")
          .join('\n');
      await File(concatListPath).writeAsString(concatContent);

      final codecArgs = _audioCodecArgs(outputPath);

      await FFmpegService.run(
        [
          '-y',
          '-f',
          'concat',
          '-safe',
          '0',
          '-i',
          concatListPath,
          ...codecArgs,
          outputPath,
        ],
        errorMessage: 'Failed to concat audio',
        onLog: log.addSubLog,
      );

      onLog?.call(LogEntry.success('Audio concatenated to $outputPath'));
    } finally {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    }
  }

  Future<void> concatVideos({
    required List<String> videoPaths,
    required String outputPath,
    required bool keepAudio,
    required bool smoothTransition,
    bool fadeIn = false,
    bool fadeOut = false,
    String fadeInColor = '#000000',
    String fadeOutColor = '#000000',
    String encodingPreset = 'veryfast',
    String? hwEncoder,
    void Function(LogEntry)? onLog,
  }) async {
    if (videoPaths.isEmpty) return;
    final tempDir = await TempDirectoryHelper.create(
      prefix: 'swaloka_tools',
      onLog: onLog,
    );

    final log = videoPaths.length == 1
        ? LogEntry.info('Processing single video with effects...')
        : LogEntry.info('Concatenating ${videoPaths.length} videos...');
    onLog?.call(log);

    try {
      if (smoothTransition && videoPaths.length > 1) {
        // Complex filter for xfade with resolution/fps normalization
        // xfade requires all inputs to have the same resolution and fps

        log.addSubLog(
          LogEntry.info('Analyzing videos for smooth transition...'),
        );

        // Clear cache to ensure fresh metadata with hasAudio field
        FFmpegService.clearMetadataCache();

        // Get metadata for all videos
        final metadataList = <VideoMetadata>[];
        final durations = <double>[];
        for (final path in videoPaths) {
          final metadata = await FFmpegService.getVideoMetadata(path);
          if (metadata.duration == null) {
            throw Exception('Could not determine duration for $path');
          }
          metadataList.add(metadata);
          durations.add(metadata.duration!.inMicroseconds / 1000000.0);
        }

        // Check which videos have audio
        final anyHasAudio = metadataList.any((m) => m.hasAudio);
        final allHaveAudio = metadataList.every((m) => m.hasAudio);

        if (keepAudio && !allHaveAudio && anyHasAudio) {
          log.addSubLog(
            LogEntry.info(
              'Some videos have no audio - will generate silence for those',
            ),
          );
        } else if (keepAudio && !anyHasAudio) {
          log.addSubLog(
            LogEntry.info('No videos have audio tracks - skipping audio'),
          );
        }

        // Use first video's resolution and fps as target
        final targetWidth = metadataList[0].width ?? 1920;
        final targetHeight = metadataList[0].height ?? 1080;
        final targetFps = metadataList[0].fps ?? 30;

        log.addSubLog(
          LogEntry.info(
            'Normalizing all videos to ${targetWidth}x$targetHeight @ ${targetFps}fps...',
          ),
        );

        // Inputs
        final inputs = <String>[];
        for (final path in videoPaths) {
          inputs.add('-i');
          inputs.add(path);
        }

        final filterComplex = StringBuffer();

        // First, scale and set fps for all video inputs
        for (var i = 0; i < videoPaths.length; i++) {
          filterComplex.write(
            '[$i:v]scale=$targetWidth:$targetHeight:force_original_aspect_ratio=decrease,pad=$targetWidth:$targetHeight:(ow-iw)/2:(oh-ih)/2,setsar=1,fps=$targetFps[v${i}s];',
          );
        }

        // Now apply xfade transitions
        double currentOffset = 0;
        var prevLabel = '[v0s]';
        const transitionDuration = 1.0;

        for (var i = 0; i < videoPaths.length - 1; i++) {
          final nextLabel = '[v${i + 1}x]';
          final duration = durations[i];
          currentOffset += duration - transitionDuration;

          filterComplex.write(
            '$prevLabel[v${i + 1}s]xfade=transition=fade:duration=$transitionDuration:offset=${currentOffset.toStringAsFixed(2)}$nextLabel;',
          );
          prevLabel = nextLabel;
        }

        // Calculate total duration after crossfades
        // Total = sum(durations) - (n-1) * transitionDuration
        final totalDuration =
            durations.reduce((a, b) => a + b) -
            (videoPaths.length - 1) * transitionDuration;

        // Add fade in/out if enabled
        const fadeDuration = 1.0;
        if (fadeIn || fadeOut) {
          log.addSubLog(
            LogEntry.info(
              'Adding fade effects (${fadeIn ? "in:$fadeInColor" : ""}${fadeIn && fadeOut ? " / " : ""}${fadeOut ? "out:$fadeOutColor" : ""})...',
            ),
          );
          final fadeOutStart = (totalDuration - fadeDuration).toStringAsFixed(
            2,
          );

          if (fadeIn && fadeOut) {
            const fadeInLabel = '[vfin]';
            const fadeOutLabel = '[vfout]';
            filterComplex.write(
              '${prevLabel}fade=t=in:st=0:d=$fadeDuration:c=$fadeInColor$fadeInLabel;',
            );
            filterComplex.write(
              '${fadeInLabel}fade=t=out:st=$fadeOutStart:d=$fadeDuration:c=$fadeOutColor$fadeOutLabel;',
            );
            prevLabel = fadeOutLabel;
          } else if (fadeIn) {
            const fadeInLabel = '[vfin]';
            filterComplex.write(
              '${prevLabel}fade=t=in:st=0:d=$fadeDuration:c=$fadeInColor$fadeInLabel;',
            );
            prevLabel = fadeInLabel;
          } else if (fadeOut) {
            const fadeOutLabel = '[vfout]';
            filterComplex.write(
              '${prevLabel}fade=t=out:st=$fadeOutStart:d=$fadeDuration:c=$fadeOutColor$fadeOutLabel;',
            );
            prevLabel = fadeOutLabel;
          }
        }

        var prevAudioLabel = '';
        final canProcessAudio = keepAudio && anyHasAudio;

        if (canProcessAudio) {
          // Generate audio labels - use real audio or silence for each video
          final audioLabels = <String>[];
          for (var i = 0; i < videoPaths.length; i++) {
            if (metadataList[i].hasAudio) {
              // Use real audio from video
              audioLabels.add('[$i:a]');
            } else {
              // Generate silence for the duration of this video
              final silenceLabel = '[sil$i]';
              final dur = durations[i].toStringAsFixed(2);
              filterComplex.write(
                'anullsrc=channel_layout=stereo:sample_rate=44100,atrim=duration=$dur$silenceLabel;',
              );
              audioLabels.add(silenceLabel);
            }
          }

          // Apply audio crossfade chain
          prevAudioLabel = audioLabels[0];
          for (var i = 0; i < videoPaths.length - 1; i++) {
            final nextAudioLabel = '[a${i + 1}x]';
            filterComplex.write(
              '$prevAudioLabel${audioLabels[i + 1]}acrossfade=d=$transitionDuration:c1=tri:c2=tri$nextAudioLabel;',
            );
            prevAudioLabel = nextAudioLabel;
          }

          // Add audio fade in/out if fade effects enabled
          if (fadeIn || fadeOut) {
            final fadeOutStart = (totalDuration - fadeDuration).toStringAsFixed(
              2,
            );

            if (fadeIn && fadeOut) {
              const aFadeInLabel = '[afin]';
              const aFadeOutLabel = '[afout]';
              filterComplex.write(
                '${prevAudioLabel}afade=t=in:st=0:d=$fadeDuration$aFadeInLabel;',
              );
              filterComplex.write(
                '${aFadeInLabel}afade=t=out:st=$fadeOutStart:d=$fadeDuration$aFadeOutLabel;',
              );
              prevAudioLabel = aFadeOutLabel;
            } else if (fadeIn) {
              const aFadeInLabel = '[afin]';
              filterComplex.write(
                '${prevAudioLabel}afade=t=in:st=0:d=$fadeDuration$aFadeInLabel;',
              );
              prevAudioLabel = aFadeInLabel;
            } else if (fadeOut) {
              const aFadeOutLabel = '[afout]';
              filterComplex.write(
                '${prevAudioLabel}afade=t=out:st=$fadeOutStart:d=$fadeDuration$aFadeOutLabel;',
              );
              prevAudioLabel = aFadeOutLabel;
            }
          }
        }

        // Remove trailing semicolon
        var fc = filterComplex.toString();
        if (fc.endsWith(';')) fc = fc.substring(0, fc.length - 1);

        final cmd = [
          '-y',
          ...inputs,
          '-filter_complex',
          fc,
          '-map',
          prevLabel,
        ];

        if (canProcessAudio) {
          cmd.add('-map');
          cmd.add(prevAudioLabel);
        }

        // Re-encode is necessary for filters
        if (hwEncoder != null &&
            hwEncoder.isNotEmpty &&
            hwEncoder != 'libx264') {
          cmd.addAll(['-c:v', hwEncoder]);
          // Approximate equivalent quality for HW
          cmd.addAll(_getHwEncoderArgs(hwEncoder, 23, encodingPreset));
        } else {
          cmd.addAll([
            '-c:v',
            'libx264',
            '-preset',
            encodingPreset,
            '-crf',
            '23',
          ]);
        }

        if (canProcessAudio) {
          cmd.addAll(['-c:a', 'aac', '-b:a', '192k']);
        }

        cmd.add(outputPath);

        await FFmpegService.run(
          cmd,
          errorMessage: 'Failed to smooth concat videos',
          onLog: log.addSubLog,
        );
      } else if (fadeIn || fadeOut) {
        // Simple concat with fade effects - requires re-encoding for filters
        log.addSubLog(
          LogEntry.info(
            'Adding fade effects (${fadeIn ? "in:$fadeInColor" : ""}${fadeIn && fadeOut ? " / " : ""}${fadeOut ? "out:$fadeOutColor" : ""})...',
          ),
        );

        // Clear cache to ensure fresh metadata with hasAudio field
        FFmpegService.clearMetadataCache();

        // Get total duration and check for audio
        var totalDuration = 0.0;
        var allHaveAudio = true;
        for (final path in videoPaths) {
          final metadata = await FFmpegService.getVideoMetadata(path);
          if (metadata.duration != null) {
            totalDuration += metadata.duration!.inMicroseconds / 1000000.0;
          }
          if (!metadata.hasAudio) {
            allHaveAudio = false;
          }
        }

        final canProcessAudio = keepAudio && allHaveAudio;
        if (keepAudio && !allHaveAudio) {
          log.addSubLog(
            LogEntry.info(
              'Some videos have no audio track - skipping audio processing',
            ),
          );
        }

        // Build concat filter with fade
        final concatListPath = p.join(tempDir.path, 'concat_list.txt');
        final concatContent = videoPaths
            .map((f) => "file '${_formatPathForConcatFile(f)}'")
            .join('\n');
        await File(concatListPath).writeAsString(concatContent);

        const fadeDuration = 1.0;
        final fadeOutStart = (totalDuration - fadeDuration).toStringAsFixed(2);

        // Build video filter based on selected options
        final vFilterParts = <String>[];
        final aFilterParts = <String>[];

        if (fadeIn) {
          vFilterParts.add('fade=t=in:st=0:d=$fadeDuration:c=$fadeInColor');
          aFilterParts.add('afade=t=in:st=0:d=$fadeDuration');
        }
        if (fadeOut) {
          vFilterParts.add(
            'fade=t=out:st=$fadeOutStart:d=$fadeDuration:c=$fadeOutColor',
          );
          aFilterParts.add('afade=t=out:st=$fadeOutStart:d=$fadeDuration');
        }

        final vFilter = vFilterParts.join(',');
        final aFilter = aFilterParts.join(',');

        final cmd = [
          '-y',
          '-f',
          'concat',
          '-safe',
          '0',
          '-i',
          concatListPath,
          '-vf',
          vFilter,
        ];

        if (canProcessAudio) {
          cmd.addAll(['-af', aFilter]);
        } else {
          cmd.add('-an');
        }

        // Re-encode is necessary for filters
        if (hwEncoder != null &&
            hwEncoder.isNotEmpty &&
            hwEncoder != 'libx264') {
          cmd.addAll(['-c:v', hwEncoder]);
          cmd.addAll(_getHwEncoderArgs(hwEncoder, 23, encodingPreset));
        } else {
          cmd.addAll([
            '-c:v',
            'libx264',
            '-preset',
            encodingPreset,
            '-crf',
            '23',
          ]);
        }

        if (keepAudio) {
          cmd.addAll(['-c:a', 'aac', '-b:a', '192k']);
        }

        cmd.add(outputPath);

        await FFmpegService.run(
          cmd,
          errorMessage: 'Failed to concat videos with fade',
          onLog: log.addSubLog,
        );
      } else {
        // Simple concat without fade - use stream copy (fastest)
        final concatListPath = p.join(tempDir.path, 'concat_list.txt');
        final concatContent = videoPaths
            .map((f) => "file '${_formatPathForConcatFile(f)}'")
            .join('\n');
        await File(concatListPath).writeAsString(concatContent);

        final cmd = [
          '-y',
          '-f',
          'concat',
          '-safe',
          '0',
          '-i',
          concatListPath,
        ];

        if (!keepAudio) {
          cmd.add('-an'); // Remove audio
          cmd.addAll(['-c:v', 'copy']); // Copy video
        } else {
          cmd.addAll(['-c', 'copy']); // Copy everything
        }

        cmd.add(outputPath);

        await FFmpegService.run(
          cmd,
          errorMessage: 'Failed to concat videos',
          onLog: log.addSubLog,
        );
      }

      final successMsg = videoPaths.length == 1
          ? 'Video processed successfully: $outputPath'
          : 'Videos concatenated to $outputPath';
      onLog?.call(LogEntry.success(successMsg));
    } finally {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    }
  }

  Future<void> compressVideo({
    required String videoPath,
    required String outputPath,
    required int crf,
    required String preset,
    required bool keepAudio,
    String? hwEncoder, // Optional HW Encoder
    void Function(LogEntry)? onLog,
  }) async {
    final log = LogEntry.info('Compressing video ${p.basename(videoPath)}...');
    onLog?.call(log);

    final cmd = [
      '-y',
      '-i',
      videoPath,
    ];

    // Add Video Encoder settings
    if (hwEncoder != null && hwEncoder.isNotEmpty && hwEncoder != 'libx264') {
      cmd.addAll(['-c:v', hwEncoder]);
      cmd.addAll(_getHwEncoderArgs(hwEncoder, crf, preset));
    } else {
      cmd.addAll([
        '-c:v',
        'libx264',
        '-crf',
        crf.toString(),
        '-preset',
        preset,
      ]);
    }

    if (keepAudio) {
      cmd.addAll(['-c:a', 'copy']); // Copy original audio stream
    } else {
      cmd.add('-an'); // Remove audio
    }

    cmd.add(outputPath);

    await FFmpegService.run(
      cmd,
      errorMessage: 'Failed to compress video',
      onLog: log.addSubLog,
    );

    onLog?.call(LogEntry.success('Video compressed to $outputPath'));
  }

  Future<void> reencodeVideo({
    required String videoPath,
    required String outputPath,
    required int width,
    required int height,
    required int fps,
    required String preset,
    required bool keepAudio,
    String? hwEncoder, // Optional HW Encoder
    void Function(LogEntry)? onLog,
  }) async {
    final log = LogEntry.info('Re-encoding video ${p.basename(videoPath)}...');
    onLog?.call(log);

    log.addSubLog(
      LogEntry.info(
        'Target format: ${width}x$height @ ${fps}fps',
      ),
    );

    // Build filter: scale to exact resolution, set fps, normalize pixel format
    final filter =
        'scale=$width:$height:force_original_aspect_ratio=decrease,'
        'pad=$width:$height:(ow-iw)/2:(oh-ih)/2,'
        'fps=$fps,'
        'format=yuv420p,'
        'setsar=1';

    final cmd = [
      '-y',
      '-i',
      videoPath,
      '-vf',
      filter,
    ];

    // Add Video Encoder settings (use CRF 23 for quality)
    const crf = 23;
    if (hwEncoder != null && hwEncoder.isNotEmpty && hwEncoder != 'libx264') {
      cmd.addAll(['-c:v', hwEncoder]);
      cmd.addAll(_getHwEncoderArgs(hwEncoder, crf, preset));
    } else {
      cmd.addAll([
        '-c:v',
        'libx264',
        '-crf',
        crf.toString(),
        '-preset',
        preset,
      ]);
    }

    // Audio handling
    if (keepAudio) {
      cmd.addAll(['-c:a', 'aac', '-b:a', '192k']); // Re-encode audio to AAC
    } else {
      cmd.add('-an'); // Remove audio
    }

    cmd.add(outputPath);

    await FFmpegService.run(
      cmd,
      errorMessage: 'Failed to re-encode video',
      onLog: log.addSubLog,
    );

    onLog?.call(LogEntry.success('Video re-encoded to $outputPath'));
  }

  List<String> _getHwEncoderArgs(String encoder, int crf, String preset) {
    // Map standard CRF (0-51, lower=better) and Preset to HW specific args

    // General note: Hardware encoders often have different quality ranges
    // This is a rough approximation to prevent crashes and give expected results

    switch (encoder) {
      case 'h264_videotoolbox': // macOS
        // Uses -q:v (0-100, higher=better).
        // CRF 18 (High) -> ~75
        // CRF 23 (Balanced) -> ~60
        // CRF 28 (Low) -> ~45
        // CRF 32 (Very Low) -> ~35
        var quality = 60;
        if (crf <= 18) {
          quality = 75;
        } else if (crf >= 28) {
          quality = 45;
        } else if (crf >= 32) {
          quality = 35;
        }

        return ['-q:v', quality.toString(), '-allow_sw', '1'];

      case 'h264_nvenc': // NVIDIA
        // Uses -cq (0-51, lower=better) with -rc vbr
        // Presets: p1-p7, but also supports 'fast', 'slow' mappings sometimes.
        // We'll use -cq same as crf, it's close enough.
        return [
          '-rc',
          'vbr',
          '-cq',
          crf.toString(),
          '-preset',
          if (preset == 'veryfast' || preset == 'ultrafast')
            'p1'
          else
            'p4', // p1=fastest, p4=medium
        ];

      case 'h264_amf': // AMD
        // Uses -rc cqp (Constant Quantization Parameter) ideally, or vbr_latency
        // We'll try simple usage to avoid complex failures
        // -quality: speed, balanced, quality
        var quality = 'balanced';
        if (preset == 'ultrafast' || preset == 'veryfast') quality = 'speed';
        if (preset == 'slow') quality = 'quality';
        return ['-usage', 'transcoding', '-quality', quality];

      case 'h264_qsv': // Intel
        // -global_quality (1-51)
        return ['-global_quality', crf.toString(), '-look_ahead', '0'];

      case 'h264_vaapi': // Linux VAAPI
        // Often needs huge setup (-vaapi_device etc).
        // Assuming user has default setup or this might fail.
        // -qp is often used.
        return ['-qp', crf.toString()];

      default:
        return [];
    }
  }

  String _formatPathForConcatFile(String path) {
    var safePath = p.normalize(path);
    if (Platform.isWindows) {
      safePath = safePath.replaceAll(r'\', '/');
    }
    return safePath.replaceAll("'", r"'\''");
  }

  List<String> _audioCodecArgs(String outputPath) {
    final ext = p.extension(outputPath).toLowerCase();
    switch (ext) {
      case '.mp3':
        return ['-c:a', 'libmp3lame', '-b:a', '192k'];
      case '.m4a':
      case '.aac':
        return ['-c:a', 'aac', '-b:a', '192k'];
      case '.wav':
        return ['-c:a', 'pcm_s16le'];
      case '.flac':
        return ['-c:a', 'flac'];
      case '.ogg':
        return ['-c:a', 'libvorbis', '-qscale:a', '4'];
      default:
        // Fallback to AAC as a safe, widely supported default
        return ['-c:a', 'aac', '-b:a', '192k'];
    }
  }
}
