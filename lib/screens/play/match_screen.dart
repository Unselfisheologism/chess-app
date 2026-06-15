import 'package:flutter/material.dart';

import '../../services/stockfish_service.dart';
import '../../theme/brand.dart';
import '../../theme/spacing.dart';
import '../../widgets/chess_board.dart';

/// Initial chess position as a square -> piece map (uppercase = white).
const Map<String, String> _kInitialPosition = {
  'a1': 'R', 'b1': 'N', 'c1': 'B', 'd1': 'Q', 'e1': 'K', 'f1': 'B', 'g1': 'N', 'h1': 'R',
  'a2': 'P', 'b2': 'P', 'c2': 'P', 'd2': 'P', 'e2': 'P', 'f2': 'P', 'g2': 'P', 'h2': 'P',
  'a7': 'p', 'b7': 'p', 'c7': 'p', 'd7': 'p', 'e7': 'p', 'f7': 'p', 'g7': 'p', 'h7': 'p',
  'a8': 'r', 'b8': 'n', 'c8': 'b', 'd8': 'q', 'e8': 'k', 'f8': 'b', 'g8': 'n', 'h8': 'r',
};

/// Spectator-mode Stockfish board. The user is a spectator: they
/// press a button, Stockfish (via lichess's cloud-eval API) picks a
/// move from the current position, and the board updates. Real
/// user-vs-engine play with move validation is a future unit
/// (U7.2) — it needs a chess engine, which is what the
/// lichess API integration is a stopgap for.
class MatchScreen extends StatefulWidget {
  const MatchScreen({super.key});

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> {
  final _service = StockfishService();
  Map<String, String> _position = Map<String, String>.from(_kInitialPosition);
  String _status = 'Press "Ask chessito AI" to start. Needs internet.';
  bool _isThinking = false;
  int _moveCount = 0;
  String? _lastMove;
  StockfishEvaluation? _lastEval;

  @override
  void dispose() {
    _service.close();
    super.dispose();
  }

  Future<void> _askStockfish() async {
    if (_isThinking) return;
    setState(() {
      _isThinking = true;
      _status = 'Asking chessito AI...';
    });
    try {
      final fen = _toFen(_position);
      final eval = await _service.getBestMove(fen);
      if (!mounted) return;
      setState(() {
        _position = _applyMove(_position, eval.bestMove);
        _moveCount++;
        _lastMove = eval.bestMove;
        _lastEval = eval;
        _isThinking = false;
        _status = 'chessito AI played: ${eval.bestMove} '
            '(depth ${eval.depth}, eval ${eval.evalSummary})';
      });
    } on StockfishException catch (e) {
      if (!mounted) return;
      setState(() {
        _isThinking = false;
        _status = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isThinking = false;
        _status = 'Error: $e';
      });
    }
  }

  void _reset() {
    setState(() {
      _position = Map<String, String>.from(_kInitialPosition);
      _moveCount = 0;
      _lastMove = null;
      _lastEval = null;
      _status = 'Position reset to the opening setup.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrandColors.cream,
      appBar: AppBar(
        title: Text(
          'Play chessito AI',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        backgroundColor: BrandColors.cream,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.l),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: ChessBoard(
                      pieces: _position,
                      selectedSquare: _lastMove != null && _lastMove!.length >= 4
                          ? _lastMove!.substring(2, 4)
                          : null,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.m),
              Container(
                padding: const EdgeInsets.all(AppSpacing.m),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppSpacing.s),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _status,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                    Text(
                      'moves: $_moveCount',
                      style: const TextStyle(
                        fontSize: 12,
                        color: BrandColors.lockedGrey,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.m),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isThinking ? null : _askStockfish,
                      icon: _isThinking
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: BrandColors.deepInk,
                              ),
                            )
                          : const Icon(Icons.smart_toy, color: BrandColors.deepInk),
                      label: Text(
                        _isThinking ? 'Thinking...' : 'Ask chessito AI',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: BrandColors.deepInk,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BrandColors.gold,
                        padding: const EdgeInsets.all(AppSpacing.m),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s),
                  IconButton(
                    onPressed: _isThinking ? null : _reset,
                    icon: const Icon(Icons.refresh, color: BrandColors.deepInk),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.all(AppSpacing.m),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _toFen(Map<String, String> position) {
  final ranks = <String>[];
  for (int rank = 8; rank >= 1; rank--) {
    var rankStr = '';
    var empty = 0;
    for (int file = 0; file < 8; file++) {
      final square = '${String.fromCharCode(97 + file)}$rank';
      final piece = position[square];
      if (piece == null) {
        empty++;
      } else {
        if (empty > 0) {
          rankStr += '$empty';
          empty = 0;
        }
        rankStr += piece;
      }
    }
    if (empty > 0) rankStr += '$empty';
    ranks.add(rankStr);
  }
  return '${ranks.join('/')} w - - 0 1';
}

Map<String, String> _applyMove(Map<String, String> position, String uciMove) {
  if (uciMove.length < 4) return position;
  final from = uciMove.substring(0, 2);
  final to = uciMove.substring(2, 4);
  final piece = position[from];
  if (piece == null) return position;
  final next = Map<String, String>.from(position);
  next.remove(from);
  if (uciMove.length == 5) {
    final promo = uciMove[4];
    final isWhite = piece == piece.toUpperCase();
    next[to] = isWhite ? promo.toUpperCase() : promo.toLowerCase();
  } else {
    next[to] = piece;
  }
  return next;
}
