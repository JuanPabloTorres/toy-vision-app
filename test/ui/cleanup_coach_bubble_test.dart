import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toyvision_realtime/app/app_theme.dart';
import 'package:toyvision_realtime/ui/panels/cleanup_coach_bubble.dart';

Widget _harness(Widget child) {
  return MaterialApp(
    theme: AppTheme.dark(),
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  testWidgets('renders the mascot name and the message', (tester) async {
    await tester.pumpWidget(
      _harness(
        const CleanupCoachBubble(message: 'Veo 4 juguetes.'),
      ),
    );
    await tester.pump();
    expect(find.text('Tobi dice'), findsOneWidget);
    expect(find.text('Veo 4 juguetes.'), findsOneWidget);
  });

  testWidgets('renders nothing when the message is empty', (tester) async {
    await tester.pumpWidget(
      _harness(
        const CleanupCoachBubble(message: ''),
      ),
    );
    expect(find.text('Tobi dice'), findsNothing);
  });

  testWidgets('uses the custom mascot name when provided', (tester) async {
    await tester.pumpWidget(
      _harness(
        const CleanupCoachBubble(message: 'Hola', mascotName: 'Luna'),
      ),
    );
    await tester.pump();
    expect(find.text('Luna dice'), findsOneWidget);
  });
}
