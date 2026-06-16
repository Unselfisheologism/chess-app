import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/lesson.dart';
import '../../services/analytics_service.dart';
import '../../services/lesson_loader.dart';
import '../../services/streak_service.dart';
import '../../theme/brand.dart';
import '../../theme/spacing.dart';
import '../../widgets/feedback_overlay.dart';
import '../../widgets/progress_bar.dart';
import 'completion_screen.dart';
import 'shells/multiple_choice_shell.dart';
import 'shells/tap_square_shell.dart';

/// Orchestrator for a single lesson. Loads the lesson, walks the
/// user through each question, validates the answer, shows feedback,
/// and lands on [CompletionScreen] at the end.
///
/// Two entry points:
///   - [LessonPlayerScreen] (day-based): loads from bundled assets
///     via [LessonLoader]. Used for the curriculum days 1-10.
///   - [LessonPlayerScreen.forLesson] (in-memory): runs a lesson
///     that's been generated at runtime (e.g. by the LLM). Used
///     for "New lesson" beyond the bundled set.
///
/// State is held locally; the streak service (U5) will hook in here
/// once `markLessonComplete` exists.
class LessonPlayerScreen extends StatefulWidget {
  /// Day index (1-10) to load from bundled assets. Mutually
  /// exclusive with [LessonPlayerScreen.forLesson].
  final int? day;

  /// Pre-built lesson to run, typically from an LLM. When this is
  /// non-null, [day] is ignored and the loader is bypassed.
  final Lesson? lesson;

  /// Convenience: day-based lesson (bundled).
  const LessonPlayerScreen({super.key, this.day}) : lesson = null;

  /// In-memory lesson (e.g. LLM-generated). [streakKey] is the
  /// SharedPreferences key used to track completion; defaults to
  /// the bundled-lesson key so streak counts as one lesson done.
  const LessonPlayerScreen.forLesson(
    this.lesson, {
    super.key,
  }) : day = null;

  @override
  State<LessonPlayerScreen> createState() => _LessonPlayerScreenState();
}

class _LessonPlayerScreenState extends State<LessonPlayerScreen> {
  final _loader = LessonLoader();

  Lesson? _lesson;
  int _currentIndex = 0;
  int _score = 0;
  bool _isShowingFeedback = false;
  bool _lastWasCorrect = false;
  String _lastExplanation = '';
  int _attemptsThisQuestion = 0;
  bool _hasLockedAnswer = false;
  bool _isLoading = true;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.lesson != null) {
      // In-memory lesson (e.g. LLM-generated). No async load.
      unawaited(AnalyticsService.instance.track('lesson_start', properties: {
        'day': widget.lesson!.day,
        'source': 'bytez',
        'lesson_id': widget.lesson!.id,
      }));
      if (!mounted) return;
      setState(() {
        _lesson = widget.lesson;
        _isLoading = false;
      });
      return;
    }

    final day = widget.day;
    if (day == null) {
      // Defensive: should never happen, the constructor enforces
      // exactly one of {day, lesson} is provided.
      setState(() {
        _loadError = StateError('LessonPlayerScreen needs day or lesson');
        _isLoading = false;
      });
      return;
    }

    unawaited(AnalyticsService.instance.track('lesson_start', properties: {
      'day': day,
      'source': 'bundled',
    }));
    try {
      final lesson = await _loader.load(day);
      if (!mounted) return;
      setState(() {
        _lesson = lesson;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e;
        _isLoading = false;
      });
    }
  }

  void _onSubmit(dynamic answer) {
    if (_isShowingFeedback) return;
    final question = _lesson!.questions[_currentIndex];
    final correct = _validate(question, answer);
    _attemptsThisQuestion++;

    setState(() {
      _isShowingFeedback = true;
      _lastWasCorrect = correct;
      _lastExplanation = question.explanation;
      if (correct) {
        _score++;
        _hasLockedAnswer = true;
      } else if (_attemptsThisQuestion >= 2) {
        // 2nd wrong answer: lock and reveal.
        _hasLockedAnswer = true;
      } else {
        // 1st wrong: allow another attempt.
        _hasLockedAnswer = false;
      }
    });
  }

  bool _validate(LessonQuestion q, dynamic answer) {
    switch (q.shellType) {
      case LessonShellType.multipleChoice:
      case LessonShellType.nameOpening:
        return answer is int && answer == q.correctIndex;
      case LessonShellType.tapSquare:
      case LessonShellType.findCheckmate:
      case LessonShellType.tapWeakSquare:
        return answer is String &&
            q.correctSquare != null &&
            answer.toLowerCase() == q.correctSquare!.toLowerCase();
      case LessonShellType.dragPiece:
      case LessonShellType.makeBestMove:
      case LessonShellType.readPosition:
        return false;
    }
  }

  void _dismissFeedback() {
    if (_isShowingFeedback && _hasLockedAnswer) {
      if (_currentIndex + 1 < _lesson!.questions.length) {
        setState(() {
          _currentIndex++;
          _isShowingFeedback = false;
          _attemptsThisQuestion = 0;
        });
      } else {
        // Lesson complete. Mark the streak (fire-and-forget; the
        // next read on the home screen will see the update).
        // Use the lesson's own day number so LLM-generated
        // lessons (day 11+) show the right number on the
        // completion screen and analytics events.
        final completedDay = _lesson!.day;
        unawaited(AnalyticsService.instance.track('lesson_complete', properties: {
          'day': completedDay,
          'source': widget.lesson != null ? 'bytez' : 'bundled',
          'lesson_id': _lesson!.id,
          'score': _score,
          'total': _lesson!.questions.length,
        }));
        unawaited(StreakService.instance.markLessonComplete());
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => CompletionScreen(
              day: completedDay,
              score: _score,
              total: _lesson!.questions.length,
            ),
          ),
        );
      }
    } else {
      setState(() {
        _isShowingFeedback = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(child: Text('Failed to load lesson: $_loadError')),
      );
    }

    final lesson = _lesson!;
    final question = lesson.questions[_currentIndex];
    final shellLocked = _isShowingFeedback && _hasLockedAnswer;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          lesson.title,
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
                children: [
                  LessonProgressBar(
                    currentIndex: _currentIndex,
                    total: lesson.questions.length,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Expanded(
                    child: SingleChildScrollView(
                      child: _buildShell(question, shellLocked),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isShowingFeedback)
            FeedbackOverlay(
              kind: _lastWasCorrect
                  ? FeedbackKind.correct
                  : FeedbackKind.wrong,
              explanation: _lastExplanation,
              onDismiss: _dismissFeedback,
            ),
        ],
      ),
    );
  }

  Widget _buildShell(LessonQuestion q, bool shellLocked) {
    switch (q.shellType) {
      case LessonShellType.multipleChoice:
      case LessonShellType.nameOpening:
        return MultipleChoiceShell(
          question: q,
          isLocked: shellLocked,
          onSubmit: _onSubmit,
        );
      case LessonShellType.tapSquare:
      case LessonShellType.findCheckmate:
      case LessonShellType.tapWeakSquare:
        return TapSquareShell(
          question: q,
          isLocked: shellLocked,
          onSubmit: _onSubmit,
        );
      case LessonShellType.dragPiece:
      case LessonShellType.makeBestMove:
      case LessonShellType.readPosition:
        return Center(
          child: Text(
            'Shell type ${q.shellType.name} not yet implemented.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        );
    }
  }
}
