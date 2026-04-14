import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:FocusFlow/views/app_shell.dart';

// ─── Paste the same Gemini API key used in ai_agent_view.dart ────────────────
const String _geminiApiKey = 'API_Key';
// ─────────────────────────────────────────────────────────────────────────────

// ═══════════════════════════════════════════════════════════════════════════════
// GEMINI HELPER
// ═══════════════════════════════════════════════════════════════════════════════

Future<String> _callGemini(String prompt,
    {int maxTokens = 1500, double temp = 0.7, bool expectJson = false}) async {
  final url = Uri.parse(
    'https://generativelanguage.googleapis.com/v1beta/models/'
    'gemini-2.5-flash:generateContent?key=AIzaSyCbsJ9WyBfqR2WyMIfZ787XFAptDZEl2HY',
  );

  final body = jsonEncode({
    'contents': [
      {
        'role': 'user',
        'parts': [
          {'text': prompt}
        ],
      }
    ],
    'generationConfig': {
      'temperature': temp,
      'maxOutputTokens': maxTokens,
      if (expectJson) 'responseMimeType': 'application/json',
    },
  });

  late http.Response response;
  bool assigned = false;
  for (int attempt = 1; attempt <= 3; attempt++) {
    try {
      response = await http
          .post(url,
              headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(const Duration(seconds: 45));
      assigned = true;
      break;
    } catch (e) {
      if (attempt == 3) rethrow;
      await Future.delayed(Duration(seconds: attempt * 2));
    }
  }
  if (!assigned) {
    throw Exception('Failed to get Gemini response after 3 retries (timeout/network)');
  }

  if (response.statusCode == 503) {
    throw Exception('Gemini service temporarily unavailable (503). Wait 1-2 min and retry. Check quota at https://aistudio.google.com/app/apikey.');
  }
  if (response.statusCode == 429) {
    throw Exception('Gemini rate limit exceeded (429). Wait 1 min and retry.');
  }
  if (response.statusCode != 200) {
    throw Exception('Gemini error ${response.statusCode}');
  }

  final data = jsonDecode(response.body);
  return (data['candidates'][0]['content']['parts'][0]['text'] as String)
      .trim();
}

// ═══════════════════════════════════════════════════════════════════════════════
// ROOT SCREEN
// ═══════════════════════════════════════════════════════════════════════════════

class StudyBuddyView extends StatefulWidget {
  const StudyBuddyView({super.key});

  @override
  State<StudyBuddyView> createState() => _StudyBuddyViewState();
}

class _StudyBuddyViewState extends State<StudyBuddyView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FF.bg,
      appBar: AppBar(
        backgroundColor: FF.bg,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3DDC84), Color(0xFF4F8EF7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.school_rounded,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Study Buddy',
                  style: TextStyle(
                    color: FF.textPri,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
                Text('Powered by Gemini',
                    style: TextStyle(color: FF.textSec, fontSize: 11)),
              ],
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: FF.accent,
          labelColor: FF.accent,
          unselectedLabelColor: FF.textSec,
          labelStyle:
              const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          tabs: const [
            Tab(icon: Icon(Icons.style_rounded, size: 18), text: 'Flashcards'),
            Tab(icon: Icon(Icons.quiz_rounded, size: 18), text: 'Quiz'),
            Tab(icon: Icon(Icons.notes_rounded, size: 18), text: 'Notes'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          FlashcardsTab(),
          QuizTab(),
          NotesTab(),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SHARED TOPIC INPUT WIDGET
// ═══════════════════════════════════════════════════════════════════════════════

class _TopicInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool loading;
  final VoidCallback onGenerate;

  const _TopicInput({
    required this.controller,
    required this.hint,
    required this.loading,
    required this.onGenerate,
  });

  // ── Robust JSON array parser for Gemini responses ──────────────────────────
  List<Map<String, String>> _parseGeminiJsonArray(String raw, {required String expectedKeys}) {
    // Strip markdown, whitespace
    var cleaned = raw
        .replaceAll(RegExp(r'```json\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'```\s*$', multiLine: true), '')
        .replaceAll(RegExp(r'//.*'), '')
        .trim();

    // Regex to extract outermost array: [ ... ] even if incomplete
    final arrayMatch = RegExp(r'\[\s*(.*?)\s*\]?', dotAll: true).firstMatch(cleaned);
    if (arrayMatch == null) {
      throw FormatException('No JSON array found in Gemini response');
    }
    cleaned = '[${arrayMatch.group(1)!}]'; // Ensure closed

    // Fix common Gemini issues: trailing commas, unquoted keys
    cleaned = cleaned
        .replaceAll(RegExp(r',\s*(\]|\})'), r'$1') // trailing comma
        .replaceAll(RegExp(r'"([^"]+)":', caseSensitive: false), r'"$1":'); // keys

    try {
      final list = jsonDecode(cleaned) as List;
      final result = <Map<String, String>>[];
      for (final item in list) {
        if (item is! Map<String, dynamic>) continue;
        final front = (item['front'] ?? item['question'] ?? '').toString().trim();
        final back = (item['back'] ?? item['answer'] ?? '').toString().trim();
        if (front.isNotEmpty && back.isNotEmpty) {
          result.add({'front': front, 'back': back});
        }
      }
      if (result.length < 3 || result.length > 15) {
        throw FormatException('Invalid number of valid cards: ${result.length}');
      }
      return result.take(12).toList();
    } catch (e) {
      throw FormatException('Failed to parse Gemini JSON: $e\nRaw: $raw');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              style: TextStyle(color: FF.textPri, fontSize: 14),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: FF.textSec, fontSize: 14),
                filled: true,
                fillColor: FF.card,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: FF.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: FF.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: FF.accent),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: ElevatedButton(
              onPressed: loading ? null : onGenerate,
              style: ElevatedButton.styleFrom(
                backgroundColor: FF.accent,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Row(
                      children: [
                        Icon(Icons.auto_awesome_rounded, size: 16),
                        SizedBox(width: 6),
                        Text('Generate',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700)),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// FLASHCARDS TAB
// ═══════════════════════════════════════════════════════════════════════════════

class FlashcardsTab extends StatefulWidget {
  const FlashcardsTab({super.key});

  @override
  State<FlashcardsTab> createState() => _FlashcardsTabState();
}

class _FlashcardsTabState extends State<FlashcardsTab> {
  final _topicCtrl = TextEditingController();
  List<Map<String, String>> _cards = [];
  int _current = 0;
  bool _flipped = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _topicCtrl.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final topic = _topicCtrl.text.trim();
    if (topic.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
      _cards = [];
      _current = 0;
      _flipped = false;
    });

    try {
      final prompt = '''
Generate exactly 8 flashcards about: "$topic"

Return ONLY a valid JSON array with no extra text, markdown, or explanation.
Each item must have exactly two keys: "front" and "back".
The "front" is a concise question or term (max 15 words).
The "back" is a clear answer or definition (max 40 words).

Example format:
[
  {"front": "What is photosynthesis?", "back": "The process by which plants use sunlight, water, and CO2 to produce oxygen and glucose."},
  ...
]
''';

      final raw = await _callGemini(prompt, maxTokens: 1200, temp: 0.5, expectJson: true);

      // strip markdown fences if present
      var cleaned = raw
          .replaceAll(RegExp(r'```json', caseSensitive: false), '')
          .replaceAll(RegExp(r'```'), '')
          .trim();

      List list;
      try {
        final parsed = jsonDecode(cleaned);
        if (parsed is List) {
          list = parsed;
        } else if (parsed is Map && parsed.values.any((v) => v is List)) {
          list = parsed.values.firstWhere((v) => v is List) as List;
        } else {
          throw FormatException();
        }
      } catch (_) {
        final start = cleaned.indexOf('[');
        final end   = cleaned.lastIndexOf(']');
        if (start == -1 || end == -1) {
          throw Exception('Invalid JSON from Gemini:\\n$raw');
        }
        cleaned = cleaned.substring(start, end + 1);
        list = jsonDecode(cleaned) as List;
      }

      setState(() {
        _cards = list
            .map<Map<String, String>>((e) => {
                  'front': e['front'] as String,
                  'back':  e['back']  as String,
                })
            .toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _next() {
    setState(() {
      _flipped = false;
      _current = (_current + 1) % _cards.length;
    });
  }

  void _prev() {
    setState(() {
      _flipped = false;
      _current = (_current - 1 + _cards.length) % _cards.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TopicInput(
          controller: _topicCtrl,
          hint: 'Enter topic (e.g. Photosynthesis)',
          loading: _loading,
          onGenerate: _generate,
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('⚠️ $_error',
                style: TextStyle(color: FF.danger, fontSize: 12)),
          ),
        if (_cards.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Card ${_current + 1} of ${_cards.length}',
                  style: TextStyle(
                      color: FF.textSec,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
                Text(
                  'Tap card to reveal answer',
                  style: TextStyle(color: FF.textSec, fontSize: 11),
                ),
              ],
            ),
          ),
          // Progress bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (_current + 1) / _cards.length,
                backgroundColor: FF.card,
                color: FF.accent,
                minHeight: 4,
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _flipped = !_flipped),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: _FlipCard(
                  front: _cards[_current]['front']!,
                  back:  _cards[_current]['back']!,
                  flipped: _flipped,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _prev,
                    icon: const Icon(Icons.arrow_back_ios_rounded, size: 14),
                    label: const Text('Prev'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: FF.textPri,
                      side: BorderSide(color: FF.divider),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _next,
                    icon: const Text('Next'),
                    label: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FF.accent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ] else if (!_loading)
          Expanded(child: _EmptyPrompt(
            icon: Icons.style_rounded,
            label: 'Enter a topic above to generate flashcards',
          )),
      ],
    );
  }
}

// Flip Card widget
class _FlipCard extends StatefulWidget {
  final String front;
  final String back;
  final bool flipped;

  const _FlipCard({
    required this.front,
    required this.back,
    required this.flipped,
  });

  @override
  State<_FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<_FlipCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _anim = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(_FlipCard old) {
    super.didUpdateWidget(old);
    if (widget.flipped != old.flipped) {
      if (widget.flipped) {
        _ctrl.forward();
      } else {
        _ctrl.reverse();
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final angle = _anim.value * pi;
        final isFront = angle < pi / 2;
        final displayAngle = isFront ? angle : angle - pi;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(displayAngle),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: isFront
                  ? LinearGradient(
                      colors: [FF.card, FF.surface],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : const LinearGradient(
                      colors: [Color(0xFF4F8EF7), Color(0xFF3DDC84)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              borderRadius: BorderRadius.circular(24),
              border: isFront ? Border.all(color: FF.divider) : null,
              boxShadow: [
                BoxShadow(
                  color: (isFront ? FF.accent : const Color(0xFF3DDC84))
                      .withOpacity(0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isFront
                          ? Icons.help_outline_rounded
                          : Icons.lightbulb_rounded,
                      color: isFront ? FF.textSec : Colors.white70,
                      size: 32,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      isFront ? widget.front : widget.back,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isFront ? FF.textPri : Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isFront ? 'TAP TO FLIP' : 'ANSWER',
                      style: TextStyle(
                        color: isFront
                            ? FF.textSec.withOpacity(0.5)
                            : Colors.white54,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// QUIZ TAB
// ═══════════════════════════════════════════════════════════════════════════════

class QuizQuestion {
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  QuizQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });
}

class QuizTab extends StatefulWidget {
  const QuizTab({super.key});

  @override
  State<QuizTab> createState() => _QuizTabState();
}

class _QuizTabState extends State<QuizTab> {
  final _topicCtrl = TextEditingController();
  List<QuizQuestion> _questions = [];
  int _current = 0;
  int? _selected;
  bool _answered = false;
  int _score = 0;
  bool _finished = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _topicCtrl.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final topic = _topicCtrl.text.trim();
    if (topic.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
      _questions = [];
      _current = 0;
      _selected = null;
      _answered = false;
      _score = 0;
      _finished = false;
    });

    try {
      final prompt = '''
Generate exactly 6 multiple-choice quiz questions about: "$topic"

Return ONLY a valid JSON array with no extra text, markdown, or explanation.
Each item must have:
  - "question": the question string (max 20 words)
  - "options": array of exactly 4 answer strings (keep each under 12 words)
  - "correct": integer index (0-3) of the correct option
  - "explanation": one sentence explaining why the correct answer is right (max 30 words)

Example:
[
  {
    "question": "What organelle performs photosynthesis?",
    "options": ["Mitochondria", "Chloroplast", "Nucleus", "Ribosome"],
    "correct": 1,
    "explanation": "Chloroplasts contain chlorophyll that absorbs sunlight to drive the photosynthesis reaction."
  }
]
''';

      final raw = await _callGemini(prompt, maxTokens: 1500, temp: 0.4, expectJson: true);

      var cleaned = raw
          .replaceAll(RegExp(r'```json', caseSensitive: false), '')
          .replaceAll(RegExp(r'```'), '')
          .trim();

      List list;
      try {
        final parsed = jsonDecode(cleaned);
        if (parsed is List) {
          list = parsed;
        } else if (parsed is Map && parsed.values.any((v) => v is List)) {
          list = parsed.values.firstWhere((v) => v is List) as List;
        } else {
          throw FormatException();
        }
      } catch (_) {
        final start = cleaned.indexOf('[');
        final end   = cleaned.lastIndexOf(']');
        if (start == -1 || end == -1) {
          throw Exception('Invalid JSON from Gemini:\\n$raw');
        }
        cleaned = cleaned.substring(start, end + 1);
        list = jsonDecode(cleaned) as List;
      }

      setState(() {
        _questions = list.map<QuizQuestion>((e) {
          final opts = List<String>.from(e['options'] as List);
          return QuizQuestion(
            question: e['question'] as String,
            options: opts,
            correctIndex: (e['correct'] as num).toInt(),
            explanation: e['explanation'] as String,
          );
        }).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _answer(int idx) {
    if (_answered) return;
    setState(() {
      _selected = idx;
      _answered = true;
      if (idx == _questions[_current].correctIndex) _score++;
    });
  }

  void _next() {
    if (_current + 1 >= _questions.length) {
      setState(() => _finished = true);
    } else {
      setState(() {
        _current++;
        _selected = null;
        _answered = false;
      });
    }
  }

  void _restart() {
    setState(() {
      _current = 0;
      _selected = null;
      _answered = false;
      _score = 0;
      _finished = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TopicInput(
          controller: _topicCtrl,
          hint: 'Enter topic (e.g. World War II)',
          loading: _loading,
          onGenerate: _generate,
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('⚠️ $_error',
                style: TextStyle(color: FF.danger, fontSize: 12)),
          ),
        if (_questions.isNotEmpty && !_finished) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Question ${_current + 1}/${_questions.length}',
                  style: TextStyle(
                      color: FF.textSec,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: FF.success.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Score: $_score',
                    style: TextStyle(
                        color: FF.success,
                        fontSize: 12,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (_current + 1) / _questions.length,
                backgroundColor: FF.card,
                color: FF.accent,
                minHeight: 4,
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _QuizCard(
                question: _questions[_current],
                selected: _selected,
                answered: _answered,
                onAnswer: _answer,
              ),
            ),
          ),
          if (_answered)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FF.accent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    _current + 1 >= _questions.length
                        ? 'See Results'
                        : 'Next Question',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
        ] else if (_finished)
          Expanded(
            child: _QuizResults(
              score: _score,
              total: _questions.length,
              onRetry: _restart,
              onNew: _generate,
            ),
          )
        else if (!_loading)
          Expanded(child: _EmptyPrompt(
            icon: Icons.quiz_rounded,
            label: 'Enter a topic above to generate a quiz',
          )),
      ],
    );
  }
}

class _QuizCard extends StatelessWidget {
  final QuizQuestion question;
  final int? selected;
  final bool answered;
  final ValueChanged<int> onAnswer;

  const _QuizCard({
    required this.question,
    required this.selected,
    required this.answered,
    required this.onAnswer,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: FF.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: FF.divider),
          ),
          child: Text(
            question.question,
            style: TextStyle(
              color: FF.textPri,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 16),
        ...List.generate(question.options.length, (i) {
          Color bg = FF.card;
          Color border = FF.divider;
          Color text = FF.textPri;
          IconData? icon;

          if (answered) {
            if (i == question.correctIndex) {
              bg     = FF.success.withOpacity(0.12);
              border = FF.success;
              text   = FF.success;
              icon   = Icons.check_circle_rounded;
            } else if (i == selected) {
              bg     = FF.danger.withOpacity(0.12);
              border = FF.danger;
              text   = FF.danger;
              icon   = Icons.cancel_rounded;
            }
          } else if (selected == i) {
            bg     = FF.accentSoft;
            border = FF.accent;
          }

          return GestureDetector(
            onTap: () => onAnswer(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 10),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: border, width: 1.5),
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: border.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        ['A', 'B', 'C', 'D'][i],
                        style: TextStyle(
                          color: text,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      question.options[i],
                      style: TextStyle(
                        color: text,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ),
                  if (icon != null) ...[
                    const SizedBox(width: 8),
                    Icon(icon, color: text, size: 20),
                  ],
                ],
              ),
            ),
          );
        }),
        if (answered) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: FF.accentSoft.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: FF.accentSoft),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_rounded, color: FF.accent, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    question.explanation,
                    style: TextStyle(
                      color: FF.textSec,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _QuizResults extends StatelessWidget {
  final int score;
  final int total;
  final VoidCallback onRetry;
  final VoidCallback onNew;

  const _QuizResults({
    required this.score,
    required this.total,
    required this.onRetry,
    required this.onNew,
  });

  @override
  Widget build(BuildContext context) {
    final pct = score / total;
    final emoji = pct == 1.0
        ? '🏆'
        : pct >= 0.7
            ? '🎉'
            : pct >= 0.5
                ? '😊'
                : '📚';
    final msg = pct == 1.0
        ? 'Perfect score!'
        : pct >= 0.7
            ? 'Great job!'
            : pct >= 0.5
                ? 'Good effort!'
                : 'Keep studying!';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text(
              msg,
              style: TextStyle(
                  color: FF.textPri,
                  fontSize: 24,
                  fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'You scored $score out of $total',
              style: TextStyle(color: FF.textSec, fontSize: 15),
            ),
            const SizedBox(height: 24),
            // Score ring
            SizedBox(
              width: 100,
              height: 100,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: pct,
                    strokeWidth: 8,
                    backgroundColor: FF.card,
                    color: pct >= 0.7 ? FF.success : FF.warning,
                  ),
                  Text(
                    '${(pct * 100).toInt()}%',
                    style: TextStyle(
                      color: FF.textPri,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.replay_rounded, size: 18),
                label: const Text('Retry Same Quiz'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: FF.accent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onNew,
                icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                label: const Text('Generate New Quiz'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: FF.textPri,
                  side: BorderSide(color: FF.divider),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// NOTES TAB
// ═══════════════════════════════════════════════════════════════════════════════

class NotesTab extends StatefulWidget {
  const NotesTab({super.key});

  @override
  State<NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends State<NotesTab> {
  final _topicCtrl = TextEditingController();
  String _notes = '';
  bool _loading = false;
  String? _error;
  String _style = 'Summary';

  final _styles = ['Summary', 'Bullet Points', 'Mind Map', 'Study Sheet'];

  @override
  void dispose() {
    _topicCtrl.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final topic = _topicCtrl.text.trim();
    if (topic.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
      _notes = '';
    });

    try {
      final styleInstruction = switch (_style) {
        'Summary'      => 'Write a clear, well-structured summary with 3-4 short paragraphs covering the key concepts.',
        'Bullet Points'=> 'Write organized bullet-point notes using • for main points and  – for sub-points. Group related points under bold headings.',
        'Mind Map'     => 'Create a text-based mind map. Put the central topic at the top, then use indented levels (→, ••, --) to show branches and sub-branches of related concepts.',
        'Study Sheet'  => 'Create a structured study sheet with sections: KEY CONCEPTS, IMPORTANT FACTS, DEFINITIONS, and REMEMBER THIS. Use clear headings.',
        _ => 'Write clear, concise notes.',
      };

      final prompt = '''
Create study notes about: "$topic"

Format: $_style
$styleInstruction

Keep the total response under 400 words. Make it student-friendly, accurate, and easy to review.
Do not add any preamble like "Here are your notes" — start the content directly.
''';

      final result = await _callGemini(prompt, maxTokens: 1000, temp: 0.6);
      setState(() {
        _notes = result;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TopicInput(
          controller: _topicCtrl,
          hint: 'Enter topic (e.g. Newton\'s Laws)',
          loading: _loading,
          onGenerate: _generate,
        ),
        // Style picker
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _styles.map((s) {
                final sel = s == _style;
                return GestureDetector(
                  onTap: () => setState(() => _style = s),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: sel ? FF.accent : FF.card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: sel ? FF.accent : FF.divider),
                    ),
                    child: Text(
                      s,
                      style: TextStyle(
                        color: sel ? Colors.white : FF.textSec,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('⚠️ $_error',
                style: TextStyle(color: FF.danger, fontSize: 12)),
          ),
        if (_notes.isNotEmpty)
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: FF.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: FF.divider),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: FF.accentSoft,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _style,
                            style: TextStyle(
                              color: FF.accent,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _topicCtrl.text.trim(),
                          style: TextStyle(
                              color: FF.textSec, fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _notes,
                      style: TextStyle(
                        color: FF.textPri,
                        fontSize: 14,
                        height: 1.7,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else if (!_loading)
          Expanded(child: _EmptyPrompt(
            icon: Icons.notes_rounded,
            label: 'Pick a style, enter a topic, and generate notes',
          )),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SHARED EMPTY STATE
// ═══════════════════════════════════════════════════════════════════════════════

class _EmptyPrompt extends StatelessWidget {
  final IconData icon;
  final String label;

  const _EmptyPrompt({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: FF.card,
              shape: BoxShape.circle,
              border: Border.all(color: FF.divider),
            ),
            child: Icon(icon, color: FF.textSec, size: 30),
          ),
          const SizedBox(height: 16),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(color: FF.textSec, fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }
}
