import 'package:flutter/foundation.dart';

@immutable
class Puzzle {
  final String id;
  final int day;
  final String title;
  final String prompt;
  final Map<String, String> board; // square -> piece
  final String uciMove;
  final String explanation;

  const Puzzle({
    required this.id,
    required this.day,
    required this.title,
    required this.prompt,
    required this.board,
    required this.uciMove,
    required this.explanation,
  });

  /// The destination square of [uciMove] (e.g. "c1b5" -> "b5").
  /// This is what the user has to tap on the board.
  String get correctSquare =>
      uciMove.length >= 4 ? uciMove.substring(2, 4) : '';

  factory Puzzle.fromJson(Map<String, dynamic> json) {
    return Puzzle(
      id: json['id'] as String,
      day: (json['day'] as num).toInt(),
      title: json['title'] as String,
      prompt: json['prompt'] as String,
      board: (json['board'] as Map<String, dynamic>).cast<String, String>(),
      uciMove: json['uciMove'] as String,
      explanation: json['explanation'] as String,
    );
  }
}
