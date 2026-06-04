import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The single, app-wide [SharedPreferences] instance.
///
/// `SharedPreferences.getInstance()` is async, but every read/write on the
/// obtained instance is synchronous — which is what lets the persistent
/// repositories load their seed state inside a synchronous Riverpod
/// `Notifier.build()` and keep all existing synchronous `ref.watch(...)`
/// call sites working unchanged.
///
/// To make that possible the instance is loaded ONCE in `main()` and injected
/// here via a `ProviderScope` override. This provider therefore throws if it
/// is read without an override — a loud, early failure beats a silent
/// not-persisting bug.
///
/// In tests, override it with a mock instance:
/// ```dart
/// SharedPreferences.setMockInitialValues({});
/// final prefs = await SharedPreferences.getInstance();
/// final container = ProviderContainer(overrides: [
///   sharedPreferencesProvider.overrideWithValue(prefs),
/// ]);
/// ```
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in main() (or a test) with '
    'the instance returned by SharedPreferences.getInstance().',
  );
});
