import 'dart:convert';

import 'package:eduserveapp/core/constants/app_config.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class AiService {
  AiService._();

  static final AiService instance = AiService._();

  Future<String> sendMessage(String message) async {
    return sendChat(
      messages: <Map<String, String>>[
        <String, String>{'role': 'user', 'content': message},
      ],
    );
  }

  Future<String> sendChat({
    required List<Map<String, String>> messages,
  }) async {
    if (messages.isEmpty) {
      throw Exception('AI request requires at least one message');
    }

    final apiKey = dotenv.env['pollination_api_key']?.trim() ?? '';
    if (apiKey.isEmpty) {
      throw Exception('Pollinations API key is missing in .env');
    }

    final uri = Uri.parse(AppConfig.aiEndpoint);
    final response = await http
        .post(
          uri,
          headers: <String, String>{
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          body: jsonEncode(<String, dynamic>{
            'model': AppConfig.aiModel,
            'messages': messages,
          }),
        )
        .timeout(const Duration(seconds: 18));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'AI request failed: ${response.statusCode} ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = decoded['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      throw Exception('AI response is empty');
    }

    final first = choices.first as Map<String, dynamic>;
    final messageMap = first['message'] as Map<String, dynamic>?;
    final content = _extractContent(
      messageMap?['content'],
      first['text'],
    );
    if (content == null || content.trim().isEmpty) {
      throw Exception('AI response content missing');
    }

    return content.trim();
  }

  String? _extractContent(dynamic messageContent, dynamic legacyText) {
    if (messageContent is String && messageContent.trim().isNotEmpty) {
      return messageContent;
    }

    // Some providers may return content as a structured array.
    if (messageContent is List<dynamic>) {
      final joined = messageContent
          .whereType<Map<String, dynamic>>()
          .map((item) => item['text'])
          .whereType<String>()
          .join(' ')
          .trim();
      if (joined.isNotEmpty) {
        return joined;
      }
    }

    if (legacyText is String && legacyText.trim().isNotEmpty) {
      return legacyText;
    }

    return null;
  }
}
