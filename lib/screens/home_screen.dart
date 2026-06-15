import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/analytics_service.dart';
import '../../services/streak_service.dart';
import '../../theme/brand.dart';
import '../../theme/spacing.dart';
import 'lesson/lesson_player_screen.dart';
import 'play/match_screen.dart';
import 'puzzle/daily_puzzle_screen.dart';
import '../widgets/mascot.dart';

/// Home screen. Shows the current day, the streak (with freeze
/// tokens), the at-risk banner if today's lesson is overdue, and
/// the CTA cards to start today's lesson / play / solve.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<StreakState>? _streakFuture;

  @override
  void initState() {
    super.initState();
    _streakFuture = StreakService.instance.read();
    unawaited(AnalyticsService.instance.track('home_view'));
  }

  Future<void> _refreshStreak() async {
    final next = StreakService.instance.read();
    if (!mounted) return;
    setState(() {
      _streakFuture = next;
    });
    await next;
  }

  /// True when the user has an active streak but hasn't completed
  /// today's lesson yet. The at-risk banner shows this.
  static bool _isStreakAtRisk(StreakState s) {
    if (s.currentStreak == 0) return false;
    final last = s.lastLessonDate;
    if (last == null) return true;
    final now = DateTime.now();
    return !(last.year == now.year &&
        last.month == now.month &&
        last.day == now.day);
  }

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
              FutureBuilder<StreakState>(
                future: _streakFuture,
                builder: (context, snap) {
                  final state = snap.data ?? StreakState.empty;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'chess-do-it',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      Row(
                        children: [
                          _StreakChip(
                            icon: Icons.local_fire_department,
                            value: state.currentStreak,
                            label: state.currentStreak == 1 ? 'day' : 'days',
                          ),
                          const SizedBox(width: AppSpacing.s),
                          _StreakChip(
                            icon: Icons.ac_unit,
                            value: state.freezeTokens,
                            label: state.freezeTokens == 1 ? 'freeze' : 'freezes',
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSpacing.m),
              const Center(
                child: Mascot(mood: MascotMood.idle, size: 120),
              ),
              const SizedBox(height: AppSpacing.m),
              FutureBuilder<StreakState>(
                future: _streakFuture,
                builder: (context, snap) {
                  final state = snap.data ?? StreakState.empty;
                  if (!_isStreakAtRisk(state)) {
                    return const SizedBox.shrink();
                  }
                  return Container(
                    padding: const EdgeInsets.all(AppSpacing.m),
                    decoration: BoxDecoration(
                      color: BrandColors.error.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(AppSpacing.m),
                      border: Border.all(
                        color: BrandColors.error.withOpacity(0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: BrandColors.error,
                        ),
                        const SizedBox(width: AppSpacing.s),
                        Expanded(
                          child: Text(
                            "Streak at risk — finish today's lesson to keep it",
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: BrandColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.m),
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
                onStart: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const LessonPlayerScreen(day: 1),
                    ),
                  );
                  await _refreshStreak();
                },
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: _SecondaryCard(
                      icon: Icons.extension,
                      title: 'Daily puzzle',
                      subtitle: 'Find the move',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const DailyPuzzleScreen(day: 1),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s),
                  Expanded(
                    child: _SecondaryCard(
                      icon: Icons.smart_toy,
                      title: 'Play chessito AI',
                      subtitle: 'Needs internet',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const MatchScreen(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s),
              FutureBuilder<StreakState>(
                future: _streakFuture,
                builder: (context, snap) {
                  final state = snap.data ?? StreakState.empty;
                  if (state.longestStreak <= 1) {
                    return Text(
                      'Complete a lesson to keep your streak alive.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    );
                  }
                  return Text(
                    'Best streak: ${state.longestStreak} days · '
                    '${state.totalLessonsCompleted} lessons completed',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: BrandColors.lockedGrey,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StreakChip extends StatelessWidget {
  final IconData icon;
  final int value;
  final String label;

  const _StreakChip({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: BrandColors.gold, size: 20),
        const SizedBox(width: AppSpacing.xs),
        Text(
          '$value',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: BrandColors.deepInk,
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
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
                '~$minutes minutes',
                style: TextStyle(
                  fontSize: 14,
                  color: BrandColors.cream.withOpacity(0.7),
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

class _SecondaryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SecondaryCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppSpacing.m),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.m),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.m),
          child: Row(
            children: [
              Icon(icon, color: BrandColors.deepInk, size: 24),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: BrandColors.deepInk,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
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
