import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toyvision_realtime/app/app_theme.dart';
import 'package:toyvision_realtime/ui/panels/mission_complete_panel.dart';

Widget _harness(Widget child) {
  return MaterialApp(
    theme: AppTheme.dark(),
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('shows the celebration headline and CTA', (tester) async {
    await tester.pumpWidget(
      _harness(
        MissionCompletePanel(
          collectedToyCount: 4,
          onNewMission: () {},
        ),
      ),
    );
    expect(find.text('¡Terminaste!'), findsOneWidget);
    expect(find.text('Nueva misión'), findsOneWidget);
  });

  testWidgets('includes the count in the summary when > 0', (tester) async {
    await tester.pumpWidget(
      _harness(
        MissionCompletePanel(
          collectedToyCount: 3,
          onNewMission: () {},
        ),
      ),
    );
    expect(find.textContaining('3'), findsOneWidget);
  });

  testWidgets('CTA fires the callback', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _harness(
        MissionCompletePanel(
          collectedToyCount: 2,
          onNewMission: () => taps++,
        ),
      ),
    );
    await tester.tap(find.text('Nueva misión'));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('shows "Ver mis estrellas" and fires it when onSeeStars is set',
      (tester) async {
    var sees = 0;
    await tester.pumpWidget(
      _harness(
        MissionCompletePanel(
          collectedToyCount: 2,
          onNewMission: () {},
          onSeeStars: () => sees++,
        ),
      ),
    );
    expect(find.text('Ver mis estrellas'), findsOneWidget);
    await tester.tap(find.text('Ver mis estrellas'));
    await tester.pump();
    expect(sees, 1);
  });

  testWidgets('hides "Ver mis estrellas" when onSeeStars is null',
      (tester) async {
    await tester.pumpWidget(
      _harness(
        MissionCompletePanel(collectedToyCount: 1, onNewMission: () {}),
      ),
    );
    expect(find.text('Ver mis estrellas'), findsNothing);
  });
}
