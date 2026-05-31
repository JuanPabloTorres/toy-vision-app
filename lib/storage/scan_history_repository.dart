import 'saved_scan_summary.dart';

/// Repository interface for saved scan summaries.
///
/// Phase 3.3 ships only [InMemoryScanHistoryRepository]; a persistent
/// implementation (SQLite/Hive) is a later phase. The interface exists so the
/// rest of the app depends on the abstraction, not the storage engine.
abstract class ScanHistoryRepository {
  List<SavedScanSummary> get all;
  Future<void> save(SavedScanSummary summary);
  Future<void> clear();
}
