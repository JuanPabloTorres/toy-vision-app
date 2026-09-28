import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toyvision_realtime/application/settings/app_settings_controller.dart';
import 'package:toyvision_realtime/infrastructure/persistence/shared_preferences_provider.dart';

void main() {
  test('adult settings persist on device', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final first = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
    );
    await first.read(appSettingsProvider.notifier).setMusic(false);
    await first.read(appSettingsProvider.notifier).setAnimations(false);
    first.dispose();

    final restored = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
    );
    addTearDown(restored.dispose);

    expect(restored.read(appSettingsProvider).musicEnabled, isFalse);
    expect(restored.read(appSettingsProvider).animationsEnabled, isFalse);
    expect(restored.read(appSettingsProvider).kidModeEnabled, isTrue);
  });
}
