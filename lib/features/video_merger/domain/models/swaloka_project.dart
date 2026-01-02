import 'package:path/path.dart' as p;

/// Model representing a Swaloka video merger project
class SwalokaProject {
  SwalokaProject({
    required this.name,
    required this.rootPath,
    this.customOutputPath,
    this.audioFiles = const [],
    this.backgroundVideo,
    this.title,
    this.author,
    this.comment,
    this.concurrencyLimit = 4,
    this.audioLoopCount = 1,
  });

  factory SwalokaProject.fromJson(Map<String, dynamic> json) {
    // Normalize paths for current platform
    String? normalizePath(String? path) =>
        path != null ? p.normalize(path) : null;

    return SwalokaProject(
      name: json['name'] as String,
      rootPath: p.normalize(json['rootPath'] as String),
      customOutputPath: normalizePath(json['customOutputPath'] as String?),
      audioFiles:
          (json['audioFiles'] as List<dynamic>?)
              ?.map((e) => p.normalize(e as String))
              .toList() ??
          [],
      backgroundVideo: normalizePath(json['backgroundVideo'] as String?),
      title: json['title'] as String?,
      author: json['author'] as String?,
      comment: json['comment'] as String?,
      concurrencyLimit: json['concurrencyLimit'] as int? ?? 4,
      audioLoopCount: json['audioLoopCount'] as int? ?? 1,
    );
  }
  final String name;
  final String rootPath;
  final String? customOutputPath;
  final List<String> audioFiles;
  final String? backgroundVideo;
  final String? title;
  final String? author;
  final String? comment;
  final int concurrencyLimit;
  final int audioLoopCount;

  Map<String, dynamic> toJson() {
    // Normalize paths for consistent storage
    String? normalizePath(String? path) =>
        path != null ? p.normalize(path) : null;

    return {
      'name': name,
      'rootPath': p.normalize(rootPath),
      'customOutputPath': normalizePath(customOutputPath),
      'audioFiles': audioFiles.map(p.normalize).toList(),
      'backgroundVideo': normalizePath(backgroundVideo),
      'title': title,
      'author': author,
      'comment': comment,
      'concurrencyLimit': concurrencyLimit,
      'audioLoopCount': audioLoopCount,
    };
  }

  String get effectiveOutputPath =>
      customOutputPath ?? p.join(rootPath, 'outputs');

  SwalokaProject copyWith({
    String? name,
    String? rootPath,
    String? customOutputPath,
    bool clearCustomOutputPath = false,
    List<String>? audioFiles,
    String? backgroundVideo,
    bool clearBackgroundVideo = false,
    String? title,
    String? author,
    String? comment,
    int? concurrencyLimit,
    int? audioLoopCount,
  }) {
    // Normalize paths for consistency
    final normalizedAudioFiles = audioFiles?.map(p.normalize).toList();
    final normalizedBackgroundVideo = backgroundVideo != null
        ? p.normalize(backgroundVideo)
        : null;

    return SwalokaProject(
      name: name ?? this.name,
      rootPath: rootPath != null ? p.normalize(rootPath) : this.rootPath,
      customOutputPath: clearCustomOutputPath
          ? null
          : (customOutputPath != null
                ? p.normalize(customOutputPath)
                : this.customOutputPath),
      audioFiles: normalizedAudioFiles ?? this.audioFiles,
      backgroundVideo: clearBackgroundVideo
          ? null
          : (normalizedBackgroundVideo ?? this.backgroundVideo),
      title: title ?? this.title,
      author: author ?? this.author,
      comment: comment ?? this.comment,
      concurrencyLimit: concurrencyLimit ?? this.concurrencyLimit,
      audioLoopCount: audioLoopCount ?? this.audioLoopCount,
    );
  }
}
