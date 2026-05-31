import 'package:flutter/material.dart';

import '../camera/screens/live_camera_screen.dart';
import '../ui/screens/scan_history_screen.dart';

/// Centralized route names and route generation for ToyVision.
class AppRoutes {
  AppRoutes._();

  static const String live = '/';
  static const String history = '/history';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case history:
        return MaterialPageRoute<void>(
          builder: (_) => const ScanHistoryScreen(),
          settings: settings,
        );
      case live:
      default:
        return MaterialPageRoute<void>(
          builder: (_) => const LiveCameraScreen(),
          settings: settings,
        );
    }
  }
}
