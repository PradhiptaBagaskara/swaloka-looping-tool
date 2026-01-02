import 'package:path/path.dart' as p;

/// Modes for handling intro video audio
enum IntroAudioMode {
  /// Play audio from the intro video
  keepOriginal,

  /// Intro video plays in silence
  silent,

  /// Play main audio playlist during intro
  overlayPlaylist,
}

/// Model representing a Swaloka video merger project
class SwalokaProject {
  SwalokaProject({
    required this.name,
    required this.rootPath,
    this.customOutputPath,
    this.audioFiles = const [],
    this.backgroundVideo,
    this.introVideo,
    this.introAudioMode = IntroAudioMode.overlayPlaylist,
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

    // Handle intro audio mode migration
    var mode = IntroAudioMode.keepOriginal;
    if (json['introAudioMode'] != null) {
      try {
        mode = IntroAudioMode.values.byName(json['introAudioMode'] as String);
      } on Exception catch (_) {
        // Fallback to default if invalid enum name
      }
    } else if (json['introKeepAudio'] != null) {
      // Migration from bool to enum
      final keep = json['introKeepAudio'] as bool;
      mode = keep ? IntroAudioMode.keepOriginal : IntroAudioMode.silent;
    }

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
      introVideo: normalizePath(json['introVideo'] as String?),
      introAudioMode: mode,
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
  final String? introVideo;
  final IntroAudioMode introAudioMode;
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
      'introVideo': normalizePath(introVideo),
      'introAudioMode': introAudioMode.name,
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
    String? introVideo,
    bool clearIntroVideo = false,
    IntroAudioMode? introAudioMode,
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
    final normalizedIntroVideo = introVideo != null
        ? p.normalize(introVideo)
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
      introVideo: clearIntroVideo
          ? null
          : (normalizedIntroVideo ?? this.introVideo),
      introAudioMode: introAudioMode ?? this.introAudioMode,
      title: title ?? this.title,
      author: author ?? this.author,
      comment: comment ?? this.comment,
      concurrencyLimit: concurrencyLimit ?? this.concurrencyLimit,
      audioLoopCount: audioLoopCount ?? this.audioLoopCount,
    );
  }
}
