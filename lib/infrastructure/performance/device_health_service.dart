import 'package:flutter/services.dart';

import '../../core/performance/adaptive_inference_scheduler.dart';

abstract interface class DeviceHealthService {
  Future<DeviceHealth> read();
}

class AndroidDeviceHealthService implements DeviceHealthService {
  const AndroidDeviceHealthService();

  static const MethodChannel _channel = MethodChannel(
    'toyvision/device_health',
  );

  @override
  Future<DeviceHealth> read() async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>('read');
      if (result == null) return const DeviceHealth();
      return DeviceHealth(
        thermalState: _thermalState((result['thermalStatus'] as num?)?.toInt()),
        batteryLevel:
            ((result['batteryPercent'] as num?)?.toDouble() ?? 100) / 100,
        isCharging: result['isCharging'] as bool? ?? false,
      );
    } on MissingPluginException {
      return const DeviceHealth();
    } on PlatformException {
      return const DeviceHealth();
    }
  }

  ThermalState _thermalState(int? status) {
    if (status == null) return ThermalState.nominal;
    if (status >= 5) return ThermalState.critical;
    if (status >= 3) return ThermalState.serious;
    if (status >= 1) return ThermalState.fair;
    return ThermalState.nominal;
  }
}
