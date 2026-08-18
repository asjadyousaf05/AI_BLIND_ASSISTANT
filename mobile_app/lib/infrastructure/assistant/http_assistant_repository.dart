import 'dart:convert';
import 'dart:io';

import '../../core/constants/assistant_defaults.dart';
import '../../domain/entities/assistant_credential.dart';
import '../../domain/entities/assistant_message.dart';
import '../../domain/entities/assistant_response.dart';
import '../../domain/entities/assistant_tool_result.dart';
import '../../domain/repositories/assistant_repository.dart';

/// Native HTTP implementation of [AssistantRepository] using `dart:io` `HttpClient`.
///
/// Requires zero third-party packages.
/// Applies a fixed timeout and bounded retry on transient failures.
/// Never logs bearer token or audio bytes.
class HttpAssistantRepository implements AssistantRepository {
  HttpAssistantRepository({HttpClient? client})
    : _client = client ?? HttpClient();

  final HttpClient _client;

  static const int _timeoutSeconds = 8;
  static const int _connectTimeoutSeconds = 4;
  static const int _maxRetries = 1;

  List<String> _candidateUrls(String baseUrl) {
    final uri = Uri.tryParse(baseUrl);
    if (uri == null) return [baseUrl];
    final port = uri.hasPort ? uri.port : AssistantDefaults.currentLaptopPort;
    final scheme = uri.scheme.isNotEmpty ? uri.scheme : 'http';

    final candidates = <String>[baseUrl];
    for (final fallback in AssistantDefaults.fallbackHosts) {
      final candidate = '$scheme://$fallback:$port';
      if (!candidates.contains(candidate)) {
        candidates.add(candidate);
      }
    }
    return candidates;
  }

  @override
  Future<int?> checkHealth(AssistantCredential credential) async {
    final candidateUrls = _candidateUrls(credential.backendUrl);
    for (final url in candidateUrls) {
      try {
        final uri = Uri.parse('$url/health');
        final request = await _client
            .getUrl(uri)
            .timeout(const Duration(seconds: _connectTimeoutSeconds));
        final response = await request.close().timeout(
          const Duration(seconds: _connectTimeoutSeconds),
        );

        if (response.statusCode == 200) {
          final body = await response.transform(utf8.decoder).join();
          final json = jsonDecode(body) as Map<String, dynamic>;
          return json['protocol_version'] as int? ?? 1;
        }
      } catch (_) {}
    }
    return null;
  }

  @override
  Future<AssistantCredential> pair({
    required String backendUrl,
    required String pairingCode,
  }) async {
    final candidateUrls = _candidateUrls(backendUrl);
    dynamic lastException;

    for (final url in candidateUrls) {
      try {
        final uri = Uri.parse('$url/auth/pair');
        final request = await _client
            .postUrl(uri)
            .timeout(const Duration(seconds: _connectTimeoutSeconds));
        request.headers.contentType = ContentType.json;
        final payload = jsonEncode({'pairing_code': pairingCode});
        request.write(payload);

        final response = await request.close().timeout(
          const Duration(seconds: _connectTimeoutSeconds),
        );
        final body = await response.transform(utf8.decoder).join();

        if (response.statusCode == 200) {
          final json = jsonDecode(body) as Map<String, dynamic>;
          return AssistantCredential(
            backendUrl: url,
            bearerToken: json['token'] as String,
            userId: json['user_id'] as String,
            displayName: json['display_name'] as String? ?? 'User',
            pairedAt: DateTime.now(),
            protocolVersion: json['protocol_version'] as int? ?? 1,
          );
        } else if (response.statusCode == 401 || response.statusCode == 403) {
          throw const AssistantAuthException(
            'Invalid or expired pairing code.',
          );
        } else {
          lastException = AssistantNetworkException(
            'Pairing failed: HTTP ${response.statusCode}',
            statusCode: response.statusCode,
          );
        }
      } on AssistantAuthException {
        rethrow;
      } on AssistantNetworkException catch (e) {
        lastException = e;
      } on SocketException catch (e) {
        lastException = AssistantNetworkException(
          'Cannot reach backend: ${e.message}',
        );
      } catch (e) {
        lastException = AssistantNetworkException('Pairing error: $e');
      }
    }

    if (lastException != null) {
      throw lastException;
    }
    throw const AssistantNetworkException('Cannot reach backend.');
  }

  @override
  Future<AssistantResponse> sendTextQuery({
    required AssistantCredential credential,
    required String query,
    required List<AssistantMessage> conversationHistory,
  }) async {
    final candidateUrls = _candidateUrls(credential.backendUrl);
    dynamic lastException;

    for (final url in candidateUrls) {
      try {
        final uri = Uri.parse('$url/assistant/query');
        final request = await _client
            .postUrl(uri)
            .timeout(const Duration(seconds: _timeoutSeconds));
        request.headers.contentType = ContentType.json;
        request.headers.set(
          'Authorization',
          'Bearer ${credential.bearerToken}',
        );
        request.write(
          jsonEncode({
            'query': query,
            'history': _historyToJson(conversationHistory),
          }),
        );

        final response = await request.close().timeout(
          const Duration(seconds: _timeoutSeconds),
        );
        final body = await response.transform(utf8.decoder).join();
        return _parseResponse(response.statusCode, body, credential);
      } on AssistantAuthException {
        rethrow;
      } catch (e) {
        lastException = e;
      }
    }

    if (lastException != null) {
      if (lastException is AssistantAuthException ||
          lastException is AssistantNetworkException) {
        throw lastException;
      }
      throw AssistantNetworkException('Network error: $lastException');
    }
    throw const AssistantNetworkException('Cannot reach backend.');
  }

  @override
  Future<AssistantResponse> sendAudioQuery({
    required AssistantCredential credential,
    required String audioFilePath,
    required List<AssistantMessage> conversationHistory,
  }) async {
    final file = File(audioFilePath);
    if (!await file.exists()) {
      throw const AssistantNetworkException('Audio file not found');
    }
    final fileBytes = await file.readAsBytes();
    final candidateUrls = _candidateUrls(credential.backendUrl);
    dynamic lastException;

    for (final url in candidateUrls) {
      try {
        final uri = Uri.parse('$url/assistant/audio');
        final boundary =
            '----AssistantBoundary${DateTime.now().millisecondsSinceEpoch}';
        final request = await _client
            .postUrl(uri)
            .timeout(const Duration(seconds: _timeoutSeconds));
        request.headers.set(
          'Content-Type',
          'multipart/form-data; boundary=$boundary',
        );
        request.headers.set(
          'Authorization',
          'Bearer ${credential.bearerToken}',
        );

        request.write('--$boundary\r\n');
        request.write(
          'Content-Disposition: form-data; name="audio"; filename="recording.m4a"\r\n',
        );
        request.write('Content-Type: audio/m4a\r\n\r\n');
        request.add(fileBytes);
        request.write('\r\n');

        request.write('--$boundary\r\n');
        request.write('Content-Disposition: form-data; name="history"\r\n\r\n');
        request.write(jsonEncode(_historyToJson(conversationHistory)));
        request.write('\r\n');
        request.write('--$boundary--\r\n');

        final response = await request.close().timeout(
          const Duration(seconds: _timeoutSeconds),
        );
        final body = await response.transform(utf8.decoder).join();
        return _parseResponse(response.statusCode, body, credential);
      } on AssistantAuthException {
        rethrow;
      } catch (e) {
        lastException = e;
      }
    }

    if (lastException != null) {
      if (lastException is AssistantAuthException ||
          lastException is AssistantNetworkException) {
        throw lastException;
      }
      throw AssistantNetworkException('Audio upload error: $lastException');
    }
    throw const AssistantNetworkException('Cannot reach backend.');
  }

  @override
  Future<AssistantResponse> reportToolResult({
    required AssistantCredential credential,
    required String requestId,
    required AssistantToolResult result,
    required List<AssistantMessage> conversationHistory,
  }) async {
    final uri = Uri.parse('${credential.backendUrl}/assistant/tool-result');
    return _withRetry(() async {
      final request = await _client
          .postUrl(uri)
          .timeout(const Duration(seconds: _timeoutSeconds));
      request.headers.contentType = ContentType.json;
      request.headers.set('Authorization', 'Bearer ${credential.bearerToken}');
      request.write(
        jsonEncode({
          'request_id': requestId,
          'tool_result': result.toJson(),
          'history': _historyToJson(conversationHistory),
        }),
      );

      final response = await request.close().timeout(
        const Duration(seconds: _timeoutSeconds),
      );
      final body = await response.transform(utf8.decoder).join();
      return _parseResponse(response.statusCode, body, credential);
    });
  }

  @override
  Future<List<AssistantMessage>> loadConversationHistory(
    AssistantCredential credential, {
    int limit = 20,
  }) async {
    final uri = Uri.parse(
      '${credential.backendUrl}/assistant/history?limit=$limit',
    );
    try {
      final request = await _client
          .getUrl(uri)
          .timeout(const Duration(seconds: _connectTimeoutSeconds));
      request.headers.set('Authorization', 'Bearer ${credential.bearerToken}');

      final response = await request.close().timeout(
        const Duration(seconds: _connectTimeoutSeconds),
      );
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        final items = json['messages'] as List<dynamic>? ?? [];
        return items.map(_messageFromJson).toList();
      }
    } catch (_) {}
    return [];
  }

  @override
  Future<void> clearConversationHistory(AssistantCredential credential) async {
    final uri = Uri.parse('${credential.backendUrl}/assistant/history');
    try {
      final request = await _client
          .deleteUrl(uri)
          .timeout(const Duration(seconds: _connectTimeoutSeconds));
      request.headers.set('Authorization', 'Bearer ${credential.bearerToken}');
      await request.close();
    } catch (_) {}
  }

  @override
  Future<List<Map<String, dynamic>>> listReminders(
    AssistantCredential credential,
  ) async {
    final uri = Uri.parse('${credential.backendUrl}/assistant/reminders');
    try {
      final request = await _client
          .getUrl(uri)
          .timeout(const Duration(seconds: _connectTimeoutSeconds));
      request.headers.set('Authorization', 'Bearer ${credential.bearerToken}');

      final response = await request.close().timeout(
        const Duration(seconds: _connectTimeoutSeconds),
      );
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        return (json['reminders'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    return [];
  }

  @override
  Future<List<Map<String, dynamic>>> listNotes(
    AssistantCredential credential,
  ) async {
    final uri = Uri.parse('${credential.backendUrl}/assistant/notes');
    try {
      final request = await _client
          .getUrl(uri)
          .timeout(const Duration(seconds: _connectTimeoutSeconds));
      request.headers.set('Authorization', 'Bearer ${credential.bearerToken}');

      final response = await request.close().timeout(
        const Duration(seconds: _connectTimeoutSeconds),
      );
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        return (json['notes'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    return [];
  }

  @override
  Future<String> getDailySummary(AssistantCredential credential) async {
    final uri = Uri.parse('${credential.backendUrl}/assistant/daily-summary');
    try {
      final request = await _client
          .getUrl(uri)
          .timeout(const Duration(seconds: _timeoutSeconds));
      request.headers.set('Authorization', 'Bearer ${credential.bearerToken}');

      final response = await request.close().timeout(
        const Duration(seconds: _timeoutSeconds),
      );
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        return json['summary'] as String? ?? '';
      }
    } catch (_) {}
    return '';
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  AssistantResponse _parseResponse(
    int statusCode,
    String body,
    AssistantCredential credential,
  ) {
    if (statusCode == 200 || statusCode == 201) {
      try {
        final json = jsonDecode(body) as Map<String, dynamic>;
        return AssistantResponse.fromJson(json);
      } catch (e) {
        throw AssistantNetworkException('Invalid response format: $e');
      }
    } else if (statusCode == 401 || statusCode == 403) {
      throw const AssistantAuthException('Session expired or token rejected.');
    } else if (statusCode == 426) {
      throw const AssistantVersionException(0);
    } else {
      throw AssistantNetworkException(
        'Backend error: HTTP $statusCode',
        statusCode: statusCode,
      );
    }
  }

  Future<AssistantResponse> _withRetry(
    Future<AssistantResponse> Function() fn,
  ) async {
    int attempt = 0;
    while (true) {
      try {
        return await fn();
      } on AssistantAuthException {
        rethrow;
      } on AssistantVersionException {
        rethrow;
      } on AssistantNetworkException catch (e) {
        attempt++;
        if (attempt >= _maxRetries ||
            (e.statusCode != null && e.statusCode! < 500)) {
          rethrow;
        }
        await Future<void>.delayed(
          Duration(milliseconds: 500 * (1 << attempt)),
        );
      } on SocketException catch (e) {
        attempt++;
        if (attempt >= _maxRetries) {
          throw AssistantNetworkException('Cannot reach backend: ${e.message}');
        }
        await Future<void>.delayed(
          Duration(milliseconds: 500 * (1 << attempt)),
        );
      } catch (e) {
        throw AssistantNetworkException('Unexpected error: $e');
      }
    }
  }

  List<Map<String, dynamic>> _historyToJson(List<AssistantMessage> messages) =>
      messages
          .take(10)
          .map((m) => {'role': m.role.name, 'content': m.text, 'id': m.id})
          .toList();

  AssistantMessage _messageFromJson(dynamic item) {
    final m = item as Map<String, dynamic>;
    final roleStr = m['role'] as String? ?? 'assistant';
    final role = AssistantMessageRole.values.firstWhere(
      (r) => r.name == roleStr,
      orElse: () => AssistantMessageRole.assistant,
    );
    return AssistantMessage(
      id: m['id'] as String? ?? DateTime.now().toIso8601String(),
      role: role,
      text: m['content'] as String? ?? '',
      createdAt:
          DateTime.tryParse(m['created_at'] as String? ?? '') ?? DateTime.now(),
      toolName: m['tool_name'] as String?,
    );
  }
}
