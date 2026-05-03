import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:path/path.dart' as p;
import 'package:swaloka_looping_tool/core/services/ffmpeg_service.dart';
import 'package:swaloka_looping_tool/core/services/log_service.dart';
import 'package:swaloka_looping_tool/core/utils/temp_directory_helper.dart';

/// Service for merging background video with sequential audio files
class VideoMergerService {
  static const int _estimatedAudioBitrateKbps = 192;
  static const double _diskEstimateSafetyMultiplier = 1.2;
  static const double _preprocessedBackgroundMinimumSeconds = 600;
  static const _cacheDirectoryName = 'cache';
  static const _audioCacheDirectoryName = 'audios';
  static const _audioCacheManifestFileName = 'audio_cache.json';

  String _formatPathForConcatFile(String path) {
    var safePath = p.normalize(path);
    if (Platform.isWindows) {
      safePath = safePath.replaceAll(r'\', '/');
    }
    return safePath.replaceAll("'", r"'\''");
  }

  Future<double?> _getAudioDurationSeconds(String audioPath) async {
    try {
      final result = await Process.run(
        FFmpegService.ffprobePath,
        [
          '-v',
          'error',
          '-show_entries',
          'format=duration',
          '-of',
          'default=noprint_wrappers=1:nokey=1',
          p.absolute(audioPath),
        ],
        environment: FFmpegService.extendedEnvironment,
      );
      if (result.exitCode != 0) return null;
      final out = (result.stdout as String).trim();
      if (out.isEmpty) return null;
      return double.tryParse(out);
    } on Exception catch (_) {
      return null;
    }
  }

  /// Check if audio file is already in AAC format based on extension
  /// .m4a and .aac files typically use AAC codec
  bool _isAudioAlreadyAAC(String audioPath) {
    final ext = p.extension(audioPath).toLowerCase();
    return ext == '.m4a' || ext == '.aac';
  }

  /// Check multiple audio files for AAC format
  /// Based on file extensions (.m4a, .aac)
  List<bool> _checkAudioFilesAAC(List<String> audioPaths) {
    return audioPaths.map(_isAudioAlreadyAAC).toList();
  }

  Future<List<String>> _normalizeAudioFilesToAacM4a({
    required List<String> audioFiles,
    required String projectRootPath,
    void Function(LogEntry log)? onLog,
  }) async {
    final log = LogEntry.info(
      'Checking ${audioFiles.length} audio file(s) for AAC format...',
    );
    onLog?.call(log);

    if (audioFiles.isEmpty) return [];

    // Check all files by extension
    final isAACResults = _checkAudioFilesAAC(audioFiles);

    // Separate files into already AAC vs needs conversion
    final normalized = List<String?>.filled(audioFiles.length, null);
    final needsConversion =
        <({int originalIndex, String sourcePath, String outputPath})>[];
    final cacheManifest = await _readAudioCacheManifest(projectRootPath);

    for (var i = 0; i < audioFiles.length; i++) {
      final sourcePath = p.normalize(p.absolute(audioFiles[i]));
      final sourceCacheKey = await _buildAudioCacheKey(sourcePath);
      if (isAACResults[i]) {
        normalized[i] = sourcePath;
        log.addSubLog(
          LogEntry.info('✓ Already AAC: ${p.basename(sourcePath)}'),
        );
      } else {
        final cachedPath = cacheManifest[sourceCacheKey];
        if (cachedPath != null && await File(cachedPath).exists()) {
          normalized[i] = p.normalize(cachedPath);
          log.addSubLog(
            LogEntry.info('✓ Cache hit: ${p.basename(sourcePath)}'),
          );
          continue;
        }
        final outputPath = _buildCachedAudioPath(
          projectRootPath: projectRootPath,
          sourcePath: sourcePath,
          sourceCacheKey: sourceCacheKey,
        );
        needsConversion.add(
          (
            originalIndex: i,
            sourcePath: sourcePath,
            outputPath: outputPath,
          ),
        );
      }
    }

    // Convert files that need it
    if (needsConversion.isNotEmpty) {
      final convertLog = LogEntry.info(
        'Converting ${needsConversion.length} file(s) to AAC (cache miss)...',
      );
      log.addSubLog(convertLog);

      final converted = await _executeSingleRunFFmpeg(
        needsConversion,
        parentLog: convertLog,
      );

      for (final item in converted) {
        normalized[item.index] = item.path;
        final cacheKey = await _buildAudioCacheKey(item.sourcePath);
        cacheManifest[cacheKey] = item.path;
      }

      await _writeAudioCacheManifest(
        projectRootPath: projectRootPath,
        manifest: cacheManifest,
      );

      convertLog.addSubLog(
        LogEntry.success(
          'Conversion complete: ${converted.length} file(s) processed',
        ),
      );
    }

    log.addSubLog(
      LogEntry.success(
        'Audio check complete: ${audioFiles.length - needsConversion.length} skipped, ${needsConversion.length} converted',
      ),
    );

    if (normalized.any((e) => e == null)) {
      throw Exception('Failed to normalize all audio files');
    }

    return normalized.cast<String>();
  }

  // Helper function to run one FFmpeg command for multiple files
  Future<List<({int index, String path, String sourcePath})>>
  _executeSingleRunFFmpeg(
    List<({int originalIndex, String sourcePath, String outputPath})> inputs, {
    required LogEntry parentLog,
  }) async {
    final batchLog = LogEntry.info(
      'Processing batch of ${inputs.length} file(s)...',
    );
    parentLog.addSubLog(batchLog);

    final args = ['-y'];

    // Add all inputs in this batch
    for (final input in inputs) {
      args.addAll(['-i', p.absolute(input.sourcePath)]);
    }

    final results = <({int index, String path, String sourcePath})>[];

    // Map each input to its output
    for (var i = 0; i < inputs.length; i++) {
      final idx = inputs[i].originalIndex;
      final outPath = inputs[i].outputPath;

      args.addAll([
        '-map',
        '$i:a',
        '-vn',
        '-c:a',
        'aac',
        '-b:a',
        '192k', // 192kbps standard for MP3, good balance of quality and size
        '-ar',
        '44100', // 44.1kHz ideal for music, speed and quality balance
        '-ac',
        '2', // Stereo
        p.absolute(outPath),
      ]);

      results.add(
        (
          index: idx,
          path: p.normalize(outPath),
          sourcePath: p.normalize(inputs[i].sourcePath),
        ),
      );
    }

    await FFmpegService.run(
      args,
      errorMessage: 'Failed to process audio normalization batch',
      onLog: batchLog.addSubLog,
    );

    batchLog.addSubLog(
      LogEntry.success('Batch complete: ${inputs.length} file(s) processed'),
    );

    return results;
  }

  String _cacheRootPath(String projectRootPath) {
    return p.join(projectRootPath, _cacheDirectoryName);
  }

  String _audioCacheDirectoryPath(String projectRootPath) {
    return p.join(_cacheRootPath(projectRootPath), _audioCacheDirectoryName);
  }

  String _audioCacheManifestPath(String projectRootPath) {
    return p.join(_cacheRootPath(projectRootPath), _audioCacheManifestFileName);
  }

  BigInt _fnv1a64(String value) {
    var hash = BigInt.parse('cbf29ce484222325', radix: 16);
    final prime = BigInt.from(0x100000001b3);
    final mask = BigInt.parse('7fffffffffffffff', radix: 16);
    for (final code in value.codeUnits) {
      hash ^= BigInt.from(code);
      hash = (hash * prime) & mask;
    }
    return hash;
  }

  String _buildCachedAudioPath({
    required String projectRootPath,
    required String sourcePath,
    required String sourceCacheKey,
  }) {
    final sourceNormalized = p.normalize(p.absolute(sourcePath));
    final sourceBase = p.basenameWithoutExtension(sourceNormalized);
    final safeBase = sourceBase.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    final shortBase = safeBase.isEmpty
        ? 'audio'
        : (safeBase.length <= 48 ? safeBase : safeBase.substring(0, 48));
    final hashHex = _fnv1a64(sourceCacheKey).toRadixString(16);
    final filename = '${shortBase}_$hashHex.m4a';
    return p.join(_audioCacheDirectoryPath(projectRootPath), filename);
  }

  Future<String> _buildAudioCacheKey(String sourcePath) async {
    final absolutePath = p.normalize(p.absolute(sourcePath));
    var canonicalPath = absolutePath;
    try {
      canonicalPath = p.normalize(
        await File(absolutePath).resolveSymbolicLinks(),
      );
    } on Exception {
      // Keep absolute normalized path when canonical resolution fails.
      canonicalPath = absolutePath;
    }
    if (Platform.isWindows || Platform.isMacOS) {
      canonicalPath = canonicalPath.toLowerCase();
    }
    return canonicalPath;
  }

  Future<Map<String, String>> _readAudioCacheManifest(
    String projectRootPath,
  ) async {
    final cacheDir = Directory(_cacheRootPath(projectRootPath));
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    final audioCacheDir = Directory(_audioCacheDirectoryPath(projectRootPath));
    if (!await audioCacheDir.exists()) {
      await audioCacheDir.create(recursive: true);
    }

    final manifestFile = File(_audioCacheManifestPath(projectRootPath));
    if (!await manifestFile.exists()) {
      return {};
    }

    try {
      final raw = await manifestFile.readAsString();
      if (raw.trim().isEmpty) return {};
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return {};
      return {
        for (final entry in decoded.entries)
          p.normalize(entry.key): p.normalize(entry.value as String),
      };
    } on Exception {
      return {};
    }
  }

  Future<void> _writeAudioCacheManifest({
    required String projectRootPath,
    required Map<String, String> manifest,
  }) async {
    final manifestFile = File(_audioCacheManifestPath(projectRootPath));
    final normalized = <String, String>{
      for (final entry in manifest.entries)
        p.normalize(entry.key): p.normalize(entry.value),
    };
    final content = const JsonEncoder.withIndent('  ').convert(normalized);
    await manifestFile.writeAsString(content);
  }

  Future<int> clearGlobalAudioCache({
    required String projectRootPath,
    void Function(LogEntry log)? onLog,
  }) async {
    final cacheRoot = Directory(_cacheRootPath(projectRootPath));
    final audioCacheDir = Directory(_audioCacheDirectoryPath(projectRootPath));
    final manifestFile = File(_audioCacheManifestPath(projectRootPath));
    final logsDir = Directory(p.join(projectRootPath, 'logs'));

    var removedAudioCount = 0;

    if (await audioCacheDir.exists()) {
      final entities = await audioCacheDir.list().toList();
      for (final entity in entities) {
        if (entity is File) {
          try {
            await entity.delete();
            removedAudioCount++;
          } on Exception {
            // Ignore single file deletion failure and continue.
          }
        }
      }
      try {
        await audioCacheDir.delete();
      } on Exception {
        // Ignore directory delete failure.
      }
    }

    if (await manifestFile.exists()) {
      try {
        await manifestFile.delete();
      } on Exception {
        // Ignore manifest deletion failure.
      }
    }

    if (await cacheRoot.exists()) {
      final remaining = await cacheRoot.list().isEmpty;
      if (remaining) {
        try {
          await cacheRoot.delete();
        } on Exception {
          // Ignore root deletion failure.
        }
      }
    }

    final removedLogCount = await _clearLogsDirectory(logsDir);
    final removedCount = removedAudioCount + removedLogCount;

    onLog?.call(
      LogEntry.success(
        'Cache cleaned: $removedAudioCount audio file(s), '
        '$removedLogCount log file(s)',
      ),
    );
    return removedCount;
  }

  Future<int> _clearLogsDirectory(Directory logsDir) async {
    if (!await logsDir.exists()) return 0;

    var removedLogs = 0;
    await for (final entity in logsDir.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is File) {
        try {
          await entity.delete();
          removedLogs++;
        } on Exception {
          // Ignore single log deletion failure and continue.
        }
      }
    }
    return removedLogs;
  }

  List<int> _buildAudioPlaylistOrder(
    int totalAudioFiles,
    int audioLoopCount,
    void Function(LogEntry log)? onLog,
  ) {
    final processLog = LogEntry.info(
      'Building audio playlist from $totalAudioFiles file(s)...',
    );
    onLog?.call(processLog);

    final orderedIndexes = List<int>.generate(totalAudioFiles, (i) => i);
    final playlistOrder = <int>[];

    // First iteration: Always use original order from UI
    // This ensures the first play through matches the user's intended sequence
    playlistOrder.addAll(orderedIndexes);

    if (audioLoopCount > 1) {
      // Subsequent iterations: Shuffle each time for variety
      // Example with 3 files and loopCount=3:
      //   Loop 1: [file1, file2, file3] <- original order
      //   Loop 2: [file2, file3, file1] <- shuffled
      //   Loop 3: [file3, file1, file2] <- shuffled again
      for (var loop = 1; loop < audioLoopCount; loop++) {
        final filesToConcat = List<int>.from(orderedIndexes);
        filesToConcat.shuffle(Random());
        playlistOrder.addAll(filesToConcat);
      }

      processLog.addSubLog(
        LogEntry.info(
          'Looping audio $audioLoopCount times (first loop: original order, subsequent loops: randomized)',
        ),
      );
    }

    processLog.addSubLog(
      LogEntry.success(
        'Audio playlist ready (${playlistOrder.length} item(s))',
      ),
    );
    return playlistOrder;
  }

  List<String> _applyPlaylistOrder(List<String> sourceFiles, List<int> order) {
    return order.map((idx) => sourceFiles[idx]).toList();
  }

  String _formatTimestamp(double seconds) {
    final totalSeconds = seconds.floor();
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final secs = totalSeconds % 60;
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    if (minutes == 0) {
      return '0:${secs.toString().padLeft(2, '0')}';
    }
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  Future<void> _writeYouTubeTimestampFile({
    required String outputPath,
    required List<String> playlistSourceFiles,
    void Function(LogEntry log)? onLog,
  }) async {
    if (playlistSourceFiles.isEmpty) return;

    final timestampLog = LogEntry.info('Generating YouTube timestamp file...');
    onLog?.call(timestampLog);

    final durationCache = <String, double>{};
    var accumulatedSeconds = 0.0;
    final lines = <String>[];

    for (final sourcePath in playlistSourceFiles) {
      final startTimestamp = _formatTimestamp(accumulatedSeconds);
      final title = p.basenameWithoutExtension(sourcePath);
      lines.add('$startTimestamp - $title');

      if (!durationCache.containsKey(sourcePath)) {
        durationCache[sourcePath] =
            await _getAudioDurationSeconds(sourcePath) ?? 0;
      }
      accumulatedSeconds += durationCache[sourcePath]!;
    }

    final outputDir = p.dirname(outputPath);
    final outputBase = p.basenameWithoutExtension(outputPath);
    final timestampPath = p.join(outputDir, '${outputBase}_timestamp.txt');
    await File(timestampPath).writeAsString(lines.join('\n'));

    timestampLog.addSubLog(
      LogEntry.success('YouTube timestamp file created: $timestampPath'),
    );
  }

  Future<String> _mergeAudioPlaylist(
    Directory tempDir,
    List<String> playlistFiles,
    void Function(LogEntry log)? onLog,
  ) async {
    final mergedAudioPath = p.join(tempDir.path, 'audio_merged.m4a');

    // Create parent log for merging operation
    final mergeLog = LogEntry.info('Concatenating audio playlist...');
    onLog?.call(mergeLog);

    if (playlistFiles.isEmpty) {
      throw Exception('No audio files to merge');
    }

    final concatListPath = p.join(tempDir.path, 'audio_concat.txt');
    final concatContent = playlistFiles
        .map((f) => "file '${_formatPathForConcatFile(f)}'")
        .join('\n');
    await File(concatListPath).writeAsString(concatContent);

    final cmd = <String>[
      '-y',
      '-f',
      'concat',
      '-safe',
      '0',
      '-i',
      concatListPath,
      '-vn',
      '-c',
      'copy',
      p.absolute(mergedAudioPath),
    ];

    await FFmpegService.run(
      cmd,
      errorMessage: 'Failed to merge audio tracks',
      onLog: mergeLog.addSubLog,
    );

    // Mark merge as complete
    mergeLog.addSubLog(
      LogEntry.success('Audio tracks merged successfully: $mergedAudioPath'),
    );

    return mergedAudioPath;
  }

  Future<double?> _getVideoDurationSeconds(String videoPath) async {
    try {
      final meta = await FFmpegService.getVideoMetadata(videoPath);
      if (meta.duration != null) {
        return meta.duration!.inMilliseconds / 1000.0;
      }
      return null;
    } on Exception catch (_) {
      return null;
    }
  }

  Future<int?> _getVideoBitrateKbps(String videoPath) async {
    try {
      final meta = await FFmpegService.getVideoMetadata(videoPath);
      return meta.bitrate;
    } on Exception catch (_) {
      return null;
    }
  }

  int _estimateBytesFromBitrateKbps({
    required double durationSeconds,
    required int bitrateKbps,
  }) {
    final bits = durationSeconds * bitrateKbps * 1000;
    return (bits / 8).ceil();
  }

  Future<
    ({
      int estimatedOutputBytes,
      int estimatedTempPeakBytes,
      int estimatedRequiredBytes,
      double estimatedDurationSeconds,
      int videoBitrateKbps,
      int audioBitrateKbps,
    })
  >
  estimateDiskUsage({
    required String backgroundVideoPath,
    required List<String> audioFiles,
    int audioLoopCount = 1,
    String? introVideoPath,
    void Function(LogEntry log)? onLog,
  }) async {
    final estimateLog = LogEntry.info(
      'Estimating disk usage for video merge...',
    );
    onLog?.call(estimateLog);

    var singleLoopAudioSeconds = 0.0;
    for (final audioPath in audioFiles) {
      singleLoopAudioSeconds += await _getAudioDurationSeconds(audioPath) ?? 0;
    }

    var estimatedDurationSeconds = singleLoopAudioSeconds * audioLoopCount;
    if (estimatedDurationSeconds <= 0) {
      // Fallback when one or more audio durations cannot be read.
      estimatedDurationSeconds =
          max(1, audioFiles.length * audioLoopCount) * 180.0;
      estimateLog.addSubLog(
        LogEntry.info(
          'Audio duration metadata incomplete, using fallback estimate',
        ),
      );
    }

    final backgroundBitrateKbps =
        await _getVideoBitrateKbps(backgroundVideoPath) ?? 8000;
    final introBitrateKbps = introVideoPath == null
        ? null
        : await _getVideoBitrateKbps(introVideoPath);
    final selectedVideoBitrateKbps = introBitrateKbps == null
        ? backgroundBitrateKbps
        : max(backgroundBitrateKbps, introBitrateKbps);

    final estimatedOutputBytes = _estimateBytesFromBitrateKbps(
      durationSeconds: estimatedDurationSeconds,
      bitrateKbps: selectedVideoBitrateKbps + _estimatedAudioBitrateKbps,
    );

    var estimatedTempPeakBytes = _estimateBytesFromBitrateKbps(
      durationSeconds: estimatedDurationSeconds,
      bitrateKbps: _estimatedAudioBitrateKbps,
    );

    if (introVideoPath != null) {
      final bgDurationSeconds = await _getVideoDurationSeconds(
        backgroundVideoPath,
      );
      if (bgDurationSeconds != null &&
          bgDurationSeconds > 0 &&
          bgDurationSeconds < _preprocessedBackgroundMinimumSeconds) {
        estimatedTempPeakBytes += _estimateBytesFromBitrateKbps(
          durationSeconds: _preprocessedBackgroundMinimumSeconds,
          bitrateKbps: backgroundBitrateKbps,
        );
      }
    }

    final estimatedRequiredBytes =
        ((estimatedOutputBytes + estimatedTempPeakBytes) *
                _diskEstimateSafetyMultiplier)
            .ceil();

    estimateLog.addSubLog(
      LogEntry.success(
        'Disk estimate ready: output=${estimatedOutputBytes}B, peak-temp=${estimatedTempPeakBytes}B, required=${estimatedRequiredBytes}B',
      ),
    );

    return (
      estimatedOutputBytes: estimatedOutputBytes,
      estimatedTempPeakBytes: estimatedTempPeakBytes,
      estimatedRequiredBytes: estimatedRequiredBytes,
      estimatedDurationSeconds: estimatedDurationSeconds,
      videoBitrateKbps: selectedVideoBitrateKbps,
      audioBitrateKbps: _estimatedAudioBitrateKbps,
    );
  }

  /// Create concat demuxer file for intro + background videos
  /// Returns the path to the concat file
  Future<String> _createVideoConcatFile({
    required String introVideoPath,
    required String backgroundVideoPath,
    required int backgroundLoopCount,
    required Directory tempDir,
  }) async {
    final concatListPath = p.join(tempDir.path, 'video_concat.txt');

    // Build concat list: intro once, background N times
    final lines = <String>[
      "file '${_formatPathForConcatFile(introVideoPath)}'",
      ...List.generate(
        backgroundLoopCount,
        (_) => "file '${_formatPathForConcatFile(backgroundVideoPath)}'",
      ),
    ];

    await File(concatListPath).writeAsString(lines.join('\n'));
    return concatListPath;
  }

  Future<String> _prepareBackgroundLoopSourceWithStreamLoop({
    required String backgroundVideoPath,
    required Directory tempDir,
    void Function(LogEntry log)? onLog,
  }) async {
    const minTargetSeconds = 600.0; // 10 minutes
    final bgDurationSeconds = await _getVideoDurationSeconds(
      backgroundVideoPath,
    );

    if (bgDurationSeconds == null || bgDurationSeconds <= 0) {
      onLog?.call(
        LogEntry.info(
          'Background duration unavailable, skip pre-process and use original source',
        ),
      );
      return backgroundVideoPath;
    }

    if (bgDurationSeconds >= minTargetSeconds) {
      onLog?.call(
        LogEntry.info(
          'Background duration ${bgDurationSeconds.toStringAsFixed(1)}s already >= 10 minutes, skip pre-process',
        ),
      );
      return backgroundVideoPath;
    }

    final repeatCount = (minTargetSeconds / bgDurationSeconds).ceil();
    final additionalLoops = repeatCount > 0 ? repeatCount - 1 : 0;
    final preprocessedPath = p.join(tempDir.path, 'background_preloop.mp4');

    final preprocessLog = LogEntry.info(
      'Pre-processing background using -stream_loop $additionalLoops to reach minimum 10 minutes...',
    );
    onLog?.call(preprocessLog);

    await FFmpegService.run(
      [
        '-y',
        '-hwaccel',
        'auto',
        '-stream_loop',
        additionalLoops.toString(),
        '-i',
        p.absolute(backgroundVideoPath),
        '-map',
        '0:v:0',
        '-c:v',
        'copy',
        '-an',
        p.absolute(preprocessedPath),
      ],
      errorMessage: 'Failed to pre-process background video with stream_loop',
      onLog: preprocessLog.addSubLog,
    );

    preprocessLog.addSubLog(
      LogEntry.success('Background pre-process complete: $preprocessedPath'),
    );
    return preprocessedPath;
  }

  // Process audio files
  Future<String> _mergeVideoWithAudioFiles(
    String backgroundVideoPath,
    String outputPath,
    String mergedAudioPath,
    Directory tempDir,
    void Function(LogEntry log)? onLog,
  ) async {
    // 6. Fast mode: Loop video to match audio duration
    // -stream_loop -1 applies to next input (background video)
    // -shortest ensures we stop when audio ends

    // Create parent log for video merge operation
    final videoMergeLog = LogEntry.info('Merging video with audio...');
    onLog?.call(videoMergeLog);

    // Loop video to match audio duration (same approach as intro+background case)
    // Use hwaccel auto for hardware-accelerated decoding
    await FFmpegService.run(
      [
        '-y',
        '-hwaccel',
        'auto', // Hardware-accelerated decoding
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
        ...await FFmpegService.getStandardYouTubeVideoMetadataFlags(),
        '-c:a',
        'copy',
        '-shortest',
        '-movflags',
        '+faststart',
        p.absolute(outputPath),
      ],
      errorMessage: 'Failed to merge video with audio',
      onLog: videoMergeLog.addSubLog,
    );

    return outputPath;
  }

  /// Merge concat video file with audio in single pass
  Future<String> _mergeConcatVideoWithAudio(
    String videoConcatPath,
    String outputPath,
    String mergedAudioPath,
    void Function(LogEntry log)? onLog,
  ) async {
    final videoMergeLog = LogEntry.info(
      'Merging concatenated video with audio...',
    );
    onLog?.call(videoMergeLog);

    await FFmpegService.run(
      [
        '-y',
        '-hwaccel',
        'auto',
        '-f',
        'concat',
        '-safe',
        '0',
        '-i',
        p.absolute(videoConcatPath),
        '-i',
        p.absolute(mergedAudioPath),
        '-map',
        '0:v',
        '-map',
        '1:a',
        '-c:v',
        'copy',
        ...await FFmpegService.getStandardYouTubeVideoMetadataFlags(),
        '-c:a',
        'copy',
        '-shortest',
        '-movflags',
        '+faststart',
        p.absolute(outputPath),
      ],
      errorMessage: 'Failed to merge concat video with audio',
      onLog: videoMergeLog.addSubLog,
    );

    return outputPath;
  }

  Future<String> processVideoWithAudio({
    required String backgroundVideoPath,
    required List<String> audioFiles,
    required String outputPath,
    required String projectRootPath,
    int audioLoopCount = 1,
    String? introVideoPath,
    bool enableParallelProcessing = true,
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
      final String mergedAudioPath;

      // 1) Audio pipeline - Normalize to AAC once, then concat with stream copy
      onLog?.call(
        LogEntry.info(
          'Audio pipeline: AAC normalize then concat copy',
        ),
      );
      final normalizedAudioFiles = await _normalizeAudioFilesToAacM4a(
        audioFiles: audioFiles,
        projectRootPath: projectRootPath,
        onLog: onLog,
      );
      final playlistOrder = _buildAudioPlaylistOrder(
        audioFiles.length,
        audioLoopCount,
        onLog,
      );
      final playlistFiles = _applyPlaylistOrder(
        normalizedAudioFiles,
        playlistOrder,
      );
      final timestampSourceFiles = _applyPlaylistOrder(
        audioFiles,
        playlistOrder,
      );
      onProgress?.call(0.3);
      mergedAudioPath = await _mergeAudioPlaylist(
        tempDir,
        playlistFiles,
        onLog,
      );
      onProgress?.call(0.5);

      // If no intro, output directly to final path
      if (introVideoPath == null) {
        await _mergeVideoWithAudioFiles(
          backgroundVideoPath,
          outputPath,
          mergedAudioPath,
          tempDir,
          onLog,
        );
      } else {
        // NEW EFFICIENT APPROACH: Calculate loop count, create concat, merge once
        final log = LogEntry.info(
          'Creating video with intro and background (efficient mode)...',
        );
        final preprocessLog = LogEntry.info(
          'Preparing background video for looping...',
        );
        onLog?.call(log);
        onLog?.call(preprocessLog);
        final preprocessedBackgroundVideoPath =
            await _prepareBackgroundLoopSourceWithStreamLoop(
              backgroundVideoPath: backgroundVideoPath,
              tempDir: tempDir,
              onLog: preprocessLog.addSubLog,
            );

        // Get intro video duration
        final introSeconds = await _getVideoDurationSeconds(introVideoPath);
        if (introSeconds == null || introSeconds <= 0) {
          throw Exception('Could not determine intro video duration');
        }

        // Get background video duration
        final bgSeconds = await _getVideoDurationSeconds(
          preprocessedBackgroundVideoPath,
        );
        if (bgSeconds == null || bgSeconds <= 0) {
          throw Exception('Could not determine background video duration');
        }

        // Get merged audio duration
        final audioSeconds = await _getAudioDurationSeconds(mergedAudioPath);
        if (audioSeconds == null || audioSeconds <= 0) {
          throw Exception('Could not determine audio duration');
        }

        // Calculate required loop count: ceil((audioDuration - introDuration) / bgDuration)
        final remainingAudioSeconds = audioSeconds - introSeconds;
        final bgLoopCount = (remainingAudioSeconds / bgSeconds).ceil();

        log.addSubLog(
          LogEntry.info(
            'Duration calculations:\n'
            '  • Intro: ${introSeconds.toStringAsFixed(1)}s\n'
            '  • Background: ${bgSeconds.toStringAsFixed(1)}s\n'
            '  • Audio total: ${audioSeconds.toStringAsFixed(1)}s\n'
            '  • Remaining after intro: ${remainingAudioSeconds.toStringAsFixed(1)}s\n'
            '  • Background loop count: $bgLoopCount',
          ),
        );

        onProgress?.call(0.6);

        // Step 1: Create concat demuxer file with intro + background loops
        final concatLog = LogEntry.info(
          'Creating video concat file (intro + background $bgLoopCount times)...',
        );
        log.addSubLog(concatLog);

        final videoConcatPath = await _createVideoConcatFile(
          introVideoPath: introVideoPath,
          backgroundVideoPath: preprocessedBackgroundVideoPath,
          backgroundLoopCount: bgLoopCount,
          tempDir: tempDir,
        );

        concatLog.addSubLog(
          LogEntry.success('Concat file created: $videoConcatPath'),
        );

        onProgress?.call(0.7);

        // Step 2: Merge concat video with audio in SINGLE PASS
        await _mergeConcatVideoWithAudio(
          videoConcatPath,
          outputPath,
          mergedAudioPath,
          onLog,
        );

        log.addSubLog(LogEntry.success('Final video created (1 SSD write)'));
      }

      onProgress?.call(1);
      await _writeYouTubeTimestampFile(
        outputPath: outputPath,
        playlistSourceFiles: timestampSourceFiles,
        onLog: onLog,
      );
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
}
