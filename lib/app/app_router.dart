import 'package:flutter/material.dart';

import '../presentation/cleanup/cleanup_screen.dart';
import '../presentation/about/about_screen.dart';
import '../presentation/home/home_screen.dart';
import '../presentation/launch/camera_onboarding_screen.dart';
import '../presentation/launch/splash_screen.dart';
import '../presentation/progress/progress_screen.dart';
import '../presentation/settings/settings_screen.dart';

/// Centralized route names and route generation for Toy Vision.
///
class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String home = '/home';
  static const String cleanup = '/cleanup';
  static const String progress = '/progress';
  static const String settings = '/settings';
  static const String about = '/about';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case cleanup:
        return MaterialPageRoute<void>(
          builder: (_) => const CameraGameScreen(),
          settings: settings,
        );
      case AppRoutes.settings:
        return MaterialPageRoute<void>(
          builder: (_) => const SettingsScreen(),
          settings: settings,
        );
      case AppRoutes.progress:
        return MaterialPageRoute<void>(
          builder: (_) => const ProgressScreen(),
          settings: settings,
        );
      case AppRoutes.about:
        return MaterialPageRoute<void>(
          builder: (_) => const AboutScreen(),
          settings: settings,
        );
      case AppRoutes.onboarding:
        return MaterialPageRoute<void>(
          builder: (_) => const CameraOnboardingScreen(),
          settings: settings,
        );
      case home:
        return MaterialPageRoute<void>(
          builder: (_) => const HomeScreen(),
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
