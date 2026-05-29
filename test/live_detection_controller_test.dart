import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toyvision_realtime/camera/live_detection_controller.dart';
import 'package:toyvision_realtime/camera/models/camera_status.dart';
import 'package:toyvision_realtime/camera/services/camera_controller_service.dart';
import 'package:toyvision_realtime/camera/services/frame_processing_service.dart';

/// Camera service stand-in that never touches the plugin/hardware.
class FakeCameraControllerService extends CameraControllerService {
  @override
  CameraStatus build() => CameraStatus.ready;

  @override
  Future<void> startStream(void Function(CameraImage image) onFrame) async {}

  @override
  Future<void> pauseStream() async {}

  @override
  Future<void> resumeStream(void Function(CameraImage image) onFrame) async {}

  @override
  Future<void> requestPermission() async {}
}

void main() {
  late int clock;

  ProviderContainer makeContainer() {
    clock = 0;
    final container = ProviderContainer(
      overrides: [
        cameraStatusProvider.overrideWith(FakeCameraControllerService.new),
        frameProcessingServiceProvider.overrideWith(
          (ref) => FrameProcessingService(
            detector: ref.watch(toyDetectorProvider),
            config: ref.watch(realtimeConfigProvider),
            clock: () => clock,
          ),
        ),
      ],
    );
    return container;
  }

  Future<LiveDetectionController> bootController(
    ProviderContainer container,
  ) async {
    final controller =
        container.read(liveDetectionControllerProvider.notifier);
    // Let _init (detector.initialize) complete.
    await Future<void>.delayed(const Duration(milliseconds: 1));
    return controller;
  }

  Future<void> feed(LiveDetectionController c, int frames) async {
    for (var i = 0; i < frames; i++) {
      clock += 1000; // well past the throttle interval
      await c.processIncomingFrame(null);
    }
  }

  test('mock detections drive counting through the controller', () async {
    final container = makeContainer();
    addTearDown(container.dispose);
    final controller = await bootController(container);

    await feed(controller, 4); // >= minimumStableFrames
    final total =
        container.read(liveDetectionControllerProvider).totalCount;
    expect(total, greaterThan(0));
  });

  test('pause prevents detection updates', () async {
    final container = makeContainer();
    addTearDown(container.dispose);
    final controller = await bootController(container);

    await feed(controller, 4);
    final counted =
        container.read(liveDetectionControllerProvider).totalCount;

    controller.pause();
    expect(container.read(liveDetectionControllerProvider).isPaused, isTrue);

    await feed(controller, 5); // should be ignored while paused
    expect(
      container.read(liveDetectionControllerProvider).totalCount,
      counted,
    );
  });

  test('resume continues detection updates', () async {
    final container = makeContainer();
    addTearDown(container.dispose);
    final controller = await bootController(container);

    controller.pause();
    await feed(controller, 3);
    controller.resume();
    expect(container.read(liveDetectionControllerProvider).isPaused, isFalse);

    await feed(controller, 4);
    expect(
      container.read(liveDetectionControllerProvider).totalCount,
      greaterThan(0),
    );
  });

  test('reset clears live count and visible toys', () async {
    final container = makeContainer();
    addTearDown(container.dispose);
    final controller = await bootController(container);

    await feed(controller, 4);
    expect(
      container.read(liveDetectionControllerProvider).totalCount,
      greaterThan(0),
    );

    controller.reset();
    final state = container.read(liveDetectionControllerProvider);
    expect(state.totalCount, 0);
    expect(state.summary.perCategory, isEmpty);
    expect(state.visibleToys, isEmpty);
  });
}
