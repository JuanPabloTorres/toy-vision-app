import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toyvision_realtime/camera/live_detection_controller.dart';
import 'package:toyvision_realtime/detection/detectors/fallback_toy_detector.dart';
import 'package:toyvision_realtime/detection/detectors/mock_toy_detector.dart';

class _MockModeController extends ToyDetectorModeController {
  @override
  ToyDetectorMode build() => ToyDetectorMode.mock;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Phase 5.0: default detector mode is mlkitWithFallback', () {
    // Product reset: Object Assist is the default at app start. Mock is now
    // only the automatic fallback inside FallbackToyDetector when ML Kit's
    // primary fails to initialize.
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(
      container.read(toyDetectorModeProvider),
      ToyDetectorMode.mlkitWithFallback,
    );
    final detector =
        container.read(toyDetectorProvider) as FallbackToyDetector;
    expect(detector.fallback, isA<MockToyDetector>());
  });

  test('toggle API cycles mock → mlkit → remote → mock', () {
    // Phase 5.0 restored the chip toggle and added a third mode for the
    // local Python vision server. Cycle order is documented on
    // ToyDetectorModeController.toggle.
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(
      container.read(toyDetectorModeProvider),
      ToyDetectorMode.mlkitWithFallback,
    );
    container.read(toyDetectorModeProvider.notifier).toggle();
    expect(
      container.read(toyDetectorModeProvider),
      ToyDetectorMode.remoteVisionServer,
    );
    container.read(toyDetectorModeProvider.notifier).toggle();
    expect(container.read(toyDetectorModeProvider), ToyDetectorMode.mock);
    container.read(toyDetectorModeProvider.notifier).toggle();
    expect(
      container.read(toyDetectorModeProvider),
      ToyDetectorMode.mlkitWithFallback,
    );
  });

  test('mock mode (overridden) still resolves to MockToyDetector', () {
    final container = ProviderContainer(
      overrides: [
        toyDetectorModeProvider.overrideWith(_MockModeController.new),
      ],
    );
    addTearDown(container.dispose);
    expect(container.read(toyDetectorProvider), isA<MockToyDetector>());
  });
}
