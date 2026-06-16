import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/puzzle.dart';
import '../../services/analytics_service.dart';
import '../../services/puzzle_service.dart';
import '../../theme/brand.dart';
import '../../theme/spacing.dart';
import '../../widgets/chess_board.dart';
import '../../widgets/feedback_overlay.dart';
import '../../widgets/mascot.dart';

/// Daily puzzle screen. Loads today's puzzle from the bundled set
/// (selected by day index from [PuzzleService]). Shows the position
/// + prompt, and asks the user to tap the destination square of the
/// correct move.
///
/// Feedback is the same green/red overlay used by lessons. After the
/// first correct answer, the user can see the explanation.
class DailyPuzzleScreen extends StatefulWidget {
  /// The current day-of-launch index. When null, falls back to 1
  /// (the first puzzle in the bundle).
  final int? day;

  const DailyPuzzleScreen({super.key, this.day});

  @override
  State<DailyPuzzleScreen> createState() => _DailyPuzzleScreenState();
}

class _DailyPuzzleScreenState extends State<DailyPuzzleScreen> {
  final _service = PuzzleService();

  Puzzle? _puzzle;
  bool _isLoading = true;
  String? _error;

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

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final p = await _service.pickTodaysPuzzle(widget.day ?? 1);
      if (!mounted) return;
      setState(() {
        _puzzle = p;
        _isLoading = false;
      });
      if (p != null) {
        unawaited(AnalyticsService.instance.track('puzzle_start', properties: {
          'puzzle_id': p.id,
          'day': widget.day ?? 1,
        }));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load puzzle: $e';
        _isLoading = false;
      });
    }
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
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null || _puzzle == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Puzzle')),
        body: Center(child: Text(_error ?? 'No puzzles bundled yet.')),
      );
    }

    final puzzle = _puzzle!;

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
