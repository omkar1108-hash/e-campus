import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/chatbot_service.dart';
import '../widgets/link_text.dart';

/// AI doubt-clearing assistant (Gemini API).
class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  final _turns = <BotTurn>[];
  bool _thinking = false;

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final question = _text.text.trim();
    if (question.isEmpty || _thinking) return;
    final bot = context.read<ChatbotService>();
    _text.clear();
    setState(() {
      _turns.add(BotTurn(fromUser: true, text: question));
      _thinking = true;
    });
    _scrollToEnd();
    String reply;
    try {
      reply = await bot.ask(List.of(_turns));
    } on ChatbotException catch (e) {
      reply = e.message;
    }
    if (!mounted) return;
    setState(() {
      _turns.add(BotTurn(fromUser: false, text: reply));
      _thinking = false;
    });
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Expanded(
          child: _turns.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Ask me anything about your subjects - '
                      'e.g. "Explain recursion with an example".',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(12),
                  itemCount: _turns.length + (_thinking ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i == _turns.length) {
                      return const Padding(
                        padding: EdgeInsets.all(8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Thinking...'),
                        ),
                      );
                    }
                    final t = _turns[i];
                    return Align(
                      alignment: t.fromUser
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(12),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.8,
                        ),
                        decoration: BoxDecoration(
                          color: t.fromUser
                              ? scheme.primaryContainer
                              : scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: LinkText(t.text, selectable: true),
                      ),
                    );
                  },
                ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _text,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Ask a question',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                IconButton.filled(
                  onPressed: _thinking ? null : _send,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
