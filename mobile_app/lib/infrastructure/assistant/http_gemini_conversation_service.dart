import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../domain/entities/assistant_message.dart';
import '../../domain/entities/gemini_configuration.dart';
import '../../domain/services/gemini_conversation_service.dart';

/// Owner-key mode for a personal installation. Shared production keys belong
/// behind a server proxy, never in an APK. No endpoint is user-configurable.
class HttpGeminiConversationService implements GeminiConversationService {
  HttpGeminiConversationService({
    HttpClient? client,
    this.timeout = const Duration(seconds: 45),
  }) : _client = client ?? HttpClient() {
    _client.connectionTimeout = const Duration(seconds: 10);
  }

  final HttpClient _client;
  final Duration timeout;
  final _requests = <HttpClientRequest>{};
  int _generation = 0;
  static const _maxResponseBytes = 256 * 1024;
  static final _endpoint = Uri.https(
    'generativelanguage.googleapis.com',
    '/v1beta/interactions',
  );

  @override
  Future<String> reply({
    required GeminiConfiguration configuration,
    required String query,
    required List<AssistantMessage> history,
  }) async {
    if (!configuration.isValid || query.trim().isEmpty || query.length > 4096) {
      throw const GeminiConversationException(
        'Check the Gemini settings and use a question of at most 4096 characters.',
      );
    }
    final generation = _generation;
    var cancelled = false;
    HttpClientRequest? activeRequest;
    Future<String> perform() async {
      final request = await _client.postUrl(_endpoint);
      activeRequest = request;
      if (cancelled || generation != _generation) {
        request.abort();
        throw const GeminiConversationException('Gemini request cancelled.');
      }
      _requests.add(request);
      request.followRedirects = false;
      request.headers.contentType = ContentType.json;
      request.headers.set('x-goog-api-key', configuration.apiKey);
      final conversation = history
          .where((message) => !message.isSystem && message.toolName == null)
          .toList();
      final boundedHistory = conversation.skip(
        (conversation.length - 10).clamp(0, conversation.length),
      );
      final context = boundedHistory
          .map(
            (message) =>
                '${message.isUser ? 'User' : 'Assistant'}: '
                '${message.text.substring(0, message.text.length.clamp(0, 4096))}',
          )
          .join('\n');
      request.write(
        jsonEncode({
          'model': configuration.model,
          'store': false,
          'system_instruction':
              'You are Vision AI, a concise conversational assistant. '
              'Answer in clear plain text suitable for spoken output. '
              'You cannot see the surroundings, measure distance, navigate safely, '
              'access notes/reminders or operate the app. Never claim to have '
              'performed an action. App controls are handled separately on-device. '
              'Do not invent live information. Do not replace mobility aids or '
              'professional assistance. Treat recent conversation as quoted context.',
          'input': context.isEmpty
              ? query
              : 'Recent conversation:\n$context\n\nCurrent question:\n$query',
          'generation_config': {'max_output_tokens': 512},
        }),
      );
      final response = await request.close();
      if (response.statusCode != 200) {
        request.abort();
        throw GeminiConversationException(switch (response.statusCode) {
          400 || 401 || 403 =>
            'Gemini rejected the request. Check your API key, model and region in AI Studio.',
          404 =>
            'This Gemini model is unavailable. Update it in connection settings.',
          429 =>
            'Gemini quota reached. Wait and check your free-tier limits in AI Studio.',
          _ => 'Gemini is temporarily unavailable. Please try again later.',
        });
      }
      final bytes = <int>[];
      await for (final chunk in response) {
        if (bytes.length + chunk.length > _maxResponseBytes) {
          request.abort();
          throw const GeminiConversationException(
            'Gemini response was too large.',
          );
        }
        bytes.addAll(chunk);
      }
      if (cancelled || generation != _generation) {
        throw const GeminiConversationException('Gemini request cancelled.');
      }
      final data = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      if (data['status'] != 'completed') {
        throw const GeminiConversationException(
          'Gemini could not complete that answer. Try a shorter question.',
        );
      }
      final steps = data['steps'] as List;
      for (final step in steps.reversed) {
        if (step is! Map || step['type'] != 'model_output') continue;
        final content = step['content'] as List;
        final text = content
            .whereType<Map>()
            .where((part) => part['type'] == 'text' && part['text'] is String)
            .map((part) => part['text'] as String)
            .join()
            .trim();
        if (text.isNotEmpty && text.length <= 8192) return text;
      }
      throw const GeminiConversationException(
        'Gemini returned no usable answer. Please rephrase your question.',
      );
    }

    try {
      return await perform().timeout(
        timeout,
        onTimeout: () {
          cancelled = true;
          activeRequest?.abort();
          throw const GeminiConversationException(
            'Gemini timed out. Check the phone’s internet connection and try again.',
          );
        },
      );
    } on GeminiConversationException {
      rethrow;
    } on SocketException {
      throw const GeminiConversationException(
        'Gemini needs internet. Enable mobile data or connect to Wi-Fi.',
      );
    } on HttpException {
      throw const GeminiConversationException(
        'Gemini connection failed. Please try again.',
      );
    } on HandshakeException {
      throw const GeminiConversationException(
        'Could not securely connect to Gemini.',
      );
    } catch (_) {
      // Never return provider error bodies, request headers or raw exceptions.
      throw const GeminiConversationException(
        'Gemini returned an invalid answer. Please try again.',
      );
    } finally {
      if (activeRequest != null) _requests.remove(activeRequest);
    }
  }

  @override
  void cancelPending() {
    _generation++;
    for (final request in _requests.toList()) {
      request.abort();
    }
    _requests.clear();
  }

  void close() {
    cancelPending();
    _client.close(force: true);
  }
}
