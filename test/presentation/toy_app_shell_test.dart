import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toyvision_realtime/app/app_router.dart';
import 'package:toyvision_realtime/presentation/navigation/toy_app_shell.dart';

void main() {
  testWidgets('primary shell remains usable on a narrow screen',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: MaterialApp(
          home: ToyAppShell(
            section: ToyAppSection.home,
            title: 'Inicio',
            child: SizedBox(height: 700, child: Text('Contenido principal')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('toy-shell-scroll')), findsOneWidget);
    expect(find.byKey(const Key('nav-home')), findsOneWidget);
    expect(find.byKey(const Key('progress-action')), findsOneWidget);
    expect(find.byKey(const Key('adult-settings')), findsOneWidget);
    expect(find.byKey(const Key('about-action')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bottom navigation replaces the current primary section',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: const ToyAppShell(
          section: ToyAppSection.home,
          title: 'Inicio',
          child: Text('Inicio actual'),
        ),
        routes: {
          AppRoutes.settings: (_) => const Scaffold(body: Text('Ajustes ruta')),
        },
      ),
    );

    await tester.tap(find.byKey(const Key('adult-settings')));
    await tester.pumpAndSettle();

    expect(find.text('Ajustes ruta'), findsOneWidget);
    expect(find.text('Inicio actual'), findsNothing);
  });
}
