import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/smart_ai_cloud_controller.dart';
import '../../../app/voice_kernel/voice_kernel_providers.dart';
import '../../../domain/services/smart_ai_interaction_policy.dart';
import '../../../core/widgets/action_buttons.dart';
import '../../../core/widgets/app_screen_scaffold.dart';
import 'smart_ai_voice_circle.dart';

/// Smart AI-only view; all capture/network/speech work is in its controller.
class SmartAiCloudScreen extends ConsumerStatefulWidget {
  const SmartAiCloudScreen({
    super.key,
    required this.openConnectionSettings,
    this.initialDraft,
    this.onReturnHome,
    this.onUseOtherAssistant,
  });
  final Future<void> Function() openConnectionSettings;
  final String? initialDraft;
  final VoidCallback? onReturnHome;
  final VoidCallback? onUseOtherAssistant;
  @override
  ConsumerState<SmartAiCloudScreen> createState() => _SmartAiCloudScreenState();
}

class _SmartAiCloudScreenState extends ConsumerState<SmartAiCloudScreen> {
  late final SmartAiCloudController _controller;
  final _text = TextEditingController();
  bool _showText = false;
  @override
  void initState() {
    super.initState();
    _controller = ref.read(smartAiCloudControllerProvider.notifier);
    _text.text = widget.initialDraft ?? '';
    _showText = _text.text.isNotEmpty;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_controller.activate());
    });
  }

  @override
  void dispose() {
    unawaited(Future<void>.microtask(_controller.deactivate));
    _text.dispose();
    super.dispose();
  }

  Future<void> _settings() async {
    await _controller.deactivate();
    await widget.openConnectionSettings();
    if (mounted) await _controller.activate();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(smartAiCloudControllerProvider);
    ref.listen(
      smartAiCloudControllerProvider.select((s) => s.returnHomeRequested),
      (previous, next) {
        if (next && previous != true) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) widget.onReturnHome?.call();
          });
        }
      },
    );
    final answerProvider =
        state.configuration?.answerProviderName ?? 'the selected provider';
    final phase = state.phase;
    final configured = state.configuration != null;
    final canAsk = state.ready && configured;
    final recording = phase == SmartAiPhase.recording;
    final speaking = phase == SmartAiPhase.speaking;
    final paused = phase == SmartAiPhase.paused;
    final status = switch (phase) {
      SmartAiPhase.idle =>
        !configured
            ? 'Set up Smart AI on this phone'
            : state.ready
            ? 'Ready for your question'
            : 'Preparing Smart AI',
      SmartAiPhase.preparing => 'Preparing microphone',
      SmartAiPhase.recording =>
        'Listening. Release to send, or tap Send recording',
      SmartAiPhase.transcribing => 'Transcribing with Groq',
      SmartAiPhase.thinking => 'Thinking with $answerProvider',
      SmartAiPhase.speaking =>
        state.speechIsGuide
            ? 'Speaking Smart AI instructions'
            : 'Speaking the answer',
      SmartAiPhase.paused => 'Answer paused. Tap the circle to resume',
      SmartAiPhase.failed => 'Smart AI needs attention',
    };
    void tapCircle() {
      if (speaking || paused) {
        unawaited(_controller.toggleSpeechPause());
      } else if (recording) {
        unawaited(_controller.stopAndSubmit());
      } else if (!state.busy) {
        unawaited(_controller.startRecording());
      }
    }

    return AppScreenScaffold(
      title: 'Smart AI Assistant',
      trailing: IconButton(
        tooltip: 'Smart AI cloud connection settings',
        onPressed: _settings,
        icon: const Icon(Icons.settings),
      ),
      children: [
        Semantics(
          liveRegion: true,
          child: Text(status, style: Theme.of(context).textTheme.titleLarge),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              configured
                  ? 'Smart AI cloud audio is enabled. Speak sends a temporary 16 kHz mono clip to Groq; conversation text goes to $answerProvider. Replies play on this phone. Internet is required. Local Vision AI listens between recordings. Only button recordings go to Groq.'
                  : 'The Smart AI circle is ready to set up. Save your personal key and review the audio-sharing consent on this phone to enable questions. Local Vision AI commands, instructions, vibration and sound tests work without a cloud account.',
            ),
          ),
        ),
        if (!configured) ...[
          const SizedBox(height: 12),
          PrimaryActionButton(
            key: const Key('smart_ai_setup'),
            label: 'Set up Smart AI',
            icon: Icons.settings,
            onPressed: _settings,
          ),
        ],
        const SizedBox(height: 16),
        Semantics(
          header: true,
          child: Text(
            'Speak to Smart AI',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: 12),
        SmartAiVoiceCircle(
          label: recording
              ? 'Release to send'
              : speaking
              ? 'Tap to pause'
              : paused
              ? 'Tap to resume'
              : !configured
              ? 'Set up to speak'
              : state.busy
              ? 'Hold to ask'
              : 'Hold to speak',
          hint: recording
              ? 'Listening now. Lift your finger to send. For TalkBack, double-tap to send.'
              : speaking
              ? (configured
                    ? 'Tap to pause the spoken answer. Hold one second to interrupt and record a new question.'
                    : 'Tap to pause the spoken instructions. Recording is disabled until setup is complete.')
              : paused
              ? (configured
                    ? 'Tap to resume the spoken answer. Hold one second to record a new question.'
                    : 'Tap to resume the spoken instructions. Recording is disabled until setup is complete.')
              : !configured
              ? 'Choose Set up Smart AI to save your personal key and review audio-sharing consent. Recording is disabled until setup is complete.'
              : 'Hold for one second, wait for the vibration and short chime, speak, then lift your finger to send. With TalkBack, double-tap to start; double-tap again to send.',
          icon: recording
              ? Icons.mic
              : speaking
              ? Icons.pause
              : paused
              ? Icons.play_arrow
              : Icons.mic_none,
          enabled: state.ready && (configured || speaking || paused),
          listening: recording,
          onTap: tapCircle,
          onHoldStart: () => unawaited(_controller.beginHold()),
          onHoldEnd: () => unawaited(_controller.endHold()),
          onHoldCancel: () => unawaited(_controller.cancelHold()),
        ),
        const SizedBox(height: 12),
        const Text(
          'Hold for one second, wait for the vibration and short chime, then speak. Release to send. Tap during an answer to pause or resume. Hold again to ask a new question.',
        ),
        const SizedBox(height: 12),
        const Text(
          'When you are not recording, say “go back”, “go home”, “open settings”, or “open about page” without holding the circle. These commands also work when the answer is paused. Say “goodbye Smart AI” to return Home.',
        ),
        const SizedBox(height: 12),
        SecondaryActionButton(
          label: 'Hear how to use Smart AI',
          icon: Icons.help_outline,
          onPressed: state.ready && !state.busy ? _controller.speakGuide : null,
        ),
        const SizedBox(height: 16),
        SecondaryActionButton(
          label: 'Test listening vibration and sound',
          icon: Icons.vibration,
          onPressed: state.ready && !state.busy
              ? _controller.testListeningCue
              : null,
        ),
        const SizedBox(height: 12),
        Semantics(
          header: true,
          child: Text(
            'Speech language',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final language in SmartAiSpeechLanguage.values)
              ChoiceChip(
                label: Text(switch (language) {
                  SmartAiSpeechLanguage.automatic => 'Automatic',
                  SmartAiSpeechLanguage.english => 'English',
                  SmartAiSpeechLanguage.urdu => 'Urdu',
                }),
                tooltip: switch (language) {
                  SmartAiSpeechLanguage.automatic =>
                    'Automatically recognize English or Urdu',
                  SmartAiSpeechLanguage.english =>
                    'Recognize speech and answer in English',
                  SmartAiSpeechLanguage.urdu =>
                    'Recognize speech and answer in Urdu',
                },
                selected: state.speechLanguage == language,
                onSelected: state.busy
                    ? null
                    : (_) => _controller.setSpeechLanguage(language),
              ),
          ],
        ),
        const Text(
          'Automatic can mishear short questions. Choose English or Urdu if the transcript uses the wrong language.',
        ),
        const SizedBox(height: 12),
        Text(
          ref.watch(visionVoiceKernelProvider).isHandsFreeActive
              ? 'Local Vision AI: listening for app commands. No hold needed to go back.'
              : recording
              ? 'Local Vision AI: microphone reserved for your recording'
              : 'Local Vision AI: starting or unavailable. The Home button still works.',
        ),
        const SizedBox(height: 12),
        SecondaryActionButton(
          label: 'Back to Home and Vision AI',
          icon: Icons.home_outlined,
          onPressed: _controller.returnHome,
        ),
        const SizedBox(height: 16),
        if (state.error != null) ...[
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: Text(
              state.error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
        const SizedBox(height: 16),
        ExpansionTile(
          title: const Text('Button controls'),
          children: [
            PrimaryActionButton(
              label: recording
                  ? 'Send recording'
                  : speaking
                  ? 'Pause answer'
                  : paused
                  ? 'Resume answer'
                  : 'Speak to Smart AI',
              icon: recording
                  ? Icons.send
                  : speaking
                  ? Icons.pause
                  : paused
                  ? Icons.play_arrow
                  : Icons.mic,
              onPressed: !state.ready || (!configured && !speaking && !paused)
                  ? null
                  : recording
                  ? _controller.stopAndSubmit
                  : speaking || paused
                  ? _controller.toggleSpeechPause
                  : state.busy
                  ? null
                  : _controller.startRecording,
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (!state.ready && !state.busy && state.error != null)
          SecondaryActionButton(
            label: 'Retry Smart AI audio',
            onPressed: _controller.activate,
          ),
        if (state.busy)
          SecondaryActionButton(
            label: 'Cancel Smart AI turn',
            onPressed: _controller.cancel,
          ),
        if (!state.busy)
          SecondaryActionButton(
            label: _showText ? 'Hide text input' : 'Type a question',
            onPressed: () => setState(() => _showText = !_showText),
          ),
        if (!state.busy &&
            state.messages.any((message) => message.isAssistant)) ...[
          const SizedBox(height: 12),
          SecondaryActionButton(
            label: 'Read last answer aloud',
            onPressed: state.ready ? _controller.repeatLastAnswer : null,
          ),
        ],
        if (_showText) ...[
          const SizedBox(height: 16),
          TextField(
            key: const Key('smart_ai_question'),
            controller: _text,
            enabled: !state.busy && canAsk,
            maxLength: 4096,
            minLines: 1,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Question for Smart AI',
              border: OutlineInputBorder(),
            ),
          ),
          FilledButton(
            onPressed: !state.busy && canAsk
                ? () {
                    final text = _text.text;
                    _text.clear();
                    unawaited(_controller.sendText(text));
                  }
                : null,
            child: const Text('Send question'),
          ),
        ],
        if (state.messages.isNotEmpty) ...[
          const SizedBox(height: 24),
          Semantics(
            header: true,
            child: Text(
              'Conversation',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          for (final message in state.messages)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '${message.isUser ? 'You' : 'Smart AI'}: ${message.text}',
              ),
            ),
          TextButton(
            onPressed: state.busy ? null : _controller.clearHistory,
            child: const Text('Clear Smart AI conversation'),
          ),
        ],
        const SizedBox(height: 24),
        if (!configured && widget.onUseOtherAssistant != null)
          TextButton(
            key: const Key('smart_ai_other_assistants'),
            onPressed: state.busy ? null : widget.onUseOtherAssistant,
            child: const Text('Use Gemini or laptop assistant'),
          ),
        const Text(
          'An assistive aid. Keep using your usual mobility aids. Detection alerts take priority. Vision AI, object detection and the scanner retain their offline operation.',
        ),
      ],
    );
  }
}
