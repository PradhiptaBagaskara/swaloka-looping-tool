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

/// Model representing a Swaloka video merger project (persisted settings only)
/// Session-only data (file selections, metadata) are managed in UI state
class SwalokaProject {
  SwalokaProject({
    required this.name,
    required this.rootPath,
    this.customOutputPath,
    this.introAudioMode = IntroAudioMode.overlayPlaylist,
    this.concurrencyLimit = 4,
  });

  factory SwalokaProject.fromJson(Map<String, dynamic> json) {
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
      customOutputPath: json['customOutputPath'] != null
          ? p.normalize(json['customOutputPath'] as String)
          : null,
      introAudioMode: mode,
      concurrencyLimit: json['concurrencyLimit'] as int? ?? 4,
    );
  }

  final String name;
  final String rootPath;
  final String? customOutputPath;
  final IntroAudioMode introAudioMode;
  final int concurrencyLimit;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'rootPath': p.normalize(rootPath),
      'customOutputPath': customOutputPath != null
          ? p.normalize(customOutputPath!)
          : null,
      'introAudioMode': introAudioMode.name,
      'concurrencyLimit': concurrencyLimit,
    };
  }

  String get effectiveOutputPath =>
      customOutputPath ?? p.join(rootPath, 'outputs');

  SwalokaProject copyWith({
    String? name,
    String? rootPath,
    String? customOutputPath,
    bool clearCustomOutputPath = false,
    IntroAudioMode? introAudioMode,
    int? concurrencyLimit,
  }) {
    return SwalokaProject(
      name: name ?? this.name,
      rootPath: rootPath != null ? p.normalize(rootPath) : this.rootPath,
      customOutputPath: clearCustomOutputPath
          ? null
          : (customOutputPath != null
                ? p.normalize(customOutputPath)
                : this.customOutputPath),
      introAudioMode: introAudioMode ?? this.introAudioMode,
      concurrencyLimit: concurrencyLimit ?? this.concurrencyLimit,
    );
  }
}
