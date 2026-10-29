import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ai_blind_assistant/domain/entities/assistant_message.dart';
import 'package:ai_blind_assistant/domain/services/gemini_conversation_service.dart';
import 'package:ai_blind_assistant/infrastructure/assistant/http_gemini_conversation_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/gemini_fakes.dart';

/// Only this injected test client redirects the fixed Google URL to a local
/// synthetic HTTP server. Production has no configurable API endpoint.
class _LocalClient implements HttpClient {
  _LocalClient(this.port);
  final int port;
  final _delegate = HttpClient();
  Uri? requestedUri;
  @override
  Future<HttpClientRequest> postUrl(Uri uri) {
    requestedUri = uri;
    return _delegate.postUrl(Uri.parse('http://127.0.0.1:$port/'));
  }

  @override
  void close({bool force = false}) => _delegate.close(force: force);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _PendingClient implements HttpClient {
  final gate = Completer<HttpClientRequest>();
  @override
  Future<HttpClientRequest> postUrl(Uri uri) => gate.future;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _AbortedRequest implements HttpClientRequest {
  bool aborted = false;
  @override
  void abort([Object? exception, StackTrace? stackTrace]) => aborted = true;
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError('Late write');
}

void main() {
  late HttpServer server;
  late _LocalClient client;
  late HttpGeminiConversationService service;
  late Future<void> Function(HttpRequest) handler;
  Map<String, dynamic> answer(String text) => {
    'status': 'completed',
    'steps': [
      {
        'type': 'thought',
        'content': [
          {'type': 'text', 'text': 'Hidden thought'},
        ],
      },
      {
        'type': 'model_output',
        'content': [
          {'type': 'text', 'text': text},
        ],
      },
    ],
  };
  Future<String> query({List<AssistantMessage> history = const []}) =>
      service.reply(
        configuration: testGeminiConfiguration,
        query: 'A synthetic question',
        history: history,
      );

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    client = _LocalClient(server.port);
    service = HttpGeminiConversationService(
      client: client,
      timeout: const Duration(seconds: 2),
    );
    handler = (request) async {
      await request.drain<void>();
      request.response.write(jsonEncode(answer('A synthetic answer.')));
      await request.response.close();
    };
    server.listen((request) async {
      try {
        await handler(request);
      } on HttpException {
        /* Cancelled test request. */
      }
    });
  });
  tearDown(() async {
    service.close();
    await server.close(force: true);
  });

  test(
    'uses fixed HTTPS endpoint, header key, text-only payload and no stored interaction',
    () async {
      Map<String, dynamic>? payload;
      handler = (request) async {
        expect(
          request.headers.value('x-goog-api-key'),
          testGeminiConfiguration.apiKey,
        );
        payload =
            jsonDecode(await utf8.decoder.bind(request).join())
                as Map<String, dynamic>;
        request.response.write(jsonEncode(answer('A synthetic answer.')));
        await request.response.close();
      };
      expect(await query(), 'A synthetic answer.');
      expect(
        client.requestedUri.toString(),
        'https://generativelanguage.googleapis.com/v1beta/interactions',
      );
      expect(client.requestedUri!.hasQuery, isFalse);
      expect(payload!['store'], isFalse);
      expect(payload!['model'], testGeminiConfiguration.model);
      expect(payload!['input'], 'A synthetic question');
      expect(
        payload!.keys,
        unorderedEquals([
          'model',
          'store',
          'system_instruction',
          'input',
          'generation_config',
        ]),
      );
    },
  );

  test('bounds history and excludes system and tool data', () async {
    String? input;
    handler = (request) async {
      input =
          (jsonDecode(await utf8.decoder.bind(request).join()) as Map)['input']
              as String;
      request.response.write(jsonEncode(answer('Answer')));
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
    history.add(
      AssistantMessage(
        id: 'system',
        role: AssistantMessageRole.system,
        text: 'excluded-system',
        createdAt: DateTime(2026),
      ),
    );
    history.add(
      AssistantMessage(
        id: 'tool',
        role: AssistantMessageRole.assistant,
        toolName: 'private-tool',
        text: 'excluded-tool',
        createdAt: DateTime(2026),
      ),
    );
    await query(history: history);
    expect(input, isNot(contains('Message 0\n')));
    expect(input, contains('Message 2\n'));
    expect(input, isNot(contains('excluded-')));
  });

  for (final status in [302, 400, 401, 403, 404, 429, 503]) {
    test(
      'HTTP $status gives bounded recovery without exposing provider body',
      () async {
        var count = 0;
        handler = (request) async {
          count++;
          await request.drain<void>();
          request.response.statusCode = status;
          request.response.headers.set(
            'location',
            'http://127.0.0.1:${server.port}/redirected',
          );
          request.response.write('sensitive-provider-error-body');
          await request.response.close();
        };
        await expectLater(
          query(),
          throwsA(
            isA<GeminiConversationException>().having(
              (error) => error.message,
              'safe error',
              isNot(contains('sensitive-provider-error-body')),
            ),
          ),
        );
        expect(count, 1);
      },
    );
  }

  for (final payload in [
    'not JSON',
    '{"status":"in_progress","steps":[]}',
    '{"status":"completed","steps":[{"type":"function_call","name":"stop_everything"}]}',
  ]) {
    test(
      'rejects incomplete, malformed or non-text provider response: $payload',
      () async {
        handler = (request) async {
          await request.drain<void>();
          request.response.write(payload);
          await request.response.close();
        };
        await expectLater(query(), throwsA(isA<GeminiConversationException>()));
      },
    );
  }

  test('rejects an oversized response', () async {
    handler = (request) async {
      await request.drain<void>();
      request.response.write('x' * (256 * 1024 + 1));
      await request.response.close();
    };
    await expectLater(query(), throwsA(isA<GeminiConversationException>()));
  });

  test(
    'timeout prevents a late connection from uploading text or key',
    () async {
      final pending = _PendingClient();
      final delayed = HttpGeminiConversationService(
        client: pending,
        timeout: const Duration(milliseconds: 10),
      );
      await expectLater(
        delayed.reply(
          configuration: testGeminiConfiguration,
          query: 'Synthetic text',
          history: [],
        ),
        throwsA(isA<GeminiConversationException>()),
      );
      final request = _AbortedRequest();
      pending.gate.complete(request);
      await Future<void>.delayed(Duration.zero);
      expect(request.aborted, isTrue);
      delayed.close();
    },
  );

  test(
    'cancellation prevents an in-flight connection from uploading',
    () async {
      final pending = _PendingClient();
      final delayed = HttpGeminiConversationService(client: pending);
      final request = _AbortedRequest();
      final result = delayed.reply(
        configuration: testGeminiConfiguration,
        query: 'Synthetic text',
        history: [],
      );
      final expectation = expectLater(
        result,
        throwsA(isA<GeminiConversationException>()),
      );
      delayed.cancelPending();
      pending.gate.complete(request);
      await expectation;
      expect(request.aborted, isTrue);
      delayed.close();
    },
  );
}
