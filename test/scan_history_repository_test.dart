import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toyvision_realtime/storage/in_memory_scan_history_repository.dart';
import 'package:toyvision_realtime/storage/saved_scan_summary.dart';

SavedScanSummary _sample({
  required String id,
  int total = 1,
  Map<String, int>? perCategory,
  String mode = 'mock',
}) {
  return SavedScanSummary(
    id: id,
    createdAt: DateTime(2026, 5, 30, 10, int.parse(id)),
    totalToys: total,
    perCategory: perCategory ?? const {'Toy car': 1},
    detectorMode: mode,
  );
}

void main() {
  test('starts empty', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(scanHistoryProvider), isEmpty);
  });

  test('save adds the summary and the provider state updates', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final repo = container.read(scanHistoryProvider.notifier);

    await repo.save(_sample(id: '01'));
    expect(container.read(scanHistoryProvider), hasLength(1));
    expect(repo.all, hasLength(1));
    expect(repo.all.single.id, '01');
  });

  test('newer saves appear first (newest-first ordering)', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final repo = container.read(scanHistoryProvider.notifier);

    await repo.save(_sample(id: '01', total: 1));
    await repo.save(_sample(id: '02', total: 2));
    await repo.save(_sample(id: '03', total: 3));

    final ids = container.read(scanHistoryProvider).map((s) => s.id).toList();
    expect(ids, ['03', '02', '01']);
  });

  test('clear empties the list', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final repo = container.read(scanHistoryProvider.notifier);

    await repo.save(_sample(id: '01'));
    await repo.save(_sample(id: '02'));
    await repo.clear();
    expect(container.read(scanHistoryProvider), isEmpty);
  });

  test('records detector mode and per-category counts as given', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final repo = container.read(scanHistoryProvider.notifier);

    await repo.save(
      _sample(
        id: '01',
        total: 3,
        perCategory: const {'Toy car': 2, 'Doll': 1},
        mode: 'mlkitWithFallback',
      ),
    );
    final saved = container.read(scanHistoryProvider).single;
    expect(saved.totalToys, 3);
    expect(saved.perCategory, {'Toy car': 2, 'Doll': 1});
    expect(saved.detectorMode, 'mlkitWithFallback');
  });
}
