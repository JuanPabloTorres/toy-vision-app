import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toyvision_realtime/camera/live_detection_controller.dart';
import 'package:toyvision_realtime/detection/detectors/fallback_toy_detector.dart';
import 'package:toyvision_realtime/detection/detectors/mock_toy_detector.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('default detector mode is mock', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(toyDetectorModeProvider), ToyDetectorMode.mock);
    expect(container.read(toyDetectorProvider), isA<MockToyDetector>());
  });

  test('tfliteWithFallback falls back to mock when the model is unavailable',
      () async {
    final container = ProviderContainer(
      overrides: [
        toyDetectorModeProvider
            .overrideWithValue(ToyDetectorMode.tfliteWithFallback),
      ],
    );
    addTearDown(container.dispose);

    final detector =
        container.read(toyDetectorProvider) as FallbackToyDetector;
    await detector.initialize();

    // No model asset is bundled, so the TFLite primary is unavailable and the
    // detector falls back to the mock — the app keeps working.
    expect(detector.usingFallback, isTrue);
  });
}
