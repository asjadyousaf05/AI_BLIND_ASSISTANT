import 'package:flutter/material.dart';
import '../../../domain/enums/voice_runtime_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/assistant_session_controller.dart';
import '../../../app/providers.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/voice_kernel/voice_kernel_providers.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/action_buttons.dart';
import '../../../core/widgets/app_screen_scaffold.dart';

/// Settings screen for the AI assistant.
class AssistantSettingsScreen extends ConsumerWidget {
  const AssistantSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(assistantSessionControllerProvider.notifier);
    final state = ref.watch(assistantSessionControllerProvider);
    final appSettings = ref.watch(appSettingsControllerProvider);
    final voiceState = ref.watch(visionVoiceKernelProvider);

    return AppScreenScaffold(
      title: AppStrings.assistantSettingsTitle,
      children: [
        Semantics(
          headingLevel: 2,
          child: Text(
            'Hands-free voice',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: AppSpacing.space2),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.hearing),
          title: const Text('Listen for “Hey Vision AI”'),
          subtitle: Text(voiceState.statusMessage),
          value: appSettings.handsFreeAssistantEnabled,
          onChanged: controller.setHandsFreeEnabled,
        ),
        const Text(
          'Listening and app-command recognition stay on this phone. The '
          'microphone pauses when the app goes to the background and while '
          'the assistant speaks. After “Listening” or a spoken result, wait '
          'for the short tone and vibration, then say one short English '
          'command. For example: “open settings” or “start mobile mode”. '
          'The cue follows your phone’s media volume and haptic availability.',
        ),
        if (appSettings.handsFreeAssistantEnabled &&
            voiceState.runtimeState == VoiceRuntimeState.error) ...[
          const SizedBox(height: AppSpacing.space3),
          FilledButton.icon(
            onPressed: () =>
                ref.read(visionVoiceKernelProvider.notifier).restartHandsFree(),
            icon: const Icon(Icons.mic),
            label: const Text('Restart voice listening'),
          ),
        ],
        const Divider(height: AppSpacing.space8),

        // Conversation history management
        Semantics(
          headingLevel: 2,
          child: Text(
            'Conversation',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: AppSpacing.space3),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.history),
          title: Text(
            state.usesDirectGemini
                ? 'Conversation in memory'
                : 'Load conversation history',
          ),
          subtitle: Text(
            '${state.conversationHistory.length} messages in memory',
          ),
          onTap: state.usesDirectGemini
              ? null
              : () async {
                  await controller.loadHistory();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('History loaded.')),
                    );
                  }
                },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.delete_outline),
          title: const Text('Clear conversation history'),
          subtitle: Text(
            state.usesDirectGemini
                ? 'Clears conversation from this phone’s memory'
                : 'Clears this device and the paired backend session',
          ),
          onTap: () async {
            final confirm = await _confirmClear(
              context,
              state.usesDirectGemini,
            );
            if (confirm == true) {
              await controller.clearHistory();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('History cleared.')),
                );
              }
            }
          },
        ),
        const Divider(height: AppSpacing.space8),

        // Safety reminder
        Semantics(
          headingLevel: 2,
          child: Text('Safety', style: Theme.of(context).textTheme.titleMedium),
        ),
        const SizedBox(height: AppSpacing.space3),
        const Text(
          'The AI assistant is an assistive aid. '
          'It does not replace professional safety assistance. '
          'Detection alerts always take priority over conversation.',
        ),
        const SizedBox(height: AppSpacing.space4),
        const Text(
          'App controls such as Mobile Mode, Raspberry Pi connection, and '
          'settings use a deterministic offline command router and never need '
          'Gemini or Ollama. Voice and typed controls run directly on this phone '
          'using the bundled offline speech model. Personal Gemini mode needs '
          'internet and no laptop. Laptop mode can use local Ollama offline '
          'or Gemini with Ollama fallback. Gemini '
          'receives unmatched conversation text only—never app-command audio, '
          'camera frames, or raw audio.',
        ),
        const SizedBox(height: AppSpacing.space6),

        SecondaryActionButton(
          label: 'Close',
          onPressed: () => Navigator.of(context).maybePop(),
          semanticLabel: 'Close assistant settings',
        ),
      ],
    );
  }

  Future<bool?> _confirmClear(BuildContext context, bool usesDirectGemini) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear history?'),
        content: Text(
          usesDirectGemini
              ? 'This will clear the conversation from this phone’s memory. '
                    'This action cannot be undone.'
              : 'This will delete the conversation history from this device '
                    'and, when paired, from the laptop backend. '
                    'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}
