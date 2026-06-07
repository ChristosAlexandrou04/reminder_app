import 'package:flutter/material.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'ai_service.dart';
import 'app_settings.dart';

// ─────────────────────────────────────────────────────────
// Simple in-memory message model
// ─────────────────────────────────────────────────────────
class _ChatMessage {
  final String role; // 'user' or 'model'
  String text;
  _ChatMessage({required this.role, required this.text});
}

// ─────────────────────────────────────────────────────────
// AI Chat Page
// ─────────────────────────────────────────────────────────
class AiChatPage extends StatefulWidget {
  const AiChatPage({super.key});

  @override
  State<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends State<AiChatPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _service = AiService();

  final List<_ChatMessage> _messages = [];
  bool _loading = true;
  bool _responding = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  // Load reminders (for AI context) + chat history, then init service.
  Future<void> _init() async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;

      // Fetch the user's reminders so the AI knows what meds they take.
      final reminderSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('reminders')
          .get();
      final reminders = reminderSnap.docs.map((d) => d.data()).toList();

      // Load saved chat history (empty list for anonymous users).
      final history = await AiService.loadHistory();
      final historyContents = <Content>[];

      for (final msg in history) {
        final role = (msg['role'] as String?) ?? 'user';
        final text = (msg['text'] as String?) ?? '';
        _messages.add(_ChatMessage(role: role, text: text));

        if (role == 'user') {
          historyContents.add(Content('user', [TextPart(text)]));
        } else {
          historyContents.add(Content('model', [TextPart(text)]));
        }
      }

      _service.initialise(
        reminders,
        city: AppSettings.city.value,
        history: historyContents.isEmpty ? null : historyContents,
      );
    } catch (e) {
      debugPrint('AI init error: $e');
    }

    if (mounted) setState(() => _loading = false);
  }

  // ─── Send a message ──────────────────────────────────
  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _responding) return;

    _controller.clear();

    setState(() {
      _messages.add(_ChatMessage(role: 'user', text: text));
      _responding = true;
    });
    _scrollToBottom();

    // Persist user message.
    AiService.saveMessage('user', text);

    // Placeholder for streaming AI response.
    final aiMsg = _ChatMessage(role: 'model', text: '');
    setState(() => _messages.add(aiMsg));

    try {
      await for (final chunk in _service.sendMessage(text)) {
        if (!mounted) return;
        setState(() => aiMsg.text += chunk);
        _scrollToBottom();
      }

      // Persist AI response.
      AiService.saveMessage('model', aiMsg.text);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        aiMsg.text =
            'Sorry, I couldn\'t process that request. Please try again.'
            '\n\nError: $e';
      });
    } finally {
      if (mounted) setState(() => _responding = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ─── Build ───────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Health Assistant'),
        actions: [
          if (_messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Clear chat',
              onPressed: _responding
                  ? null
                  : () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: const Text('Clear chat history?'),
                          content:
                              const Text('This will remove all messages.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(c, false),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(c, true),
                              child: const Text('Clear'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await AiService.clearHistory();
                        if (mounted) setState(() => _messages.clear());
                      }
                    },
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ── Disclaimer banner ─────────────────────
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: isDark
                      ? Colors.orange.shade900.withValues(alpha: 0.3)
                      : Colors.orange.shade50,
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 16, color: Colors.orange.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'AI responses are not medical advice. '
                          'Always consult your doctor.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Messages ──────────────────────────────
                Expanded(
                  child: _messages.isEmpty
                      ? _EmptyState(isDark: isDark)
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          itemCount: _messages.length,
                          itemBuilder: (_, i) {
                            final msg = _messages[i];
                            final isUser = msg.role == 'user';
                            return _ChatBubble(
                              text: msg.text,
                              isUser: isUser,
                              isLoading:
                                  msg.text.isEmpty && !isUser && _responding,
                            );
                          },
                        ),
                ),

                // ── Input bar ─────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[900] : Colors.grey[50],
                    border: Border(
                      top: BorderSide(
                        color:
                            isDark ? Colors.grey[800]! : Colors.grey[300]!,
                      ),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _send(),
                            enabled: !_responding,
                            decoration: InputDecoration(
                              hintText: 'Ask about your medications...',
                              filled: true,
                              fillColor:
                                  isDark ? Colors.grey[800] : Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _responding ? null : _send,
                          icon: Icon(
                            Icons.send_rounded,
                            color: _responding
                                ? Colors.grey
                                : Colors.deepPurple,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Empty-state placeholder (shown when no messages yet)
// ─────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final bool isDark;
  const _EmptyState({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.smart_toy,
                size: 64,
                color: isDark
                    ? Colors.deepPurple.shade200
                    : Colors.deepPurple.shade300),
            const SizedBox(height: 16),
            const Text(
              'Ask me anything about\nyour medications',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text(
              'For example:\n'
              '"What does paracetamol do?"\n'
              '"Can I take ibuprofen with aspirin?"\n'
              '"When should I take blood pressure tablets?"',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Chat bubble
// ─────────────────────────────────────────────────────────
class _ChatBubble extends StatelessWidget {
  final String text;
  final bool isUser;
  final bool isLoading;

  const _ChatBubble({
    required this.text,
    required this.isUser,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser
              ? Colors.deepPurple
              : (isDark ? Colors.grey[800] : Colors.grey[200]),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft:
                isUser ? const Radius.circular(16) : const Radius.circular(4),
            bottomRight:
                isUser ? const Radius.circular(4) : const Radius.circular(16),
          ),
        ),
        child: isLoading
            ? const _TypingIndicator()
            : Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  color: isUser
                      ? Colors.white
                      : (isDark ? Colors.white : Colors.black87),
                  height: 1.4,
                ),
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// "Typing …" dots animation
// ─────────────────────────────────────────────────────────
class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            // Stagger each dot by a third of the cycle.
            final t = (_ctrl.value + i / 3) % 1.0;
            final opacity = 0.3 + 0.7 * (1 - (2 * t - 1).abs());
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Opacity(
                opacity: opacity,
                child: const Text('●',
                    style: TextStyle(fontSize: 12, color: Colors.deepPurple)),
              ),
            );
          }),
        );
      },
    );
  }
}
