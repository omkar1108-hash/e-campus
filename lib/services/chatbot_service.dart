import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class ChatbotException implements Exception {
  const ChatbotException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// One turn of the conversation sent to the model.
class BotTurn {
  const BotTurn({required this.fromUser, required this.text});
  final bool fromUser;
  final String text;
}

/// AI doubt-clearing assistant backed by the OpenAI (ChatGPT) API.
class ChatbotService {
  ChatbotService({http.Client? client, String? apiKey})
    : _client = client ?? http.Client(),
      _apiKey = apiKey ?? AppConfig.openAiApiKey;

  final http.Client _client;
  final String _apiKey;

  static final _endpoint = Uri.parse(
    'https://api.openai.com/v1/chat/completions',
  );

  static const _systemPrompt =
      'You are E-Campus Assistant, a friendly tutor for college students. '
      'Explain concepts step by step, keep answers concise, and use short '
      'examples. If a question is unrelated to studies or campus life, '
      'politely steer back to academics.';

  bool get isConfigured => _apiKey.isNotEmpty;

  Future<String> ask(List<BotTurn> history) async {
    if (!isConfigured) {
      throw const ChatbotException(
        'The AI chatbot is not configured. Run the app with '
        '--dart-define=OPENAI_API_KEY=<your key>.',
      );
    }

    final messages = [
      {'role': 'system', 'content': _systemPrompt},
      for (final t in history)
        {'role': t.fromUser ? 'user' : 'assistant', 'content': t.text},
    ];

    final http.Response res;
    try {
      res = await _client
          .post(
            _endpoint,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_apiKey',
            },
            body: jsonEncode({
              'model': AppConfig.openAiModel,
              'messages': messages,
              'temperature': 0.5,
            }),
          )
          .timeout(const Duration(seconds: 45));
    } catch (_) {
      throw const ChatbotException(
        'Could not reach the AI service. Check your internet connection.',
      );
    }

    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      final err = (body['error'] as Map<String, dynamic>?)?['message'];
      throw ChatbotException('AI service error: ${err ?? res.statusCode}');
    }
    final choices = body['choices'] as List<dynamic>;
    final content =
        (choices.first as Map<String, dynamic>)['message']
            as Map<String, dynamic>;
    return (content['content'] as String).trim();
  }
}
