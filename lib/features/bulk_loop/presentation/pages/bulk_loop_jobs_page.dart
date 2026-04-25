import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swaloka_looping_tool/features/bulk_loop/domain/models/models.dart';
import 'package:swaloka_looping_tool/features/bulk_loop/presentation/pages/bulk_loop_job_detail_page.dart';
import 'package:swaloka_looping_tool/features/bulk_loop/presentation/providers/providers.dart';
import 'package:swaloka_looping_tool/features/video_merger/domain/models/swaloka_project.dart';

class BulkLoopJobsPage extends ConsumerStatefulWidget {
  const BulkLoopJobsPage({required this.project, super.key});

  final SwalokaProject project;

  @override
  ConsumerState<BulkLoopJobsPage> createState() => _BulkLoopJobsPageState();
}

class _BulkLoopJobsPageState extends ConsumerState<BulkLoopJobsPage> {
  List<BulkLoopJob> _jobs = const [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadJobs();
  }

  Future<void> _loadJobs() async {
    setState(() => _isLoading = true);
    try {
      final repository = ref.read(bulkLoopJobRepositoryProvider);
      final jobs = await repository.list(widget.project.rootPath);
      if (!mounted) return;
      setState(() {
        _jobs = jobs;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildHeader(context),
        const SizedBox(height: 12),
        if (_isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_jobs.isEmpty)
          _emptyCard(context)
        else
          ..._jobs.map((job) => _jobCard(context, job)),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
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
              Icon(Icons.auto_awesome_motion, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Loop Sekaligus',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Kelola channel, lalu buka detail untuk generate plan dan proses item.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _loadJobs,
                icon: const Icon(Icons.refresh),
                label: const Text('Muat Ulang Channel'),
              ),
              ElevatedButton.icon(
                onPressed: _createJob,
                icon: const Icon(Icons.add),
                label: const Text('Buat Channel'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _emptyCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Text(
        'Belum ada channel. Klik "Buat Channel" untuk membuat channel baru.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }

  Widget _jobCard(BuildContext context, BulkLoopJob job) {
    final colorScheme = Theme.of(context).colorScheme;
    final updatedText =
        '${job.updatedAt.year}-${job.updatedAt.month.toString().padLeft(2, '0')}-${job.updatedAt.day.toString().padLeft(2, '0')} '
        '${job.updatedAt.hour.toString().padLeft(2, '0')}:${job.updatedAt.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            job.name,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(context, 'Status: ${job.status.name}'),
              _chip(context, 'Target: ${job.targetContentCount}'),
              _chip(context, 'Loop: ${job.loopCount}'),
            ],
          ),
          Text(
            'Updated: $updatedText',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              ElevatedButton(
                onPressed: () => _openDetail(job),
                child: const Text('Buka Detail'),
              ),
              IconButton(
                onPressed: () => _editJob(job),
                tooltip: 'Ubah',
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                onPressed: () => _deleteJob(job),
                tooltip: 'Hapus',
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: Theme.of(context).textTheme.labelSmall),
    );
  }

  Future<void> _createJob() async {
    final nameController = TextEditingController(
      text: 'bulk_job_${_jobs.length + 1}',
    );
    final targetController = TextEditingController(text: '30');
    final loopController = TextEditingController(text: '2');
    final minController = TextEditingController(text: '120');

    final confirmed = await _showJobDialog(
      title: 'Buat Channel',
      nameController: nameController,
      targetController: targetController,
      loopController: loopController,
      minController: minController,
    );
    if (confirmed != true) return;

    final target = int.tryParse(targetController.text.trim()) ?? 30;
    final loopCount = int.tryParse(loopController.text.trim()) ?? 2;
    final minMinutes = double.tryParse(minController.text.trim()) ?? 120;
    final nowSeed = DateTime.now().millisecondsSinceEpoch;

    final job = BulkLoopJob.create(
      id: 'bulk_$nowSeed',
      name: nameController.text.trim().isEmpty
          ? 'bulk_job'
          : nameController.text.trim(),
      projectRootPath: widget.project.rootPath,
      outputDirectoryPath: widget.project.effectiveOutputPath,
      targetContentCount: max(1, target),
      loopCount: max(1, loopCount),
      constraints: BulkLoopConstraints(
        minDurationSeconds: minMinutes * 60,
      ),
      seed: nowSeed,
      audioItems: const [],
    );

    final repository = ref.read(bulkLoopJobRepositoryProvider);
    await repository.save(job);
    await _loadJobs();
  }

  Future<void> _editJob(BulkLoopJob job) async {
    final nameController = TextEditingController(text: job.name);
    final targetController = TextEditingController(
      text: job.targetContentCount.toString(),
    );
    final loopController = TextEditingController(
      text: job.loopCount.toString(),
    );
    final minController = TextEditingController(
      text: (job.constraints.minDurationSeconds / 60).round().toString(),
    );

    final confirmed = await _showJobDialog(
      title: 'Ubah Channel',
      nameController: nameController,
      targetController: targetController,
      loopController: loopController,
      minController: minController,
    );
    if (confirmed != true) return;

    final target =
        int.tryParse(targetController.text.trim()) ?? job.targetContentCount;
    final loopCount = int.tryParse(loopController.text.trim()) ?? job.loopCount;
    final minMinutes =
        double.tryParse(minController.text.trim()) ??
        (job.constraints.minDurationSeconds / 60);

    final nextJob = job.copyWith(
      name: nameController.text.trim().isEmpty
          ? job.name
          : nameController.text.trim(),
      targetContentCount: max(1, target),
      loopCount: max(1, loopCount),
      constraints: BulkLoopConstraints(
        minDurationSeconds: minMinutes * 60,
      ),
    );

    final repository = ref.read(bulkLoopJobRepositoryProvider);
    await repository.save(nextJob);
    await _loadJobs();
  }

  Future<void> _deleteJob(BulkLoopJob job) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus Channel'),
        content: Text('Hapus channel "${job.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final repository = ref.read(bulkLoopJobRepositoryProvider);
    await repository.delete(
      projectRootPath: widget.project.rootPath,
      jobId: job.id,
    );
    await _loadJobs();
  }

  Future<bool?> _showJobDialog({
    required String title,
    required TextEditingController nameController,
    required TextEditingController targetController,
    required TextEditingController loopController,
    required TextEditingController minController,
  }) {
    Widget input(TextEditingController controller, String label) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
      );
    }

    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              input(nameController, 'Nama Channel'),
              input(targetController, 'Target Konten'),
              input(loopController, 'Jumlah Loop'),
              input(minController, 'Durasi Minimum (menit)'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _openDetail(BulkLoopJob job) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => BulkLoopJobDetailPage(
          project: widget.project,
          jobId: job.id,
        ),
      ),
    );
  }
}
