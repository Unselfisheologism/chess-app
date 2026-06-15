import 'package:flutter/foundation.dart';

/// Shell types for a single question in a lesson. Each shell is a
/// different interaction pattern (multiple choice, board tap, drag, etc).
enum LessonShellType {
  multipleChoice,
  tapSquare,
  findCheckmate,
  nameOpening,
  readPosition,
  tapWeakSquare,
  makeBestMove,
  dragPiece,
}

@immutable
class LessonQuestion {
  final String id;
  final LessonShellType shellType;
  final String prompt;

  /// Optional board position as a square -> piece map. Uppercase = white,
  /// lowercase = black. E.g. `{"e1": "K", "e8": "k", "e4": "N"}`.
  final Map<String, String>? board;

  /// For multipleChoice / nameOpening: the option labels.
  final List<String>? options;

  /// For multipleChoice: the index of the correct option.
  final int? correctIndex;

  /// For tapSquare / findCheckmate / tapWeakSquare: the correct square
  /// (algebraic, e.g. "e4").
  final String? correctSquare;

  /// Shown after the user answers (correct or wrong).
  final String explanation;

  const LessonQuestion({
    required this.id,
    required this.shellType,
    required this.prompt,
    this.board,
    this.options,
    this.correctIndex,
    this.correctSquare,
    required this.explanation,
  });

  factory LessonQuestion.fromJson(Map<String, dynamic> json) {
    return LessonQuestion(
      id: json['id'] as String,
      shellType: LessonShellType.values.firstWhere(
        (e) => e.name == json['shellType'],
        orElse: () => throw FormatException(
          'Unknown shellType: ${json['shellType']} in question ${json['id']}',
        ),
      ),
      prompt: json['prompt'] as String,
      board: (json['board'] as Map<String, dynamic>?)?.cast<String, String>(),
      options: (json['options'] as List<dynamic>?)?.cast<String>(),
      correctIndex: json['correctIndex'] as int?,
      correctSquare: json['correctSquare'] as String?,
      explanation: json['explanation'] as String,
    );
  }
}

@immutable
class Lesson {
  final String id;
  final int day;
  final String title;
  final int estimatedMinutes;
  final List<LessonQuestion> questions;

  const Lesson({
    required this.id,
    required this.day,
    required this.title,
    required this.estimatedMinutes,
    required this.questions,
  });

  factory Lesson.fromJson(Map<String, dynamic> json) {
    return Lesson(
      id: json['id'] as String,
      day: json['day'] as int,
      title: json['title'] as String,
      estimatedMinutes: json['estimatedMinutes'] as int,
      questions: (json['questions'] as List<dynamic>)
          .map((q) => LessonQuestion.fromJson(q as Map<String, dynamic>))
          .toList(),
    );
  }
}
