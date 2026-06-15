import 'package:chess_do_it/models/lesson.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Lesson.fromJson', () {
    test('parses a minimal lesson', () {
      final json = {
        'id': 'test_lesson',
        'day': 1,
        'title': 'Test',
        'estimatedMinutes': 5,
        'questions': [
          {
            'id': 'q1',
            'shellType': 'multipleChoice',
            'prompt': 'Pick one',
            'options': ['A', 'B'],
            'correctIndex': 0,
            'explanation': 'A is correct.',
          },
        ],
      };
      final lesson = Lesson.fromJson(json);
      expect(lesson.id, 'test_lesson');
      expect(lesson.day, 1);
      expect(lesson.title, 'Test');
      expect(lesson.estimatedMinutes, 5);
      expect(lesson.questions.length, 1);
      expect(lesson.questions.first.shellType, LessonShellType.multipleChoice);
      expect(lesson.questions.first.options, ['A', 'B']);
      expect(lesson.questions.first.correctIndex, 0);
    });

    test('parses a tapSquare question with board', () {
      final json = {
        'id': 'test',
        'day': 2,
        'title': 'Test',
        'estimatedMinutes': 5,
        'questions': [
          {
            'id': 'q1',
            'shellType': 'tapSquare',
            'prompt': 'Tap a square',
            'board': {'e1': 'K', 'e4': 'N'},
            'correctSquare': 'f6',
            'explanation': 'f6 is one of the knight\'s squares.',
          },
        ],
      };
      final lesson = Lesson.fromJson(json);
      final q = lesson.questions.first;
      expect(q.shellType, LessonShellType.tapSquare);
      expect(q.board, {'e1': 'K', 'e4': 'N'});
      expect(q.correctSquare, 'f6');
    });

    test('throws on unknown shellType', () {
      final json = {
        'id': 'test',
        'day': 1,
        'title': 'Test',
        'estimatedMinutes': 5,
        'questions': [
          {
            'id': 'q1',
            'shellType': 'unknownType',
            'prompt': '?',
            'explanation': '?',
          },
        ],
      };
      expect(() => Lesson.fromJson(json), throwsA(isA<FormatException>()));
    });
  });
}
