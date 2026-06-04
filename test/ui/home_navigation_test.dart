import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toyvision_realtime/ui/navigation/app_shell.dart';

/// Verifies the bottom-nav swaps tabs inside the shell AND that the two
/// Home call-to-actions lead to *different* flows: "Nueva misión" opens the
/// pre-camera mission intro, "Ver progreso" opens the progress dashboard.
/// The Mission tab / camera is intentionally never reached here because it
/// mounts a native camera view (YOLOView), unavailable in a widget test.
void main() {
  // The Home primary CTA breathes (a continuous pulse). A repeating
  // animation never lets pumpAndSettle() settle, so we run the harness in
  // reduced-motion — injected *below* MaterialApp via its builder, since
  // MaterialApp installs its own MediaQuery that would otherwise override an
  // ancestor. This also mirrors a real reduced-motion user.
  Widget app() => ProviderScope(
        child: MaterialApp(
          home: const AppShell(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
        ),
      );

  testWidgets('opens on the Home tab with both call-to-actions',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pump();
    expect(find.text('Nueva misión'), findsOneWidget);
    expect(find.text('Ver progreso'), findsOneWidget);
    expect(find.text('Misión del día'), findsOneWidget);
  });

  testWidgets('"Ver progreso" opens the progress dashboard, not the camera',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pump();

    await tester.tap(find.text('Ver progreso'));
    await tester.pumpAndSettle();

    // Dashboard markers — no camera, no detection.
    expect(find.text('Mis estrellas'), findsOneWidget);
    expect(find.text('Logros'), findsOneWidget);
    // We never left for the active mission flow.
    expect(find.text('Misión activa'), findsNothing);
  });

  testWidgets('"Nueva misión" opens the mission intro (pre-camera)',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pump();

    await tester.tap(find.text('Nueva misión'));
    await tester.pumpAndSettle();

    // Intro step is shown; the camera is not mounted until "¡Vamos!".
    expect(find.text('¡Preparados para la misión!'), findsOneWidget);
    expect(find.text('¡Vamos!'), findsOneWidget);
  });

  testWidgets('bottom nav: Home → Progreso → Padres → Inicio', (tester) async {
    await tester.pumpWidget(app());
    await tester.pump();

    await tester.tap(find.text('Progreso'));
    await tester.pumpAndSettle();
    expect(find.text('Mis estrellas'), findsOneWidget);

    await tester.tap(find.text('Padres'));
    await tester.pumpAndSettle();
    expect(find.text('Para padres'), findsOneWidget);
    // "Sistema" is the first section at the top of the Parents list (always
    // built). "Privacidad" now sits below the System/Detector/Mission/Audio
    // sections, so it's off-screen in the lazy ListView.
    expect(find.text('Sistema'), findsOneWidget);

    await tester.tap(find.text('Inicio'));
    await tester.pumpAndSettle();
    expect(find.text('Nueva misión'), findsOneWidget);
  });
}
