import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/lesson.dart';
import '../../services/analytics_service.dart';
import '../../services/bytez_service.dart';
import '../../services/streak_service.dart';
import '../../theme/brand.dart';
import '../../theme/spacing.dart';
import '../../widgets/mascot.dart';
import 'lesson_player_screen.dart';

/// "New lesson" page. Auto-generates a fresh lesson via the Bytez
/// LLM (day 11+, beyond the bundled curriculum), then pushes the
/// generated lesson into [LessonPlayerScreen.forLesson].
///
/// The user never types to the LLM — the page is content-first, not
/// a chat interface. The mascot waits, the LLM generates, the
/// lesson plays.
///
/// Loading flow:
///   1. Fetch user's streak (for lesson count -> difficulty +
///      day number).
///   2. Call BytezService.generateLesson with dayNumber =
///      totalLessonsCompleted + 11 (so first generation is day 11,
///      next is 12, ...).
///   3. On transient error, auto-retry with exponential backoff
///      (handled inside BytezService).
///   4. On hard error, show a "Try again" button.
class NewLessonScreen extends StatefulWidget {
  const NewLessonScreen({super.key});

  @override
  State<NewLessonScreen> createState() => _NewLessonScreenState();
}

class _NewLessonScreenState extends State<NewLessonScreen> {
  final _bytez = BytezService();

  Lesson? _lesson;
  bool _isLoading = true;
  int _attemptCount = 0;
  String? _error;
  String? _errorDetail;
  bool _isErrorRecoverable = true;

  @override
  void initState() {
    super.initState();
    unawaited(AnalyticsService.instance.track('new_lesson_open'));
    _load();
  }

  @override
  void dispose() {
    _bytez.close();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _attemptCount++;
    });

    int dayNumber;
    int userLevel;
    try {
      final streak = await StreakService.instance.read();
      userLevel = streak.totalLessonsCompleted;
      // Generate day 11 first, then 12, 13, ... and wrap around
      // when the user's count is small. Using totalLessonsCompleted
      // + 11 means a brand-new user (0 lessons) gets day 11.
      dayNumber = userLevel + 11;
    } catch (_) {
      userLevel = 0;
      dayNumber = 11;
    }

    try {
      final lesson = await _bytez.generateLesson(
        dayNumber: dayNumber,
        userLevel: userLevel,
      );
      if (!mounted) return;
      setState(() {
        _lesson = lesson;
        _isLoading = false;
        _error = null;
      });
      unawaited(AnalyticsService.instance.track('lesson_generated', properties: {
        'lesson_id': lesson.id,
        'day': dayNumber,
        'attempts': _attemptCount,
        'questions': lesson.questions.length,
      }));
    } on BytezAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = _humanError(e);
        _errorDetail = e.toString();
        _isErrorRecoverable = false;
      });
    } on BytezFormatException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = _humanError(e);
        _errorDetail = e.toString();
        _isErrorRecoverable = true;
      });
    } on BytezException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = _humanError(e);
        _errorDetail = e.toString();
        _isErrorRecoverable = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = _humanError(e);
        _errorDetail = e.toString();
        _isErrorRecoverable = true;
      });
    }
  }

  void _userRetry() {
    setState(() {
      _attemptCount = 0;
    });
    unawaited(_load());
  }

  String _humanError(Object e) {
    final msg = e.toString();
    if (msg.contains('SocketException') ||
        msg.contains('Failed host lookup') ||
        msg.contains('Network is unreachable')) {
      return 'You appear to be offline. Connect to the internet and try again.';
    }
    if (msg.contains('TimeoutException') || msg.contains('timed out')) {
      return 'The LLM took too long to respond. Try again in a moment.';
    }
    if (msg.contains('401') || msg.contains('403')) {
      return 'API key rejected. Rebuild the app with a valid BYTEZ_API_KEY.';
    }
    if (msg.contains('429')) {
      return 'Rate limited. Wait a moment and try again.';
    }
    if (msg.contains('500') || msg.contains('502') || msg.contains('503')) {
      return 'The LLM service is having trouble. Try again in a moment.';
    }
    if (msg.contains('Build with the secret configured') ||
        msg.contains('not set in build')) {
      return 'LLM is not configured in this build. Contact support.';
    }
    if (msg.contains('non-JSON') || msg.contains('not an object')) {
      return 'The LLM returned an unexpected response. Try again.';
    }
    return 'Could not generate a lesson. Try again.';
  }

  void _startLesson() {
    final lesson = _lesson;
    if (lesson == null) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => LessonPlayerScreen.forLesson(lesson),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return _buildLoading(context);
    if (_error != null) return _buildError(context);
    if (_lesson == null) return _buildError(context); // defensive
    return _buildPreview(context, _lesson!);
  }

  Widget _buildLoading(BuildContext context) {
    return Scaffold(
      backgroundColor: BrandColors.cream,
      appBar: AppBar(
        title: Text(
          'New lesson',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        backgroundColor: BrandColors.cream,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Mascot(mood: MascotMood.idle, size: 120),
                const SizedBox(height: AppSpacing.l),
                Text(
                  'Designing a new lesson for you...',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                if (_attemptCount > 1) ...[
                  const SizedBox(height: AppSpacing.s),
                  Text(
                    'Attempt $_attemptCount',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: BrandColors.lockedGrey,
                        ),
                  ),
                ],
                const SizedBox(height: AppSpacing.l),
                const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    final detail = _errorDetail;
    return Scaffold(
      backgroundColor: BrandColors.cream,
      appBar: AppBar(
        title: Text(
          'New lesson',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        backgroundColor: BrandColors.cream,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Mascot(mood: MascotMood.idle, size: 100),
                const SizedBox(height: AppSpacing.l),
                Text(
                  _error ?? 'Something went wrong.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: AppSpacing.l),
                ElevatedButton(
                  onPressed: _userRetry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BrandColors.gold,
                    foregroundColor: BrandColors.deepInk,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                      vertical: AppSpacing.l,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.m),
                    ),
                  ),
                  child: Text(
                    'Try again',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                if (detail != null && detail.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.l),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.m),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppSpacing.m),
                      border: Border.all(color: BrandColors.lockedGrey),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Error details',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: BrandColors.lockedGrey,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
                          detail,
                          style: const TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color: BrandColors.deepInk,
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () => _copyError(context, detail),
                          icon: const Icon(Icons.copy, size: 14),
                          label: const Text(
                            'Copy error',
                            style: TextStyle(fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: BrandColors.deepInk,
                            side: const BorderSide(color: BrandColors.lockedGrey),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.m,
                              vertical: 6,
                            ),
                            minimumSize: const Size(0, 32),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (!_isErrorRecoverable) ...[
                  const SizedBox(height: AppSpacing.s),
                  Text(
                    'The LLM rejected the request. This is a build-time issue, not a network problem.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: BrandColors.lockedGrey,
                        ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _copyError(BuildContext context, String detail) async {
    // ignore: deprecated_member_use
    await Clipboard.setData(ClipboardData(text: detail));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Error details copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// Brief preview before launching the lesson. Shows the title +
  /// topic and a Start button. The lesson content (questions) is
  /// already on screen via [LessonPlayerScreen] once the user
  /// taps Start, so this is intentionally minimal.
  Widget _buildPreview(BuildContext context, Lesson lesson) {
    return Scaffold(
      backgroundColor: BrandColors.cream,
      appBar: AppBar(
        title: Text(
          'New lesson',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        backgroundColor: BrandColors.cream,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: Mascot(mood: MascotMood.celebrate, size: 120)),
              const SizedBox(height: AppSpacing.l),
              Text(
                'Day ${lesson.day}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: BrandColors.gold,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
              ),
              const SizedBox(height: AppSpacing.s),
              Text(
                lesson.title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displayLarge,
              ),
              const SizedBox(height: AppSpacing.l),
              Container(
                padding: const EdgeInsets.all(AppSpacing.l),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppSpacing.m),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _Stat(
                      icon: Icons.help_outline,
                      label: 'Questions',
                      value: '${lesson.questions.length}',
                    ),
                    _Stat(
                      icon: Icons.timer_outlined,
                      label: 'Minutes',
                      value: '${lesson.estimatedMinutes}',
                    ),
                    _Stat(
                      icon: Icons.auto_awesome,
                      label: 'Source',
                      value: 'LLM',
                    ),
                  ],
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _startLesson,
                style: ElevatedButton.styleFrom(
                  backgroundColor: BrandColors.gold,
                  foregroundColor: BrandColors.deepInk,
                  padding: const EdgeInsets.all(AppSpacing.l),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.m),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.play_arrow, color: BrandColors.deepInk),
                    const SizedBox(width: AppSpacing.s),
                    Text(
                      'Start lesson',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.s),
              TextButton(
                onPressed: _userRetry,
                child: Text(
                  'Generate a different lesson',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: BrandColors.deepInk,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _Stat({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: BrandColors.deepInk, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: BrandColors.deepInk,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: BrandColors.lockedGrey,
          ),
        ),
      ],
    );
  }
}
