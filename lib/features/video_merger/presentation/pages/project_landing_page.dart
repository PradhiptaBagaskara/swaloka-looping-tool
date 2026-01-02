import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../providers/video_merger_providers.dart';
import '../providers/ffmpeg_provider.dart';
import 'ffmpeg_error_page.dart';

/// Landing page for creating or opening projects
class ProjectLandingPage extends ConsumerStatefulWidget {
  const ProjectLandingPage({super.key});

  @override
  ConsumerState<ProjectLandingPage> createState() => _ProjectLandingPageState();
}

class _ProjectLandingPageState extends ConsumerState<ProjectLandingPage> {
  @override
  Widget build(BuildContext context) {
    final recentProjects = ref.watch(recentProjectsProvider);
    final ffmpegStatus = ref.watch(ffmpegStatusProvider);

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
                  // FFmpeg status banner
                  if (ffmpegStatus == null)
                    _buildFFmpegCheckingBanner(context)
                  else if (ffmpegStatus == false)
                    _buildFFmpegWarning(context),

                  // Logo
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

                  // Title
                  Text(
                    'SWALOKA LOOPING TOOL',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 56),

                  // Action buttons - use Wrap for responsive layout
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 24,
                    runSpacing: 24,
                    children: [
                      _buildLandingCard(
                        context,
                        title: 'Create New Project',
                        description: 'Start a new video project from scratch',
                        icon: Icons.add_to_photos_outlined,
                        onTap: () => _createNewProject(context),
                      ),
                      _buildLandingCard(
                        context,
                        title: 'Open Existing Project',
                        description: 'Continue working on a saved project',
                        icon: Icons.folder_open_outlined,
                        onTap: () => _openProject(context),
                      ),
                    ],
                  ),

                  // Recent projects
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
                              'Recent Projects',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[600],
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                          ...recentProjects.map(
                            (path) => _buildRecentProjectItem(context, path),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 64),
                  // Version info
                  ref
                      .watch(appVersionProvider)
                      .when(
                        data: (version) => Text(
                          version,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[700],
                            letterSpacing: 1,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        loading: () => const SizedBox.shrink(),
                        error: (_, _) => const SizedBox.shrink(),
                      ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFFmpegCheckingBanner(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3), width: 2),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.blue,
            ),
          ),
          SizedBox(width: 16),
          Text(
            'Checking FFmpeg installation...',
            style: TextStyle(color: Colors.blue, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildFFmpegWarning(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.orange.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange,
            size: 32,
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'FFmpeg Not Found',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'FFmpeg is required for video processing. Please install it to continue.',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const FFmpegErrorPage(),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                        side: const BorderSide(color: Colors.orange),
                      ),
                      child: const Text('Installation Guide'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        ref.read(ffmpegStatusProvider.notifier).recheckFFmpeg();
                      },
                      child: const Text('Re-check'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
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

  Widget _buildRecentProjectItem(BuildContext context, String path) {
    // Use platform-aware path operations
    final normalizedPath = p.normalize(path);
    final projectName = p.basename(normalizedPath);
    final projectFile = File(p.join(normalizedPath, 'project.swaloka'));
    final isCompatible = projectFile.existsSync();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _loadProject(path),
          onSecondaryTapDown: (details) {
            _showProjectContextMenu(context, path, details);
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
                  child: Icon(
                    isCompatible ? Icons.movie_filter : Icons.folder_outlined,
                    size: 20,
                    color: isCompatible ? Colors.black : Colors.grey,
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
                        normalizedPath,
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

  void _showProjectContextMenu(
    BuildContext context,
    String path,
    TapDownDetails details,
  ) {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
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
  }

  void _loadProject(String path) {
    // Use microtask to avoid InkWell animation issues during state change
    Future.microtask(() {
      if (!mounted) return;

      ref
          .read(activeProjectProvider.notifier)
          .loadProject(
            path,
            onProjectAdded: (p) {
              if (!mounted) return;
              ref.read(recentProjectsProvider.notifier).addProject(p);
            },
            onFilesRefresh: () {
              if (!mounted) return;
              final project = ref.read(activeProjectProvider);
              if (project != null) {
                ref
                    .read(projectFilesProvider.notifier)
                    .refresh(project.effectiveOutputPath);
              }
            },
          );
    });
  }

  Future<void> _createNewProject(BuildContext context) async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select or Create a Project Folder',
    );

    if (result == null) return;

    // Use platform-aware path operations
    final normalizedPath = p.normalize(result);
    final nameController = TextEditingController(
      text: p.basename(normalizedPath),
    );
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
                  Navigator.pop(context);
                  // Use microtask to avoid InkWell animation issues
                  Future.microtask(() {
                    if (!mounted) return;

                    ref
                        .read(activeProjectProvider.notifier)
                        .createProject(
                          result,
                          nameController.text,
                          onProjectAdded: (p) {
                            if (!mounted) return;
                            ref
                                .read(recentProjectsProvider.notifier)
                                .addProject(p);
                          },
                          onFilesRefresh: () {
                            if (!mounted) return;
                            final project = ref.read(activeProjectProvider);
                            if (project != null) {
                              ref
                                  .read(projectFilesProvider.notifier)
                                  .refresh(project.effectiveOutputPath);
                            }
                          },
                        );
                  });
                }
              },
              child: const Text('Create Project'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _openProject(BuildContext context) async {
    final dir = await FilePicker.platform.getDirectoryPath(
      lockParentWindow: true,
      dialogTitle: 'Select your Project Folder',
    );

    if (dir != null) {
      final normalizedDir = p.normalize(dir);
      final projectFile = File(p.join(normalizedDir, 'project.swaloka'));
      if (await projectFile.exists()) {
        _loadProject(normalizedDir);
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
      // Fallback: pick the file directly
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['swaloka'],
        lockParentWindow: true,
        dialogTitle: 'Or pick the .swaloka file directly',
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        final projectDir = File(filePath).parent.path;
        _loadProject(projectDir);
      }
    }
  }
}
