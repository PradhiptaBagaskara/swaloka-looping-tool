import 'dart:io';
import 'dart:math';
import 'package:path/path.dart' as p;
import 'package:swaloka_looping_tool/core/services/ffmpeg_service.dart';
import 'package:swaloka_looping_tool/core/services/log_service.dart';
import 'package:swaloka_looping_tool/core/utils/temp_directory_helper.dart';
import 'package:swaloka_looping_tool/features/video_merger/domain/models/swaloka_project.dart';

/// Service for merging background video with sequential audio files
class VideoMergerService {
  // Concat audio files
  Future<String> _concatAudioFiles(
    List<String> audioFiles,
    Directory tempDir,
    int audioLoopCount,
    int concurrencyLimit,
    void Function(LogEntry log)? onLog,
  ) async {
    final processLog = LogEntry.info(
      'Processing ${audioFiles.length} audio file(s)...',
    );
    onLog?.call(processLog);

    final extractedFiles = <String>[];
    for (var i = 0; i < audioFiles.length; i += concurrencyLimit) {
      final end = (i + concurrencyLimit < audioFiles.length)
          ? i + concurrencyLimit
          : audioFiles.length;
      final batch = audioFiles.sublist(i, end);

      final batchLog = LogEntry.info(
        'Extracting audio batch ${(i ~/ concurrencyLimit) + 1}...',
      );
      processLog.addSubLog(batchLog);

      await Future.wait(
        batch.asMap().entries.map((entry) async {
          final idx = i + entry.key;
          final inputPath = entry.value;
          final outPath = p.join(tempDir.path, 'audio_part_$idx.aac');

          await FFmpegService.run(
            [
              '-y',
              '-i',
              p.absolute(inputPath),
              '-vn',
              '-acodec',
              'aac',
              '-ar',
              '44100',
              '-ac',
              '2',
              '-b:a',
              '192k',
              p.absolute(outPath),
            ],
            errorMessage: 'Failed to extract audio from $inputPath',
            onLog: batchLog.addSubLog,
          );
          extractedFiles.add(outPath);
        }),
      );
    }
    final concatFilePath = p.join(tempDir.path, 'audio_concat.txt');
    final concatFiles = <String>[];

    // First iteration: Always use original order from UI
    // This ensures the first play through matches the user's intended sequence
    concatFiles.addAll(extractedFiles);

    if (audioLoopCount > 1) {
      // Subsequent iterations: Shuffle each time for variety
      // Example with 3 files and loopCount=3:
      //   Loop 1: [file1, file2, file3] <- original order
      //   Loop 2: [file2, file3, file1] <- shuffled
      //   Loop 3: [file3, file1, file2] <- shuffled again
      for (var loop = 1; loop < audioLoopCount; loop++) {
        final filesToConcat = List<String>.from(extractedFiles);
        filesToConcat.shuffle(Random());
        concatFiles.addAll(filesToConcat);
      }

      processLog.addSubLog(
        LogEntry.info(
          'Looping audio $audioLoopCount times (first loop: original order, subsequent loops: randomized)',
        ),
      );
    }

    final concatContent = concatFiles
        .map((f) => "file '${_formatPathForConcatFile(f)}'")
        .join('\n');
    await File(concatFilePath).writeAsString(concatContent);

    // Mark processing as complete
    processLog.addSubLog(LogEntry.success('Audio processing completed'));

    return concatFilePath;
  }

  // Merge audio files
  Future<String> _mergeAudioFiles(
    Directory tempDir,
    String concatFilePath,
    void Function(LogEntry log)? onLog,
  ) async {
    final mergedAudioPath = p.join(tempDir.path, 'audio_merged.aac');

    // Create parent log for merging operation
    final mergeLog = LogEntry.info('Merging audio tracks...');
    onLog?.call(mergeLog);

    await FFmpegService.run(
      [
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
      ],
      errorMessage: 'Failed to merge audio tracks',
      onLog: mergeLog.addSubLog,
    );

    // Mark merge as complete
    mergeLog.addSubLog(
      LogEntry.success('Audio tracks merged successfully: $mergedAudioPath'),
    );

    return mergedAudioPath;
  }

  // Process audio files
  Future<String> _mergeVideoWithAudioFiles(
    String backgroundVideoPath,
    String outputPath,
    String mergedAudioPath,
    List<String> metadataFlags,
    void Function(LogEntry log)? onLog,
  ) async {
    // 6. Fast mode: Loop video to match audio duration
    // -stream_loop -1 applies to next input (background video)
    // -shortest ensures we stop when audio ends

    // Create parent log for video merge operation
    final videoMergeLog = LogEntry.info('Merging video with audio...');
    onLog?.call(videoMergeLog);

    // Build optimized FFmpeg command
    final command = [
      '-stream_loop',
      '-1',
      '-i',
      p.absolute(backgroundVideoPath),
      '-i',
      p.absolute(mergedAudioPath),
      '-map',
      '0:v',
      '-map',
      '1:a',
      '-c:v',
      'copy',
      '-c:a',
      'copy',
      '-shortest',
      ...metadataFlags,
      p.absolute(outputPath),
      '-y',
    ];

    await FFmpegService.run(
      command,
      errorMessage: 'Failed to merge video',
      onLog: videoMergeLog.addSubLog,
    );

    return outputPath;
  }

  /// Prepare intro video (ensure AAC audio)
  Future<String> _prepareIntro(
    String introVideoPath,
    bool introKeepAudio,
    Directory tempDir,
    void Function(LogEntry log)? onLog,
  ) async {
    final preparedIntroPath = p.join(tempDir.path, 'intro_prepared.mp4');
    final log = LogEntry.info('Preparing intro video...');
    onLog?.call(log);

    final List<String> command;

    if (introKeepAudio) {
      // Check if intro has audio (naive check by trying to copy audio)
      // We'll just try to convert to AAC. If input has no audio, this might fail or produce silent audio.
      // Safer approach: Use a complex filter that mixes with nullsrc, but that requires re-encoding.
      // For now, let's try strict AAC conversion. If the input has no audio stream, FFmpeg will likely complain.
      // A robust way: use -f lavfi -i anullsrc and map it IF audio is missing.
      // But we can't easily detect if audio is missing without probing.
      //
      // Compromise: Assume intro has audio if user says "Keep Audio".
      // If they say "Keep Audio" but file has none, we might want to fail-safe to silence.
      //
      // Let's implement the "mute" logic clearly first.
      command = [
        '-i',
        p.absolute(introVideoPath),
        '-c:v',
        'copy', // Copy video stream
        '-c:a',
        'aac', // Transcode audio to AAC
        '-b:a',
        '192k',
        p.absolute(preparedIntroPath),
        '-y',
      ];
    } else {
      // Mute audio: Generate silence
      command = [
        '-i',
        p.absolute(introVideoPath),
        '-f',
        'lavfi',
        '-i',
        'anullsrc=channel_layout=stereo:sample_rate=44100',
        '-c:v',
        'copy',
        '-c:a',
        'aac',
        '-shortest', // Stop when video ends
        '-map',
        '0:v',
        '-map',
        '1:a',
        p.absolute(preparedIntroPath),
        '-y',
      ];
    }

    try {
      await FFmpegService.run(
        command,
        errorMessage: 'Failed to prepare intro video',
        onLog: log.addSubLog,
      );
    } catch (e) {
      // Fallback: If "Keep Audio" failed (likely no audio stream), try mute approach
      if (introKeepAudio) {
        log.addSubLog(
          LogEntry.warning(
            'Failed to keep intro audio (maybe no audio stream?), falling back to silent audio...',
          ),
        );
        await _prepareIntro(introVideoPath, false, tempDir, onLog);
        return preparedIntroPath;
      }
      rethrow;
    }

    log.addSubLog(LogEntry.success('Intro prepared: $preparedIntroPath'));
    return preparedIntroPath;
  }

  /// Concatenate intro with main content using stream copy (fast & lossless)
  Future<void> _concatIntroWithMain(
    String introPath,
    String mainPath,
    String outputPath,
    Directory tempDir,
    List<String> metadataFlags,
    void Function(LogEntry log)? onLog,
  ) async {
    final log = LogEntry.info('Concatenating intro with main content...');
    onLog?.call(log);

    final concatListPath = p.join(tempDir.path, 'concat_list.txt');
    final concatContent = [
      "file '${_formatPathForConcatFile(introPath)}'",
      "file '${_formatPathForConcatFile(mainPath)}'",
    ].join('\n');
    await File(concatListPath).writeAsString(concatContent);

    // Stream copy (fastest, but requires compatible formats)
    log.addSubLog(LogEntry.info('Using stream copy for concatenation...'));
    try {
      await FFmpegService.run(
        [
          '-f',
          'concat',
          '-safe',
          '0',
          '-i',
          concatListPath,
          '-c',
          'copy',
          ...metadataFlags,
          p.absolute(outputPath),
          '-y',
        ],
        errorMessage: 'Stream copy concat failed',
        onLog: log.addSubLog,
      );
      log.addSubLog(LogEntry.success('Stream copy concatenation successful'));
    } on Exception catch (e) {
      // Provide helpful error message
      throw Exception(
        'Failed to concatenate intro with main video. '
        'Videos must have matching formats (codec, resolution, fps). '
        'Tip: Use "Video Tools" to compress/re-encode your intro video '
        "to match the main video's format before adding it here. "
        'Original error: $e',
      );
    }
  }

  Future<String> processVideoWithAudio({
    required String backgroundVideoPath,
    required List<String> audioFiles,
    required String outputPath,
    required String projectRootPath,
    String? title,
    String? author,
    String? comment,
    int concurrencyLimit = 4,
    int audioLoopCount = 1,
    String? introVideoPath,
    IntroAudioMode introAudioMode = IntroAudioMode.keepOriginal,
    void Function(double progress)? onProgress,
    void Function(LogEntry log)? onLog,
  }) async {
    await FFmpegService.verifyInstallation(onLog);
    onProgress?.call(0.1);

    final tempDir = await TempDirectoryHelper.create(
      fallbackBasePath: projectRootPath,
      prefix: 'swaloka_merger',
      onLog: onLog,
    );
    try {
      // 1. Concat audio files
      final concatFilePath = await _concatAudioFiles(
        audioFiles,
        tempDir,
        audioLoopCount,
        concurrencyLimit,
        onLog,
      );
      onProgress?.call(0.3);

      // 2. Merge audio into single track
      final mergedAudioPath = await _mergeAudioFiles(
        tempDir,
        concatFilePath,
        onLog,
      );
      onProgress?.call(0.5);

      final metadataFlags = _buildMetadataFlags(title, author, comment);

      // If no intro, output directly to final path
      if (introVideoPath == null) {
        await _mergeVideoWithAudioFiles(
          backgroundVideoPath,
          outputPath,
          mergedAudioPath,
          metadataFlags,
          onLog,
        );
      } else {
        // If intro exists:
        // a. Generate looped content to temp file
        final loopedContentPath = p.join(tempDir.path, 'looped_content.mp4');
        await _mergeVideoWithAudioFiles(
          backgroundVideoPath,
          loopedContentPath,
          mergedAudioPath,
          [], // Metadata applied at final stage
          onLog,
        );
        onProgress?.call(0.7);

        // b. Prepare intro (standardize audio)
        // If overlayPlaylist mode, we use silent audio for intro to allow clean concat
        // before we replace the audio track completely.
        final shouldKeepAudio = introAudioMode == IntroAudioMode.keepOriginal;

        final preparedIntroPath = await _prepareIntro(
          introVideoPath,
          shouldKeepAudio,
          tempDir,
          onLog,
        );
        onProgress?.call(0.8);

        if (introAudioMode == IntroAudioMode.overlayPlaylist) {
          // OVERLAY MODE: Concat video streams, then mux with main audio from start
          final tempConcatPath = p.join(tempDir.path, 'temp_concat.mp4');

          // c. Concatenate intro + looped content (creates temporary file)
          await _concatIntroWithMain(
            preparedIntroPath,
            loopedContentPath,
            tempConcatPath,
            tempDir,
            [], // No metadata yet
            onLog,
          );

          // d. Overlay main audio on the concatenated video
          final log = LogEntry.info('Overlaying main audio playlist...');
          onLog?.call(log);

          await FFmpegService.run(
            [
              '-i',
              p.absolute(tempConcatPath),
              '-i',
              p.absolute(mergedAudioPath),
              '-map',
              '0:v', // Video from concat
              '-map',
              '1:a', // Audio from merged playlist
              '-c:v',
              'copy',
              '-c:a',
              'copy',
              '-shortest', // Cut video when audio ends
              ...metadataFlags,
              p.absolute(outputPath),
              '-y',
            ],
            errorMessage: 'Failed to overlay audio',
            onLog: log.addSubLog,
          );
          log.addSubLog(LogEntry.success('Audio overlay successful'));
        } else {
          // PREPEND MODE: Just concat (Intro Audio + Main Audio)
          await _concatIntroWithMain(
            preparedIntroPath,
            loopedContentPath,
            outputPath,
            tempDir,
            metadataFlags,
            onLog,
          );
        }
      }

      onProgress?.call(1);
      onLog?.call(
        LogEntry.success('Video merge complete! Output: $outputPath'),
      );
      return outputPath;
    } finally {
      // Cleanup
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    }
  }

  // Helper to format path specifically for FFmpeg concat demuxer text files
  // Handles normalization, Windows path separators, and single-quote escaping.
  String _formatPathForConcatFile(String path) {
    var safePath = p.normalize(path);
    if (Platform.isWindows) {
      safePath = safePath.replaceAll(r'\', '/');
    }
    return safePath.replaceAll("'", r"'\''");
  }

  // Build metadata flags
  List<String> _buildMetadataFlags(
    String? title,
    String? author,
    String? comment,
  ) {
    final metadataFlags = <String>[];
    if (title != null && title.isNotEmpty) {
      metadataFlags.addAll(['-metadata', 'title=$title']);
    }
    if (author != null && author.isNotEmpty) {
      // depending on the platform/ffmpeg installation it might accept artist or author. So we add both.
      metadataFlags.addAll(['-metadata', 'artist=$author']);
      metadataFlags.addAll(['-metadata', 'author=$author']);
    }
    if (comment != null && comment.isNotEmpty) {
      metadataFlags.addAll(['-metadata', 'comment=$comment']);
    }
    return metadataFlags;
  }
}
