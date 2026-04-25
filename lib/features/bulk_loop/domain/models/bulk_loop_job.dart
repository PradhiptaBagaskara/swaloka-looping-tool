import 'package:path/path.dart' as p;

enum BulkLoopJobStatus {
  draft,
  planning,
  ready,
  running,
  partiallyDone,
  completed,
  failed,
}

enum BulkLoopContentStatus {
  pendingMedia,
  ready,
  queued,
  running,
  done,
  failed,
}

class BulkLoopConstraints {
  const BulkLoopConstraints({
    required this.minDurationSeconds,
    this.minDurationGapSeconds = 120,
  });

  factory BulkLoopConstraints.fromJson(Map<String, dynamic> json) {
    final minDurationSeconds = _readDouble(
      json['minDurationSeconds'],
      fallback: 3600,
    );
    return BulkLoopConstraints(
      minDurationSeconds: minDurationSeconds,
      minDurationGapSeconds: _readDouble(
        json['minDurationGapSeconds'],
        fallback: 120,
      ),
    );
  }

  final double minDurationSeconds;
  final double minDurationGapSeconds;

  Map<String, dynamic> toJson() {
    return {
      'minDurationSeconds': minDurationSeconds,
      'minDurationGapSeconds': minDurationGapSeconds,
    };
  }
}

class BulkLoopAudioItem {
  const BulkLoopAudioItem({
    required this.id,
    required this.path,
    this.durationSeconds,
  });

  factory BulkLoopAudioItem.fromJson(Map<String, dynamic> json) {
    return BulkLoopAudioItem(
      id: json['id'] as String,
      path: p.normalize(json['path'] as String),
      durationSeconds: (json['durationSeconds'] as num?)?.toDouble(),
    );
  }

  final String id;
  final String path;
  final double? durationSeconds;

  BulkLoopAudioItem copyWith({double? durationSeconds}) {
    return BulkLoopAudioItem(
      id: id,
      path: path,
      durationSeconds: durationSeconds ?? this.durationSeconds,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'path': p.normalize(path),
      'durationSeconds': durationSeconds,
    };
  }
}

class BulkLoopContentPlan {
  const BulkLoopContentPlan({
    required this.id,
    required this.index,
    required this.seedTargetSeconds,
    required this.estimatedSeedSeconds,
    required this.audioItemIds,
    required this.status,
    this.backgroundVideoPath,
    this.introVideoPath,
    this.outputPath,
    this.error,
    this.processedAt,
    this.finishedAt,
  });

  factory BulkLoopContentPlan.fromJson(Map<String, dynamic> json) {
    final statusRaw = json['status'] as String? ?? 'pendingMedia';
    return BulkLoopContentPlan(
      id: json['id'] as String,
      index: _readInt(json['index'], fallback: 0),
      seedTargetSeconds: _readDouble(json['seedTargetSeconds'], fallback: 0),
      estimatedSeedSeconds: _readDouble(
        json['estimatedSeedSeconds'],
        fallback: 0,
      ),
      audioItemIds: (json['audioItemIds'] as List<dynamic>).cast<String>(),
      status: BulkLoopContentStatus.values.firstWhere(
        (value) => value.name == statusRaw,
        orElse: () => BulkLoopContentStatus.pendingMedia,
      ),
      backgroundVideoPath: json['backgroundVideoPath'] as String?,
      introVideoPath: json['introVideoPath'] as String?,
      outputPath: json['outputPath'] as String?,
      error: json['error'] as String?,
      processedAt: _readDateTime(json['processedAt']),
      finishedAt: _readDateTime(json['finishedAt']),
    );
  }

  final String id;
  final int index;
  final double seedTargetSeconds;
  final double estimatedSeedSeconds;
  final List<String> audioItemIds;
  final BulkLoopContentStatus status;
  final String? backgroundVideoPath;
  final String? introVideoPath;
  final String? outputPath;
  final String? error;
  final DateTime? processedAt;
  final DateTime? finishedAt;

  BulkLoopContentPlan copyWith({
    double? seedTargetSeconds,
    double? estimatedSeedSeconds,
    List<String>? audioItemIds,
    BulkLoopContentStatus? status,
    String? backgroundVideoPath,
    String? introVideoPath,
    String? outputPath,
    String? error,
    DateTime? processedAt,
    DateTime? finishedAt,
    bool clearError = false,
    bool clearOutputPath = false,
    bool clearBackgroundVideoPath = false,
    bool clearIntroVideoPath = false,
    bool clearProcessedAt = false,
    bool clearFinishedAt = false,
  }) {
    return BulkLoopContentPlan(
      id: id,
      index: index,
      seedTargetSeconds: seedTargetSeconds ?? this.seedTargetSeconds,
      estimatedSeedSeconds: estimatedSeedSeconds ?? this.estimatedSeedSeconds,
      audioItemIds: audioItemIds ?? this.audioItemIds,
      status: status ?? this.status,
      backgroundVideoPath: clearBackgroundVideoPath
          ? null
          : (backgroundVideoPath ?? this.backgroundVideoPath),
      introVideoPath: clearIntroVideoPath
          ? null
          : (introVideoPath ?? this.introVideoPath),
      outputPath: clearOutputPath ? null : (outputPath ?? this.outputPath),
      error: clearError ? null : (error ?? this.error),
      processedAt: clearProcessedAt ? null : (processedAt ?? this.processedAt),
      finishedAt: clearFinishedAt ? null : (finishedAt ?? this.finishedAt),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'index': index,
      'seedTargetSeconds': seedTargetSeconds,
      'estimatedSeedSeconds': estimatedSeedSeconds,
      'audioItemIds': audioItemIds,
      'status': status.name,
      'backgroundVideoPath': backgroundVideoPath == null
          ? null
          : p.normalize(backgroundVideoPath!),
      'introVideoPath': introVideoPath == null
          ? null
          : p.normalize(introVideoPath!),
      'outputPath': outputPath == null ? null : p.normalize(outputPath!),
      'error': error,
      'processedAt': processedAt?.toIso8601String(),
      'finishedAt': finishedAt?.toIso8601String(),
    };
  }
}

class BulkLoopJob {
  const BulkLoopJob({
    required this.id,
    required this.name,
    required this.projectRootPath,
    required this.outputDirectoryPath,
    required this.targetContentCount,
    required int? loopCount,
    required this.constraints,
    required this.seed,
    required this.audioItems,
    required this.contents,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  }) : _loopCount = loopCount;

  factory BulkLoopJob.create({
    required String id,
    required String name,
    required String projectRootPath,
    required String outputDirectoryPath,
    required int targetContentCount,
    required int loopCount,
    required BulkLoopConstraints constraints,
    required int seed,
    required List<BulkLoopAudioItem> audioItems,
  }) {
    final now = DateTime.now();
    return BulkLoopJob(
      id: id,
      name: name,
      projectRootPath: p.normalize(projectRootPath),
      outputDirectoryPath: p.normalize(outputDirectoryPath),
      targetContentCount: targetContentCount,
      loopCount: loopCount,
      constraints: constraints,
      seed: seed,
      audioItems: audioItems,
      contents: const [],
      status: BulkLoopJobStatus.draft,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory BulkLoopJob.fromJson(Map<String, dynamic> json) {
    final statusRaw = json['status'] as String? ?? 'draft';
    return BulkLoopJob(
      id: json['id'] as String,
      name: json['name'] as String,
      projectRootPath: p.normalize(json['projectRootPath'] as String),
      outputDirectoryPath: p.normalize(json['outputDirectoryPath'] as String),
      targetContentCount: _readInt(json['targetContentCount'], fallback: 1),
      loopCount: _readInt(json['loopCount'], fallback: 1),
      constraints: BulkLoopConstraints.fromJson(
        json['constraints'] as Map<String, dynamic>,
      ),
      seed: _readInt(json['seed'], fallback: 0),
      audioItems: (json['audioItems'] as List<dynamic>)
          .map(
            (item) => BulkLoopAudioItem.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      contents: (json['contents'] as List<dynamic>)
          .map(
            (item) =>
                BulkLoopContentPlan.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      status: BulkLoopJobStatus.values.firstWhere(
        (value) => value.name == statusRaw,
        orElse: () => BulkLoopJobStatus.draft,
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  final String id;
  final String name;
  final String projectRootPath;
  final String outputDirectoryPath;
  final int targetContentCount;
  final int? _loopCount;
  final BulkLoopConstraints constraints;
  final int seed;
  final List<BulkLoopAudioItem> audioItems;
  final List<BulkLoopContentPlan> contents;
  final BulkLoopJobStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  int get loopCount => _loopCount ?? 1;

  BulkLoopJob copyWith({
    String? name,
    String? outputDirectoryPath,
    int? targetContentCount,
    int? loopCount,
    BulkLoopConstraints? constraints,
    int? seed,
    List<BulkLoopAudioItem>? audioItems,
    List<BulkLoopContentPlan>? contents,
    BulkLoopJobStatus? status,
    DateTime? updatedAt,
  }) {
    return BulkLoopJob(
      id: id,
      name: name ?? this.name,
      projectRootPath: projectRootPath,
      outputDirectoryPath: outputDirectoryPath ?? this.outputDirectoryPath,
      targetContentCount: targetContentCount ?? this.targetContentCount,
      loopCount: loopCount ?? this.loopCount,
      constraints: constraints ?? this.constraints,
      seed: seed ?? this.seed,
      audioItems: audioItems ?? this.audioItems,
      contents: contents ?? this.contents,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'projectRootPath': p.normalize(projectRootPath),
      'outputDirectoryPath': p.normalize(outputDirectoryPath),
      'targetContentCount': targetContentCount,
      'loopCount': loopCount,
      'constraints': constraints.toJson(),
      'seed': seed,
      'audioItems': audioItems.map((item) => item.toJson()).toList(),
      'contents': contents.map((item) => item.toJson()).toList(),
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

double _readDouble(Object? value, {required double fallback}) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) {
    final parsed = double.tryParse(value);
    if (parsed != null) return parsed;
  }
  return fallback;
}

int _readInt(Object? value, {required int fallback}) {
  if (value is int) return value;
  if (value is double) return value.round();
  if (value is String) {
    final parsed = int.tryParse(value);
    if (parsed != null) return parsed;
  }
  return fallback;
}

DateTime? _readDateTime(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}
