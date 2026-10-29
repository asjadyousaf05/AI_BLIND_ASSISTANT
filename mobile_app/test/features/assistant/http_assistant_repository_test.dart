import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ai_blind_assistant/domain/entities/assistant_credential.dart';
import 'package:ai_blind_assistant/domain/entities/assistant_message.dart';
import 'package:ai_blind_assistant/domain/entities/assistant_tool_result.dart';
import 'package:ai_blind_assistant/domain/repositories/assistant_repository.dart';
import 'package:ai_blind_assistant/infrastructure/assistant/http_assistant_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _PendingClient implements HttpClient {
  final pending = Completer<HttpClientRequest>();
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) => pending.future;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _LateRequest implements HttpClientRequest {
  bool aborted = false;
  @override
  void abort([Object? exception, StackTrace? stackTrace]) => aborted = true;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected work after timeout');
}

void main() {
  late HttpServer server;
  late HttpAssistantRepository repository;
  late AssistantCredential credential;
  late Future<void> Function(HttpRequest) handler;
  late List<String> paths;
  late List<Map<String, dynamic>> payloads;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    repository = HttpAssistantRepository(
      requestTimeout: const Duration(seconds: 2),
    );
    credential = AssistantCredential(
      backendUrl: 'http://127.0.0.1:${server.port}',
      bearerToken: 'synthetic-test-token',
      userId: 'test',
      displayName: 'Test',
      pairedAt: DateTime(2026),
    );
    paths = [];
    payloads = [];
    handler = (request) async {
      expect(
        request.headers.value('authorization'),
        'Bearer synthetic-test-token',
      );
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({'response_text': 'Done', 'request_id': 'test-request'}),
      );
      await request.response.close();
    };
    server.listen((request) async {
      paths.add(request.uri.path);
      await handler(request);
    });
  });
  tearDown(() async {
    repository.close();
    await server.close(force: true);
  });

  test(
    'a connection completing after timeout cannot send a late mutation',
    () async {
      final client = _PendingClient();
      final delayed = HttpAssistantRepository(
        client: client,
        requestTimeout: const Duration(milliseconds: 20),
      );
      await expectLater(
        delayed.sendTextQuery(
          credential: credential,
          query: 'Hello',
          conversationHistory: [],
        ),
        throwsA(isA<AssistantNetworkException>()),
      );
      final request = _LateRequest();
      client.pending.complete(request);
      await Future<void>.delayed(Duration.zero);
      expect(request.aborted, isTrue);
      delayed.close();
    },
  );

  test(
    'query and tool report stay on the selected authenticated endpoint',
    () async {
      handler = (request) async {
        expect(
          request.headers.value('authorization'),
          'Bearer synthetic-test-token',
        );
        payloads.add(
          jsonDecode(await utf8.decoder.bind(request).join())
              as Map<String, dynamic>,
        );
        request.response.write(
          jsonEncode({'response_text': 'Done', 'request_id': 'test-request'}),
        );
        await request.response.close();
      };
      final history = List.generate(
        12,
        (index) => AssistantMessage(
          id: '$index',
          role: AssistantMessageRole.user,
          text: 'Message $index',
          createdAt: DateTime(2026),
        ),
      );
      await repository.sendTextQuery(
        credential: credential,
        query: 'Hello',
        conversationHistory: history,
      );
      await repository.reportToolResult(
        credential: credential,
        requestId: 'test-request',
        result: AssistantToolResult.ok('delete_note'),
        conversationHistory: [],
      );
      expect(paths, ['/assistant/query', '/assistant/tool-result']);
      expect((payloads.first['history'] as List).first['content'], 'Message 2');
      expect((payloads.first['history'] as List).last['content'], 'Message 11');
      expect(payloads.last['tool_result']['success'], isTrue);
    },
  );

  test('pairing sends a required code only to the selected endpoint', () async {
    handler = (request) async {
      expect(request.headers.value('authorization'), isNull);
      payloads.add(
        jsonDecode(await utf8.decoder.bind(request).join())
            as Map<String, dynamic>,
      );
      request.response.write(
        jsonEncode({'token': 'test', 'user_id': 'test', 'protocol_version': 1}),
      );
      await request.response.close();
    };
    await expectLater(
      repository.pair(backendUrl: credential.backendUrl, pairingCode: ''),
      throwsA(isA<AssistantAuthException>()),
    );
    expect(paths, isEmpty);
    final result = await repository.pair(
      backendUrl: credential.backendUrl,
      pairingCode: ' ABC ',
    );
    expect(result.backendUrl, credential.backendUrl);
    expect(payloads.single['pairing_code'], 'ABC');
  });

  for (final url in [
    'http://8.8.8.8:8765',
    'http://[::ffff:8.8.8.8]:8765',
    'http://user:secret@127.0.0.1:8765',
    'http://127.0.0.1:8765/nested',
    'file:///tmp/test',
  ]) {
    test('rejects an unsafe endpoint before sending: $url', () async {
      await expectLater(
        repository.sendTextQuery(
          credential: credential.copyWith(backendUrl: url),
          query: 'Hello',
          conversationHistory: [],
        ),
        throwsA(isA<AssistantNetworkException>()),
      );
      expect(paths, isEmpty);
    });
  }

  test('does not follow redirects or retry a mutation', () async {
    handler = (request) async {
      request.response.statusCode = 307;
      request.response.headers.set(
        'location',
        '${credential.backendUrl}/redirect-target',
      );
      await request.response.close();
    };
    await expectLater(
      repository.sendTextQuery(
        credential: credential,
        query: 'Hello',
        conversationHistory: [],
      ),
      throwsA(isA<AssistantNetworkException>()),
    );
    expect(paths, ['/assistant/query']);
  });

  test(
    'list and delete failures propagate instead of claiming empty/success',
    () async {
      handler = (request) async {
        request.response.statusCode = 401;
        await request.response.close();
      };
      await expectLater(
        repository.listNotes(credential),
        throwsA(isA<AssistantAuthException>()),
      );
      await expectLater(
        repository.clearConversationHistory(credential),
        throwsA(isA<AssistantAuthException>()),
      );
    },
  );

  test('malformed and oversized responses fail with typed errors', () async {
    handler = (request) async {
      request.response.write('[]');
      await request.response.close();
    };
    await expectLater(
      repository.sendTextQuery(
        credential: credential,
        query: 'Hello',
        conversationHistory: [],
      ),
      throwsA(isA<AssistantNetworkException>()),
    );
    handler = (request) async {
      request.response.write('x' * (1024 * 1024 + 1));
      await request.response.close();
    };
    await expectLater(
      repository.sendTextQuery(
        credential: credential,
        query: 'Hello',
        conversationHistory: [],
      ),
      throwsA(isA<AssistantNetworkException>()),
    );
  });

  test(
    'timeout includes a stalled response body and sends only once',
    () async {
      repository.close();
      repository = HttpAssistantRepository(
        requestTimeout: const Duration(milliseconds: 150),
      );
      handler = (request) async {
        request.response.headers.contentType = ContentType.json;
        request.response.write('{');
        await request.response.flush();
      };
      await expectLater(
        repository.sendTextQuery(
          credential: credential,
          query: 'Hello',
          conversationHistory: [],
        ),
        throwsA(isA<AssistantNetworkException>()),
      );
      expect(paths, ['/assistant/query']);
    },
  );
}
