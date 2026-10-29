import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../../domain/entities/assistant_message.dart';
import '../../domain/entities/smart_ai_cloud_configuration.dart';
import '../../domain/services/audio_recorder_service.dart';
import '../../domain/services/smart_ai_cloud_service.dart';
import '../../domain/services/smart_ai_interaction_policy.dart';

/// Direct HTTPS using the providers' OpenAI-compatible wire protocol.
/// One long-lived client, async file upload, no isolates, redirects or retries.
class HttpSmartAiCloudService implements SmartAiCloudService {
  HttpSmartAiCloudService({
    HttpClient? client,
    this.transcriptionTimeout = const Duration(seconds: 20),
    this.replyTimeout = const Duration(seconds: 25),
  }) : _client = client ?? HttpClient() {
    _client.connectionTimeout = const Duration(seconds: 8);
  }
  final HttpClient _client;
  final Duration transcriptionTimeout;
  final Duration replyTimeout;
  final _requests = <HttpClientRequest>{};
  int _generation = 0;
  static final _groq = Uri.https(
    'api.groq.com',
    '/openai/v1/audio/transcriptions',
  );
  static final _router = Uri.https('agentrouter.org', '/v1/chat/completions');
  static final _groqChat = Uri.https(
    'api.groq.com',
    '/openai/v1/chat/completions',
  );
  static const systemPrompt =
      'You are a helpful, empathetic real-time assistant for a blind individual. Listen to their query and give highly concise, clear, and direct answers. Avoid lengthy lists, markdown symbols, or bullet points because your text output will be directly read aloud to them. Keep responses conversational and brief.';

  @override
  Future<String> transcribe({
    required SmartAiCloudConfiguration configuration,
    required String audioPath,
    SmartAiSpeechLanguage language = SmartAiSpeechLanguage.automatic,
  }) async {
    final generation = _generation;
    _validate(configuration);
    final file = File(audioPath);
    final length = await file.length();
    if (generation != _generation) {
      throw const SmartAiCloudException('Request cancelled.');
    }
    if (length < 100 || length > AudioRecorderService.maxFileSizeBytes) {
      throw const SmartAiCloudException(
        'The recording is empty or too large. Please record again.',
      );
    }
    final boundary = 'smart-ai-${Random.secure().nextInt(1 << 32)}';
    final languagePart = language == SmartAiSpeechLanguage.automatic
        ? ''
        : '--$boundary\r\nContent-Disposition: form-data; name="language"\r\n\r\n${language == SmartAiSpeechLanguage.english ? 'en' : 'ur'}\r\n';
    final prefix = utf8.encode(
      '$languagePart--$boundary\r\nContent-Disposition: form-data; name="model"\r\n\r\n${SmartAiCloudConfiguration.transcriptionModel}\r\n--$boundary\r\nContent-Disposition: form-data; name="response_format"\r\n\r\njson\r\n--$boundary\r\nContent-Disposition: form-data; name="temperature"\r\n\r\n0\r\n--$boundary\r\nContent-Disposition: form-data; name="file"; filename="speech.m4a"\r\nContent-Type: audio/mp4\r\n\r\n',
    );
    final suffix = utf8.encode('\r\n--$boundary--\r\n');
    final data = await _post(
      _groq,
      configuration.groqKey,
      'Groq',
      transcriptionTimeout,
      contentType: 'multipart/form-data; boundary=$boundary',
      length: prefix.length + length + suffix.length,
      write: (request) async {
        request.add(prefix);
        await request.addStream(file.openRead());
        request.add(suffix);
      },
    );
    final text = data['text'];
    if (text is! String || text.trim().isEmpty) {
      throw const SmartAiCloudException(
        'No clear speech was recognized. Please repeat or type your question.',
      );
    }
    if (text.length > 4096) {
      throw const SmartAiCloudException(
        'The transcript is too long. Please ask a shorter question.',
      );
    }
    return text.trim();
  }

  @override
  Future<String> reply({
    required SmartAiCloudConfiguration configuration,
    required String transcript,
    required List<AssistantMessage> history,
    SmartAiSpeechLanguage language = SmartAiSpeechLanguage.automatic,
  }) async {
    _validate(configuration);
    if (transcript.trim().isEmpty || transcript.length > 4096) {
      throw const SmartAiCloudException(
        'Use a question of at most 4096 characters.',
      );
    }
    final recent = history
        .where((m) => (m.isUser || m.isAssistant) && m.toolName == null)
        .toList();
    final messages = [
      {'role': 'system', 'content': systemPrompt},
      {
        'role': 'system',
        'content': SmartAiInteractionPolicy.responseLanguageInstruction(
          transcript,
          language: language,
        ),
      },
      for (final m in recent.skip(max(0, recent.length - 6)))
        {
          'role': m.isUser ? 'user' : 'assistant',
          'content': m.text.substring(0, min(m.text.length, 2048)),
        },
      {'role': 'user', 'content': transcript},
    ];
    final body = utf8.encode(
      jsonEncode({
        'model': configuration.answerModel,
        'messages': messages,
        if (configuration.usesGroqAnswers) ...{
          'reasoning_effort': 'low',
          'include_reasoning': false,
          // Includes the model's bounded internal reasoning and final answer.
          'max_completion_tokens': 512,
        } else ...{
          'thinking': {'type': 'disabled'},
          'max_tokens': 220,
        },
        'stream': false,
      }),
    );
    final data = await _post(
      configuration.usesGroqAnswers ? _groqChat : _router,
      configuration.usesGroqAnswers
          ? configuration.groqKey
          : configuration.routerKey,
      configuration.answerProviderName,
      replyTimeout,
      contentType: 'application/json',
      length: body.length,
      write: (request) async => request.add(body),
    );
    final choices = data['choices'];
    if (choices is! List || choices.isEmpty || choices.first is! Map) {
      throw SmartAiCloudException(
        '${configuration.answerProviderName} returned an unreadable answer. Please try again.',
      );
    }
    final choice = choices.first as Map;
    final message = choice['message'];
    final text = message is Map ? message['content'] : null;
    if (message is Map &&
        (message['tool_calls'] != null || message['function_call'] != null)) {
      throw SmartAiCloudException(
        '${configuration.answerProviderName} returned an unsupported answer. Please ask again.',
      );
    }
    if (text is! String || text.trim().isEmpty || text.length > 8192) {
      throw SmartAiCloudException(
        '${configuration.answerProviderName} returned an empty or oversized answer. Please ask again.',
      );
    }
    // Plain text is speech only; never interpret it as commands or tools.
    return text.trim();
  }

  void _validate(SmartAiCloudConfiguration configuration) {
    if (!configuration.isValid) {
      throw const SmartAiCloudException(
        'Configure both Smart AI API keys first.',
      );
    }
  }

  Future<Map<String, dynamic>> _post(
    Uri uri,
    String key,
    String provider,
    Duration timeout, {
    required String contentType,
    required int length,
    required Future<void> Function(HttpClientRequest) write,
  }) async {
    final generation = _generation;
    HttpClientRequest? active;
    bool cancelled = false;
    Future<Map<String, dynamic>> perform() async {
      final request = await _client.postUrl(uri);
      active = request;
      if (cancelled || generation != _generation) {
        request.abort();
        throw const SmartAiCloudException('Request cancelled.');
      }
      _requests.add(request);
      request.followRedirects = false;
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $key');
      request.headers.set(HttpHeaders.contentTypeHeader, contentType);
      request.contentLength = length;
      await write(request);
      final response = await request.close();
      if (response.statusCode != 200) {
        final clientBlocked =
            (response.statusCode == 401 || response.statusCode == 403) &&
            await _isUnapprovedClient(response).timeout(
              const Duration(milliseconds: 500),
              onTimeout: () => false,
            );
        request.abort();
        if (clientBlocked) {
          throw SmartAiCloudException(
            '$provider does not allow this app client. Ask the provider to enable app access.',
          );
        }
        throw SmartAiCloudException(switch (response.statusCode) {
          401 || 403 =>
            '$provider rejected access. Check its API key and account permissions.',
          402 => '$provider requires account credit. Check your balance.',
          404 =>
            '$provider endpoint or requested model is unavailable. Check your account model access.',
          429 => '$provider quota reached. Wait and check your account limits.',
          400 || 422 =>
            '$provider rejected the request settings. Check model compatibility and account access.',
          413 =>
            '$provider request exceeded its size limit. Use a shorter recording or question.',
          408 || 504 => '$provider timed out. The request was not retried.',
          _ => '$provider is temporarily unavailable. Please try again.',
        });
      }
      final bytes = <int>[];
      await for (final chunk in response) {
        if (bytes.length + chunk.length > 128 * 1024) {
          request.abort();
          throw SmartAiCloudException('$provider response was too large.');
        }
        bytes.addAll(chunk);
      }
      if (cancelled || generation != _generation) {
        throw const SmartAiCloudException('Request cancelled.');
      }
      final data = jsonDecode(utf8.decode(bytes));
      if (data is! Map<String, dynamic>) throw const FormatException();
      return data;
    }

    try {
      return await perform().timeout(timeout);
    } on TimeoutException {
      cancelled = true;
      active?.abort();
      throw SmartAiCloudException(
        '$provider timed out. Check your connection and try again.',
      );
    } on SmartAiCloudException {
      rethrow;
    } on FormatException {
      throw SmartAiCloudException(
        '$provider returned an unreadable response. Please try again.',
      );
    } catch (_) {
      active?.abort();
      throw SmartAiCloudException(
        'Cannot reach $provider. Check your internet connection and try again.',
      );
    } finally {
      if (active != null) _requests.remove(active);
    }
  }

  /// Recognize the gateway's fixed client-policy signal without retaining or
  /// displaying its diagnostic body. Invalid credentials remain a distinct
  /// error; the owner should not be told to replace a valid restricted key.
  Future<bool> _isUnapprovedClient(HttpClientResponse response) async {
    try {
      final bytes = <int>[];
      await for (final chunk in response) {
        if (bytes.length + chunk.length > 8192) return false;
        bytes.addAll(chunk);
      }
      final data = jsonDecode(utf8.decode(bytes));
      if (data is! Map) return false;
      final error = data['error'];
      if (data['type'] == 'unauthorized_client_error' ||
          (error is Map && error['type'] == 'unauthorized_client_error')) {
        return true;
      }
      final message = error is Map ? error['message'] : null;
      return message is String &&
          message.toLowerCase().startsWith('unauthorized client detected');
    } catch (_) {
      return false;
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
