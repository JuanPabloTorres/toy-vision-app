import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/camera_status.dart';

/// Owns the real camera: available cameras, the [CameraController], permission
/// and lifecycle status, and the image stream.
///
/// This is the only place that talks to the `camera` plugin. It exposes status
/// and an initialized controller to the UI, and start/stop/dispose to the
/// orchestrator. It performs no detection, counting, or validation — it only
/// produces frames. Audio is disabled and no frame is ever persisted.
class CameraControllerService extends Notifier<CameraStatus> {
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  bool _streaming = false;

  /// Initialized controller for rendering the preview, or null if not ready.
  CameraController? get controller => _controller;

  bool get isStreaming => _streaming;

  @override
  CameraStatus build() {
    ref.onDispose(_teardown);
    Future.microtask(initialize);
    return CameraStatus.initial;
  }

  /// Request cameras, select the back camera, and initialize the controller.
  /// On most platforms the OS permission prompt is triggered here.
  Future<void> initialize() async {
    state = CameraStatus.initializing;
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        state = CameraStatus.error;
        return;
      }
      final back = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );
      final controller = CameraController(
        back,
        ResolutionPreset.medium,
        enableAudio: false, // privacy: never capture audio
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await controller.initialize();
      _controller = controller;
      state = CameraStatus.ready;
    } on CameraException catch (e) {
      state = _mapException(e);
    } catch (_) {
      state = CameraStatus.error;
    }
  }

  CameraStatus _mapException(CameraException e) {
    switch (e.code) {
      case 'CameraAccessDenied':
        return CameraStatus.permissionDenied;
      case 'CameraAccessDeniedWithoutPrompt':
      case 'CameraAccessRestricted':
        return CameraStatus.permissionPermanentlyDenied;
      default:
        return CameraStatus.error;
    }
  }

  /// Retry initialization (e.g. after the user is asked to grant permission).
  Future<void> requestPermission() => initialize();

  /// Begin delivering frames to [onFrame]. No-op if already streaming or the
  /// controller is not initialized.
  Future<void> startStream(void Function(CameraImage image) onFrame) async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || _streaming) return;
    await c.startImageStream(onFrame);
    _streaming = true;
    state = CameraStatus.streaming;
  }

  /// Stop the image stream (user pause or app backgrounding). The controller
  /// stays initialized so the preview can keep showing the last frame.
  Future<void> pauseStream() async {
    final c = _controller;
    if (c == null || !_streaming) return;
    await c.stopImageStream();
    _streaming = false;
    state = CameraStatus.paused;
  }

  /// Resume streaming after a pause.
  Future<void> resumeStream(void Function(CameraImage image) onFrame) async {
    if (_controller == null) return;
    await startStream(onFrame);
  }

  Future<void> _teardown() async {
    final c = _controller;
    _controller = null;
    _streaming = false;
    if (c == null) return;
    try {
      if (c.value.isStreamingImages) await c.stopImageStream();
    } catch (_) {
      // Ignore: controller may already be torn down.
    }
    await c.dispose();
  }
}

final cameraStatusProvider =
    NotifierProvider<CameraControllerService, CameraStatus>(
  CameraControllerService.new,
);
