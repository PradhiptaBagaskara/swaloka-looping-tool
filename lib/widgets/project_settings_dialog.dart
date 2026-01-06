import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:swaloka_looping_tool/core/services/ffmpeg_service.dart';
import 'package:swaloka_looping_tool/features/video_merger/domain/models/swaloka_project.dart';
import 'package:swaloka_looping_tool/features/video_merger/presentation/providers/ffmpeg_provider.dart';
import 'package:swaloka_looping_tool/features/video_merger/presentation/providers/video_merger_providers.dart';
import 'package:swaloka_looping_tool/features/video_merger/presentation/state/settings_notifier.dart';

/// Dialog for project and app settings
class ProjectSettingsDialog extends ConsumerStatefulWidget {
  const ProjectSettingsDialog({required this.project, super.key});

  final SwalokaProject project;

  @override
  ConsumerState<ProjectSettingsDialog> createState() =>
      _ProjectSettingsDialogState();
}

class _ProjectSettingsDialogState extends ConsumerState<ProjectSettingsDialog> {
  late final TextEditingController _projectNameController;
  late final TextEditingController _outputPathController;
  final _ffmpegController = TextEditingController();

  bool _isSaving = false;
  String? _ffmpegError;

  @override
  void initState() {
    super.initState();
    _projectNameController = TextEditingController(text: widget.project.name);
    _outputPathController = TextEditingController(
      text:
          widget.project.customOutputPath ??
          p.join(widget.project.rootPath, 'outputs'),
    );
    _loadFfmpegSettings();
  }

  void _loadFfmpegSettings() {
    final settings = ref.read(settingsProvider);
    settings.whenData((value) {
      _ffmpegController.text = value.customFfmpegPath ?? '';
    });
  }

  @override
  void dispose() {
    _projectNameController.dispose();
    _outputPathController.dispose();
    _ffmpegController.dispose();
    super.dispose();
  }

  Future<void> _browseOutputPath() async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select Output Directory',
      initialDirectory: widget.project.rootPath,
    );
    if (result != null) {
      setState(() {
        _outputPathController.text = result;
      });
    }
  }

  Future<void> _browseFfmpeg() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select FFmpeg executable',
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _ffmpegController.text = result.files.single.path!;
        _ffmpegError = null;
      });
    }
  }

  void _resetOutputToDefault() {
    setState(() {
      _outputPathController.text = p.join(widget.project.rootPath, 'outputs');
    });
  }

  void _resetFfmpegToDefault() {
    setState(() {
      _ffmpegController.clear();
      _ffmpegError = null;
    });
  }

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
      _ffmpegError = null;
    });

    try {
      // Validate FFmpeg path if provided
      final ffmpegPath = _ffmpegController.text.trim();
      if (ffmpegPath.isNotEmpty) {
        final isValid = await FFmpegService.validatePath(ffmpegPath);
        if (!isValid) {
          setState(() {
            _ffmpegError =
                'Invalid FFmpeg path. Make sure it exists and is executable.';
            _isSaving = false;
          });
          return;
        }
      }

      // Save FFmpeg settings (global)
      await ref
          .read(settingsProvider.notifier)
          .setFfmpegPath(ffmpegPath.isEmpty ? null : ffmpegPath);
      await ref.read(ffmpegStatusProvider.notifier).recheckFFmpeg();

      // Save project settings
      final outputPath = _outputPathController.text.trim();
      final defaultOutput = p.join(widget.project.rootPath, 'outputs');
      final isCustomOutput =
          outputPath != defaultOutput && outputPath.isNotEmpty;

      await ref
          .read(activeProjectProvider.notifier)
          .updateSettings(
            customOutputPath: isCustomOutput ? outputPath : null,
            clearCustomOutputPath: !isCustomOutput,
          );

      // Note: Project name change would require more complex handling
      // (renaming project file, etc.) - for now we just show it as read-only info

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on Exception catch (e) {
      setState(() {
        _ffmpegError = 'Failed to save: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final ffmpegStatus = ref.watch(ffmpegStatusProvider);

    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: Row(
        children: [
          Icon(Icons.settings, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          const Text('Project Settings'),
        ],
      ),
      content: SizedBox(
        width: 550,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Project Info Section
              _buildSectionHeader('Project Information'),
              const SizedBox(height: 12),
              _buildTextField(
                label: 'Project Name',
                controller: _projectNameController,
                enabled: false, // Read-only for now
                hint: 'Project name (read-only)',
              ),
              const SizedBox(height: 8),
              Text(
                'Location: ${widget.project.rootPath}',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 24),
              const Divider(color: Color(0xFF333333)),
              const SizedBox(height: 16),

              // Output Directory Section
              _buildSectionHeader('Output Directory'),
              const SizedBox(height: 8),
              Text(
                'Where generated videos will be saved.',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _outputPathController,
                      style: const TextStyle(fontSize: 13),
                      decoration: _inputDecoration(
                        hint: 'Output directory path',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _browseOutputPath,
                    icon: const Icon(Icons.folder_open),
                    tooltip: 'Browse...',
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF2A2A2A),
                    ),
                  ),
                ],
              ),
              if (_outputPathController.text !=
                  p.join(widget.project.rootPath, 'outputs'))
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TextButton.icon(
                    onPressed: _resetOutputToDefault,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Reset to default'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[400],
                    ),
                  ),
                ),

              const SizedBox(height: 24),
              const Divider(color: Color(0xFF333333)),
              const SizedBox(height: 16),

              // FFmpeg Section
              _buildSectionHeader('FFmpeg Path'),
              const SizedBox(height: 8),
              Text(
                'By default, FFmpeg is auto-detected from system PATH.',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
              const SizedBox(height: 12),

              // FFmpeg status
              settings.when(
                data: (value) => _buildFfmpegStatus(value, ffmpegStatus),
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text(
                  'Error: $e',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ffmpegController,
                      style: const TextStyle(fontSize: 13),
                      decoration: _inputDecoration(
                        hint: 'Auto-detect (leave empty)',
                        errorText: _ffmpegError,
                      ),
                      onChanged: (_) => setState(() => _ffmpegError = null),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _browseFfmpeg,
                    icon: const Icon(Icons.folder_open),
                    tooltip: 'Browse...',
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF2A2A2A),
                    ),
                  ),
                ],
              ),
              if (_ffmpegController.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TextButton.icon(
                    onPressed: _resetFfmpegToDefault,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Reset to auto-detect'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[400],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Colors.grey[300],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    bool enabled = true,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[400]),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          enabled: enabled,
          style: TextStyle(
            fontSize: 13,
            color: enabled ? Colors.white : Colors.grey[500],
          ),
          decoration: _inputDecoration(hint: hint),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({String? hint, String? errorText}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[600]),
      errorText: errorText,
      filled: true,
      fillColor: const Color(0xFF2A2A2A),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    );
  }

  Widget _buildFfmpegStatus(SettingsState settings, bool? ffmpegStatus) {
    final isAvailable = ffmpegStatus ?? false;
    final currentPath = FFmpegService.ffmpegPath;
    final isCustom = settings.hasCustomFfmpegPath;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isAvailable
            ? Colors.green.withValues(alpha: 0.1)
            : Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isAvailable
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.orange.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isAvailable ? Icons.check_circle : Icons.warning,
            size: 20,
            color: isAvailable ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAvailable ? 'FFmpeg detected' : 'FFmpeg not found',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: isAvailable ? Colors.green[300] : Colors.orange[300],
                  ),
                ),
                if (isAvailable)
                  Text(
                    currentPath,
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (isCustom)
                  Text(
                    '(Custom path)',
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Show project settings dialog
Future<bool?> showProjectSettingsDialog(
  BuildContext context,
  SwalokaProject project,
) {
  return showDialog<bool>(
    context: context,
    builder: (context) => ProjectSettingsDialog(project: project),
  );
}
