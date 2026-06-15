import 'dart:async';

import 'package:stockfish_flutter_plus/stockfish_flutter_plus.dart';

/// Thin wrapper around stockfish_flutter_plus. Manages the singleton
/// engine instance, the engine-readiness wait, and bestmove parsing.
///
/// U7 only ever needs one move at a time from a given FEN, so the API
/// is `getBestMove(fen)`. The full match (user vs engine with
/// turn-taking) comes in a later unit.
class StockfishService {
  Stockfish? _engine;
  bool _busy = false;
  bool _disposed = false;

  /// Lazy-init the engine and wait until it reports [StockfishState.ready].
  Future<void> ensureReady() async {
    if (_disposed) {
      throw StateError('StockfishService was disposed');
    }
    if (_engine != null) {
      while (_engine!.state.value != StockfishState.ready) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      return;
    }
    final engine = Stockfish();
    if (engine == null) {
      throw StateError(
        'Stockfish engine is already running in another instance',
      );
    }
    _engine = engine;
    // The engine takes a few hundred ms to spin up.
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (_engine!.state.value != StockfishState.ready) {
      if (DateTime.now().isAfter(deadline)) {
        throw StateError('Stockfish engine did not become ready in time');
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  /// Asks the engine to pick a move from [fen], spending at most
  /// [movetimeMs] milliseconds. Returns the move in UCI notation
  /// (e.g. "e2e4" or "e7e8q" with promotion), or null on timeout /
  /// error.
  Future<String?> getBestMove(
    String fen, {
    int movetimeMs = 1500,
  }) async {
    if (_busy) return null;
    _busy = true;
    try {
      await ensureReady();
      final engine = _engine!;
      engine.stdin = 'position fen $fen';
      engine.stdin = 'go movetime $movetimeMs';

      final completer = Completer<String?>();
      late final StreamSubscription<String> sub;
      sub = engine.stdout.listen((line) {
        if (line.startsWith('bestmove')) {
          sub.cancel();
          if (line == 'bestmove (none)') {
            completer.complete(null);
          } else {
            final parts = line.split(' ');
            completer.complete(parts.length >= 2 ? parts[1] : null);
          }
        }
      });
      final move = await completer.future.timeout(
        const Duration(seconds: movetimeMs + 3000),
        onTimeout: () {
          sub.cancel();
          engine.stdin = 'stop';
          return null;
        },
      );
      return move;
    } finally {
      _busy = false;
    }
  }

  /// Tear down the engine. Hot-reload-safe (re-creating the engine
  /// after dispose is supported by the underlying plugin).
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    try {
      _engine?.dispose();
    } catch (_) {
      // Disposing can race with hot-reload; ignore failures.
    }
    _engine = null;
  }
}
