import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../infrastructure/persistence/shared_preferences_provider.dart';

class LaunchController extends Notifier<bool> {
  static const _onboardingKey = 'toyvision.onboarding.completed.v1';

  @override
  bool build() =>
      ref.watch(sharedPreferencesProvider).getBool(_onboardingKey) ?? false;

  Future<void> completeOnboarding() async {
    state = true;
    await ref.read(sharedPreferencesProvider).setBool(_onboardingKey, true);
  }
}

final launchControllerProvider = NotifierProvider<LaunchController, bool>(
  LaunchController.new,
);
