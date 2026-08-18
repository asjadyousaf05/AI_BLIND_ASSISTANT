import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/assistant_session_controller.dart';
import '../../../app/wearable_controller.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/constants/app_keys.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/assistant_defaults.dart';
import '../../../core/widgets/action_buttons.dart';
import '../../../core/widgets/app_screen_scaffold.dart';

/// Screen for pairing the phone with the laptop backend.
///
/// Supports:
/// - Manual IP / hostname entry
/// - Current-laptop mDNS endpoint preselected by default
/// - Pairing code entry
/// - Re-pair and Unpair
class AssistantConnectionScreen extends ConsumerStatefulWidget {
  const AssistantConnectionScreen({super.key});

  @override
  ConsumerState<AssistantConnectionScreen> createState() =>
      _AssistantConnectionScreenState();
}

class _AssistantConnectionScreenState
    extends ConsumerState<AssistantConnectionScreen> {
  final _hostController = TextEditingController(
    text: AssistantDefaults.currentLaptopHost,
  );
  final _portController = TextEditingController(
    text: '${AssistantDefaults.currentLaptopPort}',
  );
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _pairing = false;
  String? _pairingError;
  String? _pairingSuccess;

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controllerState = ref.watch(assistantSessionControllerProvider);
    final controller = ref.read(assistantSessionControllerProvider.notifier);
    final isPaired = controllerState.isPaired;

    return AppScreenScaffold(
      title: AppStrings.assistantConnectionTitle,
      children: [
        // Current status
        if (isPaired) ...[
          _PairedCard(credential: controllerState.credential!),
          const SizedBox(height: AppSpacing.space4),
          SecondaryActionButton(
            key: AppKeys.assistantUnpairButton,
            label: 'Unpair',
            icon: Icons.link_off,
            semanticLabel: 'Unpair from the laptop assistant',
            onPressed: () async {
              await controller.unpair();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Unpaired from laptop.')),
                );
              }
            },
          ),
          const Divider(height: AppSpacing.space8),
        ],

        // Pair form
        Semantics(
          headingLevel: 2,
          child: Text(
            isPaired
                ? 'Re-pair with a different laptop'
                : 'Pair with your laptop',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: AppSpacing.space4),

        Semantics(
          container: true,
          label:
              'This Mac is selected by default at '
              '${AssistantDefaults.currentLaptopHost}, port '
              '${AssistantDefaults.currentLaptopPort}.',
          child: Card(
            child: ListTile(
              leading: const Icon(Icons.laptop_mac, color: AppColors.primary),
              title: const Text('This Mac — Wi-Fi Direct'),
              subtitle: const Text(
                '${AssistantDefaults.currentLaptopHost}:'
                '${AssistantDefaults.currentLaptopPort}',
              ),
              trailing: TextButton(
                onPressed: _useCurrentLaptop,
                child: const Text('Use'),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.space3),

        // Quick Connection Presets
        Wrap(
          spacing: AppSpacing.space2,
          runSpacing: AppSpacing.space2,
          children: [
            ActionChip(
              avatar: const Icon(
                Icons.wifi,
                size: 16,
                color: AppColors.primary,
              ),
              label: const Text('Wi-Fi (10.141.17.235)'),
              onPressed: () {
                setState(() {
                  _hostController.text = '10.141.17.235';
                  _portController.text = '8765';
                  _pairingError = null;
                });
              },
            ),
            ActionChip(
              avatar: const Icon(Icons.usb, size: 16, color: AppColors.primary),
              label: const Text('USB Cable (127.0.0.1)'),
              onPressed: () {
                setState(() {
                  _hostController.text = '127.0.0.1';
                  _portController.text = '8765';
                  _pairingError = null;
                });
              },
            ),
            ActionChip(
              avatar: const Icon(
                Icons.phone_android,
                size: 16,
                color: AppColors.slate400,
              ),
              label: const Text('Emulator (10.0.2.2)'),
              onPressed: () {
                setState(() {
                  _hostController.text = '10.0.2.2';
                  _portController.text = '8765';
                  _pairingError = null;
                });
              },
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.space4),

        // Instructions
        _InstructionsCard(),
        const SizedBox(height: AppSpacing.space4),

        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Host
              Semantics(
                label: 'Laptop hostname or IP address',
                child: TextFormField(
                  key: AppKeys.assistantHostField,
                  controller: _hostController,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Laptop hostname or IP',
                    hintText: AssistantDefaults.currentLaptopHost,
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    return WearableController.validateHost(v);
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.space3),

              // Port
              Semantics(
                label: 'Backend port number',
                child: TextFormField(
                  key: AppKeys.assistantPortField,
                  controller: _portController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Port',
                    hintText: '8765',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    final port = int.tryParse(v ?? '');
                    if (port == null || port < 1 || port > 65535) {
                      return 'Enter a valid port (1–65535)';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.space3),

              // Pairing code (Optional)
              Semantics(
                label:
                    'Pairing code (Optional — leave blank for direct pairing)',
                child: TextFormField(
                  key: AppKeys.assistantPairingCodeField,
                  controller: _codeController,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.done,
                  obscureText: false,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(
                    labelText: 'Pairing code (Optional)',
                    hintText: 'Leave empty for 1-click direct pairing',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.space5),

              // Error
              if (_pairingError != null)
                Semantics(
                  liveRegion: true,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.space3),
                    child: Text(
                      _pairingError!,
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ),
                ),

              // Success
              if (_pairingSuccess != null)
                Semantics(
                  liveRegion: true,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.space3),
                    child: Text(
                      _pairingSuccess!,
                      style: const TextStyle(color: AppColors.success),
                    ),
                  ),
                ),

              PrimaryActionButton(
                key: AppKeys.assistantPairButton,
                label: _pairing ? 'Connecting…' : 'Connect to Laptop (Direct)',
                icon: Icons.link,
                semanticLabel:
                    'Connect this phone directly to the laptop assistant backend',
                onPressed: _pairing ? null : _doPair,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _doPair() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _pairing = true;
      _pairingError = null;
      _pairingSuccess = null;
    });

    final host = _hostController.text.trim();
    final port = _portController.text.trim();
    final url = 'http://$host:$port';
    final code = _codeController.text.trim();
    final controller = ref.read(assistantSessionControllerProvider.notifier);
    final error = await controller.pair(backendUrl: url, pairingCode: code);

    if (!mounted) return;
    setState(() {
      _pairing = false;
      if (error != null) {
        _pairingError = error;
      } else {
        _pairingSuccess = 'Paired successfully! You can now use the assistant.';
        _codeController.clear();
      }
    });
  }

  void _useCurrentLaptop() {
    setState(() {
      _hostController.text = AssistantDefaults.currentLaptopHost;
      _portController.text = '${AssistantDefaults.currentLaptopPort}';
      _pairingError = null;
      _pairingSuccess = null;
    });
  }
}

class _PairedCard extends StatelessWidget {
  const _PairedCard({required this.credential});

  final dynamic credential;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.space4),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.success),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: AppColors.success),
              const SizedBox(width: AppSpacing.space2),
              Semantics(
                headingLevel: 2,
                child: const Text(
                  'Paired',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space2),
          Text('Backend: ${credential.backendUrl}'),
          Text('Protocol: v${credential.protocolVersion}'),
        ],
      ),
    );
  }
}

class _InstructionsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.space4),
      decoration: BoxDecoration(
        color: AppColors.primaryOverlay10,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How to pair',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.space2),
          const Text(
            'This Mac is already selected and its assistant starts '
            'automatically at login. For the first secure connection, enter '
            'the one-time pairing code shown on this Mac and tap Pair. The '
            'app remembers the encrypted connection after that.\n\n'
            'When using another laptop, replace the host and port with that '
            'laptop’s details, start its backend, and use its pairing code.\n\n'
            'Gemini is used only when GEMINI_API_KEY or GOOGLE_API_KEY is set '
            'on the laptop. Otherwise the backend uses local Ollama. The phone '
            'recognizes app-control speech on-device; these commands need no '
            'pairing and bypass both providers. Only unmatched general-conversation '
            'text and typed conversation text may be sent to Gemini. Camera frames '
            'and raw audio are never sent.',
            style: TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }
}
