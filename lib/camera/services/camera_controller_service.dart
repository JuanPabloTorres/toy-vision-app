import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/camera_status.dart';

/// Owns camera permission and lifecycle status.
///
/// Phase 1 is mock-first: the real `camera` plugin is not wired yet, so this
/// service models the lifecycle and resolves to [CameraStatus.ready] (the live
/// screen then shows a preview placeholder). Phase 2 replaces the body of
/// [initialize] / [requestPermission] with real plugin calls and a
/// CameraController, without changing this contract.
class CameraControllerService extends Notifier<CameraStatus> {
  @override
  CameraStatus build() {
    Future.microtask(initialize);
    return CameraStatus.initializing;
  }

  Future<void> initialize() async {
    // Phase 2: request permission + start the real camera here.
    state = CameraStatus.ready;
  }

  Future<void> requestPermission() async {
    state = CameraStatus.ready;
  }
}

final cameraStatusProvider =
    NotifierProvider<CameraControllerService, CameraStatus>(
  CameraControllerService.new,
);
