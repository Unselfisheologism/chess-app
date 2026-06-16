import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/analytics_service.dart';
import '../../services/streak_service.dart';
import '../../theme/brand.dart';
import '../../theme/spacing.dart';

/// Build SHA injected by the CI workflow (see
/// scripts/inject-build-sha.sh). Top-level constant so both
/// [_StatsScreenState] and the [_DebugZone] widget below can
/// read it. Empty if the build wasn't made via the CI workflow
/// (e.g. local `flutter run`).
const String _kBuildSha = String.fromEnvironment('BUILD_SHA');

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsData {
  final StreakState streak;
  final List<AnalyticsEvent> events;
  _StatsData({required this.streak, required this.events});
}

class _StatsScreenState extends State<StatsScreen> {
  late Future<_StatsData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
    unawaited(AnalyticsService.instance.track('stats_view'));
  }

  Future<_StatsData> _load() async {
    final streak = await StreakService.instance.read();
    final events = await AnalyticsService.instance.read();
    return _StatsData(streak: streak, events: events);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  Future<void> _resetStreak() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset streak?'),
        content: const Text(
          'This wipes your current streak, longest streak, freeze tokens, '
          'and total lessons completed. The analytics log is kept. '
          'Cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Reset',
              style: TextStyle(color: BrandColors.error),
            ),
          ),
        ],
      ),
    );
    if (ok == true) {
      await StreakService.instance.reset();
      await _refresh();
    }
  }

  Future<void> _clearAnalytics() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear analytics log?'),
        content: const Text(
          'This deletes all tracked events. Cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Clear',
              style: TextStyle(color: BrandColors.error),
            ),
          ),
        ],
      ),
    );
    if (ok == true) {
      await AnalyticsService.instance.clear();
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrandColors.cream,
      appBar: AppBar(
        title: Text(
          'Stats',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        backgroundColor: BrandColors.cream,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: BrandColors.deepInk),
            onPressed: _refresh,
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<_StatsData>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(
                child: Text(
                  'Failed to load stats: ${snap.error}',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              );
            }
            final data = snap.data!;
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.l),
              children: [
                _StreakGrid(streak: data.streak),
                const SizedBox(height: AppSpacing.l),
                _DebugZone(
                  onResetStreak: _resetStreak,
                  onClearLog: _clearAnalytics,
                ),
                const SizedBox(height: AppSpacing.l),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent events',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    Text(
                      '${data.events.length}',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: BrandColors.lockedGrey,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s),
                _EventsList(events: data.events),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StreakGrid extends StatelessWidget {
  final StreakState streak;
  const _StreakGrid({required this.streak});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.s,
      crossAxisSpacing: AppSpacing.s,
      childAspectRatio: 1.7,
      children: [
        _MetricTile(
          icon: Icons.local_fire_department,
          value: streak.currentStreak,
          label: streak.currentStreak == 1 ? 'day streak' : 'days streak',
          color: BrandColors.gold,
        ),
        _MetricTile(
          icon: Icons.ac_unit,
          value: streak.freezeTokens,
          label: streak.freezeTokens == 1 ? 'freeze' : 'freezes',
          color: BrandColors.deepInk,
        ),
        _MetricTile(
          icon: Icons.emoji_events,
          value: streak.longestStreak,
          label: 'best streak',
          color: BrandColors.gold,
        ),
        _MetricTile(
          icon: Icons.school,
          value: streak.totalLessonsCompleted,
          label: streak.totalLessonsCompleted == 1
              ? 'lesson done'
              : 'lessons done',
          color: BrandColors.deepInk,
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final int value;
  final String label;
  final Color color;
  const _MetricTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.m),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: AppSpacing.xs),
              Text(
                '$value',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: BrandColors.lockedGrey,
            ),
          ),
        ],
      ),
    );
  }
}

class _DebugZone extends StatelessWidget {
  final VoidCallback onResetStreak;
  final VoidCallback onClearLog;
  const _DebugZone({
    required this.onResetStreak,
    required this.onClearLog,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: BrandColors.error.withOpacity(0.05),
        border: Border.all(color: BrandColors.error.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(AppSpacing.m),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.science_outlined,
                size: 16,
                color: BrandColors.error,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Debug controls',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: BrandColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Affects your real data. Use to test the streak flow without '
            'waiting 24h between lessons.',
            style: TextStyle(fontSize: 11, color: BrandColors.lockedGrey),
          ),
          const SizedBox(height: AppSpacing.m),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onResetStreak,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: BrandColors.error,
                    side: const BorderSide(color: BrandColors.error),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: const Text(
                    'Reset streak',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                child: OutlinedButton(
                  onPressed: onClearLog,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: BrandColors.error,
                    side: const BorderSide(color: BrandColors.error),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: const Text(
                    'Clear log',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.m),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          const SizedBox(height: AppSpacing.m),
          // Build diagnostic. The build SHA is injected by the
          // GitHub Actions workflow (see scripts/inject-build-sha.sh)
          // and is the single most reliable way to tell a fresh
          // APK from a stale install — the GitHub Actions run
          // number alone doesn't help if you have two APKs from
          // the same run.
          Row(
            children: [
              const Icon(
                Icons.bug_report_outlined,
                size: 16,
                color: BrandColors.deepInk,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Diagnostics',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: BrandColors.deepInk,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s),
          // Read the build SHA from the dart-define. Empty if
          // the build wasn't made via the CI workflow (e.g. local
          // `flutter run`).
          _DiagnosticRow(
            label: 'Build',
            value: _kBuildSha.isEmpty
                ? '(not injected — local build?)'
                : _kBuildSha,
          ),
        ],
      ),
    );
  }
}

class _DiagnosticRow extends StatelessWidget {
  final String label;
  final String value;
  const _DiagnosticRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              '$label',
              style: const TextStyle(
                fontSize: 11,
                color: BrandColors.lockedGrey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 11,
                color: BrandColors.deepInk,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventsList extends StatelessWidget {
  final List<AnalyticsEvent> events;
  const _EventsList({required this.events});

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.l),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppSpacing.m),
        ),
        child: Text(
          "No events yet. Use the app and they'll show up here.",
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      );
    }
    final reversed = events.reversed.toList();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.m),
      ),
      child: Column(
        children: [
          for (var i = 0; i < reversed.length; i++)
            _EventRow(
              event: reversed[i],
              isLast: i == reversed.length - 1,
            ),
        ],
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  final AnalyticsEvent event;
  final bool isLast;
  const _EventRow({required this.event, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: AppSpacing.s,
      ),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: Color(0xFFEEEEEE)),
              ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                event.type,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: BrandColors.deepInk,
                  fontFamily: 'monospace',
                ),
              ),
              Text(
                _formatTime(event.timestamp),
                style: const TextStyle(
                  fontSize: 11,
                  color: BrandColors.lockedGrey,
                ),
              ),
            ],
          ),
          if (event.properties.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                _formatProps(event.properties),
                style: const TextStyle(
                  fontSize: 11,
                  color: BrandColors.lockedGrey,
                  fontFamily: 'monospace',
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _formatTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${t.year}-${_pad(t.month)}-${_pad(t.day)}';
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');

  static String _formatProps(Map<String, Object?> p) {
    return p.entries.map((e) => '${e.key}=${e.value}').join(' · ');
  }
}
