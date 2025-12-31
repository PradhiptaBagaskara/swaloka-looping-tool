/// Model representing a Swaloka video merger project
class SwalokaProject {
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

  Map<String, dynamic> toJson() => {
        'name': name,
        'rootPath': rootPath,
        'customOutputPath': customOutputPath,
        'audioFiles': audioFiles,
        'backgroundVideo': backgroundVideo,
        'title': title,
        'author': author,
        'comment': comment,
        'concurrencyLimit': concurrencyLimit,
        'audioLoopCount': audioLoopCount,
      };

  factory SwalokaProject.fromJson(Map<String, dynamic> json) => SwalokaProject(
        name: json['name'],
        rootPath: json['rootPath'],
        customOutputPath: json['customOutputPath'],
        audioFiles: List<String>.from(json['audioFiles'] ?? []),
        backgroundVideo: json['backgroundVideo'],
        title: json['title'],
        author: json['author'],
        comment: json['comment'],
        concurrencyLimit: json['concurrencyLimit'] ?? 4,
        audioLoopCount: json['audioLoopCount'] ?? 1,
      );

  String get effectiveOutputPath => customOutputPath ?? '$rootPath/outputs';

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
    return SwalokaProject(
      name: name ?? this.name,
      rootPath: rootPath ?? this.rootPath,
      customOutputPath: clearCustomOutputPath
          ? null
          : (customOutputPath ?? this.customOutputPath),
      audioFiles: audioFiles ?? this.audioFiles,
      backgroundVideo: clearBackgroundVideo
          ? null
          : (backgroundVideo ?? this.backgroundVideo),
      title: title ?? this.title,
      author: author ?? this.author,
      comment: comment ?? this.comment,
      concurrencyLimit: concurrencyLimit ?? this.concurrencyLimit,
      audioLoopCount: audioLoopCount ?? this.audioLoopCount,
    );
  }
}
