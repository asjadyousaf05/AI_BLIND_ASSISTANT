import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// One stable touch target throughout capture and speech. Services remain in
/// the application controller; native buttons provide an equivalent fallback.
class SmartAiVoiceCircle extends StatelessWidget {
  const SmartAiVoiceCircle({
    super.key,
    required this.label,
    required this.hint,
    required this.icon,
    required this.enabled,
    required this.listening,
    required this.onTap,
    required this.onHoldStart,
    required this.onHoldEnd,
    required this.onHoldCancel,
  });
  final String label;
  final String hint;
  final IconData icon;
  final bool enabled;
  final bool listening;
  final VoidCallback onTap;
  final VoidCallback onHoldStart;
  final VoidCallback onHoldEnd;
  final VoidCallback onHoldCancel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 272),
        child: AspectRatio(
          aspectRatio: 1,
          child: Semantics(
            key: const Key('smart_ai_voice_circle'),
            button: true,
            enabled: enabled,
            label: 'Smart AI voice control',
            value: label,
            hint: hint,
            onTap: enabled ? onTap : null,
            excludeSemantics: true,
            child: FocusableActionDetector(
              enabled: enabled,
              shortcuts: const {
                SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
                SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
              },
              actions: {
                ActivateIntent: CallbackAction<ActivateIntent>(
                  onInvoke: (_) {
                    if (enabled) onTap();
                    return null;
                  },
                ),
              },
              child: RawGestureDetector(
                behavior: HitTestBehavior.opaque,
                gestures: {
                  TapGestureRecognizer:
                      GestureRecognizerFactoryWithHandlers<
                        TapGestureRecognizer
                      >(
                        TapGestureRecognizer.new,
                        (instance) => instance.onTap = enabled ? onTap : null,
                      ),
                  LongPressGestureRecognizer:
                      GestureRecognizerFactoryWithHandlers<
                        LongPressGestureRecognizer
                      >(
                        () => LongPressGestureRecognizer(
                          duration: const Duration(seconds: 1),
                        ),
                        (instance) {
                          instance.onLongPressStart = (_) {
                            if (enabled) onHoldStart();
                          };
                          instance.onLongPressEnd = (_) {
                            onHoldEnd();
                          };
                          instance.onLongPressCancel = onHoldCancel;
                        },
                      ),
                },
                child: AnimatedContainer(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 160),
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      center: const Alignment(-0.35, -0.4),
                      colors: enabled
                          ? [colors.primaryContainer, colors.primary]
                          : [colors.surfaceContainerHighest, colors.outline],
                    ),
                    border: Border.all(
                      color: listening ? colors.onSurface : colors.outline,
                      width: listening ? 5 : 2,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icon,
                        size: 48,
                        color: enabled
                            ? colors.onPrimaryContainer
                            : colors.onSurface,
                      ),
                      const SizedBox(height: 12),
                      Flexible(
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: enabled
                                    ? colors.onPrimaryContainer
                                    : colors.onSurface,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
