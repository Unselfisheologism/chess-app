import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/analytics_service.dart';
import '../../services/streak_service.dart';
import '../../theme/brand.dart';
import '../../theme/spacing.dart';
import 'lesson/lesson_player_screen.dart';
import 'play/match_screen.dart';
import 'puzzle/daily_puzzle_screen.dart';
import 'stats/stats_screen.dart';
import '../widgets/mascot.dart';

/// Total lessons bundled. Update this when adding a new day_XX.json.
const int kTotalDays = 10;

/// Home screen. Shows the current day, the streak (with freeze
/// tokens), the at-risk banner if today's lesson is overdue, a day
/// picker for navigating between days, and the CTA cards to start
/// today's lesson / play / solve.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const int _streakOffset = 1; // days completed -> next day
  Future<StreakState>? _streakFuture;
  int _selectedDay = 1;

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
    final s = await next;
    if (!mounted) return;
    setState(() {
      // After a lesson, jump to the next un-completed day.
      _selectedDay = _nextDayFor(s.totalLessonsCompleted);
    });
  }

  /// True when the user has an active streak but hasn't completed
  /// today's lesson yet.
  static bool _isStreakAtRisk(StreakState s) {
    if (s.currentStreak == 0) return false;
    final last = s.lastLessonDate;
    if (last == null) return true;
    final now = DateTime.now();
    return !(last.year == now.year &&
        last.month == now.month &&
        last.day == now.day);
  }

  static int _nextDayFor(int lessonsCompleted) {
    final next = lessonsCompleted + _streakOffset;
    if (next > kTotalDays) return kTotalDays; // capped
    return next;
  }

  /// Resolves the current day-of-launch from the cached streak and
  /// pushes the Daily puzzle screen. The LLM uses the day index to
  /// pick a theme, so consecutive days get different puzzles.
  Future<void> _openDailyPuzzle() async {
    int day = 1;
    try {
      final streak = await (_streakFuture ?? StreakService.instance.read());
      day = streak.totalLessonsCompleted + 1;
    } catch (_) {
      // Default to day 1 if streak read fails.
      day = 1;
    }
    if (!mounted) return;
    unawaited(AnalyticsService.instance.track(
      'daily_puzzle_open_from_home',
      properties: {'day': day},
    ));
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DailyPuzzleScreen(day: day),
      ),
    );
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
                          const SizedBox(width: AppSpacing.xs),
                          IconButton(
                            tooltip: 'Stats',
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const StatsScreen(),
                              ),
                            ),
                            icon: const Icon(
                              Icons.insights,
                              color: BrandColors.deepInk,
                              size: 20,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 36,
                              minHeight: 36,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSpacing.m),
              const Center(
                child: Mascot(mood: MascotMood.idle, size: 100),
              ),
              const SizedBox(height: AppSpacing.s),
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
              FutureBuilder<StreakState>(
                future: _streakFuture,
                builder: (context, snap) {
                  final completed = snap.data?.totalLessonsCompleted ?? 0;
                  return _DayPicker(
                    totalDays: kTotalDays,
                    lessonsCompleted: completed,
                    selectedDay: _selectedDay,
                    onPick: (day) {
                      if (day == _selectedDay) return;
                      setState(() {
                        _selectedDay = day;
                      });
                    },
                  );
                },
              ),
              const SizedBox(height: AppSpacing.s),
              _LessonCard(
                day: _selectedDay,
                onStart: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => LessonPlayerScreen(day: _selectedDay),
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
                      onTap: _openDailyPuzzle,
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
    // Vertical: icon on top, big value in the middle, small
    // label below. Compact horizontal chip was confusing when
    // value=0 ("0" with no context looked broken); the vertical
    // layout reads as "fire icon / 0 / days" which is
    // unambiguous.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, color: BrandColors.gold, size: 18),
        const SizedBox(height: 1),
        Text(
          '$value',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: value > 0
                    ? BrandColors.deepInk
                    : BrandColors.lockedGrey,
                fontWeight: FontWeight.w800,
                height: 1.0,
              ),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: BrandColors.lockedGrey,
            fontWeight: FontWeight.w600,
            height: 1.0,
          ),
        ),
      ],
    );
  }
}

class _DayPicker extends StatelessWidget {
  final int totalDays;
  final int lessonsCompleted;
  final int selectedDay;
  final void Function(int day) onPick;

  const _DayPicker({
    required this.totalDays,
    required this.lessonsCompleted,
    required this.selectedDay,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: totalDays,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.xs),
        itemBuilder: (context, i) {
          final day = i + 1;
          final isDone = day <= lessonsCompleted;
          final isCurrent = day == selectedDay;
          return _DayChip(
            day: day,
            isDone: isDone,
            isCurrent: isCurrent,
            onTap: () => onPick(day),
          );
        },
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  final int day;
  final bool isDone;
  final bool isCurrent;
  final VoidCallback onTap;

  const _DayChip({
    required this.day,
    required this.isDone,
    required this.isCurrent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    if (isCurrent) {
      bg = BrandColors.gold;
      fg = BrandColors.deepInk;
    } else if (isDone) {
      bg = BrandColors.deepInk;
      fg = BrandColors.cream;
    } else {
      bg = Colors.white;
      fg = BrandColors.deepInk;
    }
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppSpacing.m),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.m),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.m,
            vertical: AppSpacing.s,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isDone)
                const Icon(Icons.check, size: 14, color: BrandColors.cream)
              else if (isCurrent)
                const Icon(Icons.play_arrow, size: 14, color: BrandColors.deepInk)
              else
                const Icon(Icons.lock_outline, size: 14, color: BrandColors.lockedGrey),
              const SizedBox(width: 4),
              Text(
                'Day $day',
                style: TextStyle(
                  color: isCurrent || isDone ? fg : BrandColors.lockedGrey,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
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
  final VoidCallback onStart;

  const _LessonCard({
    required this.day,
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
              const Text(
                'Tap to start',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: BrandColors.cream,
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
