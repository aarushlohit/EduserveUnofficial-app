import 'dart:convert';

import 'package:eduserveapp/core/constants/app_config.dart';
import 'package:http/http.dart' as http;

class TopicPushService {
  TopicPushService._();

  static final TopicPushService instance = TopicPushService._();

  Future<bool> sendHackathonPush({
    required String title,
    required String message,
  }) async {
    if (AppConfig.topicPushRelayEndpoint.trim().isEmpty) {
      return false;
    }

    final uri = Uri.tryParse(AppConfig.topicPushRelayEndpoint);
    if (uri == null) {
      return false;
    }

    final response = await http.post(
      uri,
      headers: const <String, String>{
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, dynamic>{
        'topic': 'hackathons',
        'title': title,
        'body': message,
      }),
    );

    return response.statusCode >= 200 && response.statusCode < 300;
  }
}
