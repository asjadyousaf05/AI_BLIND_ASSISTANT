import 'dart:async';
import 'package:ai_blind_assistant/domain/entities/assistant_message.dart';
import 'package:ai_blind_assistant/domain/entities/gemini_configuration.dart';
import 'package:ai_blind_assistant/domain/repositories/gemini_configuration_repository.dart';
import 'package:ai_blind_assistant/domain/services/gemini_conversation_service.dart';

const testGeminiConfiguration = GeminiConfiguration(
  apiKey: 'synthetic-personal-test-key',
);

class FakeGeminiConfigurationRepository
    implements GeminiConfigurationRepository {
  GeminiConfiguration? configuration;
  bool failSave = false;
  bool failDelete = false;
  Completer<GeminiConfiguration?>? loadGate;

  @override
  Future<GeminiConfiguration?> load() async =>
      loadGate == null ? configuration : await loadGate!.future;

  @override
  Future<void> save(GeminiConfiguration value) async {
    if (failSave) throw StateError('synthetic storage failure');
    configuration = value;
  }

  @override
  Future<void> delete() async {
    if (failDelete) throw StateError('synthetic storage failure');
    configuration = null;
  }
}

class FakeGeminiConversationService implements GeminiConversationService {
  final queries = <String>[];
  List<AssistantMessage> lastHistory = [];
  String response = 'A synthetic spoken answer.';
  GeminiConversationException? failure;
  Completer<String>? gate;
  int cancellations = 0;

  @override
  Future<String> reply({
    required GeminiConfiguration configuration,
    required String query,
    required List<AssistantMessage> history,
  }) async {
    queries.add(query);
    lastHistory = history;
    if (failure != null) throw failure!;
    return gate == null ? response : await gate!.future;
  }

  @override
  void cancelPending() => cancellations++;
}
