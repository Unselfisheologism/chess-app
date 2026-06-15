import 'package:flutter/material.dart';

import '../../theme/brand.dart';
import '../../theme/spacing.dart';
import '../lesson/lesson_player_screen.dart';

/// Home screen. Shows the current day, the streak (hardcoded to 0
/// until U5's StreakService is wired in), and a CTA card to start
/// today's lesson. Daily puzzle and match are placeholders until
/// U6/U8.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrandColors.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'chess-do-it',
                    style: Theme.of(context).textTheme.h2,
                  ),
                  Row(
                    children: [
                      const Icon(
                        Icons.local_fire_department,
                        color: BrandColors.gold,
                        size: 24,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        '0',
                        style: Theme.of(context).textTheme.h2?.copyWith(
                              color: BrandColors.gold,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),
              Text(
                "Today's lesson",
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: BrandColors.lockedGrey,
                    ),
              ),
              const SizedBox(height: AppSpacing.s),
              _LessonCard(
                day: 1,
                title: 'Knight Moves',
                minutes: 8,
                onStart: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const LessonPlayerScreen(day: 1),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.l),
              _DisabledCard(
                icon: Icons.extension,
                title: 'Daily puzzle',
                subtitle: 'Coming in U8',
              ),
              const SizedBox(height: AppSpacing.m),
              _DisabledCard(
                icon: Icons.sports_esports,
                title: 'Play Stockfish',
                subtitle: 'Coming in U7',
              ),
              const Spacer(),
              Text(
                'Complete a lesson to keep your streak alive.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.caption,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LessonCard extends StatelessWidget {
  final int day;
  final String title;
  final int minutes;
  final VoidCallback onStart;

  const _LessonCard({
    required this.day,
    required this.title,
    required this.minutes,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: BrandColors.deepInk,
      borderRadius: BorderRadius.circular(AppSpacing.l),
      child: InkWell(
        onTap: onStart,
        borderRadius: BorderRadius.circular(AppSpacing.l),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'DAY $day',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: BrandColors.gold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: BrandColors.cream,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: BrandColors.cream,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '~$min minutes',
                style: TextStyle(
                  fontSize: 14,
                  color: BrandColors.cream.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: AppSpacing.l),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.l,
                  vertical: AppSpacing.s,
                ),
                decoration: BoxDecoration(
                  color: BrandColors.gold,
                  borderRadius: BorderRadius.circular(AppSpacing.s),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.play_arrow, color: BrandColors.deepInk, size: 20),
                    SizedBox(width: AppSpacing.xs),
                    Text(
                      'Start',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: BrandColors.deepInk,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DisabledCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _DisabledCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.5,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.l),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppSpacing.m),
          border: Border.all(color: BrandColors.lockedGrey, width: 1),
        ),
        child: Row(
          children: [
            Icon(icon, color: BrandColors.lockedGrey, size: 24),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: BrandColors.lockedGrey,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: BrandColors.lockedGrey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
