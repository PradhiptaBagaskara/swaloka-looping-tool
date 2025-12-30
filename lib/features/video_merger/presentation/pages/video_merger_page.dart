import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:video_player/video_player.dart';
import 'package:swaloka_looping_tool/core/constants/app_constants.dart';
import '../../domain/video_merger_service.dart';
import '../../domain/hardware_service.dart';
import '../widgets/merge_progress_dialog.dart';

// Models
class SwalokaProject {
  final String name;
  final String rootPath;
  final String? customOutputPath;
  final List<String> audioFiles;
  final String? backgroundVideo;
  final String? title;
  final String? author;
  final String? comment;
  final int resolutionWidth;
  final int resolutionHeight;
  final String preset;
  final int crf;
  final bool enableFastStart;
  final List<String> extraFlags;
  final bool useGpu;
  final String? detectedEncoder;
  final int concurrencyLimit;

  SwalokaProject({
    required this.name,
    required this.rootPath,
    this.customOutputPath,
    this.audioFiles = const [],
    this.backgroundVideo,
    this.title,
    this.author,
    this.comment,
    this.resolutionWidth = 1920,
    this.resolutionHeight = 1080,
    this.preset = 'slow',
    this.crf = 18,
    this.enableFastStart = true,
    this.extraFlags = const [],
    this.useGpu = true,
    this.detectedEncoder,
    this.concurrencyLimit = 4,
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
    'resolutionWidth': resolutionWidth,
    'resolutionHeight': resolutionHeight,
    'preset': preset,
    'crf': crf,
    'enableFastStart': enableFastStart,
    'extraFlags': extraFlags,
    'useGpu': useGpu,
    'detectedEncoder': detectedEncoder,
    'concurrencyLimit': concurrencyLimit,
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
    resolutionWidth: json['resolutionWidth'] ?? 1920,
    resolutionHeight: json['resolutionHeight'] ?? 1080,
    preset: json['preset'] ?? 'slow',
    crf: json['crf'] ?? 18,
    enableFastStart: json['enableFastStart'] ?? true,
    extraFlags: List<String>.from(json['extraFlags'] ?? []),
    useGpu: json['useGpu'] ?? true,
    detectedEncoder: json['detectedEncoder'],
    concurrencyLimit: json['concurrencyLimit'] ?? 4,
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
    int? resolutionWidth,
    int? resolutionHeight,
    String? preset,
    int? crf,
    bool? enableFastStart,
    List<String>? extraFlags,
    bool? useGpu,
    String? detectedEncoder,
    int? concurrencyLimit,
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
      resolutionWidth: resolutionWidth ?? this.resolutionWidth,
      resolutionHeight: resolutionHeight ?? this.resolutionHeight,
      preset: preset ?? this.preset,
      crf: crf ?? this.crf,
      enableFastStart: enableFastStart ?? this.enableFastStart,
      extraFlags: extraFlags ?? this.extraFlags,
      useGpu: useGpu ?? this.useGpu,
      detectedEncoder: detectedEncoder ?? this.detectedEncoder,
      concurrencyLimit: concurrencyLimit ?? this.concurrencyLimit,
    );
  }
}

// Providers
final videoMergerServiceProvider = Provider<VideoMergerService>(
  (ref) => VideoMergerService(),
);

final activeProjectProvider =
    NotifierProvider<ActiveProjectNotifier, SwalokaProject?>(
      () => ActiveProjectNotifier(),
    );

final projectFilesProvider =
    NotifierProvider<ProjectFilesNotifier, List<FileSystemEntity>>(
      () => ProjectFilesNotifier(),
    );

final processingStateProvider =
    NotifierProvider<ProcessingStateNotifier, ProcessingState>(
      () => ProcessingStateNotifier(),
    );

class CollapsedSectionsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => {};

  void toggle(String title) {
    if (state.contains(title)) {
      state = state.where((t) => t != title).toSet();
    } else {
      state = {...state, title};
    }
  }
}

final collapsedSectionsProvider =
    NotifierProvider<CollapsedSectionsNotifier, Set<String>>(
      () => CollapsedSectionsNotifier(),
    );

class RecentProjectsNotifier extends Notifier<List<String>> {
  static const _recentProjectsKey = 'recent_projects';

  @override
  List<String> build() {
    _loadRecentProjects();
    return [];
  }

  Future<void> _loadRecentProjects() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_recentProjectsKey) ?? [];
    state = list;
  }

  Future<void> addProject(String path) async {
    final prefs = await SharedPreferences.getInstance();
    final current = List<String>.from(state);
    current.remove(path); // Remove if exists to move to top
    current.insert(0, path);
    if (current.length > 5) current.removeLast(); // Keep last 5

    state = current;
    await prefs.setStringList(_recentProjectsKey, current);
  }

  Future<void> removeProject(String path) async {
    final prefs = await SharedPreferences.getInstance();
    final current = List<String>.from(state);
    current.remove(path);
    state = current;
    await prefs.setStringList(_recentProjectsKey, current);
  }
}

final recentProjectsProvider =
    NotifierProvider<RecentProjectsNotifier, List<String>>(
      () => RecentProjectsNotifier(),
    );

class ActiveProjectNotifier extends Notifier<SwalokaProject?> {
  static const _lastProjectPathKey = 'last_project_path';

  @override
  SwalokaProject? build() {
    _loadLastProject();
    return null;
  }

  Future<void> _loadLastProject() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_lastProjectPathKey);
    if (path != null) {
      await loadProject(path);
    }
  }

  Future<void> createProject(String rootPath, String name) async {
    final project = SwalokaProject(name: name, rootPath: rootPath);
    await _saveProjectToFile(project);

    // Ensure directories
    await Directory('$rootPath/outputs').create(recursive: true);
    await Directory('$rootPath/logs').create(recursive: true);

    state = project;
    await _detectHardwareEncoder(); // Detect on new project

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastProjectPathKey, rootPath);
    ref.read(recentProjectsProvider.notifier).addProject(rootPath);
    ref.read(projectFilesProvider.notifier).refresh();
  }

  Future<void> loadProject(String rootPath) async {
    final file = File('$rootPath/project.swaloka');
    if (await file.exists()) {
      final json = jsonDecode(await file.readAsString());
      state = SwalokaProject.fromJson(json);

      await _detectHardwareEncoder(); // Detect on load

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastProjectPathKey, rootPath);
      ref.read(recentProjectsProvider.notifier).addProject(rootPath);
      ref.read(projectFilesProvider.notifier).refresh();
    }
  }

  Future<void> updateSettings({
    String? customOutputPath,
    bool clearCustomOutputPath = false,
    String? title,
    String? author,
    String? comment,
    int? resolutionWidth,
    int? resolutionHeight,
    String? preset,
    int? crf,
    bool? enableFastStart,
    List<String>? extraFlags,
    bool? useGpu,
    String? detectedEncoder,
    int? concurrencyLimit,
  }) async {
    if (state == null) return;
    final newState = state!.copyWith(
      customOutputPath: customOutputPath,
      clearCustomOutputPath: clearCustomOutputPath,
      title: title,
      author: author,
      comment: comment,
      resolutionWidth: resolutionWidth,
      resolutionHeight: resolutionHeight,
      preset: preset,
      crf: crf,
      enableFastStart: enableFastStart,
      extraFlags: extraFlags,
      useGpu: useGpu,
      detectedEncoder: detectedEncoder,
      concurrencyLimit: concurrencyLimit,
    );
    state = newState;
    await _saveProjectToFile(newState);
  }

  Future<void> _detectHardwareEncoder() async {
    if (state == null) return;
    final hardwareService = ref.read(hardwareServiceProvider);
    final encoder = await hardwareService.detectBestEncoder();
    if (encoder != null && state!.detectedEncoder != encoder) {
      await updateSettings(detectedEncoder: encoder);
    }
  }

  Future<void> setBackgroundVideo(String? path) async {
    if (state == null) return;
    final newState = state!.copyWith(
      backgroundVideo: path,
      clearBackgroundVideo: path == null,
    );
    state = newState;
    await _saveProjectToFile(newState);
  }

  Future<void> setAudioFiles(List<String> files) async {
    if (state == null) return;
    final newState = state!.copyWith(audioFiles: files);
    state = newState;
    await _saveProjectToFile(newState);
  }

  Future<void> removeAudioAt(int index) async {
    if (state == null) return;
    final newList = List<String>.from(state!.audioFiles);
    newList.removeAt(index);
    final newState = state!.copyWith(audioFiles: newList);
    state = newState;
    await _saveProjectToFile(newState);
  }

  Future<void> removeAllAudios() async {
    if (state == null) return;
    final newState = state!.copyWith(audioFiles: []);
    state = newState;
    await _saveProjectToFile(newState);
  }

  Future<void> _saveProjectToFile(SwalokaProject project) async {
    final file = File('${project.rootPath}/project.swaloka');
    await file.writeAsString(jsonEncode(project.toJson()));
  }

  void closeProject() async {
    state = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastProjectPathKey);
  }
}

class ProjectFilesNotifier extends Notifier<List<FileSystemEntity>> {
  @override
  List<FileSystemEntity> build() => [];

  void refresh() {
    final project = ref.read(activeProjectProvider);
    if (project == null) {
      state = [];
      return;
    }

    final outputsDir = Directory(project.effectiveOutputPath);
    if (outputsDir.existsSync()) {
      state =
          outputsDir
              .listSync()
              .where((file) => file.path.endsWith('.mp4'))
              .toList()
            ..sort(
              (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
            );
    }
  }
}

class ProcessingStateNotifier extends Notifier<ProcessingState> {
  @override
  ProcessingState build() => ProcessingState.idle();

  void startProcessing() {
    state = ProcessingState(
      isProcessing: true,
      progress: 0.0,
      logs: [],
      startTime: DateTime.now(),
    );
  }

  void updateProgress(double progress) =>
      state = state.copyWith(isProcessing: true, progress: progress);

  void addLog(String log) {
    state = state.copyWith(isProcessing: true, logs: [...state.logs, log]);
  }

  void setSuccess(String outputPath) => state = ProcessingState(
    isProcessing: false,
    progress: 1.0,
    outputPath: outputPath,
    logs: state.logs,
    startTime: state.startTime,
  );

  void setError(String error) => state = ProcessingState(
    isProcessing: false,
    progress: 0.0,
    error: error,
    logs: state.logs,
    startTime: state.startTime,
  );

  void reset() => state = ProcessingState.idle();
}

class ProcessingState {
  final bool isProcessing;
  final double progress;
  final List<String> logs;
  final String? error;
  final String? outputPath;
  final DateTime? startTime;

  ProcessingState({
    required this.isProcessing,
    required this.progress,
    required this.logs,
    this.error,
    this.outputPath,
    this.startTime,
  });

  factory ProcessingState.idle() =>
      ProcessingState(isProcessing: false, progress: 0.0, logs: []);

  ProcessingState copyWith({
    bool? isProcessing,
    double? progress,
    List<String>? logs,
    String? error,
    String? outputPath,
    DateTime? startTime,
  }) {
    return ProcessingState(
      isProcessing: isProcessing ?? this.isProcessing,
      progress: progress ?? this.progress,
      logs: logs ?? this.logs,
      error: error ?? this.error,
      outputPath: outputPath ?? this.outputPath,
      startTime: startTime ?? this.startTime,
    );
  }
}

class VideoMergerPage extends ConsumerWidget {
  const VideoMergerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(activeProjectProvider, (previous, next) {
      if (previous == null && next != null) {
        // Project just opened, show donate dialog after a short delay
        Future.delayed(const Duration(milliseconds: 800), () {
          if (context.mounted) {
            _showDonateDialog(context);
          }
        });
      }
    });

    final project = ref.watch(activeProjectProvider);
    final processingState = ref.watch(processingStateProvider);
    final projectFiles = ref.watch(projectFilesProvider);

    if (project == null) {
      return _buildProjectLanding(context, ref);
    }

    final canMerge =
        project.backgroundVideo != null &&
        project.audioFiles.isNotEmpty &&
        project.title != null &&
        project.title!.isNotEmpty &&
        project.author != null &&
        project.author!.isNotEmpty &&
        !processingState.isProcessing;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Sidebar - 320px
                Container(
                  width: 320,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1A1A1A),
                    border: Border(right: BorderSide(color: Color(0xFF333333))),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSidebarHeader(context),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          children: [
                            _buildSectionTitle(context, 'Active Project'),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.deepPurple.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.deepPurple.withValues(
                                    alpha: 0.2,
                                  ),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    project.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    project.rootPath,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey[500],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 32),
                            _buildSectionTitle(context, 'Actions'),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: canMerge
                                  ? () => _mergeVideos(context, ref)
                                  : null,
                              icon: const Icon(Icons.auto_fix_high),
                              label: const Text('Export Video'),
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 50),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextButton.icon(
                              onPressed: () => ref
                                  .read(activeProjectProvider.notifier)
                                  .closeProject(),
                              icon: const Icon(Icons.close, size: 16),
                              label: const Text('Close Project'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.grey,
                                minimumSize: const Size(double.infinity, 40),
                              ),
                            ),
                            if (processingState.isProcessing) ...[
                              const SizedBox(height: 24),
                              _buildProcessingStatus(context, processingState),
                            ],
                            if (processingState.error != null) ...[
                              const SizedBox(height: 24),
                              _buildErrorMessage(
                                context,
                                processingState.error!,
                              ),
                            ],
                            const SizedBox(height: 32),
                            if (projectFiles.isNotEmpty) ...[
                              _buildSectionTitle(context, 'Recent Outputs'),
                              const SizedBox(height: 12),
                              ...projectFiles
                                  .take(5)
                                  .map(
                                    (file) =>
                                        _buildRecentFileItem(context, file),
                                  ),
                            ],
                          ],
                        ),
                      ),
                      _buildSidebarFooter(context),
                    ],
                  ),
                ),

                // Main Area
                Expanded(
                  child: Column(
                    children: [
                      _buildMainHeader(context, project),
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          color: const Color(0xFF0F0F0F),
                          child: _buildTimelineView(context, ref, project),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProjectLanding(BuildContext context, WidgetRef ref) {
    final recentProjects = ref.watch(recentProjectsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: SizedBox.expand(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 32),
            child: Container(
              width: double.infinity,
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.movie_filter,
                      size: 80,
                      color: Colors.deepPurple,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'SWALOKA LOOPING TOOL',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Creative Video Automation',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[500], letterSpacing: 2),
                  ),
                  const SizedBox(height: 48),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildLandingCard(
                        context,
                        title: 'New Project',
                        description: 'Start a fresh video creation',
                        icon: Icons.add_to_photos_outlined,
                        onTap: () => _createNewProject(context, ref),
                      ),
                      const SizedBox(width: 24),
                      _buildLandingCard(
                        context,
                        title: 'Open Project',
                        description: 'Continue working on existing',
                        icon: Icons.folder_open_outlined,
                        onTap: () => _openProject(context, ref),
                      ),
                    ],
                  ),
                  if (recentProjects.isNotEmpty) ...[
                    const SizedBox(height: 64),
                    Container(
                      constraints: const BoxConstraints(maxWidth: 504),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 8, bottom: 16),
                            child: Text(
                              'RECENT PROJECTS',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[600],
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                          ...recentProjects.map(
                            (path) =>
                                _buildRecentProjectItem(context, ref, path),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentProjectItem(
    BuildContext context,
    WidgetRef ref,
    String path,
  ) {
    final projectName = path.split('/').last;
    final projectFile = File('$path/project.swaloka');
    final isCompatible = projectFile.existsSync();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () =>
              ref.read(activeProjectProvider.notifier).loadProject(path),
          onSecondaryTapDown: (details) {
            // Show a context menu to remove from list
            final overlay =
                Overlay.of(context).context.findRenderObject() as RenderBox;
            showMenu(
              context: context,
              position: RelativeRect.fromRect(
                details.globalPosition & const Size(40, 40),
                Offset.zero & overlay.size,
              ),
              items: [
                const PopupMenuItem(
                  value: 'remove',
                  child: Text('Remove from Recents'),
                ),
              ],
            ).then((val) {
              if (val == 'remove') {
                ref.read(recentProjectsProvider.notifier).removeProject(path);
              }
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF333333)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isCompatible
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: isCompatible
                      ? const Icon(
                          Icons.movie_filter,
                          size: 20,
                          color: Colors.black,
                        )
                      : const Icon(
                          Icons.folder_outlined,
                          size: 20,
                          color: Colors.grey,
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        projectName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        path,
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, size: 16, color: Colors.grey[800]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLandingCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 240,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF333333)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 40, color: Colors.deepPurple[200]),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentFileItem(BuildContext context, FileSystemEntity file) {
    final fileName = file.path.split('/').last;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () async {
          final uri = Uri.file(file.parent.path);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri);
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black12,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF333333)),
          ),
          child: Row(
            children: [
              const Icon(Icons.movie_outlined, size: 16, color: Colors.grey),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  fileName,
                  style: const TextStyle(fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.movie_filter,
                  color: Colors.black,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'SWALOKA',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  letterSpacing: 2,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'LOOPING TOOL',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title.toUpperCase(),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Colors.grey[600],
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildMainHeader(BuildContext context, SwalokaProject project) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        border: Border(bottom: BorderSide(color: Color(0xFF333333))),
      ),
      child: Row(
        children: [
          Icon(Icons.folder_open, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            project.name,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white70,
            ),
          ),
          const SizedBox(width: 8),
          Text('/', style: TextStyle(color: Colors.grey[800], fontSize: 12)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              project.rootPath,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const VerticalDivider(
            indent: 12,
            endIndent: 12,
            width: 32,
            color: Colors.white10,
          ),
          TextButton.icon(
            onPressed: () => _showDonateDialog(context),
            icon: const Icon(Icons.favorite, size: 14, color: Colors.redAccent),
            label: const Text(
              'SUPPORT',
              style: TextStyle(
                fontSize: 10,
                color: Colors.white70,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineView(
    BuildContext context,
    WidgetRef ref,
    SwalokaProject project,
  ) {
    final collapsedSections = ref.watch(collapsedSectionsProvider);

    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        _buildTimelineHeader(
          context,
          ref,
          'PROJECT SETTINGS & METADATA (Required)',
          Icons.settings_suggest_outlined,
        ),
        if (!collapsedSections.contains(
          'PROJECT SETTINGS & METADATA (Required)',
        )) ...[
          const SizedBox(height: 12),
          _buildProjectSettingsInputs(context, ref, project),
        ],
        const SizedBox(height: 32),
        _buildTimelineHeader(
          context,
          ref,
          'ADVANCED ENCODING SETTINGS (Optional)',
          Icons.tune,
        ),
        if (!collapsedSections.contains(
          'ADVANCED ENCODING SETTINGS (Optional)',
        )) ...[
          const SizedBox(height: 12),
          _buildAdvancedSettings(context, ref, project),
        ],
        const SizedBox(height: 48),

        // Video Track Section
        _buildTimelineHeader(
          context,
          ref,
          'VIDEO TRACK (Background)',
          Icons.movie_outlined,
        ),
        if (!collapsedSections.contains('VIDEO TRACK (Background)')) ...[
          const SizedBox(height: 12),
          if (project.backgroundVideo != null)
            _buildMediaItem(
              context,
              project.backgroundVideo!,
              Icons.videocam,
              isVideo: true,
              onRemove: () => ref
                  .read(activeProjectProvider.notifier)
                  .setBackgroundVideo(null),
            )
          else
            _buildDropZone(
              context,
              label: 'Drop background video here or click to browse',
              icon: Icons.video_call,
              onFilesDropped: (files) {
                if (files.isNotEmpty) {
                  final path = files.first.path;
                  if (_isVideoFile(path)) {
                    ref
                        .read(activeProjectProvider.notifier)
                        .setBackgroundVideo(path);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please drop a valid video file'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                }
              },
              onTap: () => _selectBackgroundVideo(context, ref),
            ),
          const SizedBox(height: 48),
        ],

        // Audio Track Section
        _buildTimelineHeader(
          context,
          ref,
          'AUDIO TRACKS (Sequential)',
          Icons.audiotrack_outlined,
          trailing: project.audioFiles.isNotEmpty
              ? TextButton.icon(
                  onPressed: () => ref
                      .read(activeProjectProvider.notifier)
                      .removeAllAudios(),
                  icon: const Icon(
                    Icons.delete_sweep_outlined,
                    size: 14,
                    color: Colors.redAccent,
                  ),
                  label: const Text(
                    'REMOVE ALL',
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                )
              : null,
        ),
        if (!collapsedSections.contains('AUDIO TRACKS (Sequential)')) ...[
          const SizedBox(height: 12),
          _buildDropZone(
            context,
            label: 'Drop audio files here or click to add',
            icon: Icons.library_music,
            onFilesDropped: (files) {
              final audioPaths = files
                  .map((f) => f.path)
                  .where((p) => _isAudioFile(p))
                  .toList();
              if (audioPaths.isNotEmpty) {
                final current = List<String>.from(project.audioFiles);
                current.addAll(audioPaths);
                ref.read(activeProjectProvider.notifier).setAudioFiles(current);
              }

              if (audioPaths.length < files.length) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Some files were ignored. Only audio files are allowed.',
                    ),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
            onTap: () => _selectAudioFiles(context, ref),
          ),
          if (project.audioFiles.isNotEmpty) ...[
            const SizedBox(height: 24),
            ...project.audioFiles.asMap().entries.map((e) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildMediaItem(
                  context,
                  e.value,
                  Icons.audiotrack,
                  index: e.key + 1,
                  label: 'Audio file',
                  onRemove: () => ref
                      .read(activeProjectProvider.notifier)
                      .removeAudioAt(e.key),
                ),
              );
            }),
          ],
        ],
      ],
    );
  }

  Widget _buildDropZone(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Function(List<DropItem>) onFilesDropped,
    required VoidCallback onTap,
  }) {
    return DropZoneWidget(
      label: label,
      icon: icon,
      onFilesDropped: onFilesDropped,
      onTap: onTap,
    );
  }

  Widget _buildAdvancedSettings(
    BuildContext context,
    WidgetRef ref,
    SwalokaProject project,
  ) {
    final presets = [
      {
        'name': 'Ultrafast',
        'val': 'ultrafast',
        'desc': 'Fastest, largest file',
      },
      {'name': 'Superfast', 'val': 'superfast', 'desc': 'Very fast'},
      {'name': 'Veryfast', 'val': 'veryfast', 'desc': 'Optimized for speed'},
      {'name': 'Faster', 'val': 'faster', 'desc': 'Good balance'},
      {'name': 'Fast', 'val': 'fast', 'desc': 'Slightly better quality'},
      {'name': 'Medium', 'val': 'medium', 'desc': 'Default balance'},
      {'name': 'Slow', 'val': 'slow', 'desc': 'Better compression'},
      {'name': 'Slower', 'val': 'slower', 'desc': 'Highest compression'},
    ];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Presets
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ENCODER PRESET',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: project.preset,
                      isExpanded: true,
                      itemHeight: 64,
                      selectedItemBuilder: (context) {
                        return presets.map((p) {
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              p['name'] as String,
                              style: const TextStyle(fontSize: 13),
                            ),
                          );
                        }).toList();
                      },
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        filled: true,
                        fillColor: Colors.black26,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      dropdownColor: const Color(0xFF1A1A1A),
                      items: presets.map((p) {
                        return DropdownMenuItem<String>(
                          value: p['val'] as String,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                p['name'] as String,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                p['desc'] as String,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          ref
                              .read(activeProjectProvider.notifier)
                              .updateSettings(preset: val);
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              // CRF
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'QUALITY (CRF)',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      initialValue: project.crf,
                      isExpanded: true,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        filled: true,
                        fillColor: Colors.black26,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      dropdownColor: const Color(0xFF1A1A1A),
                      items:
                          [
                            {'name': 'Highest', 'val': 12},
                            {'name': 'Very High', 'val': 18},
                            {'name': 'High (Default)', 'val': 23},
                            {'name': 'Medium', 'val': 28},
                            {'name': 'Low', 'val': 35},
                          ].map((c) {
                            return DropdownMenuItem<int>(
                              value: c['val'] as int,
                              child: Text(
                                c['name'] as String,
                                style: const TextStyle(fontSize: 13),
                              ),
                            );
                          }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          ref
                              .read(activeProjectProvider.notifier)
                              .updateSettings(crf: val);
                        }
                      },
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Lower = Better',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              // FastStart
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'OPTIMIZATION',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      value: project.enableFastStart,
                      onChanged: (val) {
                        ref
                            .read(activeProjectProvider.notifier)
                            .updateSettings(enableFastStart: val);
                      },
                      title: const Text(
                        'FastStart',
                        style: TextStyle(fontSize: 13),
                      ),
                      subtitle: const Text(
                        'For YouTube/Web',
                        style: TextStyle(fontSize: 10),
                      ),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      activeThumbColor: Colors.deepPurple,
                      activeTrackColor: Colors.deepPurple.withValues(
                        alpha: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              // Concurrency Limit
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AUDIO PARALLELISM',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      value: project.concurrencyLimit,
                      isExpanded: true,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        filled: true,
                        fillColor: Colors.black26,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      dropdownColor: const Color(0xFF1A1A1A),
                      items: () {
                        final cores = Platform.numberOfProcessors;
                        final recommended = cores <= 4
                            ? 2
                            : (cores <= 8 ? 4 : 8);

                        return [
                          {'name': '1 (Slowest / Safest)', 'val': 1},
                          {'name': '2 (Conservative)', 'val': 2},
                          {'name': '4 (Standard)', 'val': 4},
                          {'name': '8 (Aggressive)', 'val': 8},
                          {'name': '16 (Extreme)', 'val': 16},
                        ].map((c) {
                          final val = c['val'] as int;
                          final isRec = val == recommended;
                          return DropdownMenuItem<int>(
                            value: val,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    c['name'] as String,
                                    style: const TextStyle(fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isRec) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.greenAccent.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: Colors.greenAccent.withValues(
                                          alpha: 0.3,
                                        ),
                                      ),
                                    ),
                                    child: const Text(
                                      'REC',
                                      style: TextStyle(
                                        fontSize: 8,
                                        color: Colors.greenAccent,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }).toList();
                      }(),
                      onChanged: (val) {
                        if (val != null) {
                          ref
                              .read(activeProjectProvider.notifier)
                              .updateSettings(concurrencyLimit: val);
                        }
                      },
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Detected CPU Cores: ${Platform.numberOfProcessors}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white38,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Higher values speed up audio prep but increase CPU heat and may cause system lag during export.',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Extra Flags
          const Text(
            'EXTRA FFMPEG FLAGS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: project.extraFlags.join(' '),
                  decoration: InputDecoration(
                    hintText: '-vf "vignette" -af "volume=1.5"',
                    hintStyle: TextStyle(color: Colors.grey[700], fontSize: 13),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    filled: true,
                    fillColor: Colors.black26,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Colors.lightBlueAccent,
                  ),
                  onChanged: (val) {
                    final flags = val
                        .split(' ')
                        .where((s) => s.isNotEmpty)
                        .toList();
                    ref
                        .read(activeProjectProvider.notifier)
                        .updateSettings(extraFlags: flags);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Separate flags with spaces. Use with caution.',
            style: TextStyle(fontSize: 10, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          // Hardware Acceleration Info
          ref
              .watch(hardwareInfoProvider)
              .when(
                data: (hw) {
                  final isWindows = Platform.isWindows;
                  final showSetupHint = isWindows && !hw.isFfmpegInstalled;

                  return Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black38,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: project.detectedEncoder != null
                                ? Colors.greenAccent.withValues(alpha: 0.1)
                                : Colors.orangeAccent.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              project.detectedEncoder != null
                                  ? (project.useGpu ? Icons.bolt : Icons.memory)
                                  : Icons.developer_board,
                              color: project.detectedEncoder != null
                                  ? (project.useGpu
                                        ? Colors.greenAccent
                                        : Colors.white70)
                                  : Colors.orangeAccent,
                              size: 20,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    project.detectedEncoder != null
                                        ? (project.useGpu
                                              ? 'GPU Acceleration Active'
                                              : 'CPU Encoding Active')
                                        : 'CPU Encoding (Default)',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    project.detectedEncoder != null
                                        ? (project.useGpu
                                              ? 'Using ${project.detectedEncoder} on ${hw.gpuName} for faster rendering.'
                                              : 'Hardware found but using CPU for encoding.')
                                        : 'No compatible GPU found. Using CPU for processing.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value:
                                  project.detectedEncoder != null &&
                                  project.useGpu,
                              activeTrackColor: Colors.greenAccent.withValues(
                                alpha: 0.5,
                              ),
                              thumbColor:
                                  WidgetStateProperty.resolveWith<Color?>((
                                    states,
                                  ) {
                                    if (states.contains(WidgetState.selected)) {
                                      return Colors.greenAccent;
                                    }
                                    if (states.contains(WidgetState.disabled)) {
                                      return Colors.grey[800];
                                    }
                                    return null; // Use default
                                  }),
                              onChanged: project.detectedEncoder != null
                                  ? (val) {
                                      ref
                                          .read(activeProjectProvider.notifier)
                                          .updateSettings(useGpu: val);
                                    }
                                  : null,
                            ),
                          ],
                        ),
                      ),
                      if (showSetupHint) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.redAccent.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    color: Colors.redAccent,
                                    size: 18,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'FFmpeg Not Found',
                                    style: TextStyle(
                                      color: Colors.redAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'FFmpeg is required for video processing on Windows. Please install it and add it to your System PATH.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: () => launchUrl(
                                      Uri.parse(
                                        'https://ffmpeg.org/download.html',
                                      ),
                                    ),
                                    icon: const Icon(Icons.download, size: 14),
                                    label: const Text('Download FFmpeg'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.redAccent,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      textStyle: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  TextButton(
                                    onPressed: () {
                                      // Refresh hardware info
                                      ref.invalidate(hardwareInfoProvider);
                                    },
                                    child: const Text(
                                      'I installed it, check again',
                                    ),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.grey,
                                      textStyle: const TextStyle(fontSize: 11),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectSettingsInputs(
    BuildContext context,
    WidgetRef ref,
    SwalokaProject project,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'VIDEO TITLE *',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: project.title,
                      onChanged: (val) => ref
                          .read(activeProjectProvider.notifier)
                          .updateSettings(title: val),
                      decoration: InputDecoration(
                        hintText: 'My YouTube Video',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        filled: true,
                        fillColor: Colors.black26,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AUTHOR / CHANNEL *',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: project.author,
                      onChanged: (val) => ref
                          .read(activeProjectProvider.notifier)
                          .updateSettings(author: val),
                      decoration: InputDecoration(
                        hintText: 'Swaloka Looping Tool',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        filled: true,
                        fillColor: Colors.black26,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'COMMENT',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: project.comment,
                      onChanged: (val) => ref
                          .read(activeProjectProvider.notifier)
                          .updateSettings(comment: val),
                      decoration: InputDecoration(
                        hintText: 'Produced with Swaloka',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        filled: true,
                        fillColor: Colors.black26,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'RESOLUTION',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue:
                          '${project.resolutionWidth}x${project.resolutionHeight}',
                      isExpanded: true,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        filled: true,
                        fillColor: Colors.black26,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      dropdownColor: const Color(0xFF1A1A1A),
                      items:
                          [
                            {'name': '1080p (FHD)', 'w': 1920, 'h': 1080},
                            {'name': '720p (HD)', 'w': 1280, 'h': 720},
                            {'name': '4K (UHD)', 'w': 3840, 'h': 2160},
                            {'name': 'Shorts (Vertical)', 'w': 1080, 'h': 1920},
                          ].map((res) {
                            return DropdownMenuItem<String>(
                              value: '${res['w']}x${res['h']}',
                              child: Text(
                                res['name'] as String,
                                style: const TextStyle(fontSize: 13),
                              ),
                            );
                          }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          final parts = val.split('x');
                          ref
                              .read(activeProjectProvider.notifier)
                              .updateSettings(
                                resolutionWidth: int.parse(parts[0]),
                                resolutionHeight: int.parse(parts[1]),
                              );
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'OUTPUT DIRECTORY',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => _selectCustomOutput(context, ref),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.folder_open,
                              size: 16,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                project.effectiveOutputPath,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(
                              Icons.edit,
                              size: 14,
                              color: Colors.grey,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineHeader(
    BuildContext context,
    WidgetRef ref,
    String title,
    IconData icon, {
    Widget? trailing,
  }) {
    final collapsedSections = ref.watch(collapsedSectionsProvider);
    final isCollapsed = collapsedSections.contains(title);

    return InkWell(
      onTap: () => ref.read(collapsedSectionsProvider.notifier).toggle(title),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(
              isCollapsed ? Icons.chevron_right : Icons.expand_more,
              size: 16,
              color: Colors.grey[600],
            ),
            const SizedBox(width: 4),
            Icon(icon, size: 14, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: Colors.grey[600],
                letterSpacing: 1.2,
              ),
            ),
            if (trailing != null) ...[const Spacer(), trailing],
          ],
        ),
      ),
    );
  }

  bool _isVideoFile(String path) {
    final ext = path.split('.').last.toLowerCase();
    return ['mp4', 'mov', 'avi', 'mkv', 'flv', 'webm'].contains(ext);
  }

  Widget _buildMediaItem(
    BuildContext context,
    String path,
    IconData icon, {
    bool isVideo = false,
    int? index,
    String? label,
    required VoidCallback onRemove,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isVideo
            ? Colors.blueGrey.withValues(alpha: 0.1)
            : Colors.deepPurple.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isVideo
              ? Colors.blueGrey.withValues(alpha: 0.2)
              : Colors.deepPurple.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          MediaPreviewPlayer(path: path, isVideo: isVideo),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (index != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '#$index',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        path.split('/').last,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (label != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  path,
                  style: TextStyle(fontSize: 9, color: Colors.grey[800]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: Icon(
              Icons.delete_outline,
              size: 18,
              color: Colors.red[300]?.withValues(alpha: 0.7),
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Remove Asset',
          ),
        ],
      ),
    );
  }

  bool _isAudioFile(String path) {
    final ext = path.split('.').last.toLowerCase();
    return ['mp3', 'wav', 'm4a', 'aac', 'ogg', 'flac'].contains(ext);
  }

  Widget _buildProcessingStatus(BuildContext context, ProcessingState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Processing...',
            style: TextStyle(fontSize: 12, color: Colors.grey[400]),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: state.progress, minHeight: 4),
          const SizedBox(height: 4),
          Text(
            '${(state.progress * 100).toStringAsFixed(0)}%',
            style: const TextStyle(fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage(BuildContext context, String error) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.errorContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.error.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            size: 16,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFF333333))),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => _showDonateDialog(context),
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.favorite, size: 18, color: Colors.redAccent),
                  const SizedBox(width: 12),
                  Text(
                    'Donate',
                    style: TextStyle(color: Colors.grey[400], fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          Text(
            'v1.0.0',
            style: TextStyle(color: Colors.grey[800], fontSize: 10),
          ),
        ],
      ),
    );
  }

  void _showDonateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF333333)),
        ),
        title: Row(
          children: [
            const Icon(Icons.favorite, color: Colors.redAccent),
            const SizedBox(width: 16),
            const Text(
              'Support Development',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'If you find this tool helpful, consider supporting the developer!',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 24),
            _buildDonateOption(
              context,
              'OVO',
              AppConstants.ovoAccount,
              Colors.deepPurple,
            ),
            const SizedBox(height: 12),
            _buildDonateOption(
              context,
              'DANA',
              AppConstants.danaAccount,
              Colors.blue,
            ),
            const SizedBox(height: 12),
            _buildDonateOption(
              context,
              'GOPAY',
              AppConstants.gopayAccount,
              Colors.green,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  Widget _buildDonateOption(
    BuildContext context,
    String name,
    String account,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              account,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                color: Colors.white,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 16, color: Colors.grey),
            onPressed: () {
              // Copy to clipboard logic could go here
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$name account copied'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _createNewProject(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select or Create a Project Folder',
    );

    if (result == null) return;

    final nameController = TextEditingController(text: result.split('/').last);
    if (context.mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF333333)),
          ),
          title: const Text(
            'Confirm Project Name',
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: nameController,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Project Name',
              filled: true,
              fillColor: Colors.black26,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isNotEmpty) {
                  ref
                      .read(activeProjectProvider.notifier)
                      .createProject(result, nameController.text);
                  Navigator.pop(context);
                }
              },
              child: const Text('Create Project'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _openProject(BuildContext context, WidgetRef ref) async {
    // 1. Try Folder Picker first (more intuitive for "Opening a Project")
    final dir = await FilePicker.platform.getDirectoryPath(
      lockParentWindow: true,
      dialogTitle: 'Select your Project Folder (e.g., "yutub")',
    );

    if (dir != null) {
      final projectFile = File('$dir/project.swaloka');
      if (await projectFile.exists()) {
        ref.read(activeProjectProvider.notifier).loadProject(dir);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No project.swaloka file found in this folder.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      // 2. Fallback: If they cancel the folder picker, maybe they want to pick the file directly?
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['swaloka'],
        lockParentWindow: true,
        dialogTitle: 'Or pick the .swaloka file directly',
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final projectDir = file.parent.path;
        ref.read(activeProjectProvider.notifier).loadProject(projectDir);
      }
    }
  }

  Future<void> _selectBackgroundVideo(
    BuildContext context,
    WidgetRef ref,
  ) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );
      if (result != null && result.files.single.path != null) {
        ref
            .read(activeProjectProvider.notifier)
            .setBackgroundVideo(result.files.single.path!);
        ref.read(processingStateProvider.notifier).reset();
      }
    } catch (e) {
      ref.read(processingStateProvider.notifier).setError('Error: $e');
    }
  }

  Future<void> _selectAudioFiles(BuildContext context, WidgetRef ref) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'm4a', 'aac', 'ogg', 'flac'],
        allowMultiple: true,
      );
      if (result != null && result.paths.isNotEmpty) {
        final selectedFiles = result.paths
            .where((path) => path != null)
            .cast<String>()
            .toList();
        final current = List<String>.from(
          ref.read(activeProjectProvider)?.audioFiles ?? [],
        );
        current.addAll(selectedFiles);
        ref.read(activeProjectProvider.notifier).setAudioFiles(current);
        ref.read(processingStateProvider.notifier).reset();
      }
    } catch (e) {
      ref.read(processingStateProvider.notifier).setError('Error: $e');
    }
  }

  Future<void> _selectCustomOutput(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result != null) {
      ref
          .read(activeProjectProvider.notifier)
          .updateSettings(customOutputPath: result);
    }
  }

  Future<void> _mergeVideos(BuildContext context, WidgetRef ref) async {
    final project = ref.read(activeProjectProvider);
    if (project == null) return;

    final backgroundVideo = project.backgroundVideo;
    final audioFiles = project.audioFiles;
    final outputDir = project.effectiveOutputPath;

    if (backgroundVideo == null || audioFiles.isEmpty) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const MergeProgressDialog(),
    );

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final sanitizedTitle = (project.title ?? 'video').replaceAll(
        RegExp(r'[^a-zA-Z0-9\s]'),
        '',
      );
      final outputFileName =
          '${sanitizedTitle.replaceAll(' ', '_')}_$timestamp.mp4';
      final outputPath = '$outputDir/$outputFileName';
      final logFilePath = '${project.rootPath}/logs/ffmpeg_log_$timestamp.log';

      ref.read(processingStateProvider.notifier).startProcessing();
      final service = ref.read(videoMergerServiceProvider);

      await service.mergeVideoWithAudio(
        backgroundVideoPath: backgroundVideo,
        audioFiles: audioFiles,
        outputPath: outputPath,
        title: project.title,
        author: project.author,
        comment: project.comment,
        width: project.resolutionWidth,
        height: project.resolutionHeight,
        preset: project.preset,
        crf: project.crf,
        enableFastStart: project.enableFastStart,
        useGpu: project.useGpu,
        concurrencyLimit: project.concurrencyLimit,
        extraFlags: project.extraFlags,
        onProgress: (progress) =>
            ref.read(processingStateProvider.notifier).updateProgress(progress),
        onLog: (log) => ref.read(processingStateProvider.notifier).addLog(log),
      );

      final logs = ref.read(processingStateProvider).logs;
      final logFile = File(logFilePath);
      await logFile.writeAsString(logs.join('\n'));

      ref.read(processingStateProvider.notifier).setSuccess(outputPath);
      ref.read(projectFilesProvider.notifier).refresh();
    } catch (e) {
      ref.read(processingStateProvider.notifier).setError(e.toString());
    }
  }
}

class DropZoneWidget extends StatefulWidget {
  final String label;
  final IconData icon;
  final Function(List<DropItem>) onFilesDropped;
  final VoidCallback onTap;

  const DropZoneWidget({
    super.key,
    required this.label,
    required this.icon,
    required this.onFilesDropped,
    required this.onTap,
  });

  @override
  State<DropZoneWidget> createState() => _DropZoneWidgetState();
}

class _DropZoneWidgetState extends State<DropZoneWidget> {
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      onDragDone: (details) {
        debugPrint('DND: Dropped ${details.files.length} files');
        for (var f in details.files) {
          debugPrint('DND: File path: ${f.path}');
        }
        setState(() => _isDragging = false);
        widget.onFilesDropped(details.files);
      },
      onDragEntered: (details) {
        debugPrint('DND: Drag entered');
        setState(() => _isDragging = true);
      },
      onDragExited: (details) {
        debugPrint('DND: Drag exited');
        setState(() => _isDragging = false);
      },
      onDragUpdated: (details) {
        // debugPrint('DND: Drag updated at ${details.localPosition}');
      },
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 100,
          width: double.infinity,
          decoration: BoxDecoration(
            color: _isDragging
                ? Colors.deepPurple.withValues(alpha: 0.15)
                : Colors.black26,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isDragging
                  ? Colors.deepPurpleAccent
                  : const Color(0xFF333333),
              width: _isDragging ? 2 : 1,
              style: BorderStyle.solid,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: _isDragging ? 1.2 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  widget.icon,
                  color: _isDragging
                      ? Colors.deepPurpleAccent
                      : Colors.grey[600],
                  size: 32,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.label,
                style: TextStyle(
                  color: _isDragging ? Colors.white : Colors.grey[600],
                  fontSize: 13,
                  fontWeight: _isDragging ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MediaPreviewPlayer extends StatefulWidget {
  final String path;
  final bool isVideo;

  const MediaPreviewPlayer({
    super.key,
    required this.path,
    this.isVideo = false,
  });

  @override
  State<MediaPreviewPlayer> createState() => _MediaPreviewPlayerState();
}

class _MediaPreviewPlayerState extends State<MediaPreviewPlayer> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  @override
  void didUpdateWidget(MediaPreviewPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _controller.dispose();
      _initialized = false;
      _initController();
    }
  }

  void _initController() {
    _controller = VideoPlayerController.file(File(widget.path));
    _controller
        .initialize()
        .then((_) {
          if (mounted) {
            setState(() {
              _initialized = true;
            });
          }
        })
        .catchError((error) {
          if (mounted) {
            setState(() {
              _error = error.toString();
            });
          }
        });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return '${twoDigits(duration.inHours)}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Container(
        width: 120,
        height: 68,
        decoration: BoxDecoration(
          color: Colors.black45,
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Icon(
          Icons.error_outline,
          size: 20,
          color: Colors.redAccent,
        ),
      );
    }

    if (!_initialized) {
      return Container(
        width: 120,
        height: 68,
        decoration: BoxDecoration(
          color: Colors.black45,
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: 120,
        height: 68,
        color: Colors.black,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (widget.isVideo)
              AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              )
            else
              const Icon(
                Icons.audiotrack,
                color: Colors.deepPurpleAccent,
                size: 30,
              ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  setState(() {
                    _controller.value.isPlaying
                        ? _controller.pause()
                        : _controller.play();
                  });
                },
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Icon(
                      _controller.value.isPlaying
                          ? Icons.pause
                          : Icons.play_arrow,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            if (_initialized)
              Positioned(
                bottom: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(
                    _formatDuration(_controller.value.duration),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: VideoProgressIndicator(
                _controller,
                allowScrubbing: true,
                padding: EdgeInsets.zero,
                colors: VideoProgressColors(
                  playedColor: widget.isVideo ? Colors.blue : Colors.deepPurple,
                  bufferedColor: Colors.white24,
                  backgroundColor: Colors.transparent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
