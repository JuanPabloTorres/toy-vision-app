import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_theme.dart';
import '../../storage/in_memory_scan_history_repository.dart';
import '../../storage/saved_scan_summary.dart';
import '../components/app_badge.dart';
import '../components/app_card.dart';
import '../components/app_status_chip.dart';

/// Read-only list of saved scan summaries for the current session.
///
/// Summary-only by design: no thumbnails, no frames, no media. Persistence
/// across sessions is a later phase.
class ScanHistoryScreen extends ConsumerWidget {
  const ScanHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaries = ref.watch(scanHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved scans'),
        actions: [
          if (summaries.isNotEmpty)
            IconButton(
              tooltip: 'Clear all',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => ref.read(scanHistoryProvider.notifier).clear(),
            ),
        ],
      ),
      body: summaries.isEmpty
          ? const _EmptyState()
          : ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: summaries.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.md),
              itemBuilder: (_, i) => _SummaryTile(summary: summaries[i]),
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inventory_2_outlined, size: 48),
            const SizedBox(height: AppSpacing.lg),
            Text('No scans saved yet.', style: textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Tap the save button on the live screen to record a count summary.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium
                  ?.copyWith(color: AppColors.onSurfaceMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.summary});

  final SavedScanSummary summary;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ts = summary.createdAt.toLocal();
    final hh = ts.hour.toString().padLeft(2, '0');
    final mm = ts.minute.toString().padLeft(2, '0');
    final ss = ts.second.toString().padLeft(2, '0');
    final timeLabel = '${ts.year}-${ts.month.toString().padLeft(2, '0')}-'
        '${ts.day.toString().padLeft(2, '0')}  $hh:$mm:$ss';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Total toys: ${summary.totalToys}',
                  style: textTheme.titleLarge,
                ),
              ),
              AppStatusChip(
                label: 'Mode: ${summary.detectorMode}',
                kind: AppStatusKind.busy,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            timeLabel,
            style:
                textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceMuted),
          ),
          if (summary.perCategory.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final entry in summary.perCategory.entries)
                  AppBadge(label: entry.key, value: '${entry.value}'),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
