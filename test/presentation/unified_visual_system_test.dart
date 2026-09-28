import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toyvision_realtime/app/app_theme.dart';
import 'package:toyvision_realtime/application/home/home_progress.dart';
import 'package:toyvision_realtime/infrastructure/persistence/shared_preferences_provider.dart';
import 'package:toyvision_realtime/presentation/about/about_screen.dart';
import 'package:toyvision_realtime/presentation/launch/camera_onboarding_screen.dart';
import 'package:toyvision_realtime/presentation/launch/splash_screen.dart';
import 'package:toyvision_realtime/presentation/navigation/toy_app_shell.dart';
import 'package:toyvision_realtime/presentation/progress/progress_screen.dart';
import 'package:toyvision_realtime/presentation/settings/settings_screen.dart';
import 'package:toyvision_realtime/presentation/widgets/tobi_3d_stage.dart';
import 'package:toyvision_realtime/ui/components/toy_surface.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'primary pages share the same shell and hero on a narrow screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final preferences = await SharedPreferences.getInstance();

      final screens = <Widget>[
        const ProgressScreen(),
        const SettingsScreen(),
        const AboutScreen(),
      ];
      for (final screen in screens) {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(preferences),
              tobi3dEnabledProvider.overrideWithValue(false),
              homeProgressProvider.overrideWith(
                (ref) async => const HomeProgress(
                  totalStars: 7,
                  currentStreak: 2,
                  completedSessions: 1,
                ),
              ),
            ],
            child: MediaQuery(
              data: const MediaQueryData(
                textScaler: TextScaler.linear(1.3),
              ),
              child: MaterialApp(theme: AppTheme.light(), home: screen),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(ToyAppShell), findsOneWidget);
        expect(find.byType(ToyPageHero), findsOneWidget);
        expect(find.byType(ToyBottomNavigation), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('launch pages remain spacious on a small phone', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final preferences = await SharedPreferences.getInstance();

    Future<void> pumpLaunchPage(Widget page) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(preferences),
            tobi3dEnabledProvider.overrideWithValue(false),
          ],
          child: MediaQuery(
            data: const MediaQueryData(
              textScaler: TextScaler.linear(1.3),
            ),
            child: MaterialApp(theme: AppTheme.light(), home: page),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
    }

    await pumpLaunchPage(const SplashScreen());
    expect(find.byType(ToyWordmark), findsOneWidget);
    expect(find.text('Tobi Ordena', findRichText: true), findsOneWidget);
    expect(find.byType(ToyCard), findsOneWidget);

    await pumpLaunchPage(const CameraOnboardingScreen());
    expect(find.byType(ToyPageHero), findsOneWidget);
    expect(find.byKey(const Key('allow-camera')), findsOneWidget);
    expect(find.text('Mira'), findsOneWidget);
    expect(find.text('Encuentra'), findsOneWidget);
    expect(find.text('Recoge'), findsOneWidget);
  });
}
