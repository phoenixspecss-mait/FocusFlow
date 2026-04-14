import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:FocusFlow/views/app_shell.dart';

// ─── GEMINI API KEY ────────────────────────────────────────────────────────────
const String _geminiApiKey = 'AIzaSyA_S6G9isQ7H5fb_d9NHNB0T6v9w1DeZQ4';
const String _geminiModel  = 'gemini-2.5-flash';
// ──────────────────────────────────────────────────────────────────────────────

const String _systemPrompt =
    'You are a friendly and helpful AI assistant inside FocusFlow, a Pomodoro and habit '
    'tracking app. While your specialty is helping users plan their day, improve focus, '
    'and build habits, you are also a general-purpose AI. You MUST cheerfully answer ANY '
    'question the user asks, regardless of the topic (e.g., math, trivia, coding, general '
    'knowledge). Keep replies concise, practical, and encouraging. Use bullet points or '
    'short paragraphs. Avoid long walls of text.';

// ── Document mode enum ────────────────────────────────────────────────────────
enum DocMode { flashcards, quiz, notes }

extension DocModeExt on DocMode {
  String get label {
    switch (this) {
      case DocMode.flashcards: return 'Flashcards';
      case DocMode.quiz:       return 'Quiz';
      case DocMode.notes:      return 'Notes';
    }
  }

  IconData get icon {
    switch (this) {
      case DocMode.flashcards: return Icons.style_rounded;
      case DocMode.quiz:       return Icons.quiz_rounded;
      case DocMode.notes:      return Icons.notes_rounded;
    }
  }

  String buildPrompt(String docText) {
    switch (this) {
      case DocMode.flashcards:
        return 'Generate 8–12 concise flashcards from the document below.\n'
            'Format each card as:\nQ: <question>\nA: <answer>\n\n'
            'Document:\n$docText';
      case DocMode.quiz:
        return 'Create a 6-question multiple-choice quiz from the document below.\n'
            'Format each question as:\nQ<n>: <question>\n'
            'A) <option>  B) <option>  C) <option>  D) <option>\n'
            'Answer: <letter>\n\nDocument:\n$docText';
      case DocMode.notes:
        return 'Summarise the document below into well-structured study notes.\n'
            'Use clear headings (##), bullet points, and highlight key terms in **bold**.\n\n'
            'Document:\n$docText';
    }
  }
}

// ── Main widget ───────────────────────────────────────────────────────────────
class AiAgentView extends StatefulWidget {
  const AiAgentView({super.key});

  @override
  State<AiAgentView> createState() => _AiAgentViewState();
}

class _AiAgentViewState extends State<AiAgentView> {
  final TextEditingController _ctrl   = TextEditingController();
  final ScrollController      _scroll = ScrollController();
  final List<Map<String, dynamic>> _history = [];

  final List<_Msg> _messages = [
    _Msg(
      text: "Hi! I'm your FocusFlow AI assistant ✨\n\n"
          "I can help you:\n"
          "• Plan your focus sessions\n"
          "• Suggest task priorities\n"
          "• Give productivity tips\n"
          "• Answer questions about your habits\n"
          "• Generate Flashcards, Quizzes & Notes from a document 📄\n\n"
          "What would you like to work on today?",
      isUser: false,
    ),
  ];

  bool    _thinking     = false;
  String? _uploadedDocText;
  String? _uploadedFileName;
  DocMode _selectedMode = DocMode.flashcards;
  bool    _showDocPanel = false;

  final List<String> _suggestions = [
    'How should I plan my day?',
    'Tips to improve focus',
    'Break down a big task',
    'Why am I feeling distracted?',
  ];

  // ── Gemini API ─────────────────────────────────────────────────────────────
  Future<String> _callGemini(String userMessage) async {
    _history.add({
      'role': 'user',
      'parts': [{'text': userMessage}],
    });

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/'
      '$_geminiModel:generateContent?key=$_geminiApiKey',
    );

    final body = jsonEncode({
      'system_instruction': {
        'parts': [{'text': _systemPrompt}],
      },
      'contents': _history,
      'generationConfig': {
        'temperature': 0.7,
        'maxOutputTokens': 1024,
      },
    });

    http.Response response;
    try {
      response = await http
          .post(url, headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(const Duration(seconds: 30));
    } catch (e) {
      _history.removeLast();
      throw Exception('Network error — check your connection.\nDetails: $e');
    }

    debugPrint('Gemini status: ${response.statusCode}');
    debugPrint('Gemini body:   ${response.body}');

    if (response.statusCode == 400) {
      _history.removeLast();
      throw Exception('Invalid API key or bad request (400).\nGet a new key at: https://aistudio.google.com');
    }
    if (response.statusCode == 403) {
      _history.removeLast();
      throw Exception('API key not authorized (403).\nEnable Gemini API at: https://console.cloud.google.com');
    }
    if (response.statusCode == 404) {
      _history.removeLast();
      throw Exception(
        'Model not found (404).\n'
        '"$_geminiModel" may not be available in your region.\n'
        'Try a new key at: https://aistudio.google.com',
      );
    }
    if (response.statusCode == 429) {
      _history.removeLast();
      throw Exception('Rate limit exceeded (429).\nWait 1 minute and try again.');
    }
    if (response.statusCode != 200) {
      _history.removeLast();
      final err = jsonDecode(response.body);
      throw Exception('Gemini error ${response.statusCode}:\n${err['error']?['message'] ?? response.body}');
    }

    final data  = jsonDecode(response.body);
    final reply = data['candidates'][0]['content']['parts'][0]['text'] as String;

    _history.add({
      'role': 'model',
      'parts': [{'text': reply}],
    });

    return reply.trim();
  }

  // ── Document paste dialog ──────────────────────────────────────────────────
  Future<void> _pickDocument() async {
    final pasteCtrl = TextEditingController();
    final nameCtrl  = TextEditingController(text: 'My Document');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FF.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.description_rounded, color: FF.accent, size: 20),
            const SizedBox(width: 8),
            Text('Paste Document Text',
                style: TextStyle(
                    color: FF.textPri,
                    fontWeight: FontWeight.w700,
                    fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Document name:',
                  style: TextStyle(color: FF.textSec, fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: nameCtrl,
                style: TextStyle(color: FF.textPri, fontSize: 13),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: FF.bg,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: FF.divider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: FF.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: FF.accent),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text('Paste your document content below:',
                  style: TextStyle(color: FF.textSec, fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: pasteCtrl,
                style: TextStyle(color: FF.textPri, fontSize: 13),
                maxLines: 8,
                decoration: InputDecoration(
                  hintText: 'Paste your notes, article, or any text here...',
                  hintStyle: TextStyle(color: FF.textSec, fontSize: 12),
                  filled: true,
                  fillColor: FF.bg,
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: FF.divider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: FF.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: FF.accent),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: FF.textSec)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: FF.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Use This Text'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final text = pasteCtrl.text.trim();
    if (text.isEmpty) {
      _showError('Please paste some text before continuing.');
      return;
    }

    final truncated = text.length > 8000
        ? '${text.substring(0, 8000)}\n\n[Truncated to 8 000 characters]'
        : text;

    setState(() {
      _uploadedDocText  = truncated;
      _uploadedFileName = nameCtrl.text.trim().isEmpty
          ? 'My Document'
          : nameCtrl.text.trim();
      _showDocPanel     = true;
    });
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  // ── Generate from doc ──────────────────────────────────────────────────────
  Future<void> _generateFromDoc() async {
    if (_uploadedDocText == null) return;
    final prompt = _selectedMode.buildPrompt(_uploadedDocText!);
    setState(() => _showDocPanel = false);
    await _send(
      '📄 Generate ${_selectedMode.label} from: $_uploadedFileName',
      overridePrompt: prompt,
    );
  }

  // ── Thin void wrapper for ValueChanged<String> callbacks ──────────────────
  void _sendFromInput(String text) => _send(text);

  // ── Core send ─────────────────────────────────────────────────────────────
  Future<void> _send(String displayText, {String? overridePrompt}) async {
    if (displayText.trim().isEmpty) return;
    _ctrl.clear();

    setState(() {
      _messages.add(_Msg(text: displayText.trim(), isUser: true));
      _thinking = true;
    });
    _scrollDown();

    try {
      final reply = await _callGemini(overridePrompt ?? displayText.trim());
      if (mounted) {
        setState(() {
          _thinking = false;
          _messages.add(_Msg(text: reply, isUser: false));
        });
        _scrollDown();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _thinking = false;
          _messages.add(_Msg(text: '⚠️ $e', isUser: false));
        });
        _scrollDown();
      }
    }
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────
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
                  colors: [Color(0xFF4F8EF7), Color(0xFFB06EF5)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.auto_awesome_rounded,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Focus AI',
                    style: TextStyle(
                        color: FF.textPri,
                        fontWeight: FontWeight.w800,
                        fontSize: 20)),
                Text('Powered by Gemini',
                    style: TextStyle(color: FF.textSec, fontSize: 11)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.upload_file_rounded, color: FF.accent),
            tooltip: 'Upload document',
            onPressed: _pickDocument,
          ),
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: FF.textSec),
            onPressed: () => setState(() {
              _messages.clear();
              _history.clear();
              _uploadedDocText  = null;
              _uploadedFileName = null;
              _showDocPanel     = false;
              _messages.add(_Msg(
                text: "Chat cleared! I'm ready to help you focus. What's on your mind?",
                isUser: false,
              ));
            }),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _messages.length + (_thinking ? 1 : 0),
              itemBuilder: (_, i) {
                if (i == _messages.length && _thinking) {
                  return const _ThinkingBubble();
                }
                return _MessageBubble(msg: _messages[i]);
              },
            ),
          ),
          if (_showDocPanel && _uploadedDocText != null) _buildDocPanel(),
          if (!_thinking && _messages.last.isUser == false && !_showDocPanel)
            _buildSuggestions(),
          _buildInputBar(),
        ],
      ),
    );
  }

  // ── Doc panel ─────────────────────────────────────────────────────────────
  Widget _buildDocPanel() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FF.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FF.accent.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.description_rounded, color: FF.accent, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _uploadedFileName ?? 'Document',
                  style: TextStyle(
                      color: FF.textPri,
                      fontWeight: FontWeight.w700,
                      fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              GestureDetector(
                onTap: () => setState(() {
                  _showDocPanel     = false;
                  _uploadedDocText  = null;
                  _uploadedFileName = null;
                }),
                child: Icon(Icons.close_rounded, color: FF.textSec, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('Generate:',
              style: TextStyle(
                  color: FF.textSec,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: DocMode.values.map((mode) {
              final selected = mode == _selectedMode;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedMode = mode),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? FF.accent
                          : FF.accentSoft.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected ? FF.accent : FF.divider,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(mode.icon,
                            color: selected ? Colors.white : FF.accent,
                            size: 18),
                        const SizedBox(height: 4),
                        Text(mode.label,
                            style: TextStyle(
                                color: selected ? Colors.white : FF.accent,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _generateFromDoc,
              icon: const Icon(Icons.auto_awesome_rounded, size: 16),
              label: Text('Generate ${_selectedMode.label}'),
              style: ElevatedButton.styleFrom(
                backgroundColor: FF.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Suggestions bar ────────────────────────────────────────────────────────
  Widget _buildSuggestions() {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: _suggestions.map((s) {
          return GestureDetector(
            onTap: () => _sendFromInput(s),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: FF.accentSoft.withOpacity(0.4),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: FF.accentSoft),
              ),
              child: Text(s,
                  style: TextStyle(
                      color: FF.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Input bar ─────────────────────────────────────────────────────────────
  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 10, 16, MediaQuery.of(context).padding.bottom + 10),
      decoration: BoxDecoration(
        color: FF.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: FF.divider.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _pickDocument,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(Icons.attach_file_rounded,
                  color: FF.textSec, size: 22),
            ),
          ),
          Expanded(
            child: TextField(
              controller: _ctrl,
              style: TextStyle(color: FF.textPri, fontSize: 14),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: _sendFromInput,
              decoration: InputDecoration(
                hintText: 'Ask me anything about focus...',
                hintStyle: TextStyle(color: FF.textSec, fontSize: 14),
                filled: true,
                fillColor: FF.card,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: FF.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: FF.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: FF.accent),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // ── Send button — fully complete widget tree ───────────────────
          GestureDetector(
            onTap: () => _sendFromInput(_ctrl.text),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: FF.accent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: FF.accent.withOpacity(0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.send_rounded,
                  color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Message bubble ────────────────────────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  final _Msg msg;
  const _MessageBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: msg.isUser ? FF.accent : FF.card,
          borderRadius: BorderRadius.only(
            topLeft:     const Radius.circular(18),
            topRight:    const Radius.circular(18),
            bottomLeft:  Radius.circular(msg.isUser ? 18 : 4),
            bottomRight: Radius.circular(msg.isUser ? 4 : 18),
          ),
          border: msg.isUser ? null : Border.all(color: FF.divider),
        ),
        child: Text(
          msg.text,
          style: TextStyle(
            color: msg.isUser ? Colors.white : FF.textPri,
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}

// ── Thinking bubble ───────────────────────────────────────────────────────────
class _ThinkingBubble extends StatefulWidget {
  const _ThinkingBubble();

  @override
  State<_ThinkingBubble> createState() => _ThinkingBubbleState();
}

class _ThinkingBubbleState extends State<_ThinkingBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: FF.card,
          borderRadius: const BorderRadius.only(
            topLeft:     Radius.circular(18),
            topRight:    Radius.circular(18),
            bottomRight: Radius.circular(18),
            bottomLeft:  Radius.circular(4),
          ),
          border: Border.all(color: FF.divider),
        ),
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final phase  = (_ctrl.value - i * 0.15).clamp(0.0, 1.0);
                final offset = -4.0 * (0.5 - (phase - 0.5).abs()) * 2;
                return Transform.translate(
                  offset: Offset(0, offset),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: FF.textSec.withOpacity(0.6),
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}

// ── Data model ────────────────────────────────────────────────────────────────
class _Msg {
  final String text;
  final bool   isUser;
  const _Msg({required this.text, required this.isUser});
}