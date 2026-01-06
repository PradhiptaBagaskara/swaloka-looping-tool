import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swaloka_looping_tool/features/media_tools/presentation/pages/audio_tools_page.dart';
import 'package:swaloka_looping_tool/features/media_tools/presentation/pages/video_tools_page.dart';
import 'package:swaloka_looping_tool/features/video_merger/domain/models/swaloka_project.dart';
import 'package:swaloka_looping_tool/features/video_merger/presentation/providers/ffmpeg_provider.dart';
import 'package:swaloka_looping_tool/features/video_merger/presentation/providers/video_merger_providers.dart';
import 'package:swaloka_looping_tool/widgets/project_settings_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

/// Layout wrapper for the project workspace with sidebar navigation
class ProjectLayout extends ConsumerStatefulWidget {
  const ProjectLayout({
    required this.project,
    required this.looperContent,
    this.looperQuickAction,
    super.key,
  });

  final SwalokaProject project;
  final Widget looperContent;
  final Widget? looperQuickAction;

  @override
  ConsumerState<ProjectLayout> createState() => _ProjectLayoutState();
}

class _ProjectLayoutState extends ConsumerState<ProjectLayout> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Sidebar
                _buildSidebar(context),
                // Main Area
                Expanded(
                  child: Column(
                    children: [
                      _buildMainHeader(context),
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          color: Theme.of(context).scaffoldBackgroundColor,
                          child: IndexedStack(
                            index: _selectedTab,
                            children: [
                              widget.looperContent,
                              AudioToolsPage(
                                initialDirectory: widget.project.rootPath,
                              ),
                              VideoToolsPage(
                                initialDirectory: widget.project.rootPath,
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
          );
        },
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    final baseFontSize = Theme.of(context).textTheme.bodyMedium!.fontSize!;

    return Container(
      width: baseFontSize * 22.86,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          right: BorderSide(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSidebarHeader(context),
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(
                horizontal: baseFontSize * 1.43,
                vertical: baseFontSize * 0.71,
              ),
              children: [
                _buildSectionTitle(context, 'Navigation'),
                SizedBox(height: baseFontSize * 0.86),
                _buildNavButton(0, 'Looping Tools', Icons.loop),
                _buildNavButton(1, 'Audio Tools', Icons.audio_file),
                _buildNavButton(2, 'Video Tools', Icons.video_library),
                SizedBox(height: baseFontSize * 2.29),
                if (_selectedTab == 0 && widget.looperQuickAction != null) ...[
                  _buildSectionTitle(context, 'Quick Actions'),
                  SizedBox(height: baseFontSize * 1.14),
                  widget.looperQuickAction!,
                ],
              ],
            ),
          ),
          _buildSidebarFooter(context),
        ],
      ),
    );
  }

  Widget _buildNavButton(int index, String label, IconData icon) {
    final isSelected = _selectedTab == index;
    final baseFontSize = Theme.of(context).textTheme.bodyMedium!.fontSize!;

    return Padding(
      padding: EdgeInsets.only(bottom: baseFontSize * 0.57),
      child: InkWell(
        onTap: () => setState(() => _selectedTab = index),
        borderRadius: BorderRadius.circular(baseFontSize * 0.57),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: baseFontSize * 0.86,
            vertical: baseFontSize * 0.71,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(baseFontSize * 0.57),
            border: isSelected
                ? Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.5),
                  )
                : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: baseFontSize * 1.43,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              SizedBox(width: baseFontSize * 0.86),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isSelected
                      ? Theme.of(context).colorScheme.onSurface
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarHeader(BuildContext context) {
    final appVersion = ref.watch(appVersionProvider);
    final baseFontSize = Theme.of(context).textTheme.bodyMedium!.fontSize!;

    return Container(
      padding: EdgeInsets.all(baseFontSize * 1.71),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(baseFontSize * 0.57),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(baseFontSize * 0.71),
                ),
                child: Icon(
                  Icons.movie_filter,
                  color: Theme.of(context).colorScheme.onPrimary,
                  size: baseFontSize * 1.71,
                ),
              ),
              SizedBox(width: baseFontSize * 0.86),
              Text(
                'SWALOKA',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  letterSpacing: 2,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          SizedBox(height: baseFontSize * 0.71),
          Row(
            children: [
              Text(
                'LOOPING TOOL',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              SizedBox(width: baseFontSize * 0.57),
              appVersion.when<Widget>(
                data: (String version) => Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: baseFontSize * 0.43,
                    vertical: baseFontSize * 0.14,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(baseFontSize * 0.29),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    version,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                loading: () => const SizedBox.shrink(),
                error: (Object error, StackTrace stackTrace) =>
                    const SizedBox.shrink(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title.toUpperCase(),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildMainHeader(BuildContext context) {
    final baseFontSize = Theme.of(context).textTheme.bodyMedium!.fontSize!;

    return Container(
      height: baseFontSize * 3.43,
      padding: EdgeInsets.symmetric(horizontal: baseFontSize * 1.71),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ),
      child: Row(
        children: [
          // Close Project Button
          Tooltip(
            message: 'Close Project',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _closeProject,
                borderRadius: BorderRadius.circular(baseFontSize * 0.57),
                hoverColor: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.2),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: baseFontSize * 0.71,
                    vertical: baseFontSize * 0.43,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(baseFontSize * 0.43),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.arrow_back_rounded,
                        size: baseFontSize,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      SizedBox(width: baseFontSize * 0.43),
                      Text(
                        'Close',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: baseFontSize * 1.14),
          Icon(
            Icons.folder_open,
            size: baseFontSize,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          SizedBox(width: baseFontSize * 0.57),
          Text(
            widget.project.name,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(width: baseFontSize * 0.57),
          Text(
            '/',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          SizedBox(width: baseFontSize * 0.57),
          Expanded(
            child: InkWell(
              onTap: () async {
                final uri = Uri.directory(widget.project.rootPath);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
              },
              child: Text(
                widget.project.rootPath,
                style: Theme.of(context).textTheme.labelSmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          VerticalDivider(
            indent: baseFontSize * 0.86,
            endIndent: baseFontSize * 0.86,
            width: baseFontSize * 2.29,
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
            thickness: 1,
          ),
          TextButton.icon(
            onPressed: () => _showDonateDialog(context),
            icon: const Icon(Icons.favorite, color: Colors.redAccent),
            label: Text(
              'Support Us',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: baseFontSize * 0.86),
            ),
          ),
        ],
      ),
    );
  }

  void _closeProject() {
    ref.read(activeProjectProvider.notifier).closeProject();
  }

  Widget _buildSidebarFooter(BuildContext context) {
    final baseFontSize = Theme.of(context).textTheme.bodyMedium!.fontSize!;

    return Container(
      padding: EdgeInsets.all(baseFontSize * 1.14),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: () => _showDonateDialog(context),
                  icon: const Icon(
                    Icons.favorite,
                    color: Colors.redAccent,
                  ),
                  label: Text(
                    'Support',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              ),
              IconButton(
                onPressed: () =>
                    showProjectSettingsDialog(context, widget.project),
                icon: Icon(
                  Icons.settings,
                  size: baseFontSize * 1.29,
                ),
                tooltip: 'Project Settings',
                style: IconButton.styleFrom(
                  foregroundColor: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          SizedBox(height: baseFontSize * 0.29),
          Text(
            'Made with ❤️ by Swaloka',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: baseFontSize * 0.64,
            ),
          ),
        ],
      ),
    );
  }

  void _showDonateDialog(BuildContext context) {
    final baseFontSize = Theme.of(context).textTheme.bodyMedium!.fontSize!;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Row(
          children: [
            const Icon(Icons.favorite, color: Colors.redAccent),
            SizedBox(width: baseFontSize * 0.86),
            Text(
              'Support Development',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'If you find this tool useful, consider supporting its development!',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            SizedBox(height: baseFontSize * 1.43),
            _buildDonateOption(
              context,
              Icons.coffee,
              'Saweria',
              'Support via Saweria',
              () async {
                final url = Uri.parse('https://saweria.co/masimas');
                if (await canLaunchUrl(url)) await launchUrl(url);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDonateOption(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    final baseFontSize = Theme.of(context).textTheme.bodyMedium!.fontSize!;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(baseFontSize * 0.57),
      child: Container(
        padding: EdgeInsets.all(baseFontSize * 0.86),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(baseFontSize * 0.57),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: Theme.of(context).colorScheme.primary,
            ),
            SizedBox(width: baseFontSize * 0.86),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.open_in_new,
              size: baseFontSize * 1.14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
