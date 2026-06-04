import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toyvision_realtime/business/review/candidate_review_controller.dart';
import 'package:toyvision_realtime/business/review/toy_candidate_status.dart';
import 'package:toyvision_realtime/detection/models/bounding_box.dart';
import 'package:toyvision_realtime/tracking/tracked_toy.dart';
import 'package:toyvision_realtime/ui/panels/review_panel.dart';

TrackedToy _tracked({int id = 1, String label = 'home_good'}) {
  return TrackedToy(
    id: id,
    label: label,
    displayName: label,
    box: const BoundingBox(x: 0.1, y: 0.1, width: 0.2, height: 0.2),
    confidence: 0.62,
  );
}

/// Wraps [ReviewPanel] inline (not as modal sheet) for widget tests.
Widget _hostInline({required ProviderContainer container}) {
  return UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 800,
          child: ReviewPanel(),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows empty state when there are no candidates', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(_hostInline(container: container));
    await tester.pumpAndSettle();

    expect(
      find.text('No detections yet. Point the camera at toys.'),
      findsOneWidget,
    );
  });

  testWidgets('renders one pending row with Count + Ignore buttons',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(candidateReviewControllerProvider.notifier)
        .ingest([_tracked(id: 7, label: 'object')], 0);

    await tester.pumpWidget(_hostInline(container: container));
    await tester.pumpAndSettle();

    expect(find.textContaining('Object #7'), findsOneWidget);
    expect(find.text('Count as toy'), findsOneWidget);
    expect(find.text('Ignore'), findsOneWidget);
  });

  testWidgets('tapping Count as toy moves candidate into confirmed',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(candidateReviewControllerProvider.notifier)
        .ingest([_tracked(id: 7)], 0);

    await tester.pumpWidget(_hostInline(container: container));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Count as toy'));
    await tester.pumpAndSettle();

    final s = container.read(candidateReviewControllerProvider);
    expect(s.byId[7]!.status, ToyCandidateStatus.confirmedToy);
    expect(s.summary.confirmed, 1);
    expect(s.summary.ignored, 0);
  });

  testWidgets('tapping Ignore excludes the candidate', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(candidateReviewControllerProvider.notifier)
        .ingest([_tracked(id: 7)], 0);

    await tester.pumpWidget(_hostInline(container: container));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ignore'));
    await tester.pumpAndSettle();

    final s = container.read(candidateReviewControllerProvider);
    expect(s.byId[7]!.status, ToyCandidateStatus.notToy);
    expect(s.summary.ignored, 1);
  });

  testWidgets('confirmed row shows Undo button and undo returns to unsure',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final ctrl = container.read(candidateReviewControllerProvider.notifier);
    ctrl.ingest([_tracked(id: 7)], 0);
    ctrl.markToy(7);

    await tester.pumpWidget(_hostInline(container: container));
    await tester.pumpAndSettle();

    expect(find.text('Undo'), findsOneWidget);
    expect(find.text('Count as toy'), findsNothing);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    final s = container.read(candidateReviewControllerProvider);
    expect(s.byId[7]!.status, ToyCandidateStatus.unsure);
  });

  testWidgets('header summary chips reflect the current breakdown',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final ctrl = container.read(candidateReviewControllerProvider.notifier);
    ctrl.ingest([_tracked(id: 1), _tracked(id: 2), _tracked(id: 3)], 0);
    ctrl.markToy(1);
    ctrl.markNotToy(2);
    // id 3 stays pending

    await tester.pumpWidget(_hostInline(container: container));
    await tester.pumpAndSettle();

    expect(find.text('Detected: 3'), findsOneWidget);
    expect(find.text('Confirmed: 1'), findsOneWidget);
    expect(find.text('Ignored: 1'), findsOneWidget);
  });
}
