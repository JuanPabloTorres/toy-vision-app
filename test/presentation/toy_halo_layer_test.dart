import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toyvision_realtime/domain/toy/normalized_box.dart';
import 'package:toyvision_realtime/domain/toy/toy_observation.dart';
import 'package:toyvision_realtime/domain/toy/toy_track.dart';
import 'package:toyvision_realtime/infrastructure/persistence/shared_preferences_provider.dart';
import 'package:toyvision_realtime/presentation/cleanup/toy_halo_layer.dart';

void main() {
  testWidgets('kid halo describes toys without exposing detector diagnostics',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'toyvision.settings.animations': false,
    });
    final preferences = await SharedPreferences.getInstance();
    final track = _track(knownClass: 'car', confidence: 0.87);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ToyHaloLayer(
              tracks: [track],
              sourceWidth: 640,
              sourceHeight: 480,
              activeTrackId: track.id,
            ),
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('1 objeto resaltado'), findsOneWidget);
    expect(find.textContaining('car'), findsNothing);
    expect(find.textContaining('0.87'), findsNothing);
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('unconfirmed proposal stays out of the child-facing overlay',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'toyvision.settings.animations': false,
    });
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ToyHaloLayer(
              tracks: [_track(confirmedToy: false)],
              sourceWidth: 640,
              sourceHeight: 480,
            ),
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Buscando cosas por recoger'), findsOneWidget);
  });

  testWidgets('overlapping tracks render as one physical toy halo',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'toyvision.settings.animations': false,
    });
    final preferences = await SharedPreferences.getInstance();
    final first = _track();
    final duplicate = _track(
      id: 8,
      bounds: const NormalizedBox(
        x: 0.21,
        y: 0.21,
        width: 0.28,
        height: 0.28,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ToyHaloLayer(
              tracks: [first, duplicate],
              sourceWidth: 640,
              sourceHeight: 480,
              activeTrackId: duplicate.id,
            ),
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('1 objeto resaltado'), findsOneWidget);
    expect(
      selectDistinctToyHalos(
        [first, duplicate],
        activeTrackId: duplicate.id,
      ).single.id,
      duplicate.id,
    );
  });
}

ToyTrack _track({
  int id = 7,
  NormalizedBox bounds = const NormalizedBox(
    x: 0.2,
    y: 0.2,
    width: 0.3,
    height: 0.3,
  ),
  bool confirmedToy = true,
  String? knownClass,
  double confidence = 0.9,
}) {
  final now = DateTime.utc(2026, 1, 1);
  return ToyTrack(
    id: id,
    lastBounds: bounds,
    initialBounds: bounds,
    visualEmbedding: const [1, 0, 0],
    visibleFrames: 8,
    missingFrames: 0,
    confidence: confidence,
    presence: TrackPresence.visible,
    firstSeenAt: now,
    lastSeenAt: now,
    updatedAt: now,
    source: ObservationSource.fused,
    confirmedToy: confirmedToy,
    confirmedAt: confirmedToy ? now : null,
    interactionEvidence: 0,
    knownClass: knownClass,
  );
}
