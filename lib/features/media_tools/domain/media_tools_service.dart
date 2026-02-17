import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:swaloka_looping_tool/core/services/ffmpeg_service.dart';
import 'package:swaloka_looping_tool/core/services/log_service.dart';
import 'package:swaloka_looping_tool/core/utils/temp_directory_helper.dart';

/// Configuration for a single audio overlay
class AudioOverlayConfig {
  const AudioOverlayConfig({
    required this.path,
    required this.volume,
  });

  final String path;
  final double volume; // 0.0 to 1.0
}

class MediaToolsService {
  String _scaleFlagsForQuality(String quality) {
    switch (quality) {
      case 'fast':
        return 'bilinear';
      case 'balanced':
        return 'bicubic';
      case 'high':
      default:
        return 'lanczos';
    }
  }

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

  Future<void> applyAudioOverlays({
    required List<AudioOverlayConfig> overlays,
    required String outputPath,
    void Function(LogEntry)? onLog,
  }) async {
    final log = LogEntry.info(
      'Applying ${overlays.length} audio overlay(s)...',
    );
    onLog?.call(log);

    if (overlays.isEmpty) {
      throw Exception('No audio overlays provided');
    }

    try {
      // Build inputs
      final inputs = <String>[];
      for (final overlay in overlays) {
        inputs.addAll(['-i', overlay.path]);
      }

      // Build filter_complex to mix all audio with volume adjustments
      final filterParts = <String>[];
      final inputLabels = <String>[];

      // Apply volume to each input and create labels
      for (var i = 0; i < overlays.length; i++) {
        final volume = overlays[i].volume;
        filterParts.add('[$i:a]volume=$volume[a$i];');
        inputLabels.add('[a$i]');
      }

      // Mix all inputs using amerge
      final allInputs = inputLabels.join();
      filterParts.add(
        '$allInputs${overlays.length == 2
            ? 'amerge=inputs=2'
            : overlays.length == 3
            ? 'amerge=inputs=3'
            : 'amerge=inputs=${overlays.length}'}[aout]',
      );

      final filterComplex = filterParts.join();

      final codecArgs = _audioCodecArgs(outputPath);

      await FFmpegService.run(
        [
          '-y',
          ...inputs,
          '-filter_complex',
          filterComplex,
          '-map',
          '[aout]',
          ...codecArgs,
          outputPath,
        ],
        errorMessage: 'Failed to apply audio overlays',
        onLog: log.addSubLog,
      );

      onLog?.call(LogEntry.success('Audio overlays applied to $outputPath'));
    } on Exception catch (e) {
      onLog?.call(LogEntry.error('Failed to apply audio overlays: $e'));
      rethrow;
    }
  }

  /// Export overlay audios as a pre-mixed WAV preset file
  ///
  /// This mixes all overlay audios with their volume settings into a single WAV file
  /// that can be reused later. Useful for saving commonly used overlay combinations.
  ///
  /// Parameters:
  /// - overlays: List of overlay configurations with paths and volumes
  /// - outputPath: Where to save the preset WAV file
  /// - onLog: Optional callback for logging progress
  Future<void> exportOverlayPreset({
    required List<AudioOverlayConfig> overlays,
    required String outputPath,
    void Function(LogEntry)? onLog,
  }) async {
    final log = LogEntry.info(
      'Exporting ${overlays.length} overlay(s) as preset...',
    );
    onLog?.call(log);

    if (overlays.isEmpty) {
      throw Exception('No overlays provided');
    }

    final tempDir = await TempDirectoryHelper.create(
      prefix: 'swaloka_preset_${DateTime.now().millisecondsSinceEpoch}',
      onLog: onLog,
    );

    try {
      // Use the pre-mix logic to create the preset
      final presetPath = await _preMixOverlays(overlays, tempDir, onLog);

      // Copy the pre-mixed file to the desired output location
      await File(presetPath).copy(outputPath);

      onLog?.call(LogEntry.success('Preset exported to $outputPath'));
    } finally {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    }
  }

  /// Pre-mix overlay audios into a single WAV file (lossless)
  ///
  /// This reduces complexity in the final mix step by combining all overlays
  /// into one file first, then mixing that with base audios.
  ///
  /// Why volume compensation is needed:
  /// - FFmpeg's amix filter normalizes (divides) output by number of inputs
  /// - Example: amix=inputs=3 → output volume /3 (too quiet!)
  /// - Solution: Add volume filter to multiply back by N
  /// - Result: Full volume restored
  Future<String> _preMixOverlays(
    List<AudioOverlayConfig> overlays,
    Directory tempDir,
    void Function(LogEntry)? onLog,
  ) async {
    final log = LogEntry.info('Pre-mixing ${overlays.length} overlay(s)...');
    onLog?.call(log);

    // Build inputs for overlays (NO stream_loop here - we want original duration)
    final inputs = <String>[];
    for (final overlay in overlays) {
      inputs.addAll(['-i', overlay.path]);
    }

    // Build filter_complex to mix overlays with volume
    // Use duration=longest so output is as long as the longest overlay
    final filterParts = <String>[];

    // Apply volume to each overlay (user-configured levels)
    for (var i = 0; i < overlays.length; i++) {
      final volume = overlays[i].volume;
      filterParts.add('[$i:a]volume=$volume[v$i]');
    }

    // Build amix inputs with volume labels
    final amixInputs = List.generate(overlays.length, (i) => '[v$i]').join();

    // Mix with duration=longest - ensures output is as long as the longest overlay
    // CRITICAL: amix normalizes (divides) by number of inputs, so we MUST compensate
    // Without compensation: amix=inputs=3 → volume /3 → output too quiet
    // With compensation: amix=inputs=3 → volume /3 → volume=3.0 → /3 * 3 = 1.0 (full volume)
    final compensation = overlays.length.toStringAsFixed(1);
    filterParts.add(
      '$amixInputs'
      'amix=inputs=${overlays.length}:duration=longest[overlay_mix];'
      '[overlay_mix]volume=$compensation[overlay_mix]',
    );

    final filterComplex = filterParts.join(';');

    // Output to WAV (lossless)
    final overlayMixPath = p.join(tempDir.path, 'overlay_mix.wav');

    await FFmpegService.run(
      [
        '-y',
        '-threads',
        '0',
        '-vn',
        ...inputs,
        '-filter_complex',
        filterComplex,
        '-map',
        '[overlay_mix]',
        '-c:a',
        'pcm_s16le', // WAV codec (lossless)
        overlayMixPath,
      ],
      errorMessage: 'Failed to pre-mix overlays',
      onLog: log.addSubLog,
    );

    onLog?.call(LogEntry.success('Overlays pre-mixed to WAV'));
    return overlayMixPath;
  }

  Future<void> applyAudioOverlaysToBaseAudios({
    required List<String> baseAudios,
    required List<AudioOverlayConfig> overlays,
    required String outputPath,
    void Function(LogEntry)? onLog,
  }) async {
    final log = LogEntry.info(
      'Processing ${baseAudios.length} base audio(s) with ${overlays.length} overlay(s)...',
    );
    onLog?.call(log);

    if (baseAudios.isEmpty) {
      throw Exception('No base audios provided');
    }

    if (overlays.isEmpty) {
      // No overlays, just concatenate base audios
      await concatAudio(
        audioPaths: baseAudios,
        outputPath: outputPath,
        onLog: onLog,
      );
      return;
    }

    // Step 1: Create concat demuxer file for base audios (more efficient)
    // This avoids opening many separate files - concat demuxer handles all base audios as one stream
    final tempDir = await TempDirectoryHelper.create(
      prefix: 'swaloka_audio_${DateTime.now().millisecondsSinceEpoch}',
      onLog: onLog,
    );

    try {
      // Step 2: Check if we need to pre-mix overlays
      // Optimization: Skip pre-mix if only 1 overlay with full volume (1.0)
      // This saves processing time and disk I/O
      String overlayMixWav;
      if (overlays.length == 1 && overlays[0].volume == 1.0) {
        // Use the overlay file directly - no pre-mixing needed
        overlayMixWav = overlays[0].path;
        log.addSubLog(
          LogEntry.info('Single overlay at full volume - skipping pre-mix'),
        );
      } else {
        // Pre-mix overlays into single WAV file (lossless)
        // This reduces complexity: instead of amix=inputs=4, we only need amix=inputs=2
        overlayMixWav = await _preMixOverlays(overlays, tempDir, onLog);
      }

      final concatListPath = p.join(tempDir.path, 'base_audios.txt');
      final concatContent = baseAudios
          .map((f) => "file '${_formatPathForConcatFile(f)}'")
          .join('\n');
      await File(concatListPath).writeAsString(concatContent);

      log.addSubLog(LogEntry.info('Base audios: ${baseAudios.length} files'));

      // Step 3: Build FFmpeg command using concat demuxer
      // Input 0: concat demuxer (all base audios merged as one stream)
      // Input 1: pre-mixed overlay WAV (with stream_loop for infinite looping)
      // -vn skips video processing (we only need audio)
      final cmd = <String>[
        '-y',
        '-threads',
        '0',
        '-vn',
        '-f',
        'concat',
        '-safe',
        '0',
        '-i',
        concatListPath,
        '-stream_loop',
        '-1',
        '-i',
        overlayMixWav,
      ];

      // Step 4: Build filter_complex
      // Simpler amix: only 2 inputs (base + pre-mixed overlay) instead of (base + N overlays)
      final filterParts = <String>[];

      // Mix base with pre-mixed overlay using amix
      // CRITICAL: amix normalizes (divides) by number of inputs, so we MUST compensate
      // Without compensation: amix=inputs=2 → volume /2 → output too quiet
      // With compensation: amix=inputs=2 → volume /2 → volume=2.0 → /2 * 2 = 1.0 (full volume)
      // This affects BOTH base audio and overlay equally, restoring both to intended levels
      filterParts.add(
        '[0:a][1:a]amix=inputs=2:duration=first[out];'
        '[out]volume=2.0[out]',
      );

      final filterComplex = filterParts.join('; ');

      log.addSubLog(LogEntry.info('Mixing audio with pre-mixed overlay...'));

      final codecArgs = _audioCodecArgs(outputPath);

      cmd.addAll([
        '-filter_complex',
        filterComplex,
        '-map',
        '[out]',
        ...codecArgs,
        outputPath,
      ]);

      await FFmpegService.run(
        cmd,
        errorMessage: 'Failed to process audio',
        onLog: log.addSubLog,
      );

      onLog?.call(LogEntry.success('Audio processing complete: $outputPath'));
    } finally {
      // Auto clean temp directory after processing
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
    int? crf,
    String scalingQuality = 'high', // fast|balanced|high
    bool enhanceQuality = false,
    bool preserveAspectRatio = false,
    String? hwEncoder, // Optional HW Encoder
    void Function(LogEntry)? onLog,
  }) async {
    final log = LogEntry.info('Re-encoding video ${p.basename(videoPath)}...');
    onLog?.call(log);

    final aspectMode = preserveAspectRatio ? 'preserved' : 'enforced';
    log.addSubLog(
      LogEntry.info(
        'Target format: ${width}x$height @ ${fps}fps (aspect ratio $aspectMode)',
      ),
    );

    final flags = _scaleFlagsForQuality(scalingQuality);
    log.addSubLog(
      LogEntry.info(
        'Scaling: $scalingQuality ($flags)${enhanceQuality ? ' + enhance' : ''}',
      ),
    );

    // Build filter based on aspect ratio handling
    final String filter;
    if (preserveAspectRatio) {
      // Preserve original aspect ratio with padding (black bars if needed)
      filter =
          // Denoise before scaling can reduce upscaling artifacts a bit.
          '${enhanceQuality ? 'hqdn3d=1.5:1.5:3:3,' : ''}'
          'scale=$width:$height:force_original_aspect_ratio=decrease:flags=$flags,'
          'pad=$width:$height:(ow-iw)/2:(oh-ih)/2,'
          'fps=$fps,'
          // Mild sharpen after scaling (avoid over-sharpening).
          '${enhanceQuality ? 'unsharp=5:5:0.6:5:5:0.0,' : ''}'
          'format=yuv420p,'
          'setsar=1';
    } else {
      // Enforce exact aspect ratio by cropping if needed
      filter =
          '${enhanceQuality ? 'hqdn3d=1.5:1.5:3:3,' : ''}'
          'scale=$width:$height:force_original_aspect_ratio=increase:flags=$flags,'
          'crop=$width:$height,'
          'fps=$fps,'
          '${enhanceQuality ? 'unsharp=5:5:0.6:5:5:0.0,' : ''}'
          'format=yuv420p,'
          'setsar=1';
    }

    final cmd = [
      '-y',
      '-i',
      videoPath,
      '-vf',
      filter,
    ];

    // Add Video Encoder settings.
    //
    // CRF notes:
    // - Lower CRF => better quality, bigger files.
    // - If `crf` is not provided, we pick a sensible default based on target
    //   resolution (smaller outputs usually need lower CRF to avoid artifacts).
    final resolvedCrf = crf ?? _autoReencodeCrf(height);
    log.addSubLog(LogEntry.info('Video quality: CRF $resolvedCrf'));
    if (hwEncoder != null && hwEncoder.isNotEmpty && hwEncoder != 'libx264') {
      cmd.addAll(['-c:v', hwEncoder]);
      cmd.addAll(_getHwEncoderArgs(hwEncoder, resolvedCrf, preset));
    } else {
      cmd.addAll([
        '-c:v',
        'libx264',
        '-crf',
        resolvedCrf.toString(),
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

  int _autoReencodeCrf(int targetHeight) {
    if (targetHeight <= 480) return 20;
    if (targetHeight <= 720) return 22;
    return 23;
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
          quality = 85;
        } else if (crf >= 32) {
          quality = 35;
        } else if (crf >= 28) {
          quality = 45;
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
