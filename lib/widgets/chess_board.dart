import 'package:flutter/material.dart';

import '../../theme/brand.dart';
import '../../theme/spacing.dart';
import '../../widgets/chess_board.dart';

/// Unicode chess piece symbols. White side uses the outlined set,
/// black side uses the filled set — this is the standard convention.
const _whitePieceSymbol = <String, String>{
  'K': '♔', 'Q': '♕', 'R': '♖', 'B': '♗', 'N': '♘', 'P': '♙',
};
const _blackPieceSymbol = <String, String>{
  'K': '♚', 'Q': '♛', 'R': '♜', 'B': '♝', 'N': '♞', 'P': '♟',
};

const _lightSquare = Color(0xFFF5EBDC); // brand cream
const _darkSquare = Color(0xFF8B7355); // wood brown
const _selectedHighlight = Color(0xFFE0B23C); // brand gold
const _pieceColor = Color(0xFF0E1116); // brand deep ink

/// Interactive chess board. Renders Unicode pieces from [pieces] (a
/// square -> piece map, e.g. `{"e1": "K", "e4": "N"}`), supports
/// single-tap via [onTapSquare], and highlights [selectedSquare] and
/// any squares in [highlightSquares].
///
/// No drag-and-drop yet — that's U6. No move validation yet — that's
/// U6 too. For now, this is a visual board used by tapSquare and
/// findCheckmate shell questions.
class ChessBoard extends StatelessWidget {
  final Map<String, String> pieces;
  final String? selectedSquare;
  final List<String> highlightSquares;
  final void Function(String square)? onTapSquare;

  const ChessBoard({
    super.key,
    required this.pieces,
    this.selectedSquare,
    this.highlightSquares = const [],
    this.onTapSquare,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: _pieceColor, width: 3),
        ),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 8,
            childAspectRatio: 1,
          ),
          itemCount: 64,
          itemBuilder: (context, i) {
            final file = i % 8; // 0 = a, 7 = h
            final rank = 7 - (i ~/ 8); // 7 = rank 8
            final square = '${String.fromCharCode(97 + file)}${rank + 1}';

            final isLightSquare = (file + rank) % 2 == 1;
            final isSelected = selectedSquare == square;
            final isHighlighted = highlightSquares.contains(square);
            final piece = pieces[square];

            Color squareColor;
            if (isSelected) {
              squareColor = _selectedHighlight;
            } else if (isHighlighted) {
              squareColor = _selectedHighlight.withOpacity(0.5);
            } else if (isLightSquare) {
              squareColor = _lightSquare;
            } else {
              squareColor = _darkSquare;
            }

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap:
                  onTapSquare != null ? () => onTapSquare!(square) : null,
              child: Container(
                color: squareColor,
                child: piece != null
                    ? Center(
                        child: Text(
                          _symbolFor(piece),
                          style: const TextStyle(
                            fontSize: 40,
                            color: _pieceColor,
                            fontFamily: 'serif',
                          ),
                        ),
                      )
                    : null,
              ),
            );
          },
        ),
      ),
    );
  }

  String _symbolFor(String piece) {
    final isWhite = piece == piece.toUpperCase();
    final table = isWhite ? _whitePieceSymbol : _blackPieceSymbol;
    return table[piece.toUpperCase()]!;
  }
}
