import 'package:flutter/material.dart';

import 'theme/app_theme.dart';

class ChessDoItApp extends StatelessWidget {
  const ChessDoItApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chess Do It',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const _Bootstrap(),
    );
  }
}

class _Bootstrap extends StatelessWidget {
  const _Bootstrap();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'chess-do-it',
              style: Theme.of(context).textTheme.displayLarge,
            ),
            const SizedBox(height: 12),
            Text(
              'Learn chess. Unlock your phone.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
