import 'package:flutter/material.dart';

import '../camera/screens/live_camera_screen.dart';

/// Centralized route names and route generation for ToyVision.
///
/// Phase 1 has a single destination: the live camera screen. Routes are
/// centralized here so new screens (history, saved summaries) plug in without
/// touching the app shell.
class AppRoutes {
  AppRoutes._();

  static const String live = '/';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case live:
      default:
        return MaterialPageRoute<void>(
          builder: (_) => const LiveCameraScreen(),
          settings: settings,
        );
    }
  }
}
