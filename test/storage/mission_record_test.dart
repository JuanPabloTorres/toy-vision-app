import 'package:flutter_test/flutter_test.dart';
import 'package:toyvision_realtime/storage/mission_record.dart';

void main() {
  group('MissionRecord serialization', () {
    test('round-trips every field, including the verification flags', () {
      final record = MissionRecord(
        id: 'm1',
        date: DateTime(2026, 6, 4, 10, 30),
        initialToyCount: 4,
        collectedToyCount: 4,
        completed: true,
        durationSeconds: 95,
        starsEarned: 2,
        visuallyVerified: true,
        usedManualHelp: true,
        hadUncertainty: true,
      );

      final restored = MissionRecord.fromJson(record.toJson());

      expect(restored.id, record.id);
      expect(restored.date, record.date);
      expect(restored.initialToyCount, 4);
      expect(restored.collectedToyCount, 4);
      expect(restored.completed, isTrue);
      expect(restored.durationSeconds, 95);
      expect(restored.starsEarned, 2);
      expect(restored.visuallyVerified, isTrue);
      expect(restored.usedManualHelp, isTrue);
      expect(restored.hadUncertainty, isTrue);
    });

    test('legacy JSON without the verification flags loads as false', () {
      // A record exactly as written by the previous schema (v1) — no
      // visuallyVerified / usedManualHelp / hadUncertainty keys.
      final legacy = <String, dynamic>{
        'id': 'old',
        'date': '2026-06-01T09:00:00.000',
        'initialToyCount': 3,
        'collectedToyCount': 2,
        'completed': false,
        'durationSeconds': 60,
        'starsEarned': 1,
      };

      final restored = MissionRecord.fromJson(legacy);

      expect(restored.collectedToyCount, 2);
      expect(restored.completed, isFalse);
      // The new flags must default to false rather than throw — no migration.
      expect(restored.visuallyVerified, isFalse);
      expect(restored.usedManualHelp, isFalse);
      expect(restored.hadUncertainty, isFalse);
    });

    test('the verification flags default to false in the constructor', () {
      final record = MissionRecord(
        id: 'm2',
        date: DateTime(2026),
        initialToyCount: 1,
        collectedToyCount: 1,
        completed: true,
        durationSeconds: 10,
        starsEarned: 1,
      );
      expect(record.visuallyVerified, isFalse);
      expect(record.usedManualHelp, isFalse);
      expect(record.hadUncertainty, isFalse);
    });
  });
}
