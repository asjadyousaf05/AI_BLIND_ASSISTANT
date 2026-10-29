import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:ai_blind_assistant/domain/entities/assistant_message.dart';
import 'package:ai_blind_assistant/domain/entities/smart_ai_cloud_configuration.dart';
import 'package:ai_blind_assistant/domain/services/smart_ai_cloud_service.dart';
import 'package:ai_blind_assistant/domain/services/smart_ai_interaction_policy.dart';
import 'package:ai_blind_assistant/infrastructure/assistant/http_smart_ai_cloud_service.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../helpers/smart_ai_cloud_fakes.dart';

/// Synthetic HTTP only. The production service's fixed origins are asserted;
/// this test-only injected client maps them to a local server.
class _LocalClient implements HttpClient {
  _LocalClient(this.port);
  final int port;
  final _delegate = HttpClient();
  final origins = <Uri>[];
  @override
  Future<HttpClientRequest> postUrl(Uri uri) {
    origins.add(uri);
    return _delegate.postUrl(Uri.parse('http://127.0.0.1:$port${uri.path}'));
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

class _UnwritableRequest implements HttpClientRequest {
  bool aborted = false;
  @override
  void abort([Object? exception, StackTrace? stackTrace]) {
    aborted = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Late upload attempted');
}

void main() {
  late HttpServer server;
  late _LocalClient client;
  late HttpSmartAiCloudService service;
  late Directory directory;
  late File clip;
  late Future<void> Function(HttpRequest) handler;
  Map<String, dynamic> answer(String text) => {
    'choices': [
      {
        'message': {'role': 'assistant', 'content': text},
      },
    ],
  };
  Future<String> reply({List<AssistantMessage> history = const []}) =>
      service.reply(
        configuration: testSmartAiConfiguration,
        transcript: 'A synthetic question',
        history: history,
      );

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('smart-ai-http-');
    clip = await File(
      '${directory.path}/not-the-uploaded-name.m4a',
    ).writeAsBytes(List.filled(128, 0));
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    client = _LocalClient(server.port);
    service = HttpSmartAiCloudService(
      client: client,
      transcriptionTimeout: const Duration(seconds: 2),
      replyTimeout: const Duration(seconds: 2),
    );
    handler = (request) async {
      await request.drain<void>();
      request.response.write(
        jsonEncode(
          request.uri.path.contains('transcriptions')
              ? {'text': 'Recognized question'}
              : answer('A brief answer.'),
        ),
      );
      await request.response.close();
    };
    server.listen((request) async {
      try {
        await handler(request);
      } catch (_) {
        /* Expected aborted synthetic requests. */
      }
    });
  });
  tearDown(() async {
    service.close();
    await server.close(force: true);
    await directory.delete(recursive: true);
  });

  test(
    'Groq uploads multipart audio with exact model, isolated key and generic filename',
    () async {
      handler = (request) async {
        expect(
          request.headers.value(HttpHeaders.authorizationHeader),
          'Bearer ${testSmartAiConfiguration.groqKey}',
        );
        expect(request.headers.contentType!.mimeType, 'multipart/form-data');
        final body = await utf8.decoder.bind(request).join();
        expect(body, contains('whisper-large-v3'));
        expect(body, contains('filename="speech.m4a"'));
        expect(body, isNot(contains(clip.path)));
        expect(body, isNot(contains(testSmartAiConfiguration.routerKey)));
        request.response.write('{"text":"Recognized question"}');
        await request.response.close();
      };
      expect(
        await service.transcribe(
          configuration: testSmartAiConfiguration,
          audioPath: clip.path,
        ),
        'Recognized question',
      );
      expect(
        client.origins.single.toString(),
        'https://api.groq.com/openai/v1/audio/transcriptions',
      );
    },
  );

  test(
    'AgentRouter uses requested origin, exact prompt/model and a bounded plain chat',
    () async {
      handler = (request) async {
        expect(
          request.headers.value(HttpHeaders.authorizationHeader),
          'Bearer ${testSmartAiConfiguration.routerKey}',
        );
        final body =
            jsonDecode(await utf8.decoder.bind(request).join())
                as Map<String, dynamic>;
        expect(body['model'], 'deepseek-v4-flash');
        expect(body['thinking'], {'type': 'disabled'});
        expect(body['stream'], false);
        expect(body['max_tokens'], 220);
        expect((body['messages'] as List).first, {
          'role': 'system',
          'content':
              'You are a helpful, empathetic real-time assistant for a blind individual. Listen to their query and give highly concise, clear, and direct answers. Avoid lengthy lists, markdown symbols, or bullet points because your text output will be directly read aloud to them. Keep responses conversational and brief.',
        });
        expect(body.containsKey('tools'), false);
        expect(
          jsonEncode(body),
          isNot(contains(testSmartAiConfiguration.groqKey)),
        );
        request.response.write(jsonEncode(answer('A brief answer.')));
        await request.response.close();
      };
      expect(await reply(), 'A brief answer.');
      expect(
        client.origins.single.toString(),
        'https://agentrouter.org/v1/chat/completions',
      );
      expect(client.origins.single.hasQuery, false);
    },
  );

  test(
    'only six recent conversation messages are forwarded, excluding system/tools',
    () async {
      handler = (request) async {
        final body =
            jsonDecode(await utf8.decoder.bind(request).join())
                as Map<String, dynamic>;
        final messages = body['messages'] as List;
        expect(messages.length, 9);
        expect(jsonEncode(messages), isNot(contains('hidden system')));
        expect(jsonEncode(messages), isNot(contains('tool content')));
        expect(messages[2]['content'], 'question 4');
        request.response.write(jsonEncode(answer('Done.')));
        await request.response.close();
      };
      await reply(
        history: [
          AssistantMessage(
            id: 's',
            role: AssistantMessageRole.system,
            text: 'hidden system',
            createdAt: DateTime(2026),
          ),
          for (var i = 0; i < 10; i++)
            AssistantMessage(
              id: '$i',
              role: AssistantMessageRole.user,
              text: 'question $i',
              createdAt: DateTime(2026),
            ),
          AssistantMessage(
            id: 't',
            role: AssistantMessageRole.assistant,
            toolName: 'synthetic',
            text: 'tool content',
            createdAt: DateTime(2026),
          ),
        ],
      );
    },
  );

  for (final question in ['What is a rainbow?', 'قوس قزح کیا ہے؟']) {
    test(
      'latest question chooses reply language despite opposite-language history: $question',
      () async {
        handler = (request) async {
          final data =
              jsonDecode(await utf8.decoder.bind(request).join()) as Map;
          final messages = data['messages'] as List;
          expect(
            messages.first['content'],
            HttpSmartAiCloudService.systemPrompt,
          );
          expect(messages[1]['role'], 'system');
          expect(
            messages[1]['content'],
            contains(question.startsWith('What') ? 'in English' : 'in Urdu'),
          );
          request.response.write(jsonEncode(answer('A short answer.')));
          await request.response.close();
        };
        await service.reply(
          configuration: testGroqSmartAiConfiguration,
          transcript: question,
          history: [
            AssistantMessage(
              id: 'old',
              role: AssistantMessageRole.user,
              text: question.startsWith('What')
                  ? 'ایک پرانا سوال'
                  : 'An old question',
              createdAt: DateTime(2026),
            ),
          ],
        );
      },
    );
  }

  test(
    'Groq speech and answers use one key and never contact AgentRouter',
    () async {
      const configuration = SmartAiCloudConfiguration(
        groqKey: 'synthetic-groq-key-only',
        routerKey: 'synthetic-router-key-not-used',
        answerProvider: SmartAiAnswerProvider.groq,
      );
      handler = (request) async {
        expect(
          request.headers.value(HttpHeaders.authorizationHeader),
          'Bearer ${configuration.groqKey}',
        );
        final raw = await utf8.decoder.bind(request).join();
        expect(raw, isNot(contains(configuration.routerKey)));
        if (request.uri.path.contains('transcriptions')) {
          request.response.write('{"text":"A synthetic question"}');
        } else {
          final body = jsonDecode(raw) as Map<String, dynamic>;
          expect(body['model'], 'openai/gpt-oss-20b');
          expect(body['reasoning_effort'], 'low');
          expect(body['include_reasoning'], false);
          expect(body['max_completion_tokens'], 512);
          expect(body.containsKey('thinking'), false);
          expect(body.containsKey('tools'), false);
          expect(
            (body['messages'] as List).first['content'],
            HttpSmartAiCloudService.systemPrompt,
          );
          request.response.write(
            jsonEncode({
              'choices': [
                {
                  'message': {
                    'content': 'A brief answer.',
                    'reasoning': 'Private model reasoning',
                  },
                },
              ],
            }),
          );
        }
        await request.response.close();
      };
      final text = await service.transcribe(
        configuration: configuration,
        audioPath: clip.path,
      );
      expect(
        await service.reply(
          configuration: configuration,
          transcript: text,
          history: [],
        ),
        'A brief answer.',
      );
      expect(client.origins.map((u) => u.toString()), [
        'https://api.groq.com/openai/v1/audio/transcriptions',
        'https://api.groq.com/openai/v1/chat/completions',
      ]);
    },
  );

  for (final status in [
    301,
    400,
    401,
    402,
    403,
    404,
    408,
    413,
    422,
    429,
    500,
    504,
  ]) {
    test(
      'HTTP $status fails safely without redirects, retries or provider body disclosure',
      () async {
        var count = 0;
        handler = (request) async {
          count++;
          await request.drain<void>();
          request.response.statusCode = status;
          request.response.headers.set(
            'location',
            'http://127.0.0.1:${server.port}/stolen',
          );
          request.response.write(
            'Private provider diagnostic ${testSmartAiConfiguration.routerKey}',
          );
          await request.response.close();
        };
        await expectLater(
          reply(),
          throwsA(
            isA<SmartAiCloudException>().having(
              (e) => e.message,
              'safe message',
              isNot(contains('Private provider diagnostic')),
            ),
          ),
        );
        expect(count, 1);
      },
    );
  }

  test(
    'a short question rejected with HTTP 400 is not described as too long',
    () async {
      handler = (request) async {
        await request.drain<void>();
        request.response.statusCode = 400;
        request.response.write('Private incompatible-model details');
        await request.response.close();
      };
      await expectLater(
        reply(),
        throwsA(
          isA<SmartAiCloudException>()
              .having(
                (e) => e.message,
                'recovery',
                contains('request settings'),
              )
              .having(
                (e) => e.message,
                'no guessed size cause',
                isNot(contains('shorter')),
              ),
        ),
      );
      expect(client.origins.length, 1);
    },
  );

  test(
    'client-policy rejection is distinct from an invalid key and stays private',
    () async {
      handler = (request) async {
        await request.drain<void>();
        request.response.statusCode = 401;
        request.response.write(
          jsonEncode({
            'type': 'unauthorized_client_error',
            'error': {
              'message':
                  'unauthorized client detected: private provider diagnostic',
              'credential': testSmartAiConfiguration.routerKey,
            },
          }),
        );
        await request.response.close();
      };
      await expectLater(
        reply(),
        throwsA(
          isA<SmartAiCloudException>()
              .having(
                (e) => e.message,
                'client recovery',
                contains('enable app access'),
              )
              .having(
                (e) => e.message,
                'no guessed credential failure',
                isNot(contains('API key')),
              )
              .having(
                (e) => e.message,
                'no body disclosure',
                isNot(contains('private provider diagnostic')),
              ),
        ),
      );
      expect(client.origins.length, 1);
    },
  );

  test(
    'a stalled authentication diagnostic cannot hide the access error',
    () async {
      final finishBody = Completer<void>();
      handler = (request) async {
        await request.drain<void>();
        request.response.statusCode = 401;
        request.response.write('{"error":');
        await request.response.flush();
        await finishBody.future;
        await request.response.close();
      };
      try {
        await expectLater(
          reply(),
          throwsA(
            isA<SmartAiCloudException>().having(
              (e) => e.message,
              'bounded auth recovery',
              contains('rejected access'),
            ),
          ),
        );
        expect(client.origins.length, 1);
      } finally {
        finishBody.complete();
      }
    },
  );

  for (final body in [
    'not json',
    '{}',
    '{"choices":[]}',
    '{"choices":[{"message":{"content":""}}]}',
  ]) {
    test('malformed/empty response $body is rejected', () async {
      handler = (request) async {
        await request.drain<void>();
        request.response.write(body);
        await request.response.close();
      };
      await expectLater(reply(), throwsA(isA<SmartAiCloudException>()));
    });
  }

  test('model-generated tool calls can never execute', () async {
    handler = (request) async {
      await request.drain<void>();
      request.response.write(
        jsonEncode({
          'choices': [
            {
              'message': {
                'content': 'Run a command',
                'tool_calls': [
                  {'name': 'delete_everything'},
                ],
              },
            },
          ],
        }),
      );
      await request.response.close();
    };
    await expectLater(reply(), throwsA(isA<SmartAiCloudException>()));
  });

  test('oversized response is bounded', () async {
    handler = (request) async {
      await request.drain<void>();
      request.response.write('x' * (129 * 1024));
      await request.response.close();
    };
    await expectLater(reply(), throwsA(isA<SmartAiCloudException>()));
  });

  test(
    'timeout aborts a connection even when its request arrives later',
    () async {
      final pending = _PendingClient();
      final delayed = HttpSmartAiCloudService(
        client: pending,
        replyTimeout: const Duration(milliseconds: 10),
      );
      await expectLater(
        delayed.reply(
          configuration: testSmartAiConfiguration,
          transcript: 'Question',
          history: [],
        ),
        throwsA(
          isA<SmartAiCloudException>().having(
            (e) => e.message,
            'timeout',
            contains('timed out'),
          ),
        ),
      );
      final request = _UnwritableRequest();
      pending.gate.complete(request);
      await Future<void>.delayed(Duration.zero);
      expect(request.aborted, true);
      delayed.close();
    },
  );

  test(
    'cancellation before connection completes prevents any upload',
    () async {
      final pending = _PendingClient();
      final delayed = HttpSmartAiCloudService(client: pending);
      final result = delayed.reply(
        configuration: testSmartAiConfiguration,
        transcript: 'Question',
        history: [],
      );
      final expectation = expectLater(
        result,
        throwsA(isA<SmartAiCloudException>()),
      );
      delayed.cancelPending();
      final request = _UnwritableRequest();
      pending.gate.complete(request);
      await expectation;
      expect(request.aborted, true);
      delayed.close();
    },
  );

  test(
    'empty/oversized clip and empty speech never proceed as conversation',
    () async {
      await clip.writeAsBytes([]);
      await expectLater(
        service.transcribe(
          configuration: testSmartAiConfiguration,
          audioPath: clip.path,
        ),
        throwsA(isA<SmartAiCloudException>()),
      );
      expect(client.origins, isEmpty);
      await clip.writeAsBytes(List.filled(128, 0));
      handler = (request) async {
        await request.drain<void>();
        request.response.write('{"text":"   "}');
        await request.response.close();
      };
      await expectLater(
        service.transcribe(
          configuration: testSmartAiConfiguration,
          audioPath: clip.path,
        ),
        throwsA(isA<SmartAiCloudException>()),
      );
    },
  );
  for (final language in SmartAiSpeechLanguage.values) {
    test(
      'transcription language field follows explicit $language choice',
      () async {
        handler = (request) async {
          final body = await utf8.decoder.bind(request).join();
          if (language == SmartAiSpeechLanguage.automatic) {
            expect(body, isNot(contains('name="language"')));
          } else {
            expect(
              body,
              contains(
                'name="language"\r\n\r\n${language == SmartAiSpeechLanguage.english ? 'en' : 'ur'}\r\n',
              ),
            );
          }
          request.response.write('{"text":"A question"}');
          await request.response.close();
        };
        await service.transcribe(
          configuration: testGroqSmartAiConfiguration,
          audioPath: clip.path,
          language: language,
        );
      },
    );
  }
  test(
    'explicit English overrides a wrongly scripted transcript for the reply',
    () async {
      handler = (request) async {
        final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map;
        expect(body['messages'][1]['content'], contains('in English'));
        request.response.write(jsonEncode(answer('An English answer.')));
        await request.response.close();
      };
      await service.reply(
        configuration: testGroqSmartAiConfiguration,
        transcript: 'یہ ایک سوال ہے',
        history: [],
        language: SmartAiSpeechLanguage.english,
      );
    },
  );
}
