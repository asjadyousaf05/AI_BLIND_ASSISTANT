import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../domain/entities/assistant_credential.dart';
import '../../domain/entities/assistant_message.dart';
import '../../domain/entities/assistant_response.dart';
import '../../domain/entities/assistant_tool_result.dart';
import '../../domain/repositories/assistant_repository.dart';

/// Communicates only with the explicitly paired private-LAN endpoint.
/// Mutations are never retried on another host or after an ambiguous failure.
class HttpAssistantRepository implements AssistantRepository {
  HttpAssistantRepository({
    HttpClient? client,
    this.requestTimeout = const Duration(seconds: 8),
  }) : _client = client ?? HttpClient() {
    _client.connectionTimeout = requestTimeout;
    _client.findProxy = (_) => 'DIRECT';
    _client.connectionFactory = (uri, proxyHost, proxyPort) async {
      final addresses = await InternetAddress.lookup(
        uri.host,
      ).timeout(requestTimeout);
      if (addresses.isEmpty || addresses.any((address) => !_isLocal(address))) {
        throw const AssistantNetworkException(
          'Use a trusted private-LAN laptop address.',
        );
      }
      // Connect to the validated address itself, preventing a second DNS lookup.
      final address = addresses.firstWhere(
        (address) => address.type == InternetAddressType.IPv4,
        orElse: () => addresses.first,
      );
      return Socket.startConnect(address, uri.port);
    };
  }

  final HttpClient _client;
  final Duration requestTimeout;
  static const _maxResponseBytes = 1024 * 1024;

  void close() => _client.close(force: true);

  static bool _isLocal(InternetAddress address) {
    final bytes = address.rawAddress;
    if (bytes.length == 4) {
      return bytes[0] == 10 ||
          bytes[0] == 127 ||
          (bytes[0] == 172 && bytes[1] >= 16 && bytes[1] <= 31) ||
          (bytes[0] == 192 && bytes[1] == 168) ||
          (bytes[0] == 169 && bytes[1] == 254);
    }
    if (bytes.take(10).every((byte) => byte == 0) &&
        bytes[10] == 255 &&
        bytes[11] == 255) {
      return _isLocal(InternetAddress.fromRawAddress(bytes.sublist(12)));
    }
    return address.isLoopback ||
        (bytes[0] & 0xfe) == 0xfc ||
        (bytes[0] == 0xfe && (bytes[1] & 0xc0) == 0x80);
  }

  Uri _endpoint(String baseUrl, String path) {
    final uri = Uri.tryParse(baseUrl);
    if (uri == null ||
        !{'http', 'https'}.contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        uri.port < 1 ||
        uri.port > 65535) {
      throw const AssistantNetworkException(
        'Enter a valid private-LAN backend URL.',
      );
    }
    final literal = InternetAddress.tryParse(uri.host);
    if (literal != null && !_isLocal(literal)) {
      throw const AssistantNetworkException(
        'Use a trusted private-LAN laptop address.',
      );
    }
    return uri.resolve(path);
  }

  Future<Map<String, dynamic>> _request(
    String baseUrl,
    String path, {
    String method = 'GET',
    String? token,
    Map<String, dynamic>? data,
    List<int>? bytes,
    String? contentType,
  }) async {
    final uri = _endpoint(baseUrl, path);
    HttpClientRequest? activeRequest;
    var timedOut = false;
    Future<Map<String, dynamic>> perform() async {
      final request = await _client.openUrl(method, uri);
      activeRequest = request;
      if (timedOut) {
        request.abort();
        throw const AssistantNetworkException('The laptop request timed out.');
      }
      // Redirects must never forward pairing codes, tokens or personal text.
      request.followRedirects = false;
      if (token != null) request.headers.set('Authorization', 'Bearer $token');
      if (data != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(data));
      } else if (bytes != null) {
        request.headers.set('Content-Type', contentType!);
        request.add(bytes);
      }
      final response = await request.close();
      if (response.statusCode == 401 || response.statusCode == 403) {
        request.abort();
        throw const AssistantAuthException(
          'Pairing code or saved session rejected. Please re-pair.',
        );
      }
      if (response.statusCode == 426) {
        request.abort();
        throw const AssistantVersionException(0);
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        request.abort();
        throw AssistantNetworkException(
          'Backend error: HTTP ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
      final result = <int>[];
      await for (final chunk in response) {
        if (result.length + chunk.length > _maxResponseBytes) {
          request.abort();
          throw const AssistantNetworkException(
            'Backend response exceeds the size limit.',
          );
        }
        result.addAll(chunk);
      }
      if (response.statusCode == 204) return {};
      final decoded = jsonDecode(utf8.decode(result));
      if (decoded is! Map<String, dynamic>) {
        throw const AssistantNetworkException('Invalid backend response.');
      }
      return decoded;
    }

    try {
      return await perform().timeout(
        requestTimeout,
        onTimeout: () {
          timedOut = true;
          activeRequest?.abort();
          throw const AssistantNetworkException(
            'The laptop request timed out.',
          );
        },
      );
    } on AssistantAuthException {
      rethrow;
    } on AssistantVersionException {
      rethrow;
    } on AssistantNetworkException {
      rethrow;
    } catch (_) {
      throw const AssistantNetworkException(
        'Cannot read a valid response from the paired laptop.',
      );
    }
  }

  @override
  Future<int?> checkHealth(AssistantCredential credential) async {
    try {
      final result = await _request(credential.backendUrl, '/health');
      final version = result['protocol_version'];
      return version is int ? version : null;
    } on AssistantNetworkException {
      return null;
    }
  }

  @override
  Future<AssistantCredential> pair({
    required String backendUrl,
    required String pairingCode,
  }) async {
    if (pairingCode.trim().isEmpty) {
      throw const AssistantAuthException(
        'Enter the one-time pairing code from your laptop.',
      );
    }
    final result = await _request(
      backendUrl,
      '/auth/pair',
      method: 'POST',
      data: {'pairing_code': pairingCode.trim()},
    );
    if (result['token'] is! String ||
        (result['token'] as String).isEmpty ||
        result['user_id'] is! String ||
        result['protocol_version'] is! int) {
      throw const AssistantNetworkException('Invalid pairing response.');
    }
    final version = result['protocol_version'] as int;
    if (version != 1) throw AssistantVersionException(version);
    return AssistantCredential(
      backendUrl: backendUrl,
      bearerToken: result['token'] as String,
      userId: result['user_id'] as String,
      displayName: result['display_name'] as String? ?? 'User',
      pairedAt: DateTime.now(),
      protocolVersion: version,
    );
  }

  @override
  Future<AssistantResponse> sendTextQuery({
    required AssistantCredential credential,
    required String query,
    required List<AssistantMessage> conversationHistory,
  }) async => AssistantResponse.fromJson(
    await _request(
      credential.backendUrl,
      '/assistant/query',
      method: 'POST',
      token: credential.bearerToken,
      data: {'query': query, 'history': _historyToJson(conversationHistory)},
    ),
  );

  @override
  Future<AssistantResponse> sendAudioQuery({
    required AssistantCredential credential,
    required String audioFilePath,
    required List<AssistantMessage> conversationHistory,
  }) async {
    final file = File(audioFilePath);
    if (!await file.exists() || await file.length() > 4 * 1024 * 1024) {
      throw const AssistantNetworkException(
        'Audio file is unavailable or exceeds the size limit.',
      );
    }
    final boundary =
        'AssistantBoundary${DateTime.now().microsecondsSinceEpoch}';
    final body = <int>[
      ...utf8.encode(
        '--$boundary\r\nContent-Disposition: form-data; name="audio"; filename="recording.m4a"\r\nContent-Type: audio/m4a\r\n\r\n',
      ),
      ...await file.readAsBytes(),
      ...utf8.encode(
        '\r\n--$boundary\r\nContent-Disposition: form-data; name="history"\r\n\r\n${jsonEncode(_historyToJson(conversationHistory))}\r\n--$boundary--\r\n',
      ),
    ];
    return AssistantResponse.fromJson(
      await _request(
        credential.backendUrl,
        '/assistant/audio',
        method: 'POST',
        token: credential.bearerToken,
        bytes: body,
        contentType: 'multipart/form-data; boundary=$boundary',
      ),
    );
  }

  @override
  Future<AssistantResponse> reportToolResult({
    required AssistantCredential credential,
    required String requestId,
    required AssistantToolResult result,
    required List<AssistantMessage> conversationHistory,
  }) async => AssistantResponse.fromJson(
    await _request(
      credential.backendUrl,
      '/assistant/tool-result',
      method: 'POST',
      token: credential.bearerToken,
      data: {
        'request_id': requestId,
        'tool_result': result.toJson(),
        'history': _historyToJson(conversationHistory),
      },
    ),
  );

  @override
  Future<List<AssistantMessage>> loadConversationHistory(
    AssistantCredential credential, {
    int limit = 20,
  }) async {
    final result = await _request(
      credential.backendUrl,
      '/assistant/history?limit=${limit.clamp(1, 100)}',
      token: credential.bearerToken,
    );
    return (result['messages'] as List<dynamic>? ?? []).map((item) {
      final message = item as Map<String, dynamic>;
      return AssistantMessage(
        id: message['id'] as String,
        role: AssistantMessageRole.values.firstWhere(
          (role) => role.name == message['role'],
          orElse: () => AssistantMessageRole.assistant,
        ),
        text: message['content'] as String,
        createdAt:
            DateTime.tryParse(message['created_at'] as String? ?? '') ??
            DateTime.now(),
        toolName: message['tool_name'] as String?,
      );
    }).toList();
  }

  @override
  Future<void> clearConversationHistory(AssistantCredential credential) async {
    await _request(
      credential.backendUrl,
      '/assistant/history',
      method: 'DELETE',
      token: credential.bearerToken,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> listReminders(
    AssistantCredential credential,
  ) async =>
      ((await _request(
                    credential.backendUrl,
                    '/assistant/reminders',
                    token: credential.bearerToken,
                  ))['reminders']
                  as List<dynamic>? ??
              [])
          .cast<Map<String, dynamic>>();

  @override
  Future<List<Map<String, dynamic>>> listNotes(
    AssistantCredential credential,
  ) async =>
      ((await _request(
                    credential.backendUrl,
                    '/assistant/notes',
                    token: credential.bearerToken,
                  ))['notes']
                  as List<dynamic>? ??
              [])
          .cast<Map<String, dynamic>>();

  @override
  Future<String> getDailySummary(AssistantCredential credential) async =>
      (await _request(
            credential.backendUrl,
            '/assistant/daily-summary',
            token: credential.bearerToken,
          ))['summary']
          as String? ??
      '';

  List<Map<String, dynamic>> _historyToJson(List<AssistantMessage> messages) =>
      messages
          .skip(messages.length > 10 ? messages.length - 10 : 0)
          .map(
            (message) => {
              'role': message.role.name,
              'content': message.text,
              'id': message.id,
            },
          )
          .toList();
}
