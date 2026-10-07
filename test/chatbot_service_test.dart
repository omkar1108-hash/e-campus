import 'dart:convert';

import 'package:e_campus/services/chatbot_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const turns = [BotTurn(fromUser: true, text: 'What is recursion?')];

  test('fails clearly when no key is configured', () {
    final bot = ChatbotService(apiKey: '');
    expect(() => bot.ask(turns), throwsA(isA<ChatbotException>()));
  });

  test('sends history in Gemini format and returns the reply', () async {
    late http.Request seen;
    final bot = ChatbotService(
      apiKey: 'k',
      model: 'm',
      client: MockClient((req) async {
        seen = req;
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': 'A function that calls '},
                    {'text': 'itself.'},
                  ],
                },
              },
            ],
          }),
          200,
        );
      }),
    );
    expect(await bot.ask(turns), 'A function that calls itself.');
    expect(seen.url.path, endsWith('/models/m:generateContent'));
    expect(seen.headers['x-goog-api-key'], 'k');
    final sent = jsonDecode(seen.body) as Map<String, dynamic>;
    expect((sent['contents'] as List).single['role'], 'user');
    expect(sent['systemInstruction'], isNotNull);
  });

  test('surfaces API error messages', () async {
    final bot = ChatbotService(
      apiKey: 'k',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'error': {'message': 'API key not valid'},
          }),
          400,
        ),
      ),
    );
    expect(
      () => bot.ask(turns),
      throwsA(
        isA<ChatbotException>().having(
          (e) => e.message,
          'message',
          contains('API key not valid'),
        ),
      ),
    );
  });

  test('reports an empty answer instead of crashing', () async {
    final bot = ChatbotService(
      apiKey: 'k',
      client: MockClient((_) async => http.Response('{"candidates":[]}', 200)),
    );
    expect(() => bot.ask(turns), throwsA(isA<ChatbotException>()));
  });
}
