import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toyvision_realtime/application/settings/app_settings_controller.dart';
import 'package:toyvision_realtime/infrastructure/persistence/shared_preferences_provider.dart';
import 'package:toyvision_realtime/presentation/cleanup/vision_display_mode.dart';

void main() {
  test('Kid Mode overrides a previously selected developer surface', () async {
    SharedPreferences.setMockInitialValues({
      'toyvision.settings.kid_mode': false,
    });
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
    );
    addTearDown(container.dispose);

    container.read(visionDisplayModeProvider.notifier).state =
        VisionDisplayMode.developerDebug;
    expect(
      container.read(effectiveVisionDisplayModeProvider),
      VisionDisplayMode.developerDebug,
    );

    await container.read(appSettingsProvider.notifier).setKidMode(true);

    expect(
      container.read(effectiveVisionDisplayModeProvider),
      VisionDisplayMode.kid,
    );
  });
}
