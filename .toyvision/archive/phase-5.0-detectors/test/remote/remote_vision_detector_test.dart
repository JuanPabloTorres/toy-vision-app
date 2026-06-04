import 'package:flutter_test/flutter_test.dart';
import 'package:toyvision_realtime/detection/detectors/remote/remote_vision_client.dart';
import 'package:toyvision_realtime/detection/detectors/remote/remote_vision_config.dart';
import 'package:toyvision_realtime/detection/detectors/remote/remote_vision_detector.dart';
import 'package:toyvision_realtime/detection/detectors/remote/remote_vision_schemas.dart';
import 'package:toyvision_realtime/detection/models/detection_frame.dart';

/// In-memory client used in place of the real HTTP client so tests run
/// without a server. Lets us exercise the detector's parsing + error paths.
class _FakeRemoteVisionClient implements RemoteVisionClient {
  _FakeRemoteVisionClient({
    this.healthOk = true,
    this.response,
    this.detectThrows,
  });

  bool healthOk;
  RemoteDetectResponse? response;
  RemoteVisionException? detectThrows;

  int healthCalls = 0;
  int detectCalls = 0;
  RemoteDetectRequest? lastRequest;
  bool closed = false;

  @override
  Future<bool> health() async {
    healthCalls++;
    return healthOk;
  }

  @override
  Future<RemoteDetectResponse> detect(RemoteDetectRequest request) async {
    detectCalls++;
    lastRequest = request;
    final e = detectThrows;
    if (e != null) throw e;
    return response ??
        const RemoteDetectResponse(
          detections: [],
          model: 'fake',
          latencyMs: 0,
        );
  }

  @override
  void close() => closed = true;
}

DetectionFrame _frame({int index = 0}) => DetectionFrame(
      cameraImage: null,
      frameIndex: index,
      capturedAt: DateTime(2026, 5, 31),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('initialize succeeds when /health returns ok', () async {
    final fake = _FakeRemoteVisionClient(healthOk: true);
    final detector = RemoteVisionDetector(client: fake);

    await detector.initialize();

    expect(fake.healthCalls, 1);
  });

  test('initialize throws RemoteVisionException when server is unreachable',
      () async {
    final fake = _FakeRemoteVisionClient(healthOk: false);
    final detector = RemoteVisionDetector(client: fake);

    expect(
      () => detector.initialize(),
      throwsA(isA<RemoteVisionException>()),
    );
  });

  test('detect maps server JSON into RawDetections with mapped_label', () async {
    final fake = _FakeRemoteVisionClient(
      response: const RemoteDetectResponse(
        detections: [
          RemoteDetection(
            label: 'toy car',
            mappedLabel: 'toy_car',
            confidence: 0.73,
            box: RemoteBox(x: 0.1, y: 0.2, width: 0.3, height: 0.18),
          ),
          RemoteDetection(
            label: 'stuffed animal',
            mappedLabel: 'stuffed_animal',
            confidence: 0.65,
            box: RemoteBox(x: 0.5, y: 0.4, width: 0.2, height: 0.22),
          ),
        ],
        model: 'placeholder',
        latencyMs: 12,
      ),
    );
    final detector = RemoteVisionDetector(client: fake);

    final raw = await detector.detect(_frame(index: 7));

    expect(raw, hasLength(2));
    expect(raw[0].label, 'toy_car');
    expect(raw[0].confidence, closeTo(0.73, 1e-9));
    expect(raw[0].box.x, closeTo(0.1, 1e-9));
    expect(raw[1].label, 'stuffed_animal');
    expect(fake.lastRequest!.frameIndex, 7);
  });

  test('detect drops the frame (empty list) when the client throws', () async {
    final fake = _FakeRemoteVisionClient(
      detectThrows: const RemoteVisionException('boom'),
    );
    final detector = RemoteVisionDetector(client: fake);

    final raw = await detector.detect(_frame());

    expect(raw, isEmpty);
  });

  test('dispose closes the underlying HTTP client exactly once', () {
    final fake = _FakeRemoteVisionClient();
    final detector = RemoteVisionDetector(client: fake);

    detector.dispose();
    detector.dispose();

    expect(fake.closed, isTrue);
  });

  test(
      'request sends frame metadata and (Phase 5.0.1) leaves imageJpegBase64 '
      'null when cameraImage is null', () async {
    final fake = _FakeRemoteVisionClient();
    final detector = RemoteVisionDetector(client: fake);

    // cameraImage is null in this test; the detector can't encode
    // nothing, so it should send a request with the metadata but no
    // bytes. The server's YOLO-World detector will return an empty
    // list in that case; this is fine for headless tests.
    await detector.detect(_frame(index: 3));

    expect(fake.lastRequest!.frameIndex, 3);
    expect(fake.lastRequest!.width, greaterThan(0));
    expect(fake.lastRequest!.height, greaterThan(0));
    expect(fake.lastRequest!.imageJpegBase64, isNull);
  });

  test('config defaults expose a usable baseUrl and timeouts', () {
    const config = RemoteVisionConfig.defaults;
    expect(config.baseUrl, startsWith('http://'));
    expect(config.requestTimeout.inSeconds, greaterThan(0));
  });
}
