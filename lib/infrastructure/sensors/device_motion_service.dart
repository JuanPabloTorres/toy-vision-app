import 'package:flutter/services.dart';

import '../../domain/scene/spatial_observation.dart';

abstract interface class DeviceMotionService {
  Future<void> start();
  Future<SpatialObservation> readLatest();
  Future<void> stop();
}

class AndroidDeviceMotionService implements DeviceMotionService {
  const AndroidDeviceMotionService();

  static const MethodChannel _channel = MethodChannel(
    'toyvision/device_motion',
  );

  @override
  Future<void> start() => _invokeVoid('start');

  @override
  Future<void> stop() => _invokeVoid('stop');

  @override
  Future<SpatialObservation> readLatest() async {
    try {
      final value = await _channel.invokeMapMethod<String, dynamic>('read');
      if (value == null) return const SpatialObservation.unavailable();
      return SpatialObservation(
        timestamp: DateTime.fromMillisecondsSinceEpoch(
          (value['timestampMs'] as num?)?.toInt() ??
              DateTime.now().millisecondsSinceEpoch,
        ),
        motionAvailable: value['motionAvailable'] as bool? ?? false,
        orientationAvailable: value['orientationAvailable'] as bool? ?? false,
        gyroscopeRadPerSecond:
            (value['gyroscopeRadPerSecond'] as num?)?.toDouble() ?? 0,
        linearAccelerationMetersPerSecond2:
            (value['linearAccelerationMetersPerSecond2'] as num?)?.toDouble() ??
                0,
        yawDegrees: (value['yawDegrees'] as num?)?.toDouble(),
        pitchDegrees: (value['pitchDegrees'] as num?)?.toDouble(),
        rollDegrees: (value['rollDegrees'] as num?)?.toDouble(),
      );
    } on MissingPluginException {
      return const SpatialObservation.unavailable();
    } on PlatformException {
      return const SpatialObservation.unavailable();
    }
  }

  Future<void> _invokeVoid(String method) async {
    try {
      await _channel.invokeMethod<void>(method);
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }
}
