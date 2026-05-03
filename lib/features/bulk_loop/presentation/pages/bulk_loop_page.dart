import 'dart:async';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:swaloka_looping_tool/core/services/ffmpeg_service.dart';
import 'package:swaloka_looping_tool/features/bulk_loop/domain/bulk_loop_executor_service.dart';
import 'package:swaloka_looping_tool/features/bulk_loop/domain/models/models.dart';
import 'package:swaloka_looping_tool/features/bulk_loop/presentation/providers/providers.dart';
import 'package:swaloka_looping_tool/features/video_merger/domain/models/swaloka_project.dart';
import 'package:swaloka_looping_tool/features/video_merger/presentation/providers/video_merger_providers.dart';
import 'package:swaloka_looping_tool/widgets/widgets.dart';

const _videoExtensions = ['mp4', 'mov', 'avi', 'mkv', 'webm', 'flv', 'wmv'];

class _BatchContentDiskEstimate {
  const _BatchContentDiskEstimate({
    required this.contentIndex,
    required this.outputBytes,
    required this.tempBytes,
    required this.requiredBytes,
  });

  final int contentIndex;
  final int outputBytes;
  final int tempBytes;
  final int requiredBytes;
}

class _BatchDiskEstimate {
  const _BatchDiskEstimate({
    required this.outputBytes,
    required this.tempBytes,
    required this.requiredBytes,
    required this.contentCount,
    required this.perContent,
  });

  final int outputBytes;
  final int tempBytes;
  final int requiredBytes;
  final int contentCount;
  final List<_BatchContentDiskEstimate> perContent;
}

class BulkLoopPage extends ConsumerStatefulWidget {
  const BulkLoopPage({
    required this.project,
    this.initialJobId,
    this.showConfigInAppBar = false,
    super.key,
  });

  final SwalokaProject project;
  final String? initialJobId;
  final bool showConfigInAppBar;

  @override
  ConsumerState<BulkLoopPage> createState() => _BulkLoopPageState();
}

class _BulkLoopPageState extends ConsumerState<BulkLoopPage> {
  final _jobNameController = TextEditingController(text: 'bulk_job');
  final _targetCountController = TextEditingController(text: '30');
  final _loopCountController = TextEditingController(text: '2');
  final _minMinutesController = TextEditingController(text: '120');
  final _audioPoolScrollController = ScrollController();

  final List<String> _audioPaths = [];
  final List<String> _events = [];
  final List<BulkLoopJob> _availableJobs = [];
  final Set<String> _expandedContentIds = <String>{};

  BulkLoopJob? _job;
  String? _selectedJobId;
  bool _isBusy = false;
  bool _isRunInBackground = false;
  double? _runProgress;
  String? _runStatusText;
  Timer? _runningPoller;

  @override
  void initState() {
    super.initState();
    _selectedJobId = widget.initialJobId;
    _refreshJobs();
  }

  @override
  void dispose() {
    _runningPoller?.cancel();
    _jobNameController.dispose();
    _targetCountController.dispose();
    _loopCountController.dispose();
    _minMinutesController.dispose();
    _audioPoolScrollController.dispose();
    super.dispose();
  }

  Future<void> _refreshJobs() async {
    final repository = ref.read(bulkLoopJobRepositoryProvider);
    final jobs = await repository.list(widget.project.rootPath);
    if (!mounted) return;

    setState(() {
      _availableJobs
        ..clear()
        ..addAll(jobs);
      if (jobs.isEmpty) {
        _syncRunStateFromJob(null);
        return;
      }

      final fallback = jobs.first;
      final selected = _selectedJobId == null
          ? fallback
          : jobs.firstWhere(
              (item) => item.id == _selectedJobId,
              orElse: () => fallback,
            );
      _selectedJobId = selected.id;
      _applyJobToForm(selected);
    });
  }

  void _applyJobToForm(BulkLoopJob job) {
    _job = job;
    _jobNameController.text = job.name;
    _targetCountController.text = job.targetContentCount.toString();
    _loopCountController.text = job.loopCount.toString();
    _minMinutesController.text = (job.constraints.minDurationSeconds / 60)
        .round()
        .toString();
    _audioPaths
      ..clear()
      ..addAll(job.audioItems.map((item) => item.path));
    _syncRunStateFromJob(job);
  }

  bool get _canStopBackgroundProcesses {
    final hasRunningContent =
        _job?.contents.any(
          (content) => content.status == BulkLoopContentStatus.running,
        ) ??
        false;
    return _isRunInBackground ||
        hasRunningContent ||
        FFmpegService.isProcessing;
  }

  void _syncRunStateFromJob(BulkLoopJob? job) {
    final targetJob = job ?? _job;
    final runningCount =
        targetJob?.contents
            .where((content) => content.status == BulkLoopContentStatus.running)
            .length ??
        0;
    final queuedCount =
        targetJob?.contents
            .where((content) => content.status == BulkLoopContentStatus.queued)
            .length ??
        0;
    final doneCount =
        targetJob?.contents
            .where((content) => content.status == BulkLoopContentStatus.done)
            .length ??
        0;
    final failedCount =
        targetJob?.contents
            .where((content) => content.status == BulkLoopContentStatus.failed)
            .length ??
        0;
    final readyCount =
        targetJob?.contents
            .where((content) => content.status == BulkLoopContentStatus.ready)
            .length ??
        0;
    final totalWork =
        doneCount + failedCount + readyCount + queuedCount + runningCount;
    final progressValue = totalWork <= 0
        ? null
        : (doneCount + failedCount) / totalWork;
    final hasRunning = runningCount > 0 || FFmpegService.isProcessing;

    _isRunInBackground = hasRunning;
    _runProgress = hasRunning ? progressValue : null;
    _runStatusText = hasRunning
        ? 'Sedang memproses ($runningCount running, $queuedCount queued)'
        : null;

    if (hasRunning) {
      _startRunningPoller();
    } else {
      _runningPoller?.cancel();
      _runningPoller = null;
    }
  }

  void _startRunningPoller() {
    if (_runningPoller != null) return;
    _runningPoller = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) return;
      _refreshJobs();
    });
  }

  @override
  Widget build(BuildContext context) {
    final content = LayoutBuilder(
      builder: (context, constraints) {
        final isSplitLayout = constraints.maxWidth >= 1100;
        if (!isSplitLayout) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (!widget.showConfigInAppBar) ...[
                _buildConfigHeader(context),
                const SizedBox(height: 12),
              ],
              _buildAudioCard(context),
              const SizedBox(height: 12),
              _buildContentItemsCard(context),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 4,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (!widget.showConfigInAppBar) ...[
                    _buildConfigHeader(context),
                    const SizedBox(height: 12),
                  ],
                  _buildAudioCard(context),
                ],
              ),
            ),
            Container(
              width: 1,
              margin: const EdgeInsets.symmetric(vertical: 20),
              color: Theme.of(context).colorScheme.outline,
            ),
            Expanded(
              flex: 6,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _buildContentItemsCard(context),
                ],
              ),
            ),
          ],
        );
      },
    );

    if (!widget.showConfigInAppBar) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 96,
        titleSpacing: 0,
        title: _buildConfigTitleBar(context),
      ),
      body: SafeArea(child: content),
    );
  }

  Widget _buildConfigHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune, color: colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Config Looping',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _isBusy || _job == null ? null : _saveConfigOnly,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Simpan Config'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Atur target konten, loop, dan durasi minimum.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            runSpacing: 12,
            spacing: 12,
            children: [
              _textInput(_jobNameController, 'Nama Channel', width: 220),
              _textInput(
                _targetCountController,
                'Target Konten',
                width: 150,
                numeric: true,
              ),
              _textInput(
                _loopCountController,
                'Jumlah Loop',
                width: 120,
                numeric: true,
              ),
              _textInput(
                _minMinutesController,
                'Durasi Min (mnt)',
                width: 180,
                numeric: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConfigTitleBar(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _textInput(_jobNameController, 'Nama Channel', width: 190),
          const SizedBox(width: 8),
          _textInput(
            _targetCountController,
            'Target',
            width: 110,
            numeric: true,
          ),
          const SizedBox(width: 8),
          _textInput(
            _loopCountController,
            'Loop',
            width: 80,
            numeric: true,
          ),
          _textInput(
            _minMinutesController,
            'Min (m)',
            width: 110,
            numeric: true,
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: _isBusy || _job == null ? null : _saveConfigOnly,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Simpan Config'),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildAudioCard(BuildContext context) {
    final audioList = _audioPaths.isEmpty
        ? _emptyLabel('Belum ada audio')
        : SizedBox(
            height: 320,
            child: Scrollbar(
              controller: _audioPoolScrollController,
              thumbVisibility: true,
              child: ListView.builder(
                controller: _audioPoolScrollController,
                itemCount: _audioPaths.length,
                itemBuilder: (context, index) {
                  final path = _audioPaths[index];
                  return MediaItemCard(
                    path: path,
                    icon: Icons.music_note,
                    onPreview: () => _showAudioPreview(path),
                    onRemove: _isBusy
                        ? () {}
                        : () {
                            setState(() {
                              _audioPaths.remove(path);
                            });
                          },
                  );
                },
              ),
            ),
          );

    return _card(
      context,
      title: 'Audio MP3 (${_audioPaths.length})',
      action: TextButton.icon(
        onPressed: _isBusy ? null : _pickAudios,
        icon: const Icon(Icons.add),
        label: const Text('Tambah Audio'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          audioList,
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _isBusy ? null : _generatePlan,
              icon: const Icon(Icons.auto_fix_high),
              label: const Text('Generate Plan'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAudioPreview(String path) async {
    final fileName = p.basename(path);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640, maxHeight: 260),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
                child: Row(
                  children: [
                    const Icon(Icons.audiotrack),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: MediaPreviewPlayer(
                  path: path,
                  isVideo: false,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContentItemsCard(BuildContext context) {
    final job = _job;
    if (job == null) {
      return _card(
        context,
        title: 'Item Konten',
        child: _emptyLabel('Generate plan dulu untuk membuat item konten.'),
      );
    }

    final readyCount = job.contents
        .where((content) => content.status == BulkLoopContentStatus.ready)
        .length;
    final queuedCount = job.contents
        .where((content) => content.status == BulkLoopContentStatus.queued)
        .length;
    final doneCount = job.contents
        .where((content) => content.status == BulkLoopContentStatus.done)
        .length;
    final pendingMediaCount = job.contents
        .where(
          (content) => content.status == BulkLoopContentStatus.pendingMedia,
        )
        .length;
    final failedCount = job.contents
        .where((content) => content.status == BulkLoopContentStatus.failed)
        .length;
    final itemListHeight = min(
      // must be double
      // ignore: prefer_int_literals
      680.0,
      // must be double
      // ignore: prefer_int_literals
      max(320.0, MediaQuery.of(context).size.height * 0.58),
    );

    return _card(
      context,
      title: 'Item Konten (${job.contents.length})',
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OutlinedButton.icon(
            onPressed: _isBusy || _isRunInBackground || _job == null
                ? null
                : _runBatch,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Proses Antrean'),
          ),
          const SizedBox(width: 6),
          OutlinedButton.icon(
            onPressed: !_canStopBackgroundProcesses
                ? null
                : _stopAllBackgroundProcesses,
            icon: const Icon(Icons.stop_circle_outlined),
            label: const Text('Stop Semua Proses'),
          ),
          const SizedBox(width: 6),
          IconButton(
            onPressed: _isBusy ? null : _refreshJobs,
            tooltip: 'Refresh job',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildMetaChip(context, 'Ready $readyCount'),
              _buildMetaChip(context, 'Queued $queuedCount'),
              _buildMetaChip(context, 'Done $doneCount'),
              _buildMetaChip(context, 'Pending media $pendingMediaCount'),
              _buildMetaChip(context, 'Failed $failedCount'),
            ],
          ),
          if (_isRunInBackground || _canStopBackgroundProcesses) ...[
            const SizedBox(height: 10),
            Text(
              _runStatusText ?? 'Sedang memproses item...',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(value: _runProgress),
          ],
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 8),
          SizedBox(
            height: itemListHeight,
            child: ListView(
              children:
                  ([...job.contents]..sort((a, b) {
                        final priorityCompare = _statusPriority(a.status)
                            .compareTo(
                              _statusPriority(b.status),
                            );
                        if (priorityCompare != 0) return priorityCompare;
                        return a.index.compareTo(b.index);
                      }))
                      .map((content) {
                        final isExpanded = _expandedContentIds.contains(
                          content.id,
                        );
                        final durationMinutes =
                            (content.estimatedSeedSeconds / 60 * job.loopCount)
                                .toStringAsFixed(1);
                        final itemDisplayName =
                            content.backgroundVideoPath == null
                            ? 'Item ${content.index + 1}'
                            : p.basenameWithoutExtension(
                                content.backgroundVideoPath!,
                              );
                        final seedItems = content.audioItemIds
                            .map(
                              (id) => (
                                path: _audioPathById(id),
                                name: _audioNameById(id),
                              ),
                            )
                            .toList();
                        final statusColor = _statusColor(
                          context,
                          content.status,
                        );
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ExpansionTile(
                            initiallyExpanded: isExpanded,
                            onExpansionChanged: (expanded) {
                              setState(() {
                                if (expanded) {
                                  _expandedContentIds.add(content.id);
                                } else {
                                  _expandedContentIds.remove(content.id);
                                }
                              });
                            },
                            tilePadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        itemDisplayName,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          _buildMetaChip(
                                            context,
                                            '~${durationMinutes}m',
                                          ),
                                          _buildMetaChip(
                                            context,
                                            'Seed ${content.audioItemIds.length}',
                                          ),
                                          _buildMetaChip(
                                            context,
                                            'Loop x${job.loopCount}',
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    _statusLabel(content.status),
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: statusColor,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  0,
                                  12,
                                  12,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          flex: 5,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              DropZoneWidget(
                                                label:
                                                    content.introVideoPath ==
                                                        null
                                                    ? 'Drop Intro Video (opsional)'
                                                    : p.basename(
                                                        content.introVideoPath!,
                                                      ),
                                                icon: Icons.play_circle_outline,
                                                onTap: _isBusy
                                                    ? () {}
                                                    : () =>
                                                          _pickIntroForContent(
                                                            content.id,
                                                          ),
                                                onClear:
                                                    content.introVideoPath ==
                                                            null ||
                                                        _isBusy
                                                    ? null
                                                    : () {
                                                        _setSingleContentMedia(
                                                          contentId: content.id,
                                                          clearIntro: true,
                                                        );
                                                      },
                                                onFilesDropped: (files) {
                                                  if (_isBusy) return;
                                                  final droppedPath = files
                                                      .map((item) => item.path)
                                                      .firstWhere(
                                                        _isVideoPath,
                                                        orElse: () => '',
                                                      );
                                                  if (droppedPath.isEmpty) {
                                                    _showSnack(
                                                      'File intro tidak valid, gunakan format video.',
                                                    );
                                                    return;
                                                  }
                                                  _setSingleContentMedia(
                                                    contentId: content.id,
                                                    introVideoPath: droppedPath,
                                                  );
                                                },
                                              ),
                                              const SizedBox(height: 10),
                                              DropZoneWidget(
                                                label:
                                                    content.backgroundVideoPath ==
                                                        null
                                                    ? 'Drop Background Video'
                                                    : p.basename(
                                                        content
                                                            .backgroundVideoPath!,
                                                      ),
                                                icon: Icons
                                                    .video_library_outlined,
                                                onTap: _isBusy
                                                    ? () {}
                                                    : () =>
                                                          _pickMediaForContent(
                                                            content.id,
                                                            withIntro: false,
                                                          ),
                                                onClear:
                                                    content.backgroundVideoPath ==
                                                            null ||
                                                        _isBusy
                                                    ? null
                                                    : () {
                                                        _setSingleContentMedia(
                                                          contentId: content.id,
                                                          clearBackground: true,
                                                        );
                                                      },
                                                onFilesDropped: (files) {
                                                  if (_isBusy) return;
                                                  final droppedPath = files
                                                      .map((item) => item.path)
                                                      .firstWhere(
                                                        _isVideoPath,
                                                        orElse: () => '',
                                                      );
                                                  if (droppedPath.isEmpty) {
                                                    _showSnack(
                                                      'File background tidak valid, gunakan format video.',
                                                    );
                                                    return;
                                                  }
                                                  _setSingleContentMedia(
                                                    contentId: content.id,
                                                    backgroundVideoPath:
                                                        droppedPath,
                                                  );
                                                },
                                              ),
                                              const SizedBox(height: 8),
                                              Wrap(
                                                spacing: 8,
                                                runSpacing: 8,
                                                children: [
                                                  if (content.status ==
                                                          BulkLoopContentStatus
                                                              .queued ||
                                                      content.status ==
                                                          BulkLoopContentStatus
                                                              .running)
                                                    OutlinedButton.icon(
                                                      onPressed:
                                                          _isBusy ||
                                                              content.status ==
                                                                  BulkLoopContentStatus
                                                                      .running
                                                          ? null
                                                          : () =>
                                                                _markContentQueued(
                                                                  content.id,
                                                                  queued: false,
                                                                ),
                                                      icon: const Icon(
                                                        Icons.playlist_remove,
                                                      ),
                                                      label: const Text(
                                                        'Hapus dari Antrean',
                                                      ),
                                                    )
                                                  else
                                                    OutlinedButton.icon(
                                                      onPressed: _isBusy
                                                          ? null
                                                          : () =>
                                                                _markContentQueued(
                                                                  content.id,
                                                                  queued: true,
                                                                ),
                                                      icon: const Icon(
                                                        Icons.queue,
                                                      ),
                                                      label: const Text(
                                                        'Masukkan Antrean',
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          flex: 5,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Seed MP3 (playable)',
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.labelMedium,
                                              ),
                                              const SizedBox(height: 6),
                                              Container(
                                                height: 220,
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        10,
                                                      ),
                                                  border: Border.all(
                                                    color: Theme.of(
                                                      context,
                                                    ).colorScheme.outline,
                                                  ),
                                                  color:
                                                      Theme.of(
                                                            context,
                                                          ).colorScheme.surface
                                                          .withValues(
                                                            alpha: 0.2,
                                                          ),
                                                ),
                                                child: seedItems.isEmpty
                                                    ? Center(
                                                        child: _emptyLabel(
                                                          'Belum ada seed MP3',
                                                        ),
                                                      )
                                                    : ListView.separated(
                                                        padding:
                                                            const EdgeInsets.all(
                                                              8,
                                                            ),
                                                        itemCount:
                                                            seedItems.length,
                                                        separatorBuilder:
                                                            (_, _) =>
                                                                const SizedBox(
                                                                  height: 6,
                                                                ),
                                                        itemBuilder: (context, seedIndex) {
                                                          final seed =
                                                              seedItems[seedIndex];
                                                          final playable =
                                                              seed.path !=
                                                                  null &&
                                                              seed
                                                                  .path!
                                                                  .isNotEmpty;
                                                          return Container(
                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                  horizontal:
                                                                      10,
                                                                  vertical: 8,
                                                                ),
                                                            decoration: BoxDecoration(
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    8,
                                                                  ),
                                                              border: Border.all(
                                                                color:
                                                                    Theme.of(
                                                                          context,
                                                                        )
                                                                        .colorScheme
                                                                        .outline
                                                                        .withValues(
                                                                          alpha:
                                                                              0.5,
                                                                        ),
                                                              ),
                                                            ),
                                                            child: Row(
                                                              children: [
                                                                Text(
                                                                  '${seedIndex + 1}.',
                                                                  style: Theme.of(
                                                                    context,
                                                                  ).textTheme.labelSmall,
                                                                ),
                                                                const SizedBox(
                                                                  width: 8,
                                                                ),
                                                                Expanded(
                                                                  child: Text(
                                                                    seed.name,
                                                                    maxLines: 1,
                                                                    overflow:
                                                                        TextOverflow
                                                                            .ellipsis,
                                                                  ),
                                                                ),
                                                                IconButton(
                                                                  tooltip:
                                                                      playable
                                                                      ? 'Play seed'
                                                                      : 'Audio path tidak ditemukan',
                                                                  onPressed:
                                                                      playable
                                                                      ? () => _showAudioPreview(
                                                                          seed.path!,
                                                                        )
                                                                      : null,
                                                                  icon: const Icon(
                                                                    Icons
                                                                        .play_circle_outline,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          );
                                                        },
                                                      ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (content.error != null &&
                                        content.error!.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color:
                                              Theme.of(
                                                    context,
                                                  ).colorScheme.errorContainer
                                                  .withValues(
                                                    alpha: 0.4,
                                                  ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          'Error: ${content.error}',
                                          style: TextStyle(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.error,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      })
                      .toList(),
            ),
          ),
          if (_events.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Text(
              'Recent events',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 6),
            ..._events.take(6).map((event) => Text('• $event')),
          ],
        ],
      ),
    );
  }

  String _statusLabel(BulkLoopContentStatus status) {
    switch (status) {
      case BulkLoopContentStatus.pendingMedia:
        return 'Pending Media';
      case BulkLoopContentStatus.ready:
        return 'Ready';
      case BulkLoopContentStatus.queued:
        return 'Queued';
      case BulkLoopContentStatus.running:
        return 'Running';
      case BulkLoopContentStatus.done:
        return 'Done';
      case BulkLoopContentStatus.failed:
        return 'Failed';
    }
  }

  int _statusPriority(BulkLoopContentStatus status) {
    switch (status) {
      case BulkLoopContentStatus.queued:
        return 0;
      case BulkLoopContentStatus.running:
        return 1;
      case BulkLoopContentStatus.ready:
        return 2;
      case BulkLoopContentStatus.pendingMedia:
        return 3;
      case BulkLoopContentStatus.failed:
        return 4;
      case BulkLoopContentStatus.done:
        return 5;
    }
  }

  Color _statusColor(BuildContext context, BulkLoopContentStatus status) {
    final scheme = Theme.of(context).colorScheme;
    switch (status) {
      case BulkLoopContentStatus.pendingMedia:
        return scheme.onSurfaceVariant;
      case BulkLoopContentStatus.ready:
        return Colors.blue;
      case BulkLoopContentStatus.queued:
        return Colors.deepPurple;
      case BulkLoopContentStatus.running:
        return Colors.orange;
      case BulkLoopContentStatus.done:
        return Colors.green;
      case BulkLoopContentStatus.failed:
        return scheme.error;
    }
  }

  Widget _buildMetaChip(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: Theme.of(context).textTheme.labelSmall),
    );
  }

  bool _isVideoPath(String path) {
    if (path.isEmpty) return false;
    final ext = p.extension(path).replaceFirst('.', '').toLowerCase();
    return _videoExtensions.contains(ext);
  }

  Widget _card(
    BuildContext context, {
    required String title,
    required Widget child,
    Widget? action,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ?action,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _textInput(
    TextEditingController controller,
    String label, {
    required double width,
    bool numeric = false,
  }) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        keyboardType: numeric ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var value = bytes.toDouble();
    var unitIdx = 0;
    while (value >= 1024 && unitIdx < units.length - 1) {
      value /= 1024;
      unitIdx++;
    }
    final decimals = value >= 10 ? 1 : 2;
    return '${value.toStringAsFixed(decimals)} ${units[unitIdx]}';
  }

  Widget _emptyLabel(String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  Future<void> _saveUpdatedJob(BulkLoopJob nextJob) async {
    final repository = ref.read(bulkLoopJobRepositoryProvider);
    await repository.save(nextJob);
    if (!mounted) return;
    setState(() {
      _job = nextJob;
      _selectedJobId = nextJob.id;
    });
    await _refreshJobs();
  }

  Future<void> _pickAudios() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['mp3', 'wav', 'm4a', 'aac', 'ogg', 'flac'],
      allowMultiple: true,
      initialDirectory: widget.project.rootPath,
    );
    if (result == null) return;
    setState(() {
      _audioPaths.addAll(result.paths.whereType<String>());
      _audioPaths.sort();
      final unique = _audioPaths.toSet().toList()..sort();
      _audioPaths
        ..clear()
        ..addAll(unique);
    });
  }

  Future<void> _pickMediaForContent(
    String contentId, {
    required bool withIntro,
  }) async {
    String? introPath;
    if (withIntro) {
      final introResult = await FilePicker.platform.pickFiles(
        type: FileType.video,
        initialDirectory: widget.project.rootPath,
        dialogTitle: 'Select intro video',
      );
      introPath = introResult?.files.single.path;
      if (introPath == null) {
        _showSnack('Intro wajib dipilih untuk mode Intro+BG');
        return;
      }
    }

    final bgResult = await FilePicker.platform.pickFiles(
      type: FileType.video,
      initialDirectory: widget.project.rootPath,
      dialogTitle: 'Select background video',
    );
    final bgPath = bgResult?.files.single.path;
    if (bgPath == null) {
      _showSnack('Background video wajib dipilih');
      return;
    }

    await _setSingleContentMedia(
      contentId: contentId,
      backgroundVideoPath: bgPath,
      introVideoPath: introPath,
    );
  }

  Future<void> _pickIntroForContent(String contentId) async {
    final introResult = await FilePicker.platform.pickFiles(
      type: FileType.video,
      initialDirectory: widget.project.rootPath,
      dialogTitle: 'Select intro video',
    );
    final introPath = introResult?.files.single.path;
    if (introPath == null || introPath.isEmpty) return;
    await _setSingleContentMedia(
      contentId: contentId,
      introVideoPath: introPath,
    );
  }

  Future<void> _setSingleContentMedia({
    required String contentId,
    String? backgroundVideoPath,
    String? introVideoPath,
    bool clearBackground = false,
    bool clearIntro = false,
  }) async {
    final current = _job;
    if (current == null) return;

    _showMediaReuseWarning(
      job: current,
      contentId: contentId,
      backgroundVideoPath: clearBackground ? null : backgroundVideoPath,
      introVideoPath: clearIntro ? null : introVideoPath,
    );

    final nextContents = current.contents.map((content) {
      if (content.id != contentId) return content;

      final hasBackground =
          !clearBackground &&
          ((backgroundVideoPath ?? content.backgroundVideoPath) != null);
      final existingStatus = content.status;
      final nextStatus = hasBackground
          ? (existingStatus == BulkLoopContentStatus.queued
                ? BulkLoopContentStatus.queued
                : BulkLoopContentStatus.ready)
          : BulkLoopContentStatus.pendingMedia;

      return content.copyWith(
        status: nextStatus,
        backgroundVideoPath: clearBackground
            ? null
            : (backgroundVideoPath ?? content.backgroundVideoPath),
        introVideoPath: clearIntro
            ? null
            : (introVideoPath ?? content.introVideoPath),
        clearBackgroundVideoPath: clearBackground,
        clearIntroVideoPath: clearIntro,
        clearError: true,
      );
    }).toList();

    await _saveUpdatedJob(current.copyWith(contents: nextContents));
  }

  Future<void> _markContentQueued(
    String contentId, {
    required bool queued,
  }) async {
    final current = _job;
    if (current == null) return;

    final nextContents = current.contents.map((content) {
      if (content.id != contentId) return content;

      final hasBackground = content.backgroundVideoPath != null;
      final hasAudio = content.audioItemIds.isNotEmpty;
      if (!queued) {
        if (content.status == BulkLoopContentStatus.running) return content;
        return content.copyWith(
          status: hasBackground
              ? BulkLoopContentStatus.ready
              : BulkLoopContentStatus.pendingMedia,
        );
      }

      if (!hasBackground || !hasAudio) {
        _showSnack('Item belum siap antre (butuh BG dan seed audio).');
        return content;
      }
      if (content.status == BulkLoopContentStatus.running ||
          content.status == BulkLoopContentStatus.done) {
        return content;
      }
      return content.copyWith(status: BulkLoopContentStatus.queued);
    }).toList();

    await _saveUpdatedJob(current.copyWith(contents: nextContents));
  }

  void _showMediaReuseWarning({
    required BulkLoopJob job,
    required String contentId,
    String? backgroundVideoPath,
    String? introVideoPath,
  }) {
    String normalizePath(String path) => p.normalize(p.absolute(path));

    int countUsage(String targetPath) {
      final normalizedTarget = normalizePath(targetPath);
      return job.contents.where((content) => content.id != contentId).where((
        content,
      ) {
        final bg = content.backgroundVideoPath;
        final intro = content.introVideoPath;
        final isBgMatch = bg != null && normalizePath(bg) == normalizedTarget;
        final isIntroMatch =
            intro != null && normalizePath(intro) == normalizedTarget;
        return isBgMatch || isIntroMatch;
      }).length;
    }

    if (backgroundVideoPath != null && backgroundVideoPath.isNotEmpty) {
      final count = countUsage(backgroundVideoPath);
      if (count > 0) {
        _showSnack(
          'Warning: BG "${p.basename(backgroundVideoPath)}" sudah dipakai di $count item lain.',
        );
      }
    }

    if (introVideoPath != null && introVideoPath.isNotEmpty) {
      final count = countUsage(introVideoPath);
      if (count > 0) {
        _showSnack(
          'Warning: Intro "${p.basename(introVideoPath)}" sudah dipakai di $count item lain.',
        );
      }
    }
  }

  String _audioNameById(String audioId) {
    final job = _job;
    if (job == null) return audioId;
    final item = job.audioItems
        .where((audio) => audio.id == audioId)
        .firstOrNull;
    if (item == null) return audioId;
    return p.basename(item.path);
  }

  String? _audioPathById(String audioId) {
    final job = _job;
    if (job == null) return null;
    final item = job.audioItems
        .where((audio) => audio.id == audioId)
        .firstOrNull;
    return item?.path;
  }

  Future<void> _generatePlan() async {
    final targetCount = int.tryParse(_targetCountController.text.trim()) ?? 0;
    final loopCount = int.tryParse(_loopCountController.text.trim()) ?? 2;
    final minMinutes =
        double.tryParse(_minMinutesController.text.trim()) ?? 120;

    if (targetCount <= 0) {
      _showSnack('Target content harus > 0');
      return;
    }
    if (_audioPaths.isEmpty) {
      _showSnack('Audio pool belum diisi');
      return;
    }

    final seed = DateTime.now().millisecondsSinceEpoch;
    final jobId = _job?.id ?? 'bulk_$seed';
    final draftJob = BulkLoopJob.create(
      id: jobId,
      name: _jobNameController.text.trim().isEmpty
          ? 'bulk_job'
          : _jobNameController.text.trim(),
      projectRootPath: widget.project.rootPath,
      outputDirectoryPath: widget.project.effectiveOutputPath,
      targetContentCount: targetCount,
      loopCount: max(1, loopCount),
      constraints: BulkLoopConstraints(
        minDurationSeconds: minMinutes * 60,
      ),
      seed: seed,
      audioItems: _audioPaths
          .asMap()
          .entries
          .map(
            (entry) => BulkLoopAudioItem(
              id: 'audio_${entry.key + 1}',
              path: entry.value,
            ),
          )
          .toList(),
    );

    setState(() => _isBusy = true);
    try {
      final planner = ref.read(bulkLoopPlannerServiceProvider);
      final repository = ref.read(bulkLoopJobRepositoryProvider);
      final plannedJob = await planner.buildPlan(
        draftJob,
        onLog: (log) => _appendEvent(log.message),
      );
      await repository.save(plannedJob);

      if (!mounted) return;
      setState(() {
        _selectedJobId = plannedJob.id;
        _applyJobToForm(plannedJob);
      });
      await _refreshJobs();
      _showSnack('Plan berhasil dibuat');
    } on Exception catch (error) {
      _showSnack('Gagal generate plan: $error');
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _saveConfigOnly() async {
    final currentJob = _job;
    if (currentJob == null) return;

    final targetCount = int.tryParse(_targetCountController.text.trim());
    final loopCount = int.tryParse(_loopCountController.text.trim());
    final minMinutes = double.tryParse(_minMinutesController.text.trim());

    final resolvedTarget = max(1, targetCount ?? currentJob.targetContentCount);
    final resolvedLoopCount = max(1, loopCount ?? currentJob.loopCount);
    final resolvedMinMinutes =
        minMinutes ?? (currentJob.constraints.minDurationSeconds / 60);

    final nextAudioItems = _audioPaths
        .asMap()
        .entries
        .map(
          (entry) => BulkLoopAudioItem(
            id: 'audio_${entry.key + 1}',
            path: entry.value,
          ),
        )
        .toList();

    final nextJob = currentJob.copyWith(
      name: _jobNameController.text.trim().isEmpty
          ? currentJob.name
          : _jobNameController.text.trim(),
      targetContentCount: resolvedTarget,
      loopCount: resolvedLoopCount,
      constraints: BulkLoopConstraints(
        minDurationSeconds: resolvedMinMinutes * 60,
      ),
      audioItems: nextAudioItems,
      status: BulkLoopJobStatus.draft,
    );

    setState(() => _isBusy = true);
    try {
      await _saveUpdatedJob(nextJob);
      _appendEvent('Config disimpan');
      _showSnack('Config berhasil disimpan');
    } on Exception catch (error) {
      _showSnack('Gagal simpan config: $error');
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _runBatch() async {
    final currentJob = _job;
    if (currentJob == null || _isRunInBackground) return;

    var estimatingDialogOpened = false;
    setState(() {
      _runProgress = null;
      _runStatusText = 'Menghitung estimasi disk...';
    });
    try {
      final estimatingDialog = _showEstimatingDiskDialog();
      estimatingDialogOpened = true;
      final diskEstimate = await _estimateBatchDiskNeed(currentJob);
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      estimatingDialogOpened = false;
      await estimatingDialog;

      if (diskEstimate.contentCount == 0) {
        _showSnack('Tidak ada item queued dengan background untuk diproses.');
        if (mounted) {
          setState(() {
            _runProgress = null;
            _runStatusText = null;
          });
        }
        return;
      }
      if (!mounted) return;
      final shouldProceed = await _showBatchDiskWarningDialog(diskEstimate);
      if (!shouldProceed) {
        setState(() {
          _runProgress = null;
          _runStatusText = null;
        });
        _showSnack('Proses dibatalkan user.');
        return;
      }
      _showSnack('Proses dimulai di background.');

      setState(() {
        _isRunInBackground = true;
        _runProgress = 0;
        _runStatusText = 'Proses berjalan di latar belakang...';
      });
      _startRunningPoller();

      final executor = ref.read(bulkLoopExecutorServiceProvider);
      unawaited(
        _runBatchInBackground(
          executor: executor,
          job: currentJob,
        ),
      );
    } on Exception catch (error) {
      if (estimatingDialogOpened && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      _showSnack('Gagal proses item: $error');
      if (mounted) {
        setState(() {
          _isRunInBackground = false;
          _runProgress = null;
          _runStatusText = null;
        });
      }
    }
  }

  Future<void> _showEstimatingDiskDialog() {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text('Menghitung estimasi disk, mohon tunggu...'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _runBatchInBackground({
    required BulkLoopExecutorService executor,
    required BulkLoopJob job,
  }) async {
    try {
      final updated = await executor.runBatch(
        job,
        onProgress: (value) {
          if (mounted) {
            setState(() {
              _runProgress = value.clamp(0, 1);
              _runStatusText = 'Memproses ${(value * 100).toStringAsFixed(0)}%';
            });
          }
          _appendEvent('Progress ${(value * 100).toStringAsFixed(0)}%');
        },
        onLog: (log) => _appendEvent(log.message),
      );

      if (!mounted) return;
      setState(() {
        _selectedJobId = updated.id;
        _applyJobToForm(updated);
      });
      await _refreshJobs();
      _showSnack('Proses selesai: status ${updated.status.name}');
    } on Exception catch (error) {
      _showSnack('Gagal proses item: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isRunInBackground = false;
          _runProgress = null;
          _runStatusText = null;
        });
      }
    }
  }

  Future<void> _stopAllBackgroundProcesses() async {
    if (!_canStopBackgroundProcesses) return;
    setState(() {
      _runStatusText = 'Menghentikan proses background...';
    });
    await ref
        .read(bulkLoopExecutorServiceProvider)
        .requestCancelAll(
          onLog: (log) => _appendEvent(log.message),
        );
    if (!mounted) return;
    _showSnack('Permintaan stop dikirim. Menunggu proses aktif berhenti.');
  }

  Future<_BatchDiskEstimate> _estimateBatchDiskNeed(BulkLoopJob job) async {
    final mergerService = ref.read(videoMergerServiceProvider);
    final audioById = <String, String>{
      for (final audio in job.audioItems) audio.id: audio.path,
    };

    final selectedContents = job.contents
        .where(
          (content) =>
              content.status == BulkLoopContentStatus.queued &&
              content.backgroundVideoPath != null,
        )
        .toList();

    var outputBytes = 0;
    var tempBytes = 0;
    var requiredBytes = 0;
    final perContent = <_BatchContentDiskEstimate>[];

    for (final content in selectedContents) {
      final backgroundVideoPath = content.backgroundVideoPath;
      if (backgroundVideoPath == null || backgroundVideoPath.isEmpty) continue;
      final audioPaths = content.audioItemIds
          .map((audioId) => audioById[audioId])
          .whereType<String>()
          .toList();
      if (audioPaths.isEmpty) continue;

      final estimate = await mergerService.estimateDiskUsage(
        backgroundVideoPath: backgroundVideoPath,
        audioFiles: audioPaths,
        audioLoopCount: job.loopCount,
        introVideoPath: content.introVideoPath,
      );
      outputBytes += estimate.estimatedOutputBytes;
      tempBytes += estimate.estimatedTempPeakBytes;
      requiredBytes += estimate.estimatedRequiredBytes;
      perContent.add(
        _BatchContentDiskEstimate(
          contentIndex: content.index + 1,
          outputBytes: estimate.estimatedOutputBytes,
          tempBytes: estimate.estimatedTempPeakBytes,
          requiredBytes: estimate.estimatedRequiredBytes,
        ),
      );
    }

    return _BatchDiskEstimate(
      outputBytes: outputBytes,
      tempBytes: tempBytes,
      requiredBytes: requiredBytes,
      contentCount: selectedContents.length,
      perContent: perContent,
    );
  }

  Future<bool> _showBatchDiskWarningDialog(_BatchDiskEstimate estimate) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Perkiraan Kebutuhan Disk Proses'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Item siap proses: ${estimate.contentCount}'),
                const SizedBox(height: 8),
                Text(
                  'Perkiraan output total: ${_formatBytes(estimate.outputBytes)}',
                ),
                Text(
                  'Perkiraan temp peak: ${_formatBytes(estimate.tempBytes)}',
                ),
                Text(
                  'Estimasi kebutuhan total: ${_formatBytes(estimate.requiredBytes)}',
                ),
                const SizedBox(height: 12),
                const Text(
                  'Estimasi per konten:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                ...estimate.perContent.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '#${item.contentIndex} | output ${_formatBytes(item.outputBytes)} | temp ${_formatBytes(item.tempBytes)} | total ${_formatBytes(item.requiredBytes)}',
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Pastikan ruang disk cukup. Jika tidak, proses bisa gagal di tengah karena disk penuh.',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Lanjutkan'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _appendEvent(String message) {
    if (!mounted) return;
    setState(() {
      _events.insert(0, message);
      if (_events.length > 30) {
        _events.removeRange(30, _events.length);
      }
    });
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
