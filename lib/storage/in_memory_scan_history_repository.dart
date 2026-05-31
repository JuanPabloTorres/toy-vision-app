import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'saved_scan_summary.dart';
import 'scan_history_repository.dart';

/// In-memory implementation of [ScanHistoryRepository]. Summaries live for the
/// lifetime of the app process; nothing is written to disk in this phase.
///
/// Exposed as a Riverpod [Notifier] so the history UI re-renders automatically
/// when a new summary is saved.
class InMemoryScanHistoryRepository extends Notifier<List<SavedScanSummary>>
    implements ScanHistoryRepository {
  @override
  List<SavedScanSummary> build() => const [];

  @override
  List<SavedScanSummary> get all => state;

  @override
  Future<void> save(SavedScanSummary summary) async {
    state = [summary, ...state]; // newest first
  }

  @override
  Future<void> clear() async {
    state = const [];
  }
}

/// The single source of saved-scan state for the UI to watch.
final scanHistoryProvider = NotifierProvider<InMemoryScanHistoryRepository,
    List<SavedScanSummary>>(
  InMemoryScanHistoryRepository.new,
);
