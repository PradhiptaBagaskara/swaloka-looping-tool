import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:swaloka_looping_tool/features/landing_page/presentation/pages/ffmpeg_error_page.dart';
import 'package:swaloka_looping_tool/features/video_merger/presentation/providers/ffmpeg_provider.dart';
import 'package:swaloka_looping_tool/features/video_merger/presentation/providers/video_merger_providers.dart';
import 'package:swaloka_looping_tool/widgets/settings_dialog.dart';

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

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // FFmpeg status banner
        if (ffmpegStatus == null)
          _buildFFmpegCheckingBanner(context)
        else if (!ffmpegStatus)
          _buildFFmpegWarning(context),

        // Logo
        Container(
          padding: EdgeInsets.all(
            Theme.of(context).textTheme.headlineLarge!.fontSize! * 0.75,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.movie_filter,
            size: Theme.of(context).textTheme.headlineLarge!.fontSize! * 2.5,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        SizedBox(height: Theme.of(context).textTheme.headlineLarge!.fontSize),

        // Title
        Text(
          'SWALOKA LOOPING TOOL',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: 4,
          ),
        ),
        SizedBox(
          height: Theme.of(context).textTheme.headlineLarge!.fontSize! * 1.75,
        ),

        // Action buttons - use Wrap for responsive layout
        Wrap(
          alignment: WrapAlignment.center,
          spacing: Theme.of(context).textTheme.bodyMedium!.fontSize!,
          runSpacing: Theme.of(context).textTheme.bodyMedium!.fontSize!,
          children: [
            _buildLandingCard(
              context,
              title: 'Create Project',
              description: 'Start a new video project from scratch',
              icon: Icons.add_to_photos_outlined,
              onTap: () => _createNewProject(context),
            ),
            _buildLandingCard(
              context,
              title: 'Open Project',
              description: 'Continue working on a saved project',
              icon: Icons.folder_open_outlined,
              onTap: () => _openProject(context),
            ),
          ],
        ),

        // Recent projects
        if (recentProjects.isNotEmpty) ...[
          SizedBox(
            height: Theme.of(context).textTheme.headlineLarge!.fontSize! * 2,
          ),
          Container(
            constraints: BoxConstraints(
              maxWidth:
                  Theme.of(context).textTheme.titleLarge!.fontSize! * 25.2,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(
                    left:
                        Theme.of(context).textTheme.bodySmall!.fontSize! * 0.67,
                    bottom:
                        Theme.of(context).textTheme.bodyMedium!.fontSize! *
                        1.14,
                  ),
                  child: Text(
                    'Recent Projects',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
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

        SizedBox(
          height: Theme.of(context).textTheme.headlineLarge!.fontSize! * 2,
        ),
        // Version info and settings
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ref
                .watch(appVersionProvider)
                .when(
                  data: (version) => Text(
                    version,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      letterSpacing: 1,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                ),
            SizedBox(
              width: Theme.of(context).textTheme.bodyMedium!.fontSize! * 1.14,
            ),
            IconButton(
              onPressed: () => showSettingsDialog(context),
              icon: Icon(
                Icons.settings,
                size: Theme.of(context).textTheme.bodyMedium!.fontSize! * 1.14,
              ),
              tooltip: 'Settings',
              style: IconButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFFmpegCheckingBanner(BuildContext context) {
    final baseFontSize = Theme.of(context).textTheme.bodyMedium!.fontSize!;

    return Container(
      margin: EdgeInsets.only(bottom: baseFontSize * 1.71),
      padding: EdgeInsets.all(baseFontSize * 1.14),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(baseFontSize * 0.86),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3), width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: baseFontSize * 1.71,
            height: baseFontSize * 1.71,
            child: const CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.blue,
            ),
          ),
          SizedBox(width: baseFontSize * 1.14),
          Text(
            'Checking FFmpeg installation...',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFFmpegWarning(BuildContext context) {
    final baseFontSize = Theme.of(context).textTheme.bodyMedium!.fontSize!;

    return Container(
      margin: EdgeInsets.only(bottom: baseFontSize * 1.71),
      padding: EdgeInsets.all(baseFontSize * 1.14),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(baseFontSize * 0.86),
        border: Border.all(
          color: Colors.orange.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange,
            size: baseFontSize * 2.29,
          ),
          SizedBox(width: baseFontSize * 1.14),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'FFmpeg Not Found',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: baseFontSize * 0.29),
                Text(
                  'FFmpeg is required for video processing. Please install it to continue.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: baseFontSize * 0.57),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
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
                    SizedBox(width: baseFontSize * 0.57),
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
    final baseFontSize = Theme.of(context).textTheme.labelMedium!.fontSize!;
    final cardWidth = baseFontSize * 16; // Compact card width
    final cardPadding = baseFontSize * 2; // Compact padding
    final iconSize = baseFontSize * 3; // Icon size

    return SizedBox(
      width: cardWidth,
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.all(cardPadding),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: iconSize,
                  color: Theme.of(context).colorScheme.primary,
                ),
                SizedBox(height: baseFontSize * 0.8),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: baseFontSize * 0.4),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: baseFontSize * 0.85,
                  ),
                ),
              ],
            ),
          ),
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
    final baseFontSize = Theme.of(context).textTheme.bodyMedium!.fontSize!;

    return Padding(
      padding: EdgeInsets.only(bottom: baseFontSize * 0.57),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _loadProject(path),
          onSecondaryTapDown: (details) {
            _showProjectContextMenu(context, path, details);
          },
          borderRadius: BorderRadius.circular(baseFontSize * 0.86),
          child: Container(
            padding: EdgeInsets.all(baseFontSize * 1.14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(baseFontSize * 0.86),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(baseFontSize * 0.71),
                  decoration: BoxDecoration(
                    color: isCompatible
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(
                            context,
                          ).colorScheme.outline.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(baseFontSize * 0.57),
                  ),
                  child: Icon(
                    isCompatible ? Icons.movie_filter : Icons.folder_outlined,
                    size: baseFontSize * 1.43,
                    color: isCompatible
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                SizedBox(width: baseFontSize * 1.14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        projectName,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: baseFontSize * 0.14),
                      Text(
                        normalizedPath,
                        style: Theme.of(context).textTheme.labelMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: baseFontSize * 1.14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
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
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    showMenu(
      context: context,
      position: RelativeRect.fromRect(
        details.globalPosition & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      items: [
        const PopupMenuItem(
          value: 'remove',
          child: Text('Remove from Recent'),
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
      unawaited(
        showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            title: Text(
              'Confirm Project Name',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            content: TextField(
              controller: nameController,
              autofocus: true,
              style: Theme.of(context).textTheme.bodyLarge,
              decoration: InputDecoration(
                hintText: 'Project Name',
                filled: true,
                fillColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
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
    }
    // Removed fallback file picker - user can just try again
  }
}
