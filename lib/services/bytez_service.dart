import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/lesson.dart';
import '../models/puzzle.dart';

/// LLM client for the Bytez API.
///
/// Used by the "Daily puzzle" and "New lesson" pages to auto-generate
/// chess content at runtime. The LLM is **not** a chat interface —
/// the user never sees or types anything that goes to the model.
/// These pages just hand the model a structured prompt and parse
/// the JSON response into a [Puzzle] or [Lesson].
///
/// Endpoint: OpenAI-compatible chat completions
///   POST https://api.bytez.com/models/v2/openai/v1/chat/completions
/// Auth:    `Authorization: <BYTEZ_API_KEY>` header (raw key, NOT
///          `Bearer ...`).
/// Model:   Qwen/Qwen3-4B (open-source chat model on Bytez).
///
/// Source: bytez-docs/docs/http-reference/examples/openai-compliant/
///         chatCompletionsExample.mdx and
///         bytez-docs/docs/model-api/docs/task/chat.mdx.
class BytezService {
  static const _endpoint =
      'https://api.bytez.com/models/v2/openai/v1/chat/completions';
  static const _model = 'Qwen/Qwen3-4B';

  /// API key injected at build time via
  ///   flutter build apk --dart-define=BYTEZ_API_KEY=...
  /// (see scripts/inject-bytez-dart-defines.py and the GitHub
  /// Actions workflows). Empty in dev / local builds without the
  /// define — see [isConfigured].
  static const String apiKey = String.fromEnvironment('BYTEZ_API_KEY');

  /// Build SHA for diagnostics, injected alongside the API key.
  /// Surfaced on the Stats screen so users can tell a fresh APK
  /// from a stale install.
  static const String buildSha = String.fromEnvironment('BUILD_SHA');

  static const _timeout = Duration(seconds: 30);
  static const _maxAttempts = 3;

  final http.Client _client;

  BytezService({http.Client? client})
      : _client = client ?? http.Client();

  /// True iff the build has a non-empty BYTEZ_API_KEY. If false,
  /// any call to generatePuzzle / generateLesson will throw a
  /// [BytezAuthException] immediately, so the caller can show a
  /// "missing build configuration" message instead of a vague
  /// network error.
  bool get isConfigured => apiKey.isNotEmpty;

  /// Close the underlying HTTP client. Used by tests; production
  /// code uses the singleton and never closes.
  void close() => _client.close();

  // -- generation entry points ---------------------------------------

  /// Generate a single chess puzzle. [day] seeds the puzzle so the
  /// same calendar day produces a stable theme (used by the "daily
  /// puzzle" page to vary content). [userLevel] (1-10) is the
  /// user's current lesson count; the model calibrates difficulty
  /// to roughly match.
  Future<Puzzle> generatePuzzle({
    required int day,
    required int userLevel,
  }) async {
    final theme = _puzzleThemeForDay(day);
    final systemPrompt = _puzzleSystemPrompt;
    final userPrompt = _puzzleUserPrompt(
      day: day,
      theme: theme,
      userLevel: userLevel,
    );

    final raw = await _chatJson(
      system: systemPrompt,
      user: userPrompt,
      temperature: 0.6,
      maxTokens: 1200,
    );
    return _parsePuzzle(raw, day: day);
  }

  /// Generate a brand-new lesson (day 11+ content) tailored to the
  /// user. [dayNumber] is the absolute day number to assign (e.g.
  /// 11, 12, ...). [userLevel] is the user's completed-lesson count.
  Future<Lesson> generateLesson({
    required int dayNumber,
    required int userLevel,
  }) async {
    final topic = _lessonTopicForDay(dayNumber);
    final systemPrompt = _lessonSystemPrompt;
    final userPrompt = _lessonUserPrompt(
      dayNumber: dayNumber,
      topic: topic,
      userLevel: userLevel,
    );

    final raw = await _chatJson(
      system: systemPrompt,
      user: userPrompt,
      temperature: 0.6,
      maxTokens: 3500,
    );
    return _parseLesson(raw, day: dayNumber, title: topic);
  }

  // -- HTTP / retries -----------------------------------------------

  Future<Map<String, dynamic>> _chatJson({
    required String system,
    required String user,
    required double temperature,
    required int maxTokens,
  }) async {
    if (!isConfigured) {
      throw BytezAuthException(
        'BYTEZ_API_KEY not set in build. Rebuild with the secret configured.',
      );
    }

    final body = jsonEncode({
      'model': _model,
      'messages': [
        {'role': 'system', 'content': system},
        {'role': 'user', 'content': user},
      ],
      'response_format': {'type': 'json_object'},
      'temperature': temperature,
      'max_tokens': maxTokens,
    });

    Object? lastError;
    for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
      try {
        final response = await _client
            .post(
              Uri.parse(_endpoint),
              headers: {
                'Authorization': apiKey,
                'Content-Type': 'application/json',
              },
              body: body,
            )
            .timeout(_timeout);

        if (response.statusCode == 401 || response.statusCode == 403) {
          throw BytezAuthException(
            'Bytez rejected the API key (HTTP ${response.statusCode}). '
            'Check the BYTEZ_API_KEY GitHub secret.',
            statusCode: response.statusCode,
          );
        }
        if (response.statusCode == 429) {
          // Rate-limited — wait and retry.
          if (kDebugMode) {
            // ignore: avoid_print
            print('[bytez] rate limited, attempt $attempt/$_maxAttempts');
          }
          lastError = BytezException(
            'Rate limited (HTTP 429)',
            statusCode: 429,
          );
          await _backoff(attempt);
          continue;
        }
        if (response.statusCode >= 500) {
          lastError = BytezException(
            'Bytez server error (HTTP ${response.statusCode})',
            statusCode: response.statusCode,
          );
          await _backoff(attempt);
          continue;
        }
        if (response.statusCode != 200) {
          throw BytezException(
            'Bytez returned HTTP ${response.statusCode}: ${response.body}',
            statusCode: response.statusCode,
          );
        }

        return _parseChatResponse(response.body);
      } on TimeoutException {
        lastError = BytezException(
          'Bytez call timed out after ${_timeout.inSeconds}s',
        );
        await _backoff(attempt);
      } on BytezAuthException {
        rethrow; // Auth errors are not transient.
      } on BytezFormatException {
        rethrow; // Format errors are not transient — caller decides.
      } catch (e) {
        lastError = e;
        await _backoff(attempt);
      }
    }
    throw lastError is Exception
        ? lastError as Exception
        : BytezException('Bytez call failed after $_maxAttempts attempts');
  }

  Future<void> _backoff(int attempt) async {
    // Exponential backoff: 1s, 2s, 4s. attempt is 1-indexed.
    final ms = 1000 * (1 << (attempt - 1));
    await Future<void>.delayed(Duration(milliseconds: ms));
  }

  Map<String, dynamic> _parseChatResponse(String body) {
    Map<String, dynamic> outer;
    try {
      outer = jsonDecode(body) as Map<String, dynamic>;
    } catch (e) {
      throw BytezFormatException('Could not parse Bytez response: $e');
    }
    final choices = outer['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      throw BytezFormatException('Bytez response had no choices');
    }
    final first = choices.first as Map<String, dynamic>;
    final message = first['message'] as Map<String, dynamic>?;
    final content = message?['content'];
    if (content is! String || content.isEmpty) {
      throw BytezFormatException('Bytez response had empty content');
    }
    return _parseJsonContent(content);
  }

  /// The model returns content as a JSON string (because we set
  /// `response_format=json_object`). The string itself is sometimes
  /// wrapped in ```json fences — strip them before parsing.
  Map<String, dynamic> _parseJsonContent(String content) {
    var s = content.trim();
    if (s.startsWith('```')) {
      // Strip leading ```json or ``` and trailing ```
      final firstNewline = s.indexOf('\n');
      if (firstNewline > 0) s = s.substring(firstNewline + 1);
      if (s.endsWith('```')) s = s.substring(0, s.length - 3);
      s = s.trim();
    }
    try {
      return jsonDecode(s) as Map<String, dynamic>;
    } catch (e) {
      throw BytezFormatException(
        'Model returned non-JSON content. First 200 chars: '
        '${s.substring(0, s.length.clamp(0, 200))}',
      );
    }
  }

  // -- prompts -------------------------------------------------------

  /// 12 themes cycled by day-of-launch modulo 12. Order is curated
  /// so the same theme doesn't repeat on consecutive days.
  static const _puzzleThemes = <String>[
    'knight fork',
    'pin (absolute or relative)',
    'skewer',
    'discovered attack',
    'back rank weakness',
    'double attack',
    'removing the defender',
    'deflection',
    'overloaded piece',
    'mate in 2',
    'promotion',
    'zwischenzug (in-between move)',
  ];

  String _puzzleThemeForDay(int day) {
    final i = ((day - 1) % _puzzleThemes.length);
    return _puzzleThemes[i];
  }

  /// 16 lesson topics, never repeating within the first 16 generated
  /// days. Picks based on dayNumber so the user gets a progression
  /// (moves -> tactics -> strategy -> endgames).
  static const _lessonTopics = <String>[
    'deflection and decoy',
    'how to spot a pin',
    'skewers in action',
    'discovered checks',
    'opposite-coloured bishop endgames',
    'the minority attack',
    'prophylaxis: preventing opponent plans',
    'outposts and weak squares',
    'the exchange sacrifice',
    'pawn structure: isolated pawn',
    'pawn structure: hanging pawns',
    'mate in 2 patterns',
    'mate in 3 patterns',
    'rook endgame technique',
    'queen vs rook endgames',
    'zugzwang positions',
  ];

  String _lessonTopicForDay(int dayNumber) {
    final i = ((dayNumber - 11) % _lessonTopics.length);
    return _lessonTopics[i < 0 ? i + _lessonTopics.length : i];
  }

  String get _puzzleSystemPrompt => '''
You are a chess coach generating a single tactical puzzle for a
chess-learning app. The puzzle is shown on a phone screen; the user
taps the destination square of the best move.

OUTPUT FORMAT — return a single JSON object, no commentary, no
markdown fences. Schema:

{
  "id": "puzzle_<short_unique>",
  "title": "Short tactic name (e.g. 'Knight Fork')",
  "prompt": "One sentence telling the user what to find. e.g. 'White to move. Find a square where the knight attacks two pieces at once.'",
  "board": { "e1": "K", "d4": "N", "a8": "r", "e8": "k", ... },
  "uciMove": "d4c6",
  "explanation": "Why this move works. 1-3 sentences."
}

Board encoding: square name (a1-h8) -> piece code.
  K=White king, Q=White queen, R=White rook, B=White bishop, N=White knight, P=White pawn (uppercase)
  k=Black king, q=Black queen, r=Black rook, b=Black bishop, n=Black knight, p=Black pawn (lowercase)
The board does not need to be a full 32-piece start position — just
include all the pieces relevant to the tactic. The kings MUST both be
on the board (one white, one black). Pawns cannot be on rank 1 or 8.
uciMove: 4 chars (e.g. "e2e4") or 5 chars with promotion (e.g. "e7e8q").

CRITICAL:
- The uciMove's destination square must match the prompt — the user
  has to TAP that square to win.
- The puzzle must have exactly one clear best move. The explanation
  must justify why that move is best.
- Do not invent pieces. The board must be internally consistent
  (e.g. a knight on a square can only reach L-shaped destinations).
''';

  String _puzzleUserPrompt({
    required int day,
    required String theme,
    required int userLevel,
  }) {
    final difficulty = (userLevel / 10).clamp(0.1, 1.0).toStringAsFixed(1);
    return '''
Generate today's puzzle.

- Day index: $day
- Theme: $theme
- User level: $userLevel completed lessons (difficulty $difficulty on a 0-1 scale)
- Side to move: White
- Move count: single move (the user just needs to find the right square)
- Keep total pieces on the board to 6-10 so the board is readable on a phone
- The destination square of uciMove must be tactically obvious given the theme
''';
  }

  String get _lessonSystemPrompt => '''
You are a chess coach generating a 3-question micro-lesson for a
chess-learning app. The user progresses through each question and
sees feedback. Keep the lesson short (3 questions, ~5-8 minutes).

OUTPUT FORMAT — return a single JSON object, no commentary, no
markdown fences. Schema:

{
  "id": "lesson_<short_unique>",
  "title": "Short lesson title",
  "estimatedMinutes": 5,
  "questions": [
    {
      "id": "q1",
      "shellType": "multipleChoice" | "tapSquare",
      "prompt": "Question text. State the position and what the user should do.",
      "options": ["A", "B", "C", "D"],      // multipleChoice only
      "correctIndex": 0,                    // multipleChoice only
      "board": { "e1": "K", ... },          // tapSquare only
      "correctSquare": "e4",                // tapSquare only
      "explanation": "Why the answer is correct. 1-2 sentences."
    },
    ...
  ]
}

The lesson MUST mix the two shell types — at least one multipleChoice
AND at least one tapSquare. The first question should be a
multipleChoice (concept question). The second should be a tapSquare
(apply the concept on a real board). The third can be either.

Board encoding: same as puzzles. Kings must be present. Pawns
cannot be on rank 1 or 8. Keep total pieces to 6-10 per board.

CRITICAL:
- Multiple choice options must be plausibly similar (no obviously
  wrong answers). One must be unambiguously correct.
- tapSquare correctSquare must be reachable by a legal move from
  the position shown.
- All explanations must teach a CONCEPT, not just say "correct".
''';

  String _lessonUserPrompt({
    required int dayNumber,
    required String topic,
    required int userLevel,
  }) {
    final difficulty = (userLevel / 10).clamp(0.1, 1.0).toStringAsFixed(1);
    return '''
Generate lesson day $dayNumber.

- Topic: $topic
- User level: $userLevel completed lessons (difficulty $difficulty on a 0-1 scale)
- 3 questions, mix multipleChoice and tapSquare
- Total pieces per board: 6-10
- The lesson should teach ONE clear concept from the topic
''';
  }

  // -- parsers + validators -----------------------------------------

  Puzzle _parsePuzzle(Map<String, dynamic> json, {required int day}) {
    final id = (json['id'] as String?)?.trim();
    final title = (json['title'] as String?)?.trim();
    final prompt = (json['prompt'] as String?)?.trim();
    final explanation = (json['explanation'] as String?)?.trim();
    final uciMove = (json['uciMove'] as String?)?.trim();
    final boardRaw = json['board'];

    if (id == null || id.isEmpty) {
      throw BytezFormatException('Puzzle missing "id"');
    }
    if (title == null || title.isEmpty) {
      throw BytezFormatException('Puzzle "$id" missing "title"');
    }
    if (prompt == null || prompt.isEmpty) {
      throw BytezFormatException('Puzzle "$id" missing "prompt"');
    }
    if (explanation == null || explanation.isEmpty) {
      throw BytezFormatException('Puzzle "$id" missing "explanation"');
    }
    if (uciMove == null) {
      throw BytezFormatException('Puzzle "$id" missing "uciMove"');
    }
    if (boardRaw is! Map<String, dynamic>) {
      throw BytezFormatException(
        'Puzzle "$id" "board" must be an object',
      );
    }
    final board = boardRaw.cast<String, dynamic>();

    final boardErr = _validateBoard(board);
    if (boardErr != null) {
      throw BytezFormatException('Puzzle "$id" invalid board: $boardErr');
    }
    final moveErr = _validateUci(uciMove);
    if (moveErr != null) {
      throw BytezFormatException(
        'Puzzle "$id" invalid uciMove "$uciMove": $moveErr',
      );
    }

    return Puzzle(
      id: id,
      day: day,
      title: title,
      prompt: prompt,
      board: board.cast<String, String>(),
      uciMove: uciMove,
      explanation: explanation,
    );
  }

  Lesson _parseLesson(
    Map<String, dynamic> json, {
    required int day,
    required String title,
  }) {
    final id = (json['id'] as String?)?.trim();
    final t = (json['title'] as String?)?.trim();
    final estimatedMinutes = (json['estimatedMinutes'] as num?)?.toInt() ?? 5;
    final questionsRaw = json['questions'];

    if (id == null || id.isEmpty) {
      throw BytezFormatException('Lesson missing "id"');
    }
    if (t == null || t.isEmpty) {
      throw BytezFormatException('Lesson "$id" missing "title"');
    }
    if (questionsRaw is! List<dynamic> || questionsRaw.isEmpty) {
      throw BytezFormatException(
        'Lesson "$id" "questions" must be a non-empty list',
      );
    }
    if (questionsRaw.length < 2 || questionsRaw.length > 6) {
      throw BytezFormatException(
        'Lesson "$id" must have 2-6 questions, got ${questionsRaw.length}',
      );
    }

    final questions = <LessonQuestion>[];
    for (var i = 0; i < questionsRaw.length; i++) {
      final q = questionsRaw[i];
      if (q is! Map<String, dynamic>) {
        throw BytezFormatException(
          'Lesson "$id" question $i must be an object',
        );
      }
      questions.add(_parseLessonQuestion(id, i, q));
    }

    return Lesson(
      id: id,
      day: day,
      title: t,
      estimatedMinutes: estimatedMinutes,
      questions: questions,
    );
  }

  LessonQuestion _parseLessonQuestion(
    String lessonId,
    int idx,
    Map<String, dynamic> json,
  ) {
    final qid = (json['id'] as String?)?.trim() ?? 'q${idx + 1}';
    final shellTypeStr = (json['shellType'] as String?)?.trim();
    final prompt = (json['prompt'] as String?)?.trim();
    final explanation = (json['explanation'] as String?)?.trim();

    if (shellTypeStr == null) {
      throw BytezFormatException(
        'Lesson "$lessonId" $qid missing "shellType"',
      );
    }
    if (prompt == null || prompt.isEmpty) {
      throw BytezFormatException(
        'Lesson "$lessonId" $qid missing "prompt"',
      );
    }
    if (explanation == null || explanation.isEmpty) {
      throw BytezFormatException(
        'Lesson "$lessonId" $qid missing "explanation"',
      );
    }

    final LessonShellType shell;
    switch (shellTypeStr) {
      case 'multipleChoice':
      case 'nameOpening':
        shell = LessonShellType.multipleChoice;
        break;
      case 'tapSquare':
      case 'findCheckmate':
      case 'tapWeakSquare':
        shell = LessonShellType.tapSquare;
        break;
      default:
        throw BytezFormatException(
          'Lesson "$lessonId" $qid unsupported shellType "$shellTypeStr"',
        );
    }

    if (shell == LessonShellType.multipleChoice) {
      final options = (json['options'] as List<dynamic>?)?.cast<String>();
      final correctIndex = (json['correctIndex'] as num?)?.toInt();
      if (options == null || options.length < 2) {
        throw BytezFormatException(
          'Lesson "$lessonId" $qid multipleChoice needs >=2 options',
        );
      }
      if (correctIndex == null ||
          correctIndex < 0 ||
          correctIndex >= options.length) {
        throw BytezFormatException(
          'Lesson "$lessonId" $qid correctIndex '
          '$correctIndex out of range 0..${options.length - 1}',
        );
      }
      return LessonQuestion(
        id: qid,
        shellType: shell,
        prompt: prompt,
        options: options,
        correctIndex: correctIndex,
        explanation: explanation,
      );
    }

    // tapSquare
    final boardRaw = json['board'];
    if (boardRaw is! Map<String, dynamic>) {
      throw BytezFormatException(
        'Lesson "$lessonId" $qid tapSquare needs "board" object',
      );
    }
    final board = boardRaw.cast<String, dynamic>();
    final boardErr = _validateBoard(board);
    if (boardErr != null) {
      throw BytezFormatException(
        'Lesson "$lessonId" $qid invalid board: $boardErr',
      );
    }
    final correctSquare = (json['correctSquare'] as String?)?.trim();
    if (correctSquare == null || correctSquare.length != 2) {
      throw BytezFormatException(
        'Lesson "$lessonId" $qid tapSquare needs "correctSquare"',
      );
    }
    final sqErr = _validateSquare(correctSquare);
    if (sqErr != null) {
      throw BytezFormatException(
        'Lesson "$lessonId" $qid correctSquare invalid: $sqErr',
      );
    }
    return LessonQuestion(
      id: qid,
      shellType: shell,
      prompt: prompt,
      board: board.cast<String, String>(),
      correctSquare: correctSquare.toLowerCase(),
      explanation: explanation,
    );
  }

  // -- chess-position validators ------------------------------------

  String? _validateBoard(Map<String, dynamic> board) {
    if (board.isEmpty) return 'board is empty';
    bool hasWhiteKing = false;
    bool hasBlackKing = false;
    for (final entry in board.entries) {
      final sqErr = _validateSquare(entry.key);
      if (sqErr != null) return 'square ${entry.key}: $sqErr';
      final piece = entry.value;
      if (piece is! String || piece.length != 1) {
        return 'piece at ${entry.key} must be single char, got "$piece"';
      }
      final code = piece.toUpperCase();
      if (!'KQRBNP'.contains(code)) {
        return 'piece at ${entry.key} is invalid code "$piece"';
      }
      if (piece == 'K') hasWhiteKing = true;
      if (piece == 'k') hasBlackKing = true;
      if (code == 'P' &&
          (entry.key.endsWith('1') || entry.key.endsWith('8'))) {
        return 'pawn at ${entry.key} cannot be on rank 1 or 8';
      }
    }
    if (!hasWhiteKing) return 'board has no white king';
    if (!hasBlackKing) return 'board has no black king';
    return null;
  }

  String? _validateSquare(String s) {
    if (s.length != 2) return 'square must be 2 chars';
    final file = s.codeUnitAt(0);
    final rank = s.codeUnitAt(1);
    if (file < 0x61 || file > 0x68) {
      return 'square file must be a-h, got "${s[0]}"';
    }
    if (rank < 0x31 || rank > 0x38) {
      return 'square rank must be 1-8, got "${s[1]}"';
    }
    return null;
  }

  String? _validateUci(String uci) {
    if (uci.length != 4 && uci.length != 5) {
      return 'UCI move must be 4 or 5 chars';
    }
    final fromErr = _validateSquare(uci.substring(0, 2));
    if (fromErr != null) return 'from-square: $fromErr';
    final toErr = _validateSquare(uci.substring(2, 4));
    if (toErr != null) return 'to-square: $toErr';
    if (uci.length == 5) {
      final promo = uci[4];
      if (!'qrbn'.contains(promo.toLowerCase())) {
        return 'promotion must be one of q,r,b,n';
      }
    }
    return null;
  }
}

class BytezException implements Exception {
  final String message;
  final int? statusCode;
  BytezException(this.message, {this.statusCode});
  @override
  String toString() => 'BytezException: $message';
}

class BytezAuthException extends BytezException {
  BytezAuthException(super.message, {super.statusCode});
  @override
  String toString() => 'BytezAuthException: $message';
}

class BytezFormatException extends BytezException {
  BytezFormatException(super.message);
  @override
  String toString() => 'BytezFormatException: $message';
}
