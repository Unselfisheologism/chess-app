import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Result of a Stockfish evaluation. [bestMove] is the engine's
/// top choice in UCI notation (e.g. "e2e4" or "e7e8q" with promotion).
class StockfishEvaluation {
  final String bestMove;
  final int? centipawns;
  final int? mateIn;
  final int depth;

  const StockfishEvaluation({
    required this.bestMove,
    required this.depth,
    this.centipawns,
    this.mateIn,
  });

  /// Human-readable eval string. "M3" for mate-in-3, "+1.5" for
  /// centipawn-150, "0.00" for equal.
  String get evalSummary {
    if (mateIn != null) {
      return 'M${mateIn! > 0 ? mateIn : -mateIn}';
    }
    if (centipawns != null) {
      final pawns = centipawns! / 100;
      return pawns >= 0 ? '+${pawns.toStringAsFixed(2)}' : pawns.toStringAsFixed(2);
    }
    return 'eval unknown';
  }
}

class StockfishException implements Exception {
  final String message;
  final int? statusCode;
  StockfishException(this.message, {this.statusCode});
  @override
  String toString() => 'StockfishException: $message';
}

/// Stockfish integration via the lichess cloud-eval API.
///
/// Why lichess: a local Stockfish binary would need to be compiled
/// for the device's CPU arch, bundled in the APK (~30MB), extracted
/// at first launch, and run as a subprocess via a custom Kotlin /
/// Swift platform channel. The flutter Gradle build on this
/// project (Flutter 3.22 / AGP 8.1 / man-wen-style setup) won't
/// auto-include plugin Android sources, and we don't have local
/// Android tooling to compile native binaries. The lichess public
/// API runs real Stockfish on its servers and returns the best
/// move as JSON — no native binary, no platform channel, no
/// Gradle discovery. Tradeoff: requires internet, and the API has
/// rate limits (anonymous: 20 reqs/sec, burst 80). For an MVP chess
/// app this is plenty.
///
/// Endpoint docs: https://lichess.org/api#tag/Analysis
class StockfishService {
  static const _apiBase = 'https://lichess.org/api/cloud-eval';

  final http.Client _client;

  StockfishService({http.Client? client})
      : _client = client ?? http.Client();

  /// Asks Stockfish (via lichess) for the best move from [fen].
  /// Throws [StockfishException] on network error, 404 (position
  /// not in cache), 429 (rate limited), or malformed response.
  Future<StockfishEvaluation> getBestMove(String fen) async {
    final uri = Uri.parse(_apiBase).replace(queryParameters: {
      'fen': fen,
      'multiPv': '1',
    });

    final http.Response response;
    try {
      response = await _client.get(uri).timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw StockfishException('Lichess API timed out after 15s');
    } catch (e) {
      throw StockfishException('Network error: $e');
    }

    if (response.statusCode == 404) {
      throw StockfishException(
        'Position not in Lichess cache — try a more common opening or a position reached by standard play',
        statusCode: 404,
      );
    }
    if (response.statusCode == 429) {
      throw StockfishException(
        'Rate limited by Lichess — wait a moment and try again',
        statusCode: 429,
      );
    }
    if (response.statusCode != 200) {
      throw StockfishException(
        'Lichess API returned ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      throw StockfishException('Malformed Lichess response: $e');
    }

    final pvs = json['pvs'] as List<dynamic>?;
    if (pvs == null || pvs.isEmpty) {
      throw StockfishException('No principal variations returned');
    }
    final firstPv = pvs.first as Map<String, dynamic>;
    final movesStr = (firstPv['moves'] as String?)?.trim() ?? '';
    if (movesStr.isEmpty) {
      throw StockfishException('Empty moves in principal variation');
    }
    final firstMove = movesStr.split(RegExp(r'\s+')).first;
    final depth = (json['depth'] as num?)?.toInt() ?? 0;
    final cp = (firstPv['cp'] as num?)?.toInt();
    final mate = (firstPv['mate'] as num?)?.toInt();

    return StockfishEvaluation(
      bestMove: firstMove,
      depth: depth,
      centipawns: cp,
      mateIn: mate,
    );
  }

  /// Test seam: inject a mock client.
  void close() {
    _client.close();
  }
}
