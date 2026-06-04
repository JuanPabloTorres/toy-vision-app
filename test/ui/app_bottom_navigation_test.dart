import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toyvision_realtime/app/app_theme.dart';
import 'package:toyvision_realtime/ui/navigation/app_bottom_navigation.dart';

void main() {
  testWidgets('renders all four destinations', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          bottomNavigationBar: AppBottomNavigation(
            current: AppTab.home,
            onSelect: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text('Misión'), findsOneWidget);
    expect(find.text('Progreso'), findsOneWidget);
    expect(find.text('Padres'), findsOneWidget);
  });

  testWidgets('tapping a destination fires onSelect with the right tab',
      (tester) async {
    AppTab? selected;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          bottomNavigationBar: AppBottomNavigation(
            current: AppTab.home,
            onSelect: (t) => selected = t,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Progreso'));
    await tester.pump();
    expect(selected, AppTab.progress);

    await tester.tap(find.text('Padres'));
    await tester.pump();
    expect(selected, AppTab.parents);

    await tester.tap(find.text('Misión'));
    await tester.pump();
    expect(selected, AppTab.mission);
  });
}
