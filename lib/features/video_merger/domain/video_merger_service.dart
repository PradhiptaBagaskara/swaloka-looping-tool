import 'dart:io';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/media_information.dart';
import 'package:path_provider/path_provider.dart';

/// Service for merging background video with sequential audio files
class VideoMergerService {
  String? _cachedEncoder;

  /// Merge background video with multiple audio files
  ///
  /// [backgroundVideoPath] - Path to the background video file
  /// [audioFiles] - List of audio/video file paths (audio will be extracted from videos)
  /// [outputPath] - Path where the final merged video will be saved
  /// [title] - Video title metadata
  /// [author] - Video author metadata
  /// [comment] - Video comment metadata
  /// [width] - Output video width
  /// [height] - Output video height
  /// [preset] - FFmpeg encoding preset (e.g., ultrafast, slow)
  /// [crf] - Constant Rate Factor (0-51, lower is better quality)
  /// [enableFastStart] - Whether to enable +faststart for web optimization
  /// [extraFlags] - Optional extra FFmpeg flags to append
  /// [onProgress] - Callback for progress updates (0.0 to 1.0)
  /// [onLog] - Callback for real-time FFmpeg logs
  ///
  /// Returns the path to the merged video file
  Future<String> mergeVideoWithAudio({
    required String backgroundVideoPath,
    required List<String> audioFiles,
    required String outputPath,
    String? title,
    String? author,
    String? comment,
    int width = 1920,
    int height = 1080,
    String preset = 'slow',
    int crf = 18,
    bool enableFastStart = true,
    bool useGpu = true,
    int concurrencyLimit = 4,
    List<String> extraFlags = const [],
    void Function(double progress)? onProgress,
    void Function(String log)? onLog,
  }) async {
    try {
      if (Platform.isWindows) {
        return _mergeVideoWithAudioWindows(
          backgroundVideoPath: backgroundVideoPath,
          audioFiles: audioFiles,
          outputPath: outputPath,
          title: title,
          author: author,
          comment: comment,
          width: width,
          height: height,
          preset: preset,
          crf: crf,
          enableFastStart: enableFastStart,
          useGpu: useGpu,
          concurrencyLimit: concurrencyLimit,
          extraFlags: extraFlags,
          onProgress: onProgress,
          onLog: onLog,
        );
      }

      // Increase session history size to avoid SESSION_NOT_FOUND
      // especially when processing many assets.
      FFmpegKitConfig.setSessionHistorySize(100);

      // Enable log callback
      FFmpegKitConfig.enableLogCallback((log) {
        onLog?.call(log.getMessage());
      });

      // Step 1: Extract audio from all files and merge them sequentially
      final mergedAudioPath = await _mergeAudioFiles(
        audioFiles: audioFiles,
        concurrencyLimit: concurrencyLimit,
        onProgress: (progress) =>
            onProgress?.call(progress * 0.5), // First 50% of progress
      );

      // Step 2: Get durations in parallel
      final durations = await Future.wait([
        _getMediaDuration(mergedAudioPath),
        _getMediaDuration(backgroundVideoPath),
      ]);
      final audioDuration = durations[0];
      final videoDuration = durations[1];

      // Step 3: Merge audio with background video
      await _mergeAudioWithVideo(
        backgroundVideoPath: backgroundVideoPath,
        audioPath: mergedAudioPath,
        outputPath: outputPath,
        audioDuration: audioDuration,
        videoDuration: videoDuration,
        title: title,
        author: author,
        comment: comment,
        width: width,
        height: height,
        preset: preset,
        crf: crf,
        enableFastStart: enableFastStart,
        useGpu: useGpu,
        extraFlags: extraFlags,
        onProgress: (progress) =>
            onProgress?.call(0.5 + (progress * 0.5)), // Last 50% of progress
      );

      // Clean up temporary merged audio file
      try {
        final tempFile = File(mergedAudioPath);
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (e) {
        // Ignore cleanup errors
      }

      // Disable log callback after done
      FFmpegKitConfig.enableLogCallback(null);

      return outputPath;
    } catch (e) {
      if (!Platform.isWindows) {
        FFmpegKitConfig.enableLogCallback(null);
      }
      throw Exception('Failed to merge video: $e');
    }
  }

  /// Windows-specific implementation using FFmpeg CLI directly
  Future<String> _mergeVideoWithAudioWindows({
    required String backgroundVideoPath,
    required List<String> audioFiles,
    required String outputPath,
    String? title,
    String? author,
    String? comment,
    int width = 1920,
    int height = 1080,
    String preset = 'slow',
    int crf = 18,
    bool enableFastStart = true,
    bool useGpu = true,
    int concurrencyLimit = 4,
    List<String> extraFlags = const [],
    void Function(double progress)? onProgress,
    void Function(String log)? onLog,
  }) async {
    // 1. Verify ffmpeg exists
    try {
      final check = await Process.run('ffmpeg', ['-version']);
      if (check.exitCode != 0) throw Exception('FFmpeg not found');
    } catch (e) {
      throw Exception(
        'FFmpeg CLI not found. Please install FFmpeg and add it to your System PATH to use this tool on Windows.',
      );
    }

    onLog?.call('Windows detected: Using FFmpeg CLI fallback.');

    // 2. Prepare temp directory
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final tempAudioDir = Directory('${tempDir.path}/swaloka_temp_$timestamp');
    await tempAudioDir.create(recursive: true);

    try {
      // 3. Extract audio from each file in parallel
      final extractedFiles = <String>[];
      for (int i = 0; i < audioFiles.length; i += concurrencyLimit) {
        final end = (i + concurrencyLimit < audioFiles.length)
            ? i + concurrencyLimit
            : audioFiles.length;
        final batch = audioFiles.sublist(i, end);

        await Future.wait(
          batch.asMap().entries.map((entry) async {
            final idx = i + entry.key;
            final inputPath = entry.value;
            final outPath = '${tempAudioDir.path}/part_$idx.wav';

            onLog?.call('Extracting audio from: $inputPath');
            final result = await Process.run('ffmpeg', [
              '-y',
              '-i',
              inputPath,
              '-vn',
              '-acodec',
              'pcm_s16le',
              '-ar',
              '44100',
              '-ac',
              '2',
              outPath,
            ]);

            if (result.exitCode != 0) {
              throw Exception('Failed to extract audio from $inputPath');
            }
            extractedFiles.add(outPath);
          }),
        );
        onProgress?.call((i / audioFiles.length) * 0.4);
      }

      // 4. Concat audio files
      final concatFilePath = '${tempAudioDir.path}/concat.txt';
      final concatContent = extractedFiles
          .map((f) => "file '${f.replaceAll("'", "'\\''")}'")
          .join('\n');
      await File(concatFilePath).writeAsString(concatContent);

      final mergedAudioPath = '${tempAudioDir.path}/merged.wav';
      onLog?.call('Merging audio tracks...');
      final concatResult = await Process.run('ffmpeg', [
        '-y',
        '-f',
        'concat',
        '-safe',
        '0',
        '-i',
        concatFilePath,
        '-c',
        'copy',
        mergedAudioPath,
      ]);

      if (concatResult.exitCode != 0) {
        throw Exception('Failed to merge audio tracks');
      }
      onProgress?.call(0.5);

      // 5. Get durations
      final audioDur = await _getDurationWindows(mergedAudioPath);
      final videoDur = await _getDurationWindows(backgroundVideoPath);

      // 6. Final Merge
      final encoder = await _getBestEncoderWindows(useGpu);
      final qParam = encoder.contains('nvenc') || encoder.contains('qsv')
          ? '-q:v ${((51 - crf) / 51 * 100).toInt()}'
          : '-crf $crf';

      final metadata = [
        if (title?.isNotEmpty ?? false) '-metadata',
        'title=$title',
        if (author?.isNotEmpty ?? false) ...[
          '-metadata',
          'artist=$author',
          '-metadata',
          'author=$author',
        ],
        if (comment?.isNotEmpty ?? false) '-metadata',
        'comment=$comment',
      ];

      final loopArgs = audioDur > videoDur
          ? [
              '-stream_loop',
              '${(audioDur / videoDur).ceil()}',
              '-i',
              backgroundVideoPath,
            ]
          : ['-i', backgroundVideoPath];

      onLog?.call('Final render starting (using $encoder)...');
      final finalResult = await Process.start('ffmpeg', [
        '-y',
        ...loopArgs,
        '-i',
        mergedAudioPath,
        '-vf',
        "scale=$width:$height:force_original_aspect_ratio=decrease,pad=$width:$height:(ow-iw)/2:(oh-ih)/2",
        '-c:v',
        encoder,
        ...qParam.split(' '),
        '-preset',
        preset,
        '-c:a',
        'aac',
        '-b:a',
        '192k',
        if (enableFastStart) ...['-movflags', '+faststart'],
        ...extraFlags,
        ...metadata,
        '-shortest',
        outputPath,
      ]);

      // Pipe FFmpeg output to our log callback
      finalResult.stderr.transform(SystemEncoding().decoder).listen((data) {
        onLog?.call(data);
      });

      final exitCode = await finalResult.exitCode;
      if (exitCode != 0) throw Exception('Final merge failed');

      onProgress?.call(1.0);
      onLog?.call('Process complete! Output: $outputPath');
      return outputPath;
    } finally {
      // Cleanup
      if (await tempAudioDir.exists()) {
        await tempAudioDir.delete(recursive: true);
      }
    }
  }

  Future<double> _getDurationWindows(String path) async {
    final result = await Process.run('ffprobe', [
      '-v',
      'error',
      '-show_entries',
      'format=duration',
      '-of',
      'default=noprint_wrappers=1:nokey=1',
      path,
    ]);
    return double.tryParse(result.stdout.toString().trim()) ?? 0.0;
  }

  Future<String> _getBestEncoderWindows(bool useGpu) async {
    if (!useGpu) return 'libx264';
    try {
      final result = await Process.run('ffmpeg', ['-encoders']);
      final output = result.stdout.toString();
      if (output.contains('h264_nvenc')) return 'h264_nvenc';
      if (output.contains('h264_qsv')) return 'h264_qsv';
      if (output.contains('h264_amf')) return 'h264_amf';
    } catch (e) {
      // ffmpeg not in path
    }
    return 'libx264';
  }


  /// Extract audio from video/audio files and merge them sequentially
  Future<String> _mergeAudioFiles({
    required List<String> audioFiles,
    int concurrencyLimit = 4,
    void Function(double progress)? onProgress,
  }) async {
    if (audioFiles.isEmpty) {
      throw Exception('No audio files provided');
    }

    final tempDir = await getTemporaryDirectory();
    final mergedAudioPath =
        '${tempDir.path}/merged_audio_${DateTime.now().millisecondsSinceEpoch}.aac';

    // If only one file, extract audio directly
    if (audioFiles.length == 1) {
      await _extractAudio(audioFiles[0], mergedAudioPath);
      onProgress?.call(1.0);
      return mergedAudioPath;
    }

    // Extract audio from each file first with a concurrency limit
    final List<String> extractedAudioFiles = [];

    for (int i = 0; i < audioFiles.length; i += concurrencyLimit) {
      final end = (i + concurrencyLimit < audioFiles.length)
          ? i + concurrencyLimit
          : audioFiles.length;

      final batchTasks = <Future<void>>[];
      for (int j = i; j < end; j++) {
        final extractedPath =
            '${tempDir.path}/audio_${j}_${DateTime.now().millisecondsSinceEpoch}_${j}.aac';
        extractedAudioFiles.add(extractedPath);
        batchTasks.add(_extractAudio(audioFiles[j], extractedPath));
      }

      await Future.wait(batchTasks);
      onProgress?.call(0.1 + (0.8 * (end / audioFiles.length)));
    }

    onProgress?.call(0.9); // Mostly done with extraction

    // Create file list for concatenation
    final fileListPath =
        '${tempDir.path}/audio_list_${DateTime.now().millisecondsSinceEpoch}.txt';
    final fileList = File(fileListPath);
    final buffer = StringBuffer();
    for (final audioFile in extractedAudioFiles) {
      buffer.writeln("file '$audioFile'");
    }
    await fileList.writeAsString(buffer.toString());

    // Concatenate all audio files
    final command =
        '-f concat -safe 0 -i "$fileListPath" -c copy "$mergedAudioPath"';
    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();

    // Clean up extracted audio files
    for (final audioFile in extractedAudioFiles) {
      try {
        await File(audioFile).delete();
      } catch (e) {
        // Ignore
      }
    }

    // Clean up file list
    try {
      await fileList.delete();
    } catch (e) {
      // Ignore
    }

    if (ReturnCode.isSuccess(returnCode)) {
      return mergedAudioPath;
    } else {
      throw Exception('Failed to merge audio files');
    }
  }

  /// Extract audio from a video/audio file and convert to standard AAC
  Future<void> _extractAudio(String inputPath, String outputPath) async {
    // We explicitly re-encode to AAC at 192k to ensure all intermediate files
    // have the exact same parameters (sample rate, codec, etc.) for perfect concatenation.
    final command =
        '-i "$inputPath" -vn -acodec aac -b:a 192k -ar 44100 -ac 2 "$outputPath"';

    // Using executeAsync is sometimes more stable for parallel batches
    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();

    if (!ReturnCode.isSuccess(returnCode)) {
      final logs = await session.getAllLogs();
      final errorMessage = logs.map((log) => log.getMessage()).join('\n');
      throw Exception('Failed to process audio from $inputPath: $errorMessage');
    }
  }

  /// Get duration of a media file in seconds
  Future<double> _getMediaDuration(String mediaPath) async {
    if (Platform.isWindows) {
      return _getDurationWindows(mediaPath);
    }
    try {
      final session = await FFprobeKit.getMediaInformation(mediaPath);
      final information = session.getMediaInformation();

      if (information != null) {
        final duration = information.getDuration();
        if (duration != null) {
          return double.parse(duration) / 1000;
        }
      }
    } catch (e) {
      // Ignore errors and try to return 0 or throw later
    }

    throw Exception('Could not get duration for $mediaPath');
  }

  /// Merge audio with background video
  Future<void> _mergeAudioWithVideo({
    required String backgroundVideoPath,
    required String audioPath,
    required String outputPath,
    required double audioDuration,
    required double videoDuration,
    String? title,
    String? author,
    String? comment,
    int width = 1920,
    int height = 1080,
    String preset = 'slow',
    int crf = 18,
    bool enableFastStart = true,
    bool useGpu = true,
    List<String> extraFlags = const [],
    void Function(double progress)? onProgress,
  }) async {
    String command;
    final metadataFlags = [
      if (title != null && title.isNotEmpty) '-metadata title="$title"',
      if (author != null && author.isNotEmpty) ...[
        '-metadata artist="$author"',
        '-metadata author="$author"',
        '-metadata composer="$author"',
        '-metadata creator="$author"',
        '-metadata publisher="$author"',
      ],
      if (comment != null && comment.isNotEmpty) '-metadata comment="$comment"',
    ].join(' ');

    // Optimization flags:
    // -vf scale: Scale to target resolution, using force_original_aspect_ratio to avoid stretching
    // -preset: Better compression (smaller size at same quality)
    // -crf: Visually transparent quality
    // -movflags +faststart: Web optimization for YouTube
    final fastStartFlag = enableFastStart ? '-movflags +faststart' : '';
    final extraFlagsStr = extraFlags.join(' ');

    // Determine best encoder based on platform and user preference
    String encoder = 'libx264';
    String qualityParam = '-crf $crf';

    if (useGpu) {
      if (Platform.isMacOS) {
        encoder = 'h264_videotoolbox';
        final qValue = ((51 - crf) / 51 * 100).clamp(30, 90).toInt();
        qualityParam = '-q:v $qValue';
      } else if (Platform.isWindows) {
        final detected = await getBestAvailableHardwareEncoder();
        if (detected != null) {
          encoder = detected;
          final qValue = ((51 - crf) / 51 * 100).clamp(30, 90).toInt();
          qualityParam = '-q:v $qValue';
        }
      }
    }

    final optimizationFlags =
        '-vf "scale=$width:$height:force_original_aspect_ratio=decrease,pad=$width:$height:(ow-iw)/2:(oh-ih)/2" '
        '-c:v $encoder $qualityParam -preset $preset -c:a aac -b:a 192k $fastStartFlag $extraFlagsStr';

    if (audioDuration > videoDuration) {
      // Audio is longer - loop the video to match audio duration
      final loopCount = (audioDuration / videoDuration).ceil();
      command =
          '-stream_loop $loopCount -i "$backgroundVideoPath" -i "$audioPath" '
          '$optimizationFlags -shortest $metadataFlags "$outputPath"';
    } else {
      // Video is longer or equal - use video duration, trim audio if needed
      command =
          '-i "$backgroundVideoPath" -i "$audioPath" '
          '$optimizationFlags -shortest $metadataFlags "$outputPath"';
    }

    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();

    if (!ReturnCode.isSuccess(returnCode)) {
      final logs = await session.getAllLogs();
      final errorMessage = logs.map((log) => log.getMessage()).join('\n');
      throw Exception('Failed to merge video with audio: $errorMessage');
    }

    onProgress?.call(1.0);
  }

  /// Get media information (duration, codec, etc.)
  Future<MediaInformation?> getMediaInformation(String mediaPath) async {
    if (Platform.isWindows) {
      // On Windows, the plugin's MediaInformation class might not be fully functional
      // without the native bridge. Return null or a minimal representation if needed.
      return null;
    }
    final session = await FFprobeKit.getMediaInformation(mediaPath);
    return session.getMediaInformation();
  }
}
