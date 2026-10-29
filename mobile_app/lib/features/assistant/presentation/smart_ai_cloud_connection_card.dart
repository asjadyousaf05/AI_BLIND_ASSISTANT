import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/smart_ai_cloud_controller.dart';
import '../../../domain/entities/smart_ai_cloud_configuration.dart';

class SmartAiCloudConnectionCard extends ConsumerStatefulWidget {
  const SmartAiCloudConnectionCard({super.key});
  @override
  ConsumerState<SmartAiCloudConnectionCard> createState() =>
      _SmartAiCloudConnectionCardState();
}

class _SmartAiCloudConnectionCardState
    extends ConsumerState<SmartAiCloudConnectionCard> {
  final _groq = TextEditingController();
  final _router = TextEditingController();
  bool _consent = false;
  bool _saving = false;
  bool _useSavedKeys = true;
  SmartAiAnswerProvider _provider = SmartAiAnswerProvider.groq;
  String? _message;
  @override
  void dispose() {
    _groq.dispose();
    _router.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_consent || _saving) return;
    setState(() => _saving = true);
    final saved = ref.read(smartAiCloudControllerProvider).configuration;
    final reuse = _useSavedKeys ? saved : null;
    final error = await ref
        .read(smartAiCloudControllerProvider.notifier)
        .configure(
          SmartAiCloudConfiguration(
            groqKey: reuse?.groqKey ?? _groq.text.trim(),
            routerKey: reuse != null && reuse.routerKey.isNotEmpty
                ? reuse.routerKey
                : _router.text.trim(),
            answerProvider: _provider,
          ),
        );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _message =
          error ??
          'Smart AI cloud audio configured. Provider access is checked when you send a question.';
      if (error == null) {
        _groq.clear();
        _router.clear();
        _consent = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final saved = ref.watch(smartAiCloudControllerProvider).configuration;
    final configured = saved != null;
    final groqAnswers = _provider == SmartAiAnswerProvider.groq;
    final reuse = _useSavedKeys ? saved : null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                'Smart AI cloud audio',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Record → speech recognition → a brief answer → phone speech. No laptop needed. This mode applies only to Smart AI.',
            ),
            if (configured) ...[
              const SizedBox(height: 12),
              Text(
                'Configured: ${saved.answerProviderName}, ${saved.answerModel}. Internet and provider account access are required.',
              ),
              TextButton(
                onPressed: _saving
                    ? null
                    : () async {
                        setState(() => _saving = true);
                        final error = await ref
                            .read(smartAiCloudControllerProvider.notifier)
                            .removeConfiguration();
                        if (mounted) {
                          setState(() {
                            _saving = false;
                            _message =
                                error ??
                                'Smart AI cloud keys removed. Personal cloud setup is now disabled.';
                          });
                        }
                      },
                child: const Text('Remove Smart AI cloud keys'),
              ),
            ],
            ExpansionTile(
              key: const Key('smart_ai_cloud_setup'),
              tilePadding: EdgeInsets.zero,
              title: Text(
                configured
                    ? 'Replace personal Smart AI keys'
                    : 'Set up personal Smart AI keys',
              ),
              children: [
                RadioGroup<SmartAiAnswerProvider>(
                  groupValue: _provider,
                  onChanged: (value) {
                    if (value == null || _saving) return;
                    setState(() {
                      _provider = value;
                      _consent = false;
                      _message = null;
                    });
                  },
                  child: const Column(
                    children: [
                      RadioListTile<SmartAiAnswerProvider>(
                        key: Key('smart_ai_provider_groq'),
                        value: SmartAiAnswerProvider.groq,
                        contentPadding: EdgeInsets.zero,
                        title: Text('Groq for speech and answers'),
                        subtitle: Text(
                          'Whisper large v3 and GPT-OSS 20B. One personal key. Free quotas depend on your account.',
                        ),
                      ),
                      RadioListTile<SmartAiAnswerProvider>(
                        key: Key('smart_ai_provider_agent_router'),
                        value: SmartAiAnswerProvider.agentRouter,
                        contentPadding: EdgeInsets.zero,
                        title: Text('Groq speech and AgentRouter answers'),
                        subtitle: Text(
                          'DeepSeek V4 Flash. AgentRouter may require approval for this app client.',
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'Smart AI Speak uploads your temporary recording to Groq. The transcript and up to six recent messages go to ${groqAnswers ? 'Groq for GPT-OSS 20B answers' : 'AgentRouter and its model providers'}. Their privacy, retention, charges and quota policies apply. The phone deletes its clip after transcription or failure; this does not delete provider copies. Replies use phone-local text-to-speech. Camera images and Vision AI audio are never sent by this mode.',
                ),
                const SizedBox(height: 12),
                SelectableText(
                  groqAnswers
                      ? 'Create a key: console.groq.com/keys'
                      : 'Create keys: console.groq.com/keys and agentrouter.org',
                ),
                const SizedBox(height: 12),
                if (configured)
                  CheckboxListTile(
                    key: const Key('smart_ai_use_saved_keys'),
                    contentPadding: EdgeInsets.zero,
                    value: _useSavedKeys,
                    onChanged: _saving
                        ? null
                        : (value) =>
                              setState(() => _useSavedKeys = value ?? false),
                    title: const Text('Use saved keys on this phone'),
                  ),
                if (reuse == null) ...[
                  TextField(
                    key: const Key('smart_ai_groq_key'),
                    controller: _groq,
                    obscureText: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    enableIMEPersonalizedLearning: false,
                    decoration: const InputDecoration(
                      labelText: 'Personal Groq API key',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (!groqAnswers &&
                    (reuse == null || reuse.routerKey.isEmpty)) ...[
                  TextField(
                    key: const Key('smart_ai_router_key'),
                    controller: _router,
                    obscureText: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    enableIMEPersonalizedLearning: false,
                    decoration: const InputDecoration(
                      labelText: 'Personal AgentRouter API key',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                CheckboxListTile(
                  key: const Key('smart_ai_cloud_consent'),
                  contentPadding: EdgeInsets.zero,
                  value: _consent,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _consent = value ?? false),
                  title: Text(
                    'I agree to send Smart AI speech to Groq and conversation text to ${groqAnswers ? 'Groq' : 'AgentRouter'}, and save my personal keys encrypted on this phone.',
                  ),
                ),
                FilledButton(
                  onPressed: _consent && !_saving ? _save : null,
                  child: Text(
                    _saving
                        ? 'Saving…'
                        : groqAnswers
                        ? 'Use Groq for Smart AI'
                        : 'Use Groq and AgentRouter for Smart AI',
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
            if (_message != null)
              Semantics(liveRegion: true, child: Text(_message!)),
          ],
        ),
      ),
    );
  }
}
