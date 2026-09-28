import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toyvision_realtime/domain/cleanup/cleanup_event.dart';
import 'package:toyvision_realtime/infrastructure/persistence/shared_preferences_provider.dart';
import 'package:toyvision_realtime/presentation/feedback/animation_director.dart';
import 'package:toyvision_realtime/presentation/widgets/tobi_3d_stage.dart';
import 'package:toyvision_realtime/ui/components/tobi_mascot.dart';

void main() {
  testWidgets('domain animation state selects the matching Tobi motion',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'toyvision.settings.animations': false,
    });
    final preferences = await SharedPreferences.getInstance();
    late ProviderContainer container;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          tobi3dEnabledProvider.overrideWithValue(false),
        ],
        child: Builder(
          builder: (context) {
            container = ProviderScope.containerOf(context);
            return const MaterialApp(
              home: Scaffold(body: Tobi3dStage(enable3d: false)),
            );
          },
        ),
      ),
    );

    expect(
      tester.widget<TobiMascot>(find.byType(TobiMascot)).motion,
      TobiMotion.idle,
    );

    container.read(animationDirectorProvider.notifier).searching();
    await tester.pump();

    expect(
      tester.widget<TobiMascot>(find.byType(TobiMascot)).motion,
      TobiMotion.searching,
    );

    container.read(animationDirectorProvider.notifier).handle(
          CleanupCompleted(DateTime.utc(2026), 2),
        );
    await tester.pump();

    expect(
      tester.widget<TobiMascot>(find.byType(TobiMascot)).motion,
      TobiMotion.celebrating,
    );
    expect(
      container.read(animationDirectorProvider).lottieEffect,
      'assets/lottie/celebration.json',
    );
  });
}
