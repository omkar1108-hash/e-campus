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

/// AI doubt-clearing assistant backed by the Google Gemini API.
class ChatbotService {
  ChatbotService({http.Client? client, String? apiKey, String? model})
    : _client = client ?? http.Client(),
      _apiKey = apiKey ?? AppConfig.geminiApiKey,
      _model = model ?? AppConfig.geminiModel;

  final http.Client _client;
  final String _apiKey;
  final String _model;

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
        '--dart-define=GEMINI_API_KEY=<your key>.',
      );
    }

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/'
      '$_model:generateContent',
    );
    final body = jsonEncode({
      'systemInstruction': {
        'parts': [
          {'text': _systemPrompt},
        ],
      },
      'contents': [
        for (final t in history)
          {
            'role': t.fromUser ? 'user' : 'model',
            'parts': [
              {'text': t.text},
            ],
          },
      ],
    });

    final http.Response res;
    try {
      res = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': _apiKey,
            },
            body: body,
          )
          .timeout(const Duration(seconds: 45));
    } catch (_) {
      throw const ChatbotException(
        'Could not reach the AI service. Check your internet connection.',
      );
    }

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw ChatbotException('AI service error: HTTP ${res.statusCode}');
    }
    if (res.statusCode != 200) {
      final err = (json['error'] as Map<String, dynamic>?)?['message'];
      throw ChatbotException('AI service error: ${err ?? res.statusCode}');
    }

    final candidates = json['candidates'] as List<dynamic>?;
    final parts =
        ((candidates?.firstOrNull as Map<String, dynamic>?)?['content']
                as Map<String, dynamic>?)?['parts']
            as List<dynamic>?;
    final text = parts
        ?.map((p) => (p as Map<String, dynamic>)['text'] ?? '')
        .join()
        .trim();
    if (text == null || text.isEmpty) {
      throw const ChatbotException(
        'The AI did not return an answer. Try rephrasing your question.',
      );
    }
    return text;
  }
}
