import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toyvision_realtime/business/live_detection_state.dart';
import 'package:toyvision_realtime/ui/panels/toy_summary_panel.dart';

Widget _harness(ToyCountSummary summary) {
  return MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.bottomCenter,
        child: ToySummaryPanel(summary: summary),
      ),
    ),
  );
}

void main() {
  testWidgets('renders nothing when there are no categories', (tester) async {
    await tester.pumpWidget(_harness(ToyCountSummary.empty));
    expect(find.byType(ToySummaryPanel), findsOneWidget);
    expect(find.textContaining('Toy car'), findsNothing);
  });

  testWidgets('renders each category as a badge', (tester) async {
    await tester.pumpWidget(
      _harness(
        const ToyCountSummary(
          total: 3,
          perCategory: {'Toy car': 2, 'Doll': 1},
        ),
      ),
    );
    expect(find.text('Toy car'), findsOneWidget);
    expect(find.text('Doll'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('many categories scroll horizontally without overflow',
      (tester) async {
    final many = <String, int>{
      for (var i = 0; i < 10; i++) 'Category $i': i + 1,
    };
    await tester.pumpWidget(
      _harness(
        ToyCountSummary(total: 55, perCategory: many),
      ),
    );
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(tester.takeException(), isNull); // no overflow
  });
}
