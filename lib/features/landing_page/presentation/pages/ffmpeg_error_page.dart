import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swaloka_looping_tool/core/services/ffmpeg_service.dart';
import 'package:swaloka_looping_tool/features/video_merger/presentation/providers/ffmpeg_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Error page shown when FFmpeg is not installed
class FFmpegErrorPage extends ConsumerWidget {
  const FFmpegErrorPage({super.key, this.error});
  final String? error;

  String get _installationInstructions {
    if (Platform.isMacOS) {
      return 'Install FFmpeg using Homebrew:\n\n'
          'brew install ffmpeg\n\n'
          'Or download from: https://evermeet.cx/ffmpeg/';
    } else if (Platform.isLinux) {
      return 'Install FFmpeg using your package manager:\n\n'
          'Ubuntu/Debian:\n'
          'sudo apt update && sudo apt install ffmpeg\n\n'
          'Fedora:\n'
          'sudo dnf install ffmpeg';
    } else if (Platform.isWindows) {
      return 'Option 1: Use the automatic installer (recommended)\n'
          'Click "Install FFmpeg" button below\n\n'
          'Option 2: Package managers\n'
          'choco install ffmpeg\n'
          'scoop install ffmpeg\n\n'
          'Option 3: Manual download\n'
          'https://www.gyan.dev/ffmpeg/builds/';
    }
    return 'Please install FFmpeg and add it to your system PATH.';
  }

  Future<void> _installFFmpegWindows(BuildContext context) async {
    // Get the executable directory
    final exePath = Platform.resolvedExecutable;
    final exeDir = File(exePath).parent.path;
    final installerPath = '$exeDir${Platform.pathSeparator}setup_ffmpeg.bat';

    // Check if installer exists
    if (!File(installerPath).existsSync()) {
      if (context.mounted) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            title: Row(
              children: [
                Icon(Icons.error, color: Theme.of(context).colorScheme.error),
                const SizedBox(width: 8),
                Text(
                  'Installer Not Found',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            content: Text(
              'FFmpeg installer not found at:\n$installerPath\n\n'
              'Please install FFmpeg manually using the instructions above.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'OK',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        );
      }
      return;
    }

    if (context.mounted) {
      // Show instructions dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Row(
            children: [
              Icon(Icons.info, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'FFmpeg Installation',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This will run the FFmpeg installer which will:',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Text(
                '• Download FFmpeg from gyan.dev\n'
                '• Install to C:\\ffmpeg\n'
                '• Add to System PATH\n'
                '• Require administrator privileges',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'A command prompt will open. Please grant administrator access when prompted.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.orange, // Keep warning orange
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
              ),
              child: const Text('Install FFmpeg'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      // Run the installer
      try {
        await Process.start('cmd', [
          '/c',
          'start',
          'cmd',
          '/k',
          installerPath,
        ], mode: ProcessStartMode.detached);

        if (context.mounted) {
          await showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: Theme.of(context).colorScheme.surface,
              title: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 8),
                  Text(
                    'Installer Started',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
              content: Text(
                'The FFmpeg installer has been started in a new window.\n\n'
                'Follow the prompts in the command window to complete installation.\n\n'
                'After installation completes, click "Re-check Installation" below.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'OK',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
      } on Exception catch (e) {
        if (context.mounted) {
          await showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: Theme.of(context).colorScheme.surface,
              title: Row(
                children: [
                  Icon(Icons.error, color: Theme.of(context).colorScheme.error),
                  const SizedBox(width: 8),
                  Text(
                    'Failed to Start Installer',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
              content: Text(
                'Error: $e\n\n'
                'Please run the installer manually:\n$installerPath',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'OK',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
      }
    }
  }

  Future<void> _openDocumentation() async {
    final url = Uri.parse('https://ffmpeg.org/download.html');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  static Widget _buildTroubleshootingStep(
    BuildContext context,
    String number,
    String title,
    String description,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 600),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.error_outline,
              size: 80,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'FFmpeg Not Found',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'FFmpeg is required to use this application but it is not installed on your system.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.code,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Installation Instructions',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  _installationInstructions,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (Platform.isWindows) ...[
            ElevatedButton.icon(
              onPressed: () => _installFFmpegWindows(context),
              icon: const Icon(Icons.download),
              label: const Text('Install FFmpeg Automatically'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                backgroundColor:
                    Colors.green, // Keep green for "Install" action
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
            const SizedBox(height: 12),
          ],
          OutlinedButton.icon(
            onPressed: _openDocumentation,
            icon: const Icon(Icons.open_in_new),
            label: Text(
              Platform.isWindows
                  ? 'Manual Installation Guide'
                  : 'Open FFmpeg Website',
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              foregroundColor: Theme.of(context).colorScheme.primary,
              side: BorderSide(color: Theme.of(context).colorScheme.primary),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              // Show checking dialog
              unawaited(
                showDialog<void>(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => AlertDialog(
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    content: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 20),
                          Text(
                            'Checking FFmpeg...',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );

              // Wait a moment for the dialog to show
              await Future<void>.delayed(
                const Duration(milliseconds: 300),
              );

              // Perform the actual check (reset cache first)
              FFmpegService.resetCache();
              final isAvailable = await FFmpegService.isAvailable();

              // Close the checking dialog
              if (context.mounted) {
                Navigator.of(context).pop();
              }

              if (!isAvailable && context.mounted) {
                // Still not found, show helpful troubleshooting dialog
                unawaited(
                  showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      title: Row(
                        children: [
                          const Icon(Icons.warning, color: Colors.orange),
                          const SizedBox(width: 8),
                          Text(
                            'FFmpeg Still Not Found',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                      ),
                      content: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'FFmpeg is still not detected. Please try the following:',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                            const SizedBox(height: 16),
                            _buildTroubleshootingStep(
                              context,
                              '1',
                              'Verify FFmpeg is installed',
                              'Open your terminal and run:\nffmpeg -version',
                            ),
                            const SizedBox(height: 12),
                            _buildTroubleshootingStep(
                              context,
                              '2',
                              'Check System PATH',
                              'Make sure FFmpeg is added to your system PATH environment variable.',
                            ),
                            const SizedBox(height: 12),
                            _buildTroubleshootingStep(
                              context,
                              '3',
                              'Restart Terminal/Shell',
                              'If you just installed FFmpeg, restart your terminal or shell session.',
                            ),
                            const SizedBox(height: 12),
                            _buildTroubleshootingStep(
                              context,
                              '4',
                              'Restart This App',
                              "If the above steps don't work, try restarting this application.",
                            ),
                          ],
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(
                            'OK',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              } else if (isAvailable && context.mounted) {
                // FFmpeg found! Update status and navigate back
                ref.read(ffmpegStatusProvider.notifier).setStatus(true);
                Navigator.of(context).pop(); // Go back to landing page
              }
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Re-check Installation'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              foregroundColor: Theme.of(context).colorScheme.primary,
              side: BorderSide(color: Theme.of(context).colorScheme.primary),
            ),
          ),
          const SizedBox(height: 24),
          if (error != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.error.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Theme.of(context).colorScheme.error,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Error: $error',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
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
