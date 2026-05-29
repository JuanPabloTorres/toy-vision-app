import 'package:flutter/material.dart';

import 'app_router.dart';
import 'app_theme.dart';

class ToyVisionApp extends StatelessWidget {
  const ToyVisionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ToyVision Real-Time',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      initialRoute: AppRoutes.live,
      onGenerateRoute: AppRoutes.onGenerateRoute,
    );
  }
}
