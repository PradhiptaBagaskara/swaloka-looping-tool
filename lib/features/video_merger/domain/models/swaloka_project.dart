import 'package:path/path.dart' as p;

/// Model representing a Swaloka video merger project (persisted settings only)
/// Session-only data (file selections, metadata) are managed in UI state
class SwalokaProject {
  SwalokaProject({
    required this.name,
    required this.rootPath,
    this.customOutputPath,
    this.enableParallelProcessing = true,
  });

  factory SwalokaProject.fromJson(Map<String, dynamic> json) {
    return SwalokaProject(
      name: json['name'] as String,
      rootPath: p.normalize(json['rootPath'] as String),
      customOutputPath: json['customOutputPath'] != null
          ? p.normalize(json['customOutputPath'] as String)
          : null,
      enableParallelProcessing:
          json['enableParallelProcessing'] as bool? ?? true,
    );
  }

  final String name;
  final String rootPath;
  final String? customOutputPath;
  final bool enableParallelProcessing;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'rootPath': p.normalize(rootPath),
      'customOutputPath': customOutputPath != null
          ? p.normalize(customOutputPath!)
          : null,
      'enableParallelProcessing': enableParallelProcessing,
    };
  }

  String get effectiveOutputPath =>
      customOutputPath ?? p.join(rootPath, 'outputs');

  SwalokaProject copyWith({
    String? name,
    String? rootPath,
    String? customOutputPath,
    bool clearCustomOutputPath = false,
    bool? enableParallelProcessing,
  }) {
    return SwalokaProject(
      name: name ?? this.name,
      rootPath: rootPath != null ? p.normalize(rootPath) : this.rootPath,
      customOutputPath: clearCustomOutputPath
          ? null
          : (customOutputPath != null
                ? p.normalize(customOutputPath)
                : this.customOutputPath),
      enableParallelProcessing:
          enableParallelProcessing ?? this.enableParallelProcessing,
    );
  }
}
