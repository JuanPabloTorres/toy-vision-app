import 'package:flutter_test/flutter_test.dart';
import 'package:toyvision_realtime/infrastructure/tflite/yolo_model_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('required bundled detector resolves offline', () async {
    final config = await YoloModelConfig.resolve();
    expect(config.modelPath, YoloModelConfig.customModelAsset);
    expect(config.useGpu, isFalse);
    expect(config.confidenceThreshold, 0.25);
  });
}
