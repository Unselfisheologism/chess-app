import 'package:flutter/material.dart';

import '../../../models/lesson.dart';
import '../../../theme/brand.dart';
import '../../../theme/spacing.dart';
import '../../../widgets/chess_board.dart';

/// Tap-square shell. Shows the prompt, then a chess board with the
/// question's piece position. User taps a square; parent validates
/// against `question.correctSquare`.
class TapSquareShell extends StatefulWidget {
  final LessonQuestion question;
  final bool isLocked;
  final void Function(String square) onSubmit;

  const TapSquareShell({
    super.key,
    required this.question,
    required this.isLocked,
    required this.onSubmit,
  });

  @override
  State<TapSquareShell> createState() => _TapSquareShellState();
}

class _TapSquareShellState extends State<TapSquareShell> {
  String? _tappedSquare;

  @override
  Widget build(BuildContext context) {
    final board = widget.question.board ?? const {};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.question.prompt,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: AppSpacing.l),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: ChessBoard(
              pieces: board,
              selectedSquare: _tappedSquare,
              onTapSquare: widget.isLocked
                  ? null
                  : (square) {
                      setState(() => _tappedSquare = square);
                      widget.onSubmit(square);
                    },
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.m),
        Text(
          _tappedSquare == null
              ? 'Tap a square on the board.'
              : 'You tapped: $_tappedSquare',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: _tappedSquare == null
                    ? BrandColors.lockedGrey
                    : BrandColors.deepInk,
              ),
        ),
      ],
    );
  }
}
