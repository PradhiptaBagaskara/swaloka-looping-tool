import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:swaloka_looping_tool/core/services/ffmpeg_service.dart';
import 'package:swaloka_looping_tool/core/theme/theme.dart';
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
  HwAccelEncoder _hwAccelEncoder = HwAccelEncoder.software;
  bool _isDetectingEncoder = false;

  @override
  void initState() {
    super.initState();
    _projectNameController = TextEditingController(text: widget.project.name);
    _outputPathController = TextEditingController(
      text:
          widget.project.customOutputPath ??
          p.join(widget.project.rootPath, 'outputs'),
    );
    _loadGlobalSettings();
  }

  void _loadGlobalSettings() {
    final settings = ref.read(settingsProvider);
    settings.whenData((value) {
      _ffmpegController.text = value.customFfmpegPath ?? '';
      _hwAccelEncoder = value.hwAccelEncoder;
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

  void _resetOutputToDefault() {
    setState(() {
      _outputPathController.text = p.join(widget.project.rootPath, 'outputs');
    });
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

  void _resetFfmpegToDefault() {
    setState(() {
      _ffmpegController.clear();
      _ffmpegError = null;
    });
  }

  Future<void> _autoDetectEncoder() async {
    setState(() {
      _isDetectingEncoder = true;
    });

    try {
      final detected = await FFmpegService.detectHardwareEncoder();

      // Find matching enum value
      final encoder = HwAccelEncoder.values.firstWhere(
        (e) => e.value == detected,
        orElse: () => HwAccelEncoder.software,
      );

      setState(() {
        _hwAccelEncoder = encoder;
        _isDetectingEncoder = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Detected: ${encoder.label}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on Exception catch (e) {
      setState(() {
        _isDetectingEncoder = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Detection failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
      _ffmpegError = null;
    });

    try {
      // Validate FFmpeg path if provided (global setting)
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

      // Save global settings (FFmpeg)
      await ref
          .read(settingsProvider.notifier)
          .setFfmpegPath(ffmpegPath.isEmpty ? null : ffmpegPath);
      await ref.read(ffmpegStatusProvider.notifier).recheckFFmpeg();

      // Save hwaccel encoder setting
      await ref
          .read(settingsProvider.notifier)
          .setHwAccelEncoder(_hwAccelEncoder);

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
      backgroundColor: Theme.of(context).colorScheme.surface,
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
              // Global Settings Header
              Row(
                children: [
                  Icon(
                    Icons.public,
                    size: 18,
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'GLOBAL SETTINGS',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: Theme.of(context).colorScheme.tertiary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 1,
                      color: Theme.of(
                        context,
                      ).colorScheme.tertiary.withValues(alpha: 0.3),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'These settings apply to all projects',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 16),

              // Theme Section (Global)
              _buildSectionHeader(context, 'Appearance'),
              const SizedBox(height: 12),
              Consumer(
                builder: (context, ref, child) {
                  final themeMode = ref.watch(themeModeProvider);
                  final isDark = themeMode == ThemeMode.dark;

                  return Container(
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    child: SwitchListTile(
                      title: Text(
                        isDark ? 'Dark Theme' : 'Light Theme',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      subtitle: Text(
                        isDark
                            ? 'Darker interface for low-light environments'
                            : 'Brighter interface for well-lit environments',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      value: isDark,
                      onChanged: (_) {
                        ref.read(themeModeProvider.notifier).toggleTheme();
                      },
                      secondary: Icon(
                        isDark ? Icons.dark_mode : Icons.light_mode,
                        color: Theme.of(context).colorScheme.tertiary,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),
              Divider(color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: 16),

              // FFmpeg Section (Global)
              _buildSectionHeader(context, 'FFmpeg Path'),
              const SizedBox(height: 8),
              Text(
                'By default, FFmpeg is auto-detected from system PATH.',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),

              // FFmpeg status
              settings.when(
                data: (value) =>
                    _buildFfmpegStatus(context, value, ffmpegStatus),
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text(
                  'Error: $e',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ffmpegController,
                      style: Theme.of(context).textTheme.bodyMedium,
                      decoration: _inputDecoration(
                        context,
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
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
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
                      foregroundColor: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),

              const SizedBox(height: 24),
              Divider(color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: 16),

              // Hardware Acceleration Section (Global)
              _buildSectionHeader(context, 'Hardware Acceleration'),
              const SizedBox(height: 8),
              Text(
                'Select hardware acceleration encoder for video processing.',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),

              // HwAccel Encoder Dropdown
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<HwAccelEncoder>(
                    value: _hwAccelEncoder,
                    isExpanded: true,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    items: HwAccelEncoder.values.map((encoder) {
                      return DropdownMenuItem<HwAccelEncoder>(
                        value: encoder,
                        child: Row(
                          children: [
                            Icon(
                              _getEncoderIcon(encoder),
                              size: 20,
                              color: Theme.of(context).colorScheme.tertiary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    encoder.label,
                                    style:
                                        Theme.of(
                                          context,
                                        ).textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w500,
                                        ),
                                  ),
                                  Text(
                                    _getEncoderDescription(encoder),
                                    style:
                                        Theme.of(
                                          context,
                                        ).textTheme.labelSmall?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _hwAccelEncoder = value;
                        });
                      }
                    },
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Auto Detect Button
              FilledButton.tonalIcon(
                onPressed: _isDetectingEncoder ? null : _autoDetectEncoder,
                icon: _isDetectingEncoder
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search),
                label: Text(
                  _isDetectingEncoder ? 'Detecting...' : 'Auto Detect',
                ),
              ),

              const SizedBox(height: 32),
              Divider(
                color: Theme.of(context).colorScheme.outline,
                thickness: 2,
              ),
              const SizedBox(height: 24),

              // Project Settings Header
              Row(
                children: [
                  Icon(
                    Icons.folder,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'PROJECT SETTINGS',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 1,
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.3),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'These settings apply only to this project',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 16),

              // Project Info Section
              _buildSectionHeader(context, 'Project Information'),
              const SizedBox(height: 12),
              _buildTextField(
                context,
                label: 'Project Name',
                controller: _projectNameController,
                enabled: false, // Read-only for now
                hint: 'Project name (read-only)',
              ),
              const SizedBox(height: 8),
              Text(
                'Location: ${widget.project.rootPath}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 24),
              Divider(color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: 16),

              // Output Directory Section
              _buildSectionHeader(context, 'Output Directory'),
              const SizedBox(height: 8),
              Text(
                'Where generated videos will be saved.',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _outputPathController,
                      style: Theme.of(context).textTheme.bodyMedium,
                      decoration: _inputDecoration(
                        context,
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
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
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
                      foregroundColor: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant,
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

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildTextField(
    BuildContext context, {
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
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          enabled: enabled,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: enabled
                ? Theme.of(context).colorScheme.onSurface
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          decoration: _inputDecoration(context, hint: hint),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(
    BuildContext context, {
    String? hint,
    String? errorText,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      errorText: errorText,
      filled: true,
      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    );
  }

  Widget _buildFfmpegStatus(
    BuildContext context,
    SettingsState settings,
    bool? ffmpegStatus,
  ) {
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
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: isAvailable
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.error,
                  ),
                ),
                if (isAvailable)
                  Text(
                    currentPath,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (isCustom)
                  Text(
                    '(Custom path)',
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.tertiary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getEncoderIcon(HwAccelEncoder encoder) {
    switch (encoder) {
      case HwAccelEncoder.nvenc:
      case HwAccelEncoder.nvencLinux:
        return Icons.computer;
      case HwAccelEncoder.amf:
        return Icons.computer;
      case HwAccelEncoder.qsv:
        return Icons.memory;
      case HwAccelEncoder.mf:
        return Icons.settings;
      case HwAccelEncoder.videotoolbox:
        return Icons.laptop_mac;
      case HwAccelEncoder.vaapi:
        return Icons.memory;
      case HwAccelEncoder.v4l2m2m:
        return Icons.developer_board;
      case HwAccelEncoder.software:
        return Icons.code;
    }
  }

  String _getEncoderDescription(HwAccelEncoder encoder) {
    switch (encoder) {
      case HwAccelEncoder.nvenc:
        return 'NVIDIA (GTX/RTX)';
      case HwAccelEncoder.amf:
        return 'AMD Radeon (RX Series)';
      case HwAccelEncoder.qsv:
        return 'Intel QuickSync (iGPU/Arc)';
      case HwAccelEncoder.mf:
        return 'Windows Media Foundation (Generic)';
      case HwAccelEncoder.videotoolbox:
        return 'Apple Silicon (M1/M2/M3) & Intel Mac';
      case HwAccelEncoder.nvencLinux:
        return 'NVIDIA (Proprietary Driver)';
      case HwAccelEncoder.vaapi:
        return 'VA-API (Intel/AMD)';
      case HwAccelEncoder.v4l2m2m:
        return 'V4L2 (Raspberry Pi / ARM)';
      case HwAccelEncoder.software:
        return 'CPU-based encoding (no hardware acceleration)';
    }
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
