import 'dart:io';
import 'dart:math';

import 'package:swaloka_looping_tool/core/services/ffmpeg_service.dart';
import 'package:swaloka_looping_tool/core/services/log_service.dart';
import 'package:swaloka_looping_tool/features/bulk_loop/domain/models/models.dart';

class BulkLoopPlannerService {
  static const double _fallbackAudioDurationSeconds = 180;

  Future<BulkLoopJob> buildPlan(
    BulkLoopJob sourceJob, {
    void Function(LogEntry log)? onLog,
  }) async {
    final planLog = LogEntry.info(
      'Planning bulk loop job: ${sourceJob.targetContentCount} content slot(s)',
    );
    onLog?.call(planLog);

    final normalizedAudios = await _hydrateAudioDurations(
      sourceJob.audioItems,
      onLog: planLog.addSubLog,
    );

    if (normalizedAudios.isEmpty) {
      throw Exception('Bulk planner requires at least one audio file');
    }

    final plannedSeedTargets = _generateSeedTargetDurations(
      sourceJob.targetContentCount,
      sourceJob.constraints,
      sourceJob.loopCount,
      sourceJob.seed,
    );

    final initialPlans = List<BulkLoopContentPlan>.generate(
      sourceJob.targetContentCount,
      (index) {
        return BulkLoopContentPlan(
          id: 'content_${index + 1}',
          index: index,
          seedTargetSeconds: plannedSeedTargets[index],
          estimatedSeedSeconds: 0,
          audioItemIds: const [],
          status: BulkLoopContentStatus.pendingMedia,
        );
      },
    );

    final plannedContents = _assignAudios(
      initialPlans,
      normalizedAudios,
      onLog: planLog.addSubLog,
    );

    final readyCount = plannedContents
        .where((content) => content.status == BulkLoopContentStatus.ready)
        .length;
    final pendingCount = plannedContents
        .where(
          (content) => content.status == BulkLoopContentStatus.pendingMedia,
        )
        .length;

    planLog.addSubLog(
      LogEntry.success(
        'Plan ready: $readyCount ready, $pendingCount pending-media',
      ),
    );

    return sourceJob.copyWith(
      audioItems: normalizedAudios,
      contents: plannedContents,
      status: readyCount > 0
          ? BulkLoopJobStatus.ready
          : BulkLoopJobStatus.partiallyDone,
    );
  }

  Future<List<BulkLoopAudioItem>> _hydrateAudioDurations(
    List<BulkLoopAudioItem> audioItems, {
    void Function(LogEntry log)? onLog,
  }) async {
    final hydrated = <BulkLoopAudioItem>[];
    for (final item in audioItems) {
      final duration =
          item.durationSeconds ?? await _readAudioDuration(item.path);
      if (duration == null || duration <= 0) {
        hydrated.add(
          item.copyWith(durationSeconds: _fallbackAudioDurationSeconds),
        );
        onLog?.call(
          LogEntry.warning(
            'Duration unavailable for ${item.path}, fallback to ${_fallbackAudioDurationSeconds.toInt()}s',
          ),
        );
        continue;
      }
      hydrated.add(item.copyWith(durationSeconds: duration));
    }
    return hydrated;
  }

  List<double> _generateSeedTargetDurations(
    int contentCount,
    BulkLoopConstraints constraints,
    int loopCount,
    int seed,
  ) {
    if (contentCount <= 0) return const [];
    final random = Random(seed);
    final planned = <double>[];
    final safeLoopCount = max(1, loopCount);
    final seedTarget = constraints.minDurationSeconds / safeLoopCount;
    final minValue = seedTarget;
    // Keep slight variation so content duration is not identical.
    final maxValue = seedTarget * 1.1;
    final range = max(1, maxValue - minValue);

    for (var i = 0; i < contentCount; i++) {
      var selected = minValue;
      var found = false;
      for (var attempt = 0; attempt < 32; attempt++) {
        final candidate = minValue + (random.nextDouble() * range);
        final isSeparated = planned.every(
          (value) =>
              (value - candidate).abs() >= constraints.minDurationGapSeconds,
        );
        if (isSeparated) {
          selected = candidate;
          found = true;
          break;
        }
      }

      if (!found) {
        selected =
            minValue + ((i % max(1, contentCount)) / contentCount) * range;
      }

      planned.add(selected);
    }

    return planned;
  }

  List<BulkLoopContentPlan> _assignAudios(
    List<BulkLoopContentPlan> initialPlans,
    List<BulkLoopAudioItem> audios, {
    void Function(LogEntry log)? onLog,
  }) {
    final result = initialPlans
        .map(
          (content) => content.copyWith(
            audioItemIds: <String>[],
            estimatedSeedSeconds: 0,
          ),
        )
        .toList();

    final usage = <String, int>{
      for (final audio in audios) audio.id: 0,
    };
    final durationByAudioId = <String, double>{
      for (final audio in audios)
        audio.id: audio.durationSeconds ?? _fallbackAudioDurationSeconds,
    };

    // Coverage seed: every audio appears at least once globally.
    for (var audioIndex = 0; audioIndex < audios.length; audioIndex++) {
      final contentIndex = audioIndex % result.length;
      final audioId = audios[audioIndex].id;
      final content = result[contentIndex];
      final nextAudioIds = <String>[...content.audioItemIds, audioId];
      final nextDuration =
          content.estimatedSeedSeconds + durationByAudioId[audioId]!;
      result[contentIndex] = content.copyWith(
        audioItemIds: nextAudioIds,
        estimatedSeedSeconds: nextDuration,
      );
      usage[audioId] = (usage[audioId] ?? 0) + 1;
    }

    // Fill each content target using least-used-first strategy.
    for (var index = 0; index < result.length; index++) {
      var content = result[index];
      while (content.estimatedSeedSeconds < content.seedTargetSeconds) {
        final nextAudioId = _pickLeastUsedAudioId(
          usage,
          content.audioItemIds.lastOrNull,
        );
        final nextAudioIds = <String>[...content.audioItemIds, nextAudioId];
        content = content.copyWith(
          audioItemIds: nextAudioIds,
          estimatedSeedSeconds:
              content.estimatedSeedSeconds + durationByAudioId[nextAudioId]!,
        );
        usage[nextAudioId] = (usage[nextAudioId] ?? 0) + 1;
      }

      result[index] = content;
    }

    final uncoveredCount = usage.values.where((value) => value == 0).length;
    onLog?.call(
      LogEntry.info(
        'Audio assignment complete: ${audios.length - uncoveredCount}/${audios.length} audio(s) covered',
      ),
    );

    return result;
  }

  String _pickLeastUsedAudioId(
    Map<String, int> usage,
    String? previousAudioId,
  ) {
    final minUsage = usage.values.reduce(min);
    var candidates = usage.entries
        .where((entry) => entry.value == minUsage)
        .map((entry) => entry.key)
        .toList();

    if (previousAudioId != null && candidates.length > 1) {
      candidates = candidates.where((id) => id != previousAudioId).toList();
    }

    candidates.sort();
    return candidates.first;
  }

  Future<double?> _readAudioDuration(String audioPath) async {
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
          audioPath,
        ],
        environment: FFmpegService.extendedEnvironment,
      );
      if (result.exitCode != 0) return null;
      final output = (result.stdout as String).trim();
      if (output.isEmpty) return null;
      return double.tryParse(output);
    } on Exception {
      return null;
    }
  }
}

extension on List<String> {
  String? get lastOrNull => isEmpty ? null : last;
}
