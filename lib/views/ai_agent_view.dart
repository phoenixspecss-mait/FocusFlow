import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:http/http.dart' as http;
import 'package:FocusFlow/views/app_shell.dart';

// ─── GEMINI API KEY ────────────────────────────────────────────────────────────
const String _geminiApiKey = 'API_KEY';
const String _geminiModel  = 'gemini-2.5-flash';

String _fixLatex(String text) {
  text = text.replaceAllMapped(RegExp(r'\\\[(.*?)\\\]', dotAll: true), (m) => '\n\$\$${m[1]!.trim()}\$\$\n');
  text = text.replaceAllMapped(RegExp(r'\$\$(.*?)\$\$', dotAll: true), (m) => '\n\$\$${m[1]!.replaceAll('\n', ' ').trim()}\$\$\n');
  text = text.replaceAllMapped(RegExp(r'\\\((.*?)\\\)', dotAll: true), (m) => '\\(${m[1]!.replaceAll('\n', ' ').trim()}\\)');
  text = text.replaceAll('ℏ', r'\hbar ').replaceAll('∂', r'\partial ').replaceAll('Ψ', r'\Psi ').replaceAll('Ĥ', r'\hat{H} ');
  text = text.replaceAll('×', r'\times ').replaceAll('÷', r'\div ').replaceAll('π', r'\pi ').replaceAll('θ', r'\theta ').replaceAll('°', r'^\circ');
  text = text.replaceAllMapped(RegExp(r'\\vec\{([^}]+)\}'), (m) => m[1]!);
  text = text.replaceAllMapped(RegExp(r'\\hat\{([^}]+)\}'), (m) => m[1]!);
  text = text.replaceAllMapped(RegExp(r'\\vec\s+([a-zA-Z])'), (m) => m[1]!);
  text = text.replaceAllMapped(RegExp(r'\\hat\s+([a-zA-Z])'), (m) => m[1]!);
  text = text.replaceAll(r'\mathbf', '');
  text = text.replaceAll(r'\left(', '(').replaceAll(r'\right)', ')');
  text = text.replaceAll(r'\left[', '[').replaceAll(r'\right]', ']');
  text = text.replaceAllMapped(RegExp(r'\^([a-zA-Z0-9])'), (m) => '^{${m[1]}}');
  text = text.replaceAll(r'\hbar\frac', r'\hbar \frac');
  text = text.replaceAll(RegExp(r'\{\s+'), '{').replaceAll(RegExp(r'\s+\}'), '}');
  text = text.replaceAllMapped(RegExp(r'\\([a-zA-Z]+)\s+\('), (m) => '\\${m[1]}(');
  text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return text;
}

const String _systemPrompt =
    'You are a friendly and helpful AI assistant inside FocusFlow, a Pomodoro and habit '
    'tracking app. While your specialty is helping users plan their day, improve focus, '
    'and build habits, you are also a general-purpose AI. You MUST cheerfully answer ANY '
    'question the user asks, regardless of the topic. Keep replies concise, practical, and encouraging. Use bullet points.\n\n'
    'MATH FORMATTING (follow strictly):\n'
    r'- Inline math: use \( and \) e.g. \(E = mc^2\)' '\n'
    r'- Block math: use $$ and $$ e.g. $$x = \frac{-b}{2a}$$' '\n'
    r'- CRITICAL: DO NOT put spaces inside curly braces (write \frac{\hbar^2}{2m} NOT \frac{ \hbar^2 }{ 2m }).' '\n'
    r'- CRITICAL: DO NOT use \left( or \right). Just use standard parentheses ( and ).' '\n'
    r'- CRITICAL: DO NOT use accents like \vec, \hat, or \mathbf. Just use standard variables.' '\n'
    r'- CRITICAL: Always wrap individual variables in \( and \) (e.g., write \(\hbar\) is the constant). NEVER leave variables naked.' '\n'
    r'- Use pure LaTeX macros for all symbols (e.g., \hbar, \partial). DO NOT use raw Unicode.' '\n'
    r'- Never use bare dollar signs like $E$ — always use \(E\)';

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

// ── Message model ─────────────────────────────────────────────────────────────
class _Msg {
  final String text;
  final bool   isUser;
  const _Msg({required this.text, required this.isUser});
}

// ── Main widget ───────────────────────────────────────────────────────────────
class AiAgentView extends StatefulWidget {
  const AiAgentView({super.key});
  @override
  State<AiAgentView> createState() => _AiAgentViewState();
}

class _AiAgentViewState extends State<AiAgentView> {
  final TextEditingController      _ctrl    = TextEditingController();
  final ScrollController           _scroll  = ScrollController();
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

  // ── Gemini text API ────────────────────────────────────────────────────────
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

    if (response.statusCode == 400) { _history.removeLast(); throw Exception('Invalid API key or bad request (400).'); }
    if (response.statusCode == 403) { _history.removeLast(); throw Exception('API key not authorized (403).'); }
    if (response.statusCode == 404) { _history.removeLast(); throw Exception('Model not found (404). Try a different model.'); }
    if (response.statusCode == 429) { _history.removeLast(); throw Exception('Rate limit exceeded (429). Wait and retry.'); }
    if (response.statusCode != 200) {
      _history.removeLast();
      final err = jsonDecode(response.body);
      throw Exception('Gemini error ${response.statusCode}:\n${err['error']?['message'] ?? response.body}');
    }

    final data  = jsonDecode(response.body);
    final reply = data['candidates'][0]['content']['parts'][0]['text'] as String;
    _history.add({'role': 'model', 'parts': [{'text': reply}]});
    return reply.trim();
  }

  // ── Gemini Vision call (image / scanned PDF) ───────────────────────────────
  Future<String> _callGeminiWithImage(
    String base64Data,
    String mimeType, {
    String? customPrompt,
    String? fileNameForHistory,
  }) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/'
      '$_geminiModel:generateContent?key=$_geminiApiKey',
    );

    final prompt = customPrompt ??
        'Please analyze this image and describe what you see. '
        'If it contains text, notes, or diagrams, extract and explain the key information.';

    final body = jsonEncode({
      'system_instruction': {
        'parts': [{'text': _systemPrompt}],
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'inline_data': {'mime_type': mimeType, 'data': base64Data}},
            {'text': prompt},
          ],
        },
      ],
      'generationConfig': {'temperature': 0.4, 'maxOutputTokens': 2048},
    });

    final response = await http
        .post(url, headers: {'Content-Type': 'application/json'}, body: body)
        .timeout(const Duration(seconds: 60));

    if (response.statusCode != 200) {
      final err = jsonDecode(response.body);
      throw Exception('Gemini error ${response.statusCode}: ${err['error']?['message']}');
    }

    final data  = jsonDecode(response.body);
    final reply = data['candidates'][0]['content']['parts'][0]['text'] as String;

    _history.add({'role': 'user',  'parts': [{'text': '[User shared: ${fileNameForHistory ?? 'an image'}]'}]});
    _history.add({'role': 'model', 'parts': [{'text': reply}]});

    return reply.trim();
  }

  // ── Document source picker (bottom sheet) ──────────────────────────────────
  Future<void> _pickDocument() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: FF.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(color: FF.divider, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            Text('Add Document', style: TextStyle(color: FF.textPri, fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 12),
            ListTile(
              leading: Icon(Icons.picture_as_pdf_rounded, color: FF.accent),
              title: Text('Pick PDF', style: TextStyle(color: FF.textPri)),
              subtitle: Text('Opens file picker', style: TextStyle(color: FF.textSec, fontSize: 12)),
              onTap: () => Navigator.pop(ctx, 'pdf'),
            ),
            ListTile(
              leading: Icon(Icons.image_rounded, color: FF.accent),
              title: Text('Pick Image', style: TextStyle(color: FF.textPri)),
              subtitle: Text('JPG, PNG from gallery', style: TextStyle(color: FF.textSec, fontSize: 12)),
              onTap: () => Navigator.pop(ctx, 'image'),
            ),
            ListTile(
              leading: Icon(Icons.text_snippet_rounded, color: FF.accent),
              title: Text('Paste Text', style: TextStyle(color: FF.textPri)),
              subtitle: Text('Copy-paste notes or articles', style: TextStyle(color: FF.textSec, fontSize: 12)),
              onTap: () => Navigator.pop(ctx, 'paste'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (choice == null) return;
    if (choice == 'paste')  { await _pickDocumentByPaste(); return; }
    if (choice == 'pdf')    { await _pickPdf();   return; }
    if (choice == 'image')  { await _pickImage(); return; }
  }

  // ── PDF picker ─────────────────────────────────────────────────────────────
  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result == null || result.files.single.path == null) return;

    final file     = File(result.files.single.path!);
    final fileName = result.files.single.name;

    setState(() => _thinking = true);

    try {
      final bytes     = await file.readAsBytes();
      final document  = PdfDocument(inputBytes: bytes);
      final extractor = PdfTextExtractor(document);
      final rawText   = extractor.extractText();
      document.dispose();

      final trimmed = rawText.trim();

      // ── Text-based PDF ────────────────────────────────────────────────────
      if (trimmed.isNotEmpty) {
        final truncated = trimmed.length > 8000
            ? '${trimmed.substring(0, 8000)}\n\n[Truncated to 8 000 characters]'
            : trimmed;
        setState(() {
          _uploadedDocText  = truncated;
          _uploadedFileName = fileName;
          _showDocPanel     = true;
          _thinking         = false;
        });
        return;
      }

      // ── Scanned PDF — render page 1 → Gemini Vision ───────────────────────
// ── Scanned PDF — send directly to Gemini ────────────────────────────────
setState(() {
  _messages.add(_Msg(
    text: '📄 Scanned PDF detected: $fileName\nSending to Gemini for OCR…',
    isUser: true,
  ));
});

final reply = await _callGeminiWithPdf(
  bytes,
  fileName: fileName,
  prompt:
    'This is a scanned PDF called "$fileName".\n'
    'Extract ALL visible text, then summarise the key information '
    'as well-structured study notes with headings and bullet points.',
);

setState(() {
  _thinking = false;
  _messages.add(_Msg(text: reply, isUser: false));
});
_scrollDown();

    } catch (e) {
      setState(() => _thinking = false);
      _showError('Failed to read PDF: $e');
    }
  }

  // ── Render first PDF page to PNG bytes ────────────────────────────────────
// ── Scanned PDF — send directly to Gemini as document ─────────────────────
Future<String> _callGeminiWithPdf(
  Uint8List pdfBytes, {
  required String fileName,
  required String prompt,
}) async {
  final url = Uri.parse(
    'https://generativelanguage.googleapis.com/v1beta/models/'
    '$_geminiModel:generateContent?key=$_geminiApiKey',
  );

  final body = jsonEncode({
    'system_instruction': {
      'parts': [{'text': _systemPrompt}],
    },
    'contents': [
      {
        'role': 'user',
        'parts': [
          {
            'inline_data': {
              'mime_type': 'application/pdf',
              'data': base64Encode(pdfBytes),
            }
          },
          {'text': prompt},
        ],
      },
    ],
    'generationConfig': {'temperature': 0.4, 'maxOutputTokens': 2048},
  });

  final response = await http
      .post(url, headers: {'Content-Type': 'application/json'}, body: body)
      .timeout(const Duration(seconds: 60));

  if (response.statusCode != 200) {
    final err = jsonDecode(response.body);
    throw Exception('Gemini error ${response.statusCode}: ${err['error']?['message']}');
  }

  final data  = jsonDecode(response.body);
  final reply = data['candidates'][0]['content']['parts'][0]['text'] as String;
  _history.add({'role': 'user',  'parts': [{'text': '[User shared PDF: $fileName]'}]});
  _history.add({'role': 'model', 'parts': [{'text': reply}]});
  return reply.trim();
}

  // ── Image picker ───────────────────────────────────────────────────────────
  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1280,
    );
    if (picked == null) return;

    final file     = File(picked.path);
    final fileName = picked.name;
    final ext      = picked.name.split('.').last.toLowerCase();
    final mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';

    setState(() {
      _thinking = true;
      _messages.add(_Msg(text: '🖼️ Analyzing image: $fileName', isUser: true));
    });

    try {
      final bytes = await file.readAsBytes();
      final reply = await _callGeminiWithImage(
        base64Encode(bytes),
        mimeType,
        fileNameForHistory: fileName,
      );
      setState(() {
        _thinking = false;
        _messages.add(_Msg(text: reply, isUser: false));
      });
      _scrollDown();
    } catch (e) {
      setState(() => _thinking = false);
      _showError('Failed to process image: $e');
    }
  }

  // ── Paste text dialog ──────────────────────────────────────────────────────
  Future<void> _pickDocumentByPaste() async {
    final pasteCtrl = TextEditingController();
    final nameCtrl  = TextEditingController(text: 'Pasted document');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FF.card,
        title: Text('Paste Document Text', style: TextStyle(color: FF.textPri)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: TextStyle(color: FF.textPri),
              decoration: InputDecoration(
                labelText: 'Document name',
                labelStyle: TextStyle(color: FF.textSec),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: FF.divider)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pasteCtrl,
              maxLines: 8,
              style: TextStyle(color: FF.textPri, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Paste your notes or article here…',
                hintStyle: TextStyle(color: FF.textSec),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: FF.divider)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: FF.accent)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: FF.textSec)),
          ),
          TextButton(
            onPressed: () {
              if (pasteCtrl.text.trim().isNotEmpty) {
                setState(() {
                  _uploadedDocText  = pasteCtrl.text.trim();
                  _uploadedFileName = nameCtrl.text.trim().isEmpty
                      ? 'Pasted document'
                      : nameCtrl.text.trim();
                  _showDocPanel = true;
                });
              }
              Navigator.pop(ctx);
            },
            child: Text('Use Text', style: TextStyle(color: FF.accent)),
          ),
        ],
      ),
    );
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

  void _sendFromInput(String text) => _send(text);

  // ── Core send ──────────────────────────────────────────────────────────────
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
        title: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF4F8EF7), Color(0xFFB06EF5)]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Focus AI', style: TextStyle(color: FF.textPri, fontWeight: FontWeight.w800, fontSize: 20)),
              Text('Powered by Gemini', style: TextStyle(color: FF.textSec, fontSize: 11)),
            ],
          ),
        ]),
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
      body: Column(children: [
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: _messages.length + (_thinking ? 1 : 0),
            itemBuilder: (_, i) {
              if (i == _messages.length && _thinking) return const _ThinkingBubble();
              return _MessageBubble(msg: _messages[i]);
            },
          ),
        ),
        if (_showDocPanel && _uploadedDocText != null) _buildDocPanel(),
        if (!_thinking && _messages.isNotEmpty && !_messages.last.isUser && !_showDocPanel)
          _buildSuggestions(),
        _buildInputBar(),
      ]),
    );
  }

  // ── Doc panel ──────────────────────────────────────────────────────────────
  Widget _buildDocPanel() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FF.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FF.accent.withOpacity(0.4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.picture_as_pdf_rounded, color: FF.accent, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _uploadedFileName ?? 'Document',
              style: TextStyle(color: FF.textPri, fontWeight: FontWeight.w600, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: () => setState(() { _showDocPanel = false; _uploadedDocText = null; _uploadedFileName = null; }),
            child: Icon(Icons.close_rounded, color: FF.textSec, size: 18),
          ),
        ]),
        const SizedBox(height: 12),
        // Mode chips
        Row(children: DocMode.values.map((m) {
          final sel = m == _selectedMode;
          return GestureDetector(
            onTap: () => setState(() => _selectedMode = m),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: sel ? FF.accent.withOpacity(0.15) : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: sel ? FF.accent : FF.divider),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(m.icon, size: 13, color: sel ? FF.accent : FF.textSec),
                const SizedBox(width: 5),
                Text(m.label, style: TextStyle(
                  color: sel ? FF.accent : FF.textSec,
                  fontSize: 12,
                  fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                )),
              ]),
            ),
          );
        }).toList()),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _generateFromDoc,
            icon: const Icon(Icons.auto_awesome_rounded, size: 16),
            label: Text('Generate ${_selectedMode.label}'),
            style: ElevatedButton.styleFrom(
              backgroundColor: FF.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
      ]),
    );
  }

  // ── Suggestion chips ───────────────────────────────────────────────────────
  Widget _buildSuggestions() {
    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _suggestions.length,
        itemBuilder: (_, i) => GestureDetector(
          onTap: () => _send(_suggestions[i]),
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: FF.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: FF.divider),
            ),
            child: Text(_suggestions[i], style: TextStyle(color: FF.textSec, fontSize: 12)),
          ),
        ),
      ),
    );
  }

  // ── Input bar ──────────────────────────────────────────────────────────────
  Widget _buildInputBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        decoration: BoxDecoration(
          color: FF.bg,
          border: Border(top: BorderSide(color: FF.divider)),
        ),
        child: Row(children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: FF.card,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: FF.divider),
              ),
              child: Row(children: [
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    style: TextStyle(color: FF.textPri, fontSize: 14),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: _sendFromInput,
                    decoration: InputDecoration(
                      hintText: 'Ask anything…',
                      hintStyle: TextStyle(color: FF.textSec),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ]),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => _send(_ctrl.text),
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF4F8EF7), Color(0xFFB06EF5)]),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ]),
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
    final isUser = msg.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser ? FF.accent : FF.card,
          borderRadius: BorderRadius.only(
            topLeft:     const Radius.circular(18),
            topRight:    const Radius.circular(18),
            bottomLeft:  Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4  : 18),
          ),
        ),
        child: isUser
            ? Text(msg.text, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4))
            : GptMarkdown(_fixLatex(msg.text),
                style: TextStyle(color: FF.textPri, fontSize: 14, height: 1.5)),
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
  late Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: FF.card,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18), topRight: Radius.circular(18),
            bottomRight: Radius.circular(18), bottomLeft: Radius.circular(4),
          ),
        ),
        child: FadeTransition(
          opacity: _anim,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _dot(0), _dot(150), _dot(300),
          ]),
        ),
      ),
    );
  }

  Widget _dot(int delayMs) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 3),
    width: 7, height: 7,
    decoration: BoxDecoration(shape: BoxShape.circle, color: FF.accent),
  );
}