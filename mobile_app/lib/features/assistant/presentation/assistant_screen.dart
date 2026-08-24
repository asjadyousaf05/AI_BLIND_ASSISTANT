import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/assistant_session_controller.dart';
import '../../../app/router/route_paths.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_icons.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/voice_kernel/voice_kernel_providers.dart';
import '../../../core/constants/app_keys.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/app_screen_scaffold.dart';
import '../../../core/widgets/visual_components.dart';
import '../../../domain/enums/assistant_session_state.dart';
import '../../../domain/enums/voice_feature_context.dart';

/// The primary Personalized Local AI Assistant screen.
///
/// Provides:
/// - Foreground wake phrase with push-to-talk as an alternative
/// - State-driven UI with semantic announcements
/// - Conversation history
/// - Connection status
/// - Text input alternative
/// - Stop speaking / Repeat last / Cancel controls
class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key});

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _showTextInput = false;
  bool _holdActive = false;
  late final VisionVoiceKernelV3 _voiceKernel;

  @override
  void initState() {
    super.initState();
    _voiceKernel = ref.read(visionVoiceKernelProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _voiceKernel.setFeatureContext(VoiceFeatureContext.smartAi);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _voiceKernel.setFeatureContext(VoiceFeatureContext.unknown);
    });
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controllerState = ref.watch(assistantSessionControllerProvider);
    final voiceState = ref.watch(visionVoiceKernelProvider);
    final controller = ref.read(assistantSessionControllerProvider.notifier);
    final sessionState = controllerState.sessionState;

    // Scroll to bottom when history changes
    ref.listen<AssistantControllerState>(assistantSessionControllerProvider, (
      previous,
      next,
    ) {
      if (next.conversationHistory.length >
          (previous?.conversationHistory.length ?? 0)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_scrollController.hasClients &&
              _scrollController.positions.isNotEmpty) {
            try {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            } catch (_) {}
          }
        });
      }
    });

    return AppScreenScaffold(
      title: AppStrings.assistantTitle,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: AppKeys.assistantSettingsButton,
            tooltip: 'Vision AI Settings',
            onPressed: () =>
                Navigator.of(context).pushNamed(RoutePaths.assistantSettings),
            icon: const Icon(AppIcons.settings),
          ),
          IconButton(
            key: AppKeys.assistantConnectionButton,
            tooltip: controllerState.isPaired
                ? 'Connected to ${controllerState.credential?.displayName ?? 'laptop'}'
                : 'Pair with Laptop',
            onPressed: () =>
                Navigator.of(context).pushNamed(RoutePaths.assistantConnection),
            icon: Icon(
              controllerState.isPaired ? AppIcons.link : AppIcons.connection,
              color: controllerState.isPaired
                  ? AppColors.success
                  : AppColors.warning,
            ),
          ),
          IconButton(
            tooltip: 'Exit to App Controller (Say "Bye")',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      children: [
        // Status pill
        _AssistantStatusPill(sessionState: sessionState),
        const SizedBox(height: AppSpacing.space3),
        Semantics(
          liveRegion: true,
          label: voiceState.statusMessage,
          child: Card(
            child: ListTile(
              leading: Icon(
                voiceState.isHandsFreeActive
                    ? Icons.hearing
                    : Icons.mic_off_outlined,
                color: voiceState.isHandsFreeActive
                    ? AppColors.success
                    : AppColors.warning,
              ),
              title: Text(
                voiceState.isHandsFreeActive
                    ? 'Hands-free voice is on'
                    : 'Hands-free voice is not active',
              ),
              subtitle: Text(voiceState.statusMessage),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.space4),

        // Optional general-conversation backend banner
        if (!controllerState.isPaired)
          _NotPairedBanner(
            onPair: () =>
                Navigator.of(context).pushNamed(RoutePaths.assistantConnection),
          ),

        // Laptop unavailable banner
        if (sessionState == AssistantSessionState.laptopUnavailable)
          _LaptopUnavailableBanner(onRetry: controller.retry),

        // Error message
        if (sessionState == AssistantSessionState.error &&
            controllerState.errorMessage != null)
          _ErrorBanner(
            message: controllerState.errorMessage!,
            onRetry: controller.retry,
            onDismiss: controller.reset,
          ),

        // Conversation history
        if (controllerState.conversationHistory.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.space3),
          _ConversationHistory(
            messages: controllerState.conversationHistory,
            scrollController: _scrollController,
          ),
          const SizedBox(height: AppSpacing.space3),
        ],

        // Transcript display
        if (controllerState.lastTranscript != null &&
            controllerState.lastTranscript!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.space3),
            child: Semantics(
              liveRegion: true,
              child: Text(
                'You said: "${controllerState.lastTranscript}"',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                textAlign: TextAlign.center,
              ),
            ),
          ),

        const SizedBox(height: AppSpacing.space4),

        // Main Tap-to-Speak Hero Button
        _PushToTalkButton(
          sessionState: sessionState,
          holdActive: _holdActive,
          onHoldStart: () async {
            setState(() => _holdActive = true);
            await controller.startListening();
            if (mounted &&
                ref.read(assistantSessionControllerProvider).sessionState !=
                    AssistantSessionState.listening) {
              setState(() => _holdActive = false);
            }
          },
          onHoldEnd: () async {
            setState(() => _holdActive = false);
            await controller.stopListeningAndSubmit();
          },
          onHoldCancel: () async {
            setState(() => _holdActive = false);
            await controller.cancelListening();
          },
          onTap: () async {
            if (sessionState == AssistantSessionState.listening) {
              setState(() => _holdActive = false);
              await controller.stopListeningAndSubmit();
            } else if (sessionState == AssistantSessionState.speaking) {
              await controller.stopSpeaking();
            } else if (sessionState.canStartNewSession ||
                sessionState == AssistantSessionState.error ||
                sessionState == AssistantSessionState.laptopUnavailable ||
                sessionState == AssistantSessionState.timeout ||
                sessionState == AssistantSessionState.authenticationFailed) {
              setState(() => _holdActive = false);
              await controller.startListening();
            }
          },
        ),

        const SizedBox(height: AppSpacing.space4),

        // Secondary controls row
        _SecondaryControlsRow(
          sessionState: sessionState,
          onCancel: controller.cancelListening,
          onStop: controller.stopSpeaking,
          onRepeat: controller.repeatLastResponse,
          onToggleText: () => setState(() => _showTextInput = !_showTextInput),
          showTextInput: _showTextInput,
        ),

        // Text input (alternative to voice)
        if (_showTextInput) ...[
          const SizedBox(height: AppSpacing.space4),
          _TextInputPanel(
            controller: _textController,
            enabled: sessionState.canStartNewSession,
            onSubmit: (text) async {
              _textController.clear();
              await controller.sendTextQuery(text);
            },
          ),
        ],

        // Confirmation panel
        if (sessionState == AssistantSessionState.awaitingConfirmation)
          _ConfirmationPanel(
            prompt:
                controllerState.pendingResponse?.confirmationPrompt ??
                controllerState.pendingResponse?.responseText ??
                'Confirm action?',
            onConfirm: controller.confirmAction,
            onCancel: controller.cancelAction,
          ),

        const SizedBox(height: AppSpacing.space6),

        // Safety reminder
        const SafetyNotice(
          title: 'Important',
          messages: [
            'The personal assistant does not replace a white cane, guide dog, or professional assistance.',
            'Detection alerts take priority over conversation.',
            'Offline app-control speech is recognized and executed on this phone. If Gemini is configured, only unmatched general-conversation text may be processed by Google. Camera frames and raw audio are never sent.',
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Tap-to-Speak Hero Button
// ---------------------------------------------------------------------------

class _PushToTalkButton extends StatelessWidget {
  const _PushToTalkButton({
    required this.sessionState,
    required this.holdActive,
    required this.onHoldStart,
    required this.onHoldEnd,
    required this.onHoldCancel,
    required this.onTap,
  });

  final AssistantSessionState sessionState;
  final bool holdActive;
  final VoidCallback onHoldStart;
  final VoidCallback onHoldEnd;
  final VoidCallback onHoldCancel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isListening = sessionState == AssistantSessionState.listening;
    final isSpeaking = sessionState == AssistantSessionState.speaking;
    final isThinking =
        sessionState == AssistantSessionState.thinking ||
        sessionState == AssistantSessionState.processingAudio ||
        sessionState == AssistantSessionState.executingAction;
    final isError =
        sessionState == AssistantSessionState.error ||
        sessionState == AssistantSessionState.laptopUnavailable ||
        sessionState == AssistantSessionState.authenticationFailed ||
        sessionState == AssistantSessionState.timeout;
    final canStart = sessionState.canStartNewSession || isError;

    final color = isListening
        ? AppColors.error
        : isSpeaking
        ? AppColors.primary
        : isThinking
        ? AppColors.warning
        : canStart
        ? AppColors.primary
        : AppColors.slate500;

    final String label;
    final IconData icon;
    final String semanticHint;

    if (isListening) {
      label = 'Listening…\nTap to send';
      icon = Icons.graphic_eq_rounded;
      semanticHint =
          'Listening to your speech. Tap to send now, or pause to send automatically.';
    } else if (isSpeaking) {
      label = 'Speaking…\nTap to stop';
      icon = Icons.volume_up_rounded;
      semanticHint = 'Assistant is speaking. Tap to stop speech.';
    } else if (isThinking) {
      label = 'Thinking…';
      icon = Icons.hourglass_top_rounded;
      semanticHint = 'Processing your query.';
    } else if (isError) {
      label = 'Tap to try again';
      icon = Icons.replay_rounded;
      semanticHint = 'Tap to start speaking again.';
    } else {
      label = 'Tap to speak';
      icon = Icons.mic_rounded;
      semanticHint =
          'Tap once to speak your question or command. Or hold to speak.';
    }

    final scaledLabelSize = MediaQuery.textScalerOf(context).scale(13);
    final controlSize =
        (AppDimensions.heroControlHeight * 1.8 +
                (scaledLabelSize - 13).clamp(0, 26) * 3)
            .toDouble();

    return Center(
      child: Semantics(
        button: true,
        label: label.replaceAll('\n', ' '),
        hint: semanticHint,
        enabled: canStart || isListening || isSpeaking,
        child: GestureDetector(
          key: AppKeys.assistantPushToTalkButton,
          onLongPressStart: canStart ? (_) => onHoldStart() : null,
          onLongPressEnd: (canStart || isListening || holdActive)
              ? (_) => onHoldEnd()
              : null,
          onLongPressCancel: (canStart || isListening || holdActive)
              ? onHoldCancel
              : null,
          onTap: (canStart || isListening || isSpeaking) ? onTap : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: controlSize,
            height: controlSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: isListening ? 0.95 : 0.85),
              border: Border.all(color: color, width: 4),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: isListening ? 0.6 : 0.3),
                  blurRadius: isListening ? 24 : 12,
                  spreadRadius: isListening ? 4 : 0,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: Colors.white,
                  size: AppDimensions.iconExtraLarge,
                  semanticLabel: '',
                ),
                const SizedBox(height: AppSpacing.space1),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status pill
// ---------------------------------------------------------------------------

class _AssistantStatusPill extends StatelessWidget {
  const _AssistantStatusPill({required this.sessionState});

  final AssistantSessionState sessionState;

  @override
  Widget build(BuildContext context) {
    final color = switch (sessionState) {
      AssistantSessionState.idle ||
      AssistantSessionState.completed => AppColors.success,
      AssistantSessionState.listening => AppColors.error,
      AssistantSessionState.laptopUnavailable ||
      AssistantSessionState.authenticationFailed ||
      AssistantSessionState.incompatible => AppColors.warning,
      AssistantSessionState.error ||
      AssistantSessionState.timeout => AppColors.error,
      _ => AppColors.primary,
    };

    return Semantics(
      liveRegion: true,
      child: StatusPill(
        label: 'Assistant: ${sessionState.label}',
        icon: switch (sessionState) {
          AssistantSessionState.listening => Icons.mic,
          AssistantSessionState.speaking => AppIcons.volume,
          AssistantSessionState.laptopUnavailable => AppIcons.wifiOff,
          AssistantSessionState.error => AppIcons.warning,
          _ => Icons.smart_toy_outlined,
        },
        color: color,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Secondary controls
// ---------------------------------------------------------------------------

class _SecondaryControlsRow extends StatelessWidget {
  const _SecondaryControlsRow({
    required this.sessionState,
    required this.onCancel,
    required this.onStop,
    required this.onRepeat,
    required this.onToggleText,
    required this.showTextInput,
  });

  final AssistantSessionState sessionState;
  final VoidCallback onCancel;
  final VoidCallback onStop;
  final VoidCallback onRepeat;
  final VoidCallback onToggleText;
  final bool showTextInput;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: AppSpacing.space3,
      runSpacing: AppSpacing.space2,
      children: [
        if (sessionState == AssistantSessionState.listening)
          _SmallActionButton(
            key: AppKeys.assistantCancelButton,
            label: 'Cancel',
            icon: Icons.cancel_outlined,
            onPressed: onCancel,
            semanticLabel: 'Cancel voice recording',
          ),
        if (sessionState == AssistantSessionState.speaking)
          _SmallActionButton(
            key: AppKeys.assistantStopSpeakingButton,
            label: 'Stop',
            icon: AppIcons.stop,
            onPressed: onStop,
            semanticLabel: 'Stop the assistant from speaking',
          ),
        if (sessionState == AssistantSessionState.completed ||
            sessionState == AssistantSessionState.idle)
          _SmallActionButton(
            key: AppKeys.assistantRepeatButton,
            label: 'Repeat',
            icon: Icons.replay,
            onPressed: onRepeat,
            semanticLabel: 'Repeat the last assistant response',
          ),
        _SmallActionButton(
          key: AppKeys.assistantTextInputToggle,
          label: showTextInput ? 'Hide text' : 'Type instead',
          icon: showTextInput ? Icons.mic : Icons.keyboard,
          onPressed: onToggleText,
          semanticLabel: showTextInput
              ? 'Hide text input'
              : 'Open text input as an alternative to voice',
        ),
      ],
    );
  }
}

class _SmallActionButton extends StatelessWidget {
  const _SmallActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: AppDimensions.iconSmall),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, AppDimensions.minTouchTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space4,
            vertical: AppSpacing.space2,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Text input panel
// ---------------------------------------------------------------------------

class _TextInputPanel extends StatelessWidget {
  const _TextInputPanel({
    required this.controller,
    required this.enabled,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool enabled;
  final void Function(String) onSubmit;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Semantics(
            label: 'Type your question or request',
            child: TextField(
              key: AppKeys.assistantTextInput,
              controller: controller,
              enabled: enabled,
              maxLines: 3,
              minLines: 1,
              decoration: const InputDecoration(
                hintText: 'Type your question or request…',
                border: OutlineInputBorder(),
              ),
              onSubmitted: enabled ? onSubmit : null,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.space2),
        Semantics(
          button: true,
          label: 'Send typed message',
          child: IconButton.filled(
            key: AppKeys.assistantTextSubmitButton,
            onPressed: enabled
                ? () {
                    final text = controller.text.trim();
                    if (text.isNotEmpty) onSubmit(text);
                  }
                : null,
            icon: const Icon(Icons.send),
            iconSize: AppDimensions.iconMedium,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Conversation history
// ---------------------------------------------------------------------------

class _ConversationHistory extends StatelessWidget {
  const _ConversationHistory({
    required this.messages,
    required this.scrollController,
  });

  final List<dynamic> messages;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 320),
      child: ListView.separated(
        controller: scrollController,
        shrinkWrap: true,
        physics: const ClampingScrollPhysics(),
        reverse: false,
        itemCount: messages.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.space2),
        itemBuilder: (context, index) {
          final msg = messages[index];
          final isUser = msg.isUser;
          return Semantics(
            label: '${isUser ? "You" : "Assistant"}: ${msg.text}',
            child: Align(
              alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.78,
                ),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.space3),
                  decoration: BoxDecoration(
                    color: isUser
                        ? AppColors.primaryOverlay20
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: isUser
                          ? const Radius.circular(16)
                          : Radius.zero,
                      bottomRight: isUser
                          ? Radius.zero
                          : const Radius.circular(16),
                    ),
                  ),
                  child: Text(msg.text),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Confirmation panel
// ---------------------------------------------------------------------------

class _ConfirmationPanel extends StatelessWidget {
  const _ConfirmationPanel({
    required this.prompt,
    required this.onConfirm,
    required this.onCancel,
  });

  final String prompt;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.space5),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.warning, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(AppIcons.warning, color: AppColors.warning),
                const SizedBox(width: AppSpacing.space2),
                Semantics(
                  headingLevel: 2,
                  child: Text(
                    'Confirm Action',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.space3),
            Text(prompt),
            const SizedBox(height: AppSpacing.space4),
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    button: true,
                    label: 'Cancel action',
                    child: OutlinedButton(
                      key: AppKeys.assistantCancelActionButton,
                      onPressed: onCancel,
                      child: const Text('Cancel'),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.space3),
                Expanded(
                  child: Semantics(
                    button: true,
                    label: 'Confirm and execute action',
                    child: FilledButton(
                      key: AppKeys.assistantConfirmActionButton,
                      onPressed: onConfirm,
                      child: const Text('Confirm'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Banners
// ---------------------------------------------------------------------------

class _NotPairedBanner extends StatelessWidget {
  const _NotPairedBanner({required this.onPair});

  final VoidCallback onPair;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: MaterialBanner(
        key: AppKeys.assistantNotPairedBanner,
        content: const Text(
          'Offline voice and typed app controls are ready on this phone. '
          'Connect the optional laptop only for general conversation.',
        ),
        leading: const Icon(AppIcons.connection, color: AppColors.warning),
        actions: [TextButton(onPressed: onPair, child: const Text('Connect'))],
        backgroundColor: AppColors.warning.withValues(alpha: 0.1),
      ),
    );
  }
}

class _LaptopUnavailableBanner extends StatelessWidget {
  const _LaptopUnavailableBanner({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: MaterialBanner(
        content: const Text(
          'Optional laptop assistant unavailable. Offline voice controls, '
          'typed app controls, and detection remain active.',
        ),
        leading: const Icon(AppIcons.wifiOff, color: AppColors.warning),
        actions: [TextButton(onPressed: onRetry, child: const Text('Retry'))],
        backgroundColor: AppColors.warning.withValues(alpha: 0.1),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({
    required this.message,
    required this.onRetry,
    required this.onDismiss,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: MaterialBanner(
        content: Text(message),
        leading: const Icon(AppIcons.warning, color: AppColors.error),
        actions: [
          TextButton(onPressed: onDismiss, child: const Text('Dismiss')),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
        backgroundColor: AppColors.error.withValues(alpha: 0.1),
      ),
    );
  }
}
