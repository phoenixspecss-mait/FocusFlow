import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:FocusFlow/views/app_shell.dart';

// ─── PASTE YOUR NEW GEMINI API KEY HERE ───────────────────────────────────────
const String _geminiApiKey = 'AIzaSyCNlfssCL360g2sR9edg_aZZer3D-W2Fs0';
// ──────────────────────────────────────────────────────────────────────────────

const String _systemPrompt =
    'You are a friendly and helpful AI assistant inside FocusFlow, a Pomodoro and habit '
    'tracking app. While your specialty is helping users plan their day, improve focus, '
    'and build habits, you are also a general-purpose AI. You MUST cheerfully answer ANY '
    'question the user asks, regardless of the topic (e.g., math, trivia, coding, general '
    'knowledge). Keep replies concise, practical, and encouraging. Use bullet points or '
    'short paragraphs. Avoid long walls of text.';

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
          "• Answer questions about your habits\n\n"
          "What would you like to work on today?",
      isUser: false,
    ),
  ];

  bool _thinking = false;

  final List<String> _suggestions = [
    'How should I plan my day?',
    'Tips to improve focus',
    'Break down a big task',
    'Why am I feeling distracted?',
  ];

  // ── Gemini API call ────────────────────────────────────────────────────────
  Future<String> _callGemini(String userMessage) async {
    if (_geminiApiKey == 'YOUR_NEW_GEMINI_API_KEY_HERE' || _geminiApiKey.isEmpty) {
      throw Exception('Please paste your Gemini API key in ai_agent_view.dart');
    }

    _history.add({
      'role': 'user',
      'parts': [{'text': userMessage}],
    });

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/'
      'gemini-2.5-flash:generateContent?key=$_geminiApiKey',
    );

    final body = jsonEncode({
      'system_instruction': {
        'parts': [{'text': _systemPrompt}],
      },
      'contents': _history,
      'generationConfig': {
        'temperature': 0.7,
        'maxOutputTokens': 512,
      },
    });

    http.Response response;
    try {
      response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      _history.removeLast();
      throw Exception('Network error — check your internet connection.\nDetails: $e');
    }

    // Debug print (visible in Flutter terminal)
    debugPrint('Gemini status: ${response.statusCode}');
    debugPrint('Gemini body: ${response.body}');

    if (response.statusCode == 400) {
      _history.removeLast();
      throw Exception('Invalid API key or bad request (400).\nPlease generate a new key at:\nhttps://aistudio.google.com');
    }

    if (response.statusCode == 403) {
      _history.removeLast();
      throw Exception('API key not authorized (403).\nMake sure Gemini API is enabled at:\nhttps://console.cloud.google.com');
    }

    if (response.statusCode == 429) {
      _history.removeLast();
      throw Exception('Rate limit exceeded (429).\nWait 1 minute and try again.\nCheck quota: https://ai.dev/rate-limit');
    }

    if (response.statusCode != 200) {
      _history.removeLast();
      final errorData = jsonDecode(response.body);
      final errorMsg  = errorData['error']?['message'] ?? response.body;
      throw Exception('Gemini error ${response.statusCode}:\n$errorMsg');
    }

    final data  = jsonDecode(response.body);
    final reply = data['candidates'][0]['content']['parts'][0]['text'] as String;

    _history.add({
      'role': 'model',
      'parts': [{'text': reply}],
    });

    return reply.trim();
  }

  // ── Send handler ───────────────────────────────────────────────────────────
  Future<void> _send(String text) async {
    if (text.trim().isEmpty) return;
    _ctrl.clear();

    setState(() {
      _messages.add(_Msg(text: text.trim(), isUser: true));
      _thinking = true;
    });
    _scrollDown();

    try {
      final reply = await _callGemini(text.trim());
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
          _messages.add(_Msg(
            text: '⚠️ $e',
            isUser: false,
          ));
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
              child: Icon(Icons.auto_awesome_rounded,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Focus AI',
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
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: FF.textSec),
            onPressed: () => setState(() {
              _messages.clear();
              _history.clear();
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
                  return _ThinkingBubble();
                }
                return _MessageBubble(msg: _messages[i]);
              },
            ),
          ),
          if (!_thinking && _messages.last.isUser == false)
            _buildSuggestions(),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildSuggestions() {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: _suggestions.map((s) {
          return GestureDetector(
            onTap: () => _send(s),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
          Expanded(
            child: TextField(
              controller: _ctrl,
              style: TextStyle(color: FF.textPri, fontSize: 14),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: _send,
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
          GestureDetector(
            onTap: () => _send(_ctrl.text),
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
              child:
                  const Icon(Icons.send_rounded, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

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
            bottomRight: Radius.circular(msg.isUser ? 4  : 18),
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

class _ThinkingBubble extends StatefulWidget {
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
          builder: (_, _) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final phase = (_ctrl.value - i * 0.15).clamp(0.0, 1.0);
                final offset = -4.0 * (0.5 - (phase - 0.5).abs()) * 2;
                return Transform.translate(
                  offset: Offset(0, offset),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: FF.textSec.withOpacity(0.15),
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

class _Msg {
  final String text;
  final bool   isUser;
  const _Msg({required this.text, required this.isUser});
}