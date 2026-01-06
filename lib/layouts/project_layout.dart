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
      backgroundColor: const Color(0xFF0F0F0F),
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
                          color: const Color(0xFF0F0F0F),
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
    return Container(
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              children: [
                _buildSectionTitle(context, 'Navigation'),
                const SizedBox(height: 12),
                _buildNavButton(0, 'Project Looper', Icons.loop),
                _buildNavButton(1, 'Audio Tools', Icons.audio_file),
                _buildNavButton(2, 'Video Tools', Icons.video_library),
                const SizedBox(height: 32),
                if (_selectedTab == 0 && widget.looperQuickAction != null) ...[
                  _buildSectionTitle(context, 'Quick Actions'),
                  const SizedBox(height: 16),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => setState(() => _selectedTab = index),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.deepPurple.withValues(alpha: 0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isSelected
                ? Border.all(color: Colors.deepPurple.withValues(alpha: 0.5))
                : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? Colors.deepPurple[200] : Colors.grey,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey,
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
              const SizedBox(width: 8),
              appVersion.when<Widget>(
                data: (String version) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: Colors.deepPurple.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    version,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[400],
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
        color: Colors.grey[600],
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildMainHeader(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        border: Border(bottom: BorderSide(color: Color(0xFF333333))),
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
                borderRadius: BorderRadius.circular(8),
                hoverColor: Colors.deepPurple.withValues(alpha: 0.2),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF3A3A3A)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.arrow_back_rounded,
                        size: 14,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Close',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Icon(Icons.folder_open, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            widget.project.name,
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
            child: InkWell(
              onTap: () async {
                final uri = Uri.directory(widget.project.rootPath);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
              },
              child: Text(
                widget.project.rootPath,
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const VerticalDivider(
            indent: 12,
            endIndent: 12,
            width: 32,
            color: Colors.white10,
            thickness: 1,
          ),
          TextButton.icon(
            onPressed: () => _showDonateDialog(context),
            icon: const Icon(Icons.favorite, size: 14, color: Colors.redAccent),
            label: const Text(
              'Support Us',
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

  void _closeProject() {
    ref.read(activeProjectProvider.notifier).closeProject();
  }

  Widget _buildSidebarFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFF333333))),
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
                    size: 14,
                    color: Colors.redAccent,
                  ),
                  label: const Text(
                    'Support',
                    style: TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                ),
              ),
              IconButton(
                onPressed: () =>
                    showProjectSettingsDialog(context, widget.project),
                icon: const Icon(Icons.settings, size: 18),
                tooltip: 'Project Settings',
                style: IconButton.styleFrom(foregroundColor: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Made with ❤️ by Swaloka',
            style: TextStyle(fontSize: 9, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }

  void _showDonateDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF333333)),
        ),
        title: const Row(
          children: [
            Icon(Icons.favorite, color: Colors.redAccent),
            SizedBox(width: 12),
            Text('Support Development', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'If you find this tool useful, consider supporting its development!',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            _buildDonateOption(
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
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  Widget _buildDonateOption(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF333333)),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.deepPurple[200]),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Icon(Icons.open_in_new, size: 16, color: Colors.grey[600]),
          ],
        ),
      ),
    );
  }
}
