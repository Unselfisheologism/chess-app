import 'package:flutter/material.dart';

import '../../models/puzzle.dart';
import '../../services/puzzle_service.dart';
import '../../theme/brand.dart';
import '../../theme/spacing.dart';
import '../../widgets/chess_board.dart';
import '../../widgets/feedback_overlay.dart';

/// Daily puzzle screen. Loads today's puzzle (selected by day index
/// from [PuzzleService]), shows the position + prompt, and asks the
/// user to tap the destination square of the correct move.
///
/// Feedback is the same green/red overlay used by lessons. After the
/// first correct answer, the user can see the explanation.
class DailyPuzzleScreen extends StatefulWidget {
  final int day;
  const DailyPuzzleScreen({super.key, required this.day});

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await _service.pickTodaysPuzzle(widget.day);
      if (!mounted) return;
      setState(() {
        _puzzle = p;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _onTapSquare(String square) {
    if (_isShowingFeedback || _puzzle == null) return;
    final correct = square.toLowerCase() == _puzzle!.correctSquare.toLowerCase();
    setState(() {
      _tappedSquare = square;
      _isShowingFeedback = true;
      _wasCorrect = correct;
      _explanation = correct
          ? _puzzle!.explanation
          : 'Not quite. The right square is ${_puzzle!.correctSquare.toUpperCase()}. ${_puzzle!.explanation}';
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
        body: Center(child: Text('Could not load puzzle: ${_error ?? "empty"}')),
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
                          onTapSquare: _onTapSquare,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.m),
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
