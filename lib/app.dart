import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

class ChessDoItApp extends StatelessWidget {
  const ChessDoItApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chess Do It',
      // Force light theme: every screen hardcodes
      // BrandColors.cream as the background, so a dark theme
      // would render theme-defaulted white text on a cream
      // background — invisible. The app's brand is built for
      // cream; dark mode support is a v1.1 redesign.
      theme: AppTheme.light(),
      themeMode: ThemeMode.light,
      home: const HomeScreen(),
    );
  }
}
