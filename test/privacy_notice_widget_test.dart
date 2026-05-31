import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toyvision_realtime/ui/components/privacy_notice.dart';

Widget _harness() {
  return const ProviderScope(
    child: MaterialApp(
      home: Scaffold(
        body: Center(child: PrivacyNotice()),
      ),
    ),
  );
}

void main() {
  testWidgets('shows the expanded notice by default', (tester) async {
    await tester.pumpWidget(_harness());
    expect(find.textContaining('No video saved or uploaded'), findsOneWidget);
    expect(find.text('On-device only'), findsNothing);
  });

  testWidgets('collapses to a compact chip after the user taps it',
      (tester) async {
    await tester.pumpWidget(_harness());
    await tester.tap(find.byType(PrivacyNotice));
    await tester.pump();

    expect(find.text('On-device only'), findsOneWidget);
    expect(
      find.textContaining('No video saved or uploaded'),
      findsNothing,
    );
  });

  testWidgets('tapping again re-expands (toggle behavior)', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.tap(find.byType(PrivacyNotice));
    await tester.pump();
    await tester.tap(find.byType(PrivacyNotice));
    await tester.pump();
    expect(find.textContaining('No video saved or uploaded'), findsOneWidget);
  });
}
