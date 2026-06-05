import 'package:flutter_test/flutter_test.dart';
import 'package:toyvision_realtime/storage/active_mission_record.dart';
import 'package:toyvision_realtime/storage/mission_record.dart';

/// Privacy-first guard: everything we persist is safe metadata (counts,
/// timestamps, flags). No frame, image, photo, or bounding-box data may ever
/// be written to disk. If a future field reintroduces media, this fails.
const _forbidden = [
  'image',
  'frame',
  'photo',
  'bitmap',
  'pixels',
  'thumbnail',
  'boundingbox',
  'box',
  'rect',
  'path',
  'uri',
  'url',
];

void _assertNoMediaKeys(Map<String, dynamic> json) {
  for (final key in json.keys) {
    final lower = key.toLowerCase();
    for (final bad in _forbidden) {
      expect(
        lower.contains(bad),
        isFalse,
        reason: 'persisted key "$key" looks like media/sensitive data ($bad)',
      );
    }
  }
}

void main() {
  test('MissionRecord persists only safe metadata', () {
    final json = MissionRecord(
      id: '1',
      date: DateTime(2026, 6, 3, 12),
      initialToyCount: 5,
      collectedToyCount: 5,
      completed: true,
      durationSeconds: 60,
      starsEarned: 3,
    ).toJson();
    _assertNoMediaKeys(json);
  });

  test('ActiveMissionRecord persists only safe metadata', () {
    final json = ActiveMissionRecord(
      missionId: 'mission-1',
      startedAt: DateTime(2026, 6, 3, 12),
      baselineToyCount: 4,
    ).toJson();
    _assertNoMediaKeys(json);
  });
}
