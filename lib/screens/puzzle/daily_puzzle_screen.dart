import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../../models/puzzle.dart';
import '../../services/analytics_service.dart';
import '../../services/bytez_service.dart';
import '../../services/streak_service.dart';
import '../../theme/brand.dart';
import '../../theme/spacing.dart';
import '../../widgets/chess_board.dart';
import '../../widgets/feedback_overlay.dart';
import '../../widgets/mascot.dart';

/// Daily puzzle screen. On open, auto-generates a fresh puzzle via
/// the Bytez LLM, tailored to the user's current lesson count. The
/// user never types to the LLM — the page is content-first, not a
/// chat interface.
///
/// Loading flow:
///   1. Fetch user's streak (for lesson count -> difficulty).
///   2. Call BytezService.generatePuzzle with the current day index.
///   3. On transient error (network / 5xx / 429), auto-retry with
///      exponential backoff (handled inside BytezService).
///   4. On hard error (auth / format / config), show a "Try again"
///      button — the user is in control of the final retry. No
///      silent fallback to a bundled puzzle; per the chess-do-it
///      design, the daily puzzle IS the LLM.
///
/// Once loaded, this page is identical in UX to the original
/// bundled-puzzle flow: prompt + board + tap-a-square.
class DailyPuzzleScreen extends StatefulWidget {
  /// The current day-of-launch index. Used to seed the puzzle theme
  /// so consecutive days get different tactics. If null, derived
  /// from the user's streak (lessons completed + 1).
  final int? day;

  const DailyPuzzleScreen({super.key, this.day});

  @override
  State<DailyPuzzleScreen> createState() => _DailyPuzzleScreenState();
}

class _DailyPuzzleScreenState extends State<DailyPuzzleScreen> {
  final _bytez = BytezService();

  Puzzle? _puzzle;
  bool _isLoading = true;
  // True when the underlying error is recoverable (network /
  // timeout / 5xx / 429) so the user sees a "Retrying..."
  // indicator and a final "Try again" button. False for hard
  // errors (auth, format) where retrying with the same key is
  // pointless.
  bool _autoRetrying = false;
  // Number of automatic retry attempts the user has watched. Shown
  // in the loading UI so the user knows the app is doing something
  // and not silently failing.
  int _attemptCount = 0;
  // User-friendly error message, displayed in big text.
  String? _error;
  // Raw exception text, displayed in small monospace text below
  // the friendly message. Always set when [_error] is set. The
  // "Copy error" button puts this on the clipboard so the user
  // can paste it to support when reporting a problem.
  String? _errorDetail;
  bool _isErrorRecoverable = true;

  String? _tappedSquare;
  bool _isShowingFeedback = false;
  bool _wasCorrect = false;
  String _explanation = '';
  bool _isDone = false;

  @override
  void initState() {
    super.initState();
    unawaited(AnalyticsService.instance.track(
      'daily_puzzle_open',
      properties: {'day': widget.day ?? 0},
    ));
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
      _autoRetrying = true;
      _attemptCount++;
    });

    int day;
    int userLevel;
    try {
      final streak = await StreakService.instance.read();
      day = widget.day ?? (streak.totalLessonsCompleted + 1);
      userLevel = streak.totalLessonsCompleted;
    } catch (_) {
      // If streak read fails, default to day 1 / beginner.
      day = widget.day ?? 1;
      userLevel = 0;
    }

    try {
      final puzzle = await _bytez.generatePuzzle(
        day: day,
        userLevel: userLevel,
      );
      if (!mounted) return;
      setState(() {
        _puzzle = puzzle;
        _isLoading = false;
        _autoRetrying = false;
        _error = null;
      });
      unawaited(AnalyticsService.instance.track(
        'puzzle_generated',
        properties: {
          'puzzle_id': puzzle.id,
          'day': day,
          'attempts': _attemptCount,
        },
      ));
    } on BytezAuthException catch (e) {
      // Hard error. No auto-retry. Show the error and a "Try again"
      // button so the user can re-attempt after fixing config.
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _autoRetrying = false;
        _error = _humanError(e);
        _errorDetail = e.toString();
        _isErrorRecoverable = false;
      });
    } on BytezFormatException catch (e) {
      // The model returned bad JSON / invalid board. One more shot
      // with the same key MIGHT help, but more likely the model is
      // confused. Show a "Try again" — user-triggered, not auto.
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _autoRetrying = false;
        _error = _humanError(e);
        _errorDetail = e.toString();
        _isErrorRecoverable = true;
      });
    } on BytezException catch (e) {
      // All attempts exhausted (network / timeout / 5xx / 429).
      // Show a "Try again" button.
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _autoRetrying = false;
        _error = _humanError(e);
        _errorDetail = e.toString();
        _isErrorRecoverable = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _autoRetrying = false;
        _error = _humanError(e);
        _errorDetail = e.toString();
        _isErrorRecoverable = true;
      });
    }
  }

  /// One auto-retry round when the user taps "Try again".
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
    return 'Could not load puzzle.';
  }

  void _onTapSquare(String square) {
    if (_isShowingFeedback || _puzzle == null || _isDone) return;
    final correct = square.toLowerCase() == _puzzle!.correctSquare.toLowerCase();
    unawaited(AnalyticsService.instance.track('puzzle_answer', properties: {
      'puzzle_id': _puzzle!.id,
      'tapped': square,
      'correct': correct,
    }));
    setState(() {
      _tappedSquare = square;
      _isShowingFeedback = true;
      _wasCorrect = correct;
      _explanation = correct
          ? _puzzle!.explanation
          : 'Not quite. The right square is ${_puzzle!.correctSquare.toUpperCase()}. ${_puzzle!.explanation}';
      if (correct) _isDone = true;
    });
  }

  void _dismissFeedback() {
    setState(() {
      _isShowingFeedback = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return _buildLoading(context);
    if (_error != null) return _buildError(context);
    if (_puzzle == null) {
      // Defensive: should not happen (error path covers null).
      return _buildError(context);
    }
    return _buildPuzzle(context, _puzzle!);
  }

  Widget _buildLoading(BuildContext context) {
    return Scaffold(
      backgroundColor: BrandColors.cream,
      appBar: AppBar(
        title: Text(
          'Daily puzzle',
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
                  _autoRetrying
                      ? 'Cooking up today\'s puzzle...'
                      : 'Loading...',
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
          'Daily puzzle',
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
    // Clipboard.setData is in services.dart, but importing it just
    // for this one call would be heavier than the inline
    // implementation. The Clipboard API has been stable since
    // Flutter 1.x.
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

  Widget _buildPuzzle(BuildContext context, Puzzle puzzle) {
    return Scaffold(
      backgroundColor: BrandColors.cream,
      appBar: AppBar(
        title: Text(
          puzzle.title,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        backgroundColor: BrandColors.cream,
        elevation: 0,
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.l),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    puzzle.prompt,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: AppSpacing.l),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 380),
                        child: ChessBoard(
                          pieces: puzzle.board,
                          selectedSquare: _tappedSquare,
                          onTapSquare:
                              _isDone ? null : _onTapSquare,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.m),
                  if (_isDone)
                    _DoneBanner(onContinue: () => Navigator.of(context).pop())
                  else
                    Text(
                      _tappedSquare == null
                          ? 'Tap a square on the board.'
                          : 'You tapped: ${_tappedSquare!.toUpperCase()}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                ],
              ),
            ),
          ),
          if (_isShowingFeedback)
            FeedbackOverlay(
              kind: _wasCorrect ? FeedbackKind.correct : FeedbackKind.wrong,
              explanation: _explanation,
              onDismiss: _dismissFeedback,
            ),
        ],
      ),
    );
  }
}

class _DoneBanner extends StatelessWidget {
  final VoidCallback onContinue;
  const _DoneBanner({required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.m),
          decoration: BoxDecoration(
            color: BrandColors.success.withOpacity(0.12),
            borderRadius: BorderRadius.circular(AppSpacing.m),
            border: Border.all(color: BrandColors.success.withOpacity(0.4)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, color: BrandColors.success),
              SizedBox(width: AppSpacing.s),
              Text(
                "You've done today's puzzle!",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: BrandColors.success,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s),
        TextButton(
          onPressed: onContinue,
          child: Text(
            'Back to home',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: BrandColors.deepInk,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.underline,
                ),
          ),
        ),
      ],
    );
  }
}
