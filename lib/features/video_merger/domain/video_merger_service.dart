import 'dart:io';
import 'dart:math';
import 'package:swaloka_looping_tool/core/services/system_info_service.dart';
import 'package:swaloka_looping_tool/core/services/log_service.dart';

/// Service for merging background video with sequential audio files
class VideoMergerService {
  /// Helper function to run FFmpeg command with hierarchical logging
  Future<void> runFFmpegWithLogging(
    List<String> command, {
    String? errorMessage,
    void Function(LogEntry log)? onLog,
  }) async {
    // Get FFmpeg path and extended environment
    final ffmpegPath = SystemInfoService.ffmpegPath;
    final env = SystemInfoService.extendedEnvironment;

    // Create and show command log immediately
    final commandLog = LogEntry.info(
      'Command: $ffmpegPath ${command.join(" ")}',
    );
    onLog?.call(commandLog);

    final startTime = DateTime.now();

    // Run FFmpeg with extended PATH environment
    final result = await Process.run(ffmpegPath, command, environment: env);

    final exitCode = result.exitCode;

    // Parse stdout and stderr into log entries
    final stdoutLogs = <LogEntry>[];
    final stderrLogs = <LogEntry>[];

    final stdoutStr = result.stdout as String;
    if (stdoutStr.isNotEmpty) {
      for (final line in stdoutStr.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isNotEmpty) {
          stdoutLogs.add(LogEntry.simple(LogLevel.info, trimmed));
        }
      }
    }

    final stderrStr = result.stderr as String;
    if (stderrStr.isNotEmpty) {
      for (final line in stderrStr.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isNotEmpty) {
          stderrLogs.add(LogEntry.simple(LogLevel.info, trimmed));
        }
      }
    }
    final executionDuration = DateTime.now().difference(startTime);

    // Format duration nicely
    String formatDuration(Duration duration) {
      if (duration.inSeconds == 0) {
        return '${duration.inMilliseconds}ms';
      } else if (duration.inSeconds < 60) {
        final seconds = duration.inMilliseconds / 1000;
        return '${seconds.toStringAsFixed(1)}s';
      } else {
        final minutes = duration.inMinutes;
        final seconds = duration.inSeconds % 60;
        return '${minutes}m ${seconds}s';
      }
    }

    // Create execution log with stdout and stderr as sub-logs
    final executionSubLogs = <LogEntry>[];

    if (stdoutLogs.isNotEmpty) {
      executionSubLogs.add(
        LogEntry.withSubLogs(
          LogLevel.info,
          'stdout (${stdoutLogs.length} lines)',
          stdoutLogs,
        ),
      );
    }

    if (stderrLogs.isNotEmpty) {
      executionSubLogs.add(
        LogEntry.withSubLogs(
          LogLevel.info,
          'stderr (${stderrLogs.length} lines)',
          stderrLogs,
        ),
      );
    }

    // Add execution details as sublog
    if (executionSubLogs.isNotEmpty) {
      final executionLog = LogEntry.withSubLogs(
        LogLevel.info,
        'Running FFmpeg command',
        executionSubLogs,
      );
      commandLog.addSubLog(executionLog);
    }

    // Add duration as sublog
    final durationLog = LogEntry.success(
      'FFmpeg command completed in ${formatDuration(executionDuration)}',
    );
    commandLog.addSubLog(durationLog);

    if (exitCode != 0) {
      final errorLog = LogEntry.error(
        'FFmpeg command failed with exit code $exitCode',
      );
      onLog?.call(errorLog);
      throw Exception(errorMessage ?? 'FFmpeg command failed');
    }
  }

  // Check if ffmpeg exists in system path
  Future<void> verifyFFmpegInstallation(
    void Function(LogEntry log)? onLog,
  ) async {
    onLog?.call(LogEntry.info('Checking if ffmpeg exists in system path...'));
    await SystemInfoService.isFFmpegAvailable(raiseException: true);
    onLog?.call(LogEntry.success('FFmpeg CLI found in system path.'));
  }

  // create temp directory in project folder
  Future<Directory> _createTempDirectory(
    String projectRootPath,
    void Function(LogEntry log)? onLog,
  ) async {
    onLog?.call(LogEntry.info('Creating temp directory...'));
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final tempDir = Directory('$projectRootPath/temp/swaloka_temp_$timestamp');
    await tempDir.create(recursive: true);
    onLog?.call(LogEntry.success('Temp directory created: ${tempDir.path}'));
    return tempDir;
  }

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
    for (int i = 0; i < audioFiles.length; i += concurrencyLimit) {
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
          final outPath = '${tempDir.path}/audio_part_$idx.aac';

          await runFFmpegWithLogging(
            [
              '-y',
              '-i',
              inputPath,
              '-vn',
              '-acodec',
              'aac',
              '-ar',
              '44100',
              '-ac',
              '2',
              '-b:a',
              '192k',
              outPath,
            ],
            errorMessage: 'Failed to extract audio from $inputPath',
            onLog: (log) => batchLog.addSubLog(log),
          );
          extractedFiles.add(outPath);
        }),
      );
    }
    final concatFilePath = '${tempDir.path}/audio_concat.txt';
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
      for (int loop = 1; loop < audioLoopCount; loop++) {
        final filesToConcat = List<String>.from(extractedFiles);
        filesToConcat.shuffle(Random());
        concatFiles.addAll(filesToConcat);
      }

      // Add looping info as sublog
      processLog.addSubLog(
        LogEntry.info(
          'Looping audio $audioLoopCount times (first loop: original order, subsequent loops: randomized)',
        ),
      );
    }

    final concatContent = concatFiles
        .map((f) => "file '${f.replaceAll("'", "'\\''")}'")
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
    final mergedAudioPath = '${tempDir.path}/audio_merged.aac';

    // Create parent log for merging operation
    final mergeLog = LogEntry.info('Merging audio tracks...');
    onLog?.call(mergeLog);

    await runFFmpegWithLogging(
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
      onLog: (log) => mergeLog.addSubLog(log),
    );

    // Mark merge as complete
    mergeLog.addSubLog(
      LogEntry.success('Audio tracks merged successfully: $mergedAudioPath'),
    );

    return mergedAudioPath;
    // end of _mergeAudioFiles
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
      backgroundVideoPath,
      '-i',
      mergedAudioPath,
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
      outputPath,
      '-y',
    ];

    await runFFmpegWithLogging(
      command,
      errorMessage: 'Failed to merge video',
      onLog: (log) => videoMergeLog.addSubLog(log),
    );

    // Mark merge as complete
    videoMergeLog.addSubLog(
      LogEntry.success('Video merge complete! Output: $outputPath'),
    );

    return outputPath;
    // end of _mergeVideoWithAudioFiles
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
    void Function(double progress)? onProgress,
    void Function(LogEntry log)? onLog,
  }) async {
    await verifyFFmpegInstallation(onLog);
    onProgress?.call(0.2);
    final tempDir = await _createTempDirectory(projectRootPath, onLog);
    try {
      final concatFilePath = await _concatAudioFiles(
        audioFiles,
        tempDir,
        audioLoopCount,
        concurrencyLimit,
        onLog,
      );
      onProgress?.call(0.4);
      final mergedAudioPath = await _mergeAudioFiles(
        tempDir,
        concatFilePath,
        onLog,
      );
      onProgress?.call(0.6);
      final metadataFlags = _buildMetadataFlags(title, author, comment);
      await _mergeVideoWithAudioFiles(
        backgroundVideoPath,
        outputPath,
        mergedAudioPath,
        metadataFlags,
        onLog,
      );
      onProgress?.call(1.0);
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

  // Build metadata flags
  List<String> _buildMetadataFlags(
    String? title,
    String? author,
    String? comment,
  ) {
    final metadataFlags = <String>[];
    if (title != null) {
      metadataFlags.addAll(['-metadata', 'title=$title']);
    }
    if (author != null) {
      // depending on the platform/ffmpeg installation it might accept artist or author. So we add both.
      metadataFlags.addAll(['-metadata', 'artist=$author']);
      metadataFlags.addAll(['-metadata', 'author=$author']);
    }
    if (comment != null) {
      metadataFlags.addAll(['-metadata', 'comment=$comment']);
    }
    return metadataFlags;
  }

  // end close of class VideoMergerService
}
