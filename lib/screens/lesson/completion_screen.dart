import 'package:flutter/material.dart';

import '../../theme/brand.dart';
import '../../theme/spacing.dart';

/// Shown when a lesson is finished. Celebrates the score, links to
/// "back to home" and (in U5) "play today's match for a freeze token."
class CompletionScreen extends StatelessWidget {
  final int day;
  final int score;
  final int total;

  const CompletionScreen({
    super.key,
    required this.day,
    required this.score,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final percent = total == 0 ? 0 : ((score / total) * 100).round();
    return Scaffold(
      backgroundColor: BrandColors.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.emoji_events,
                size: 96,
                color: BrandColors.gold,
              ),
              const SizedBox(height: AppSpacing.l),
              Text(
                'Day $day complete!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displayLarge,
              ),
              const SizedBox(height: AppSpacing.m),
              Text(
                '$score / $total correct ($percent%)',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: AppSpacing.xxl),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: BrandColors.gold,
                  foregroundColor: BrandColors.deepInk,
                  padding: const EdgeInsets.all(AppSpacing.l),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.m),
                  ),
                ),
                child: Text(
                  'Back to home',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
