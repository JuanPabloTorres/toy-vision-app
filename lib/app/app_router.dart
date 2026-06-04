import 'package:flutter/material.dart';

import '../ui/navigation/app_shell.dart';
import '../ui/screens/splash_screen.dart';

/// Centralized route names and route generation for Toy Vision.
///
/// Phase 6.4: the app opens on the [SplashScreen]; "Comenzar" replaces it
/// with the [AppShell] (bottom-nav: Inicio / Misión / Historial / Padres).
/// The mission camera is a tab inside the shell, not a top-level route.
class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String shell = '/shell';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case shell:
        return MaterialPageRoute<void>(
          builder: (_) => const AppShell(),
          settings: settings,
        );
      case splash:
      default:
        return MaterialPageRoute<void>(
          builder: (_) => const SplashScreen(),
          settings: settings,
        );
    }
  }
}
