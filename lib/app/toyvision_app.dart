import 'package:flutter/material.dart';

import 'app_router.dart';
import 'app_theme.dart';

class ToyVisionApp extends StatelessWidget {
  const ToyVisionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Toy Vision',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      initialRoute: AppRoutes.splash,
      onGenerateRoute: AppRoutes.onGenerateRoute,
    );
  }
}
