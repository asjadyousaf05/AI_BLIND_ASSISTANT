import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/assistant_session_controller.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/action_buttons.dart';
import '../../../domain/entities/gemini_configuration.dart';

class GeminiConnectionCard extends ConsumerStatefulWidget {
  const GeminiConnectionCard({super.key});

  @override
  ConsumerState<GeminiConnectionCard> createState() =>
      _GeminiConnectionCardState();
}

class _GeminiConnectionCardState extends ConsumerState<GeminiConnectionCard> {
  final _keyController = TextEditingController();
  final _modelController = TextEditingController(
    text: GeminiConfiguration.defaultModel,
  );
  bool _consent = false;
  bool _saving = false;
  String? _message;

  @override
  void dispose() {
    _keyController.clear();
    _keyController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(assistantSessionControllerProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          headingLevel: 2,
          child: Text(
            'Gemini without a laptop',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: AppSpacing.space3),
        const Text(
          'Use your own Google AI Studio API key for online conversation. '
          'No laptop or pairing is needed. Mobile data or internet Wi-Fi is required. '
          'Speak and hands-free use this phone’s offline speech recognizer; '
          'recognition accuracy may differ from laptop Whisper. Replies play on this phone.',
        ),
        const SizedBox(height: AppSpacing.space3),
        const Text(
          'Google receives your conversation text and up to 10 recent messages. '
          'Camera images and audio are never sent to Gemini. Free-tier content may '
          'be reviewed or used to improve Google products; avoid confidential text. '
          'Free quotas vary by account and model. Use a project without billing for free-tier testing.',
        ),
        const SizedBox(height: AppSpacing.space3),
        if (state.usesDirectGemini) ...[
          Semantics(
            liveRegion: true,
            child: Text(
              'Gemini enabled: ${state.geminiConfiguration!.model}. '
              'Key saved securely. A successful answer verifies API access.',
            ),
          ),
          SecondaryActionButton(
            label: 'Remove Gemini key',
            semanticLabel:
                'Remove Gemini key and return to laptop conversation mode',
            onPressed: _saving ? null : () => _update(remove: true),
          ),
          const SizedBox(height: AppSpacing.space3),
        ],
        TextField(
          key: const Key('gemini_api_key'),
          controller: _keyController,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          enableIMEPersonalizedLearning: false,
          keyboardType: TextInputType.visiblePassword,
          decoration: InputDecoration(
            labelText: state.usesDirectGemini
                ? 'Replacement Gemini API key'
                : 'Gemini API key',
            helperText: 'Create your key at aistudio.google.com/api-keys',
            helperMaxLines: 3,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: AppSpacing.space3),
        TextField(
          key: const Key('gemini_model'),
          controller: _modelController,
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(
            labelText: 'Gemini model ID',
            border: OutlineInputBorder(),
          ),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'I agree to send conversation text to Google and save my own key encrypted on this phone.',
          ),
          value: _consent,
          onChanged: _saving
              ? null
              : (value) => setState(() => _consent = value ?? false),
        ),
        PrimaryActionButton(
          label: _saving ? 'Saving…' : 'Use Gemini without laptop',
          semanticLabel:
              'Save personal Gemini key securely and enable online conversation without laptop',
          onPressed: _saving || !_consent ? null : () => _update(remove: false),
        ),
        if (_message != null)
          Semantics(
            liveRegion: true,
            child: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.space3),
              child: Text(_message!),
            ),
          ),
      ],
    );
  }

  Future<void> _update({required bool remove}) async {
    setState(() {
      _saving = true;
      _message = null;
    });
    final controller = ref.read(assistantSessionControllerProvider.notifier);
    final error = remove
        ? await controller.disableDirectGemini()
        : await controller.enableDirectGemini(
            GeminiConfiguration(
              apiKey: _keyController.text.trim(),
              model: _modelController.text.trim(),
            ),
          );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _message =
          error ??
          (remove
              ? 'Gemini key removed. Laptop mode is selected; app controls remain offline.'
              : 'Gemini enabled. Return to Smart AI and send a question to test access.');
      if (error == null) {
        _keyController.clear();
        _consent = false;
      }
    });
  }
}
