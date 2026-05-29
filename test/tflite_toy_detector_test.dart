import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:toyvision_realtime/business/toy_category_registry.dart';
import 'package:toyvision_realtime/detection/detectors/tflite/model_asset_loader.dart';
import 'package:toyvision_realtime/detection/detectors/tflite/tflite_model_output.dart';
import 'package:toyvision_realtime/detection/detectors/tflite/tflite_toy_detector.dart';
import 'package:toyvision_realtime/detection/models/detection_frame.dart';
import 'package:toyvision_realtime/detection/models/toy_model_config.dart';

class _MissingAssetLoader implements ModelAssetLoader {
  @override
  Future<Uint8List> load(String assetPath) async =>
      throw Exception('asset not found: $assetPath');
}

class _PresentAssetLoader implements ModelAssetLoader {
  @override
  Future<Uint8List> load(String assetPath) async => Uint8List(8);
}

class _FakeRuntime implements ToyModelRuntime {
  bool loaded = false;
  bool closed = false;

  @override
  Future<void> load(Uint8List modelBytes, ToyModelConfig config) async {
    loaded = true;
  }

  @override
  Future<TfliteModelOutput> infer(DetectionFrame frame) async {
    return const TfliteModelOutput(
      boxes: [
        [0.2, 0.1, 0.6, 0.5],
      ],
      scores: [0.9],
      classes: [0],
    );
  }

  @override
  void close() => closed = true;
}

void main() {
  final registry = ToyCategoryRegistry.standard();
  const config = ToyModelConfig(
    assetPath: 'assets/models/toy_detector.tflite',
    inputWidth: 320,
    inputHeight: 320,
    labels: ['toy_car'],
  );

  DetectionFrame frame() => DetectionFrame(
        cameraImage: null,
        frameIndex: 0,
        capturedAt: DateTime(2026, 5, 29),
      );

  test('throws ModelUnavailable when the model asset is missing', () {
    final detector = TfliteToyDetector(
      config: config,
      registry: registry,
      assetLoader: _MissingAssetLoader(),
    );
    expect(detector.initialize(), throwsA(isA<ModelUnavailableException>()));
  });

  test('throws ModelUnavailable when no inference runtime is wired', () {
    final detector = TfliteToyDetector(
      config: config,
      registry: registry,
      assetLoader: _PresentAssetLoader(),
      // runtime omitted -> not wired (Phase 2b foundation state)
    );
    expect(detector.initialize(), throwsA(isA<ModelUnavailableException>()));
  });

  test('throws ModelUnavailable when the config is invalid', () {
    const badConfig = ToyModelConfig(
      assetPath: 'assets/models/toy_detector.tflite',
      inputWidth: 320,
      inputHeight: 320,
      labels: ['spaceship'], // not in registry
    );
    final detector = TfliteToyDetector(
      config: badConfig,
      registry: registry,
      assetLoader: _PresentAssetLoader(),
      runtime: _FakeRuntime(),
    );
    expect(detector.initialize(), throwsA(isA<ModelUnavailableException>()));
  });

  test('with a wired runtime, detect returns adapter-normalized raw detections',
      () async {
    final runtime = _FakeRuntime();
    final detector = TfliteToyDetector(
      config: config,
      registry: registry,
      assetLoader: _PresentAssetLoader(),
      runtime: runtime,
    );

    await detector.initialize();
    expect(runtime.loaded, isTrue);

    final detections = await detector.detect(frame());
    expect(detections, hasLength(1));
    expect(detections.single.label, 'toy_car');
    expect(detections.single.box.x, closeTo(0.1, 1e-9));
    expect(detections.single.box.width, closeTo(0.4, 1e-9));

    detector.dispose();
    expect(runtime.closed, isTrue);
  });
}
