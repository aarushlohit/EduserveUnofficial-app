import 'dart:math';
import 'dart:async';

import 'package:eduserveapp/core/constants/app_config.dart';
import 'package:eduserveapp/core/services/activity_log_service.dart';
import 'package:eduserveapp/core/services/ai_service.dart';
import 'package:eduserveapp/core/services/analytics_service.dart';
import 'package:eduserveapp/core/services/app_stats_service.dart';
import 'package:flutter/material.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({
    super.key,
    required this.uid,
  });

  final String uid;

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<_ChatMessage> _messages = <_ChatMessage>[];
  bool _sending = false;
  late final String _greeting;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logAiChatOpened();
    _greeting =
        AppConfig.aiGreetings[Random().nextInt(AppConfig.aiGreetings.length)];
    ActivityLogService.instance.logCurrentUserAction(
      uid: widget.uid,
      action: 'open_ai',
      tab: 'ai',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() {
      _messages.add(_ChatMessage(role: _Role.user, content: text));
      _sending = true;
      _controller.clear();
    });

    // Do not block chat response on telemetry writes.
    unawaited(_logAiMessageSideEffects());

    try {
      final response = await AiService.instance.sendChat(
        messages: _buildContextMessages(),
      );
      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMessage(role: _Role.assistant, content: response));
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          const _ChatMessage(
            role: _Role.assistant,
            content: 'I could not fetch a response now. Please try again.',
          ),
        );
      });
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  Future<void> _logAiMessageSideEffects() async {
    try {
      await AnalyticsService.instance
          .logAiMessageSent()
          .timeout(const Duration(seconds: 4));
    } catch (_) {
      // Ignore telemetry failures to keep chat responsive.
    }

    try {
      await AppStatsService.instance
          .logAiMessage()
          .timeout(const Duration(seconds: 4));
    } catch (_) {
      // Ignore telemetry failures to keep chat responsive.
    }

    try {
      await ActivityLogService.instance
          .logCurrentUserAction(
            uid: widget.uid,
            action: 'ai_message_sent',
            tab: 'ai',
          )
          .timeout(const Duration(seconds: 4));
    } catch (_) {
      // Ignore telemetry failures to keep chat responsive.
    }
  }

  List<Map<String, String>> _buildContextMessages() {
    const maxHistoryMessages = 12;

    final history = _messages.length > maxHistoryMessages
        ? _messages.sublist(_messages.length - maxHistoryMessages)
        : _messages;

    final context = <Map<String, String>>[
      const <String, String>{
        'role': 'system',
        'content':
            'You are PocketEduServe AI Assistant. Keep replies concise, practical, and student-friendly.',
      },
    ];

    for (final message in history) {
      context.add(
        <String, String>{
          'role': message.role == _Role.user ? 'user' : 'assistant',
          'content': message.content,
        },
      );
    }

    return context;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('EduServe AI')),
      body: Column(
        children: <Widget>[
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                const Icon(Icons.auto_awesome, size: 36),
                                const SizedBox(height: 10),
                                Text(
                                  'Ask EduServe AI',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Get quick help for academics, timetable and study planning.',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _greeting,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isUser = message.role == _Role.user;
                      return Align(
                        alignment: isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: const EdgeInsets.all(12),
                          constraints: const BoxConstraints(maxWidth: 420),
                          decoration: BoxDecoration(
                            color: isUser
                                ? const Color(0xFF111111)
                                : Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            message.content,
                            style: TextStyle(
                              color: isUser ? Colors.white : null,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF141414)
                      : Color(0xFFFFFFFF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color:
                        Theme.of(context).dividerColor.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        minLines: 1,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText: 'Ask your academic question...',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 10),
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _sending ? null : _send,
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _sending
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _Role { user, assistant }

class _ChatMessage {
  const _ChatMessage({required this.role, required this.content});

  final _Role role;
  final String content;
}
