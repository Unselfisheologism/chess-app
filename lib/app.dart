import 'package:flutter/material.dart';

import 'screens/home/home_screen.dart';
import 'theme/app_theme.dart';

class ChessDoItApp extends StatelessWidget {
  const ChessDoItApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chess Do It',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const HomeScreen(),
    );
  }
}
