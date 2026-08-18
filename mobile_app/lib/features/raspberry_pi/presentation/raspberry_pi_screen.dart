import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/router/app_route.dart';
import '../../../app/router/route_paths.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_icons.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/wearable_controller.dart';
import '../../../core/constants/app_keys.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/action_buttons.dart';
import '../../../core/widgets/app_bottom_navigation.dart';
import '../../../core/widgets/app_screen_scaffold.dart';
import '../../../core/widgets/selection_components.dart';
import '../../../core/widgets/visual_components.dart';
import '../../../domain/entities/app_settings.dart';
import '../../../domain/entities/wearable_device.dart';
import '../../../domain/entities/wearable_failure.dart';
import '../../../domain/entities/wearable_session_state.dart';
import '../../../domain/entities/wearable_telemetry.dart';
import '../../../domain/enums/wearable_assistance_state.dart';
import '../../../domain/enums/wearable_component_state.dart';
import '../../../domain/enums/wearable_connection_phase.dart';

class RaspberryPiScreen extends ConsumerStatefulWidget {
  const RaspberryPiScreen({super.key});

  @override
  ConsumerState<RaspberryPiScreen> createState() => _RaspberryPiScreenState();
}

class _RaspberryPiScreenState extends ConsumerState<RaspberryPiScreen> {
  final _manualFormKey = GlobalKey<FormState>();
  final _hostController = TextEditingController();
  final _portController = TextEditingController(text: '8765');
  final _pairingCodeController = TextEditingController();

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _pairingCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewState = ref.watch(wearableControllerProvider);
    final controller = ref.read(wearableControllerProvider.notifier);
    final appSettings = ref.watch(appSettingsControllerProvider);
    final session = viewState.session;
    final phase = session.phase;
    final connected = phase.isConnected;
    final selectedDevice = session.selectedDevice;
    final showPairing =
        selectedDevice != null &&
        (phase == WearableConnectionPhase.deviceFound ||
            phase == WearableConnectionPhase.authenticationFailed ||
            viewState.failure?.kind.name == 'pairingExpired');

    return AppScreenScaffold(
      title: AppStrings.raspberryPiTitle,
      bottomNavigationBar: const AppBottomNavigation(
        selectedRoutePath: RoutePaths.raspberryPi,
      ),
      children: [
        Center(
          child: BrandIconBadge(
            icon: AppIcons.bluetooth,
            label: '${AppStrings.raspberryPiTitle} icon',
            size: 96,
            filled: connected,
          ),
        ),
        const SizedBox(height: AppSpacing.space5),
        Semantics(
          headingLevel: 2,
          child: Text(
            'Raspberry Cap',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
        const SizedBox(height: AppSpacing.space2),
        Text(
          'Control offline wearable object detection over your local network.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: AppSpacing.space4),
        Center(
          child: StatusPill(
            label: WearableController.statusLabelFor(phase),
            icon: _phaseIcon(phase),
            color: _phaseColor(phase),
          ),
        ),
        const SizedBox(height: AppSpacing.space3),
        Semantics(
          key: AppKeys.raspberryPiStatus,
          container: true,
          liveRegion: true,
          label: viewState.liveMessage,
          child: ExcludeSemantics(
            child: Text(
              viewState.liveMessage,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
        if (viewState.lifecycleSuspended) ...[
          const SizedBox(height: AppSpacing.space4),
          const FeatureNoteCard(
            icon: AppIcons.info,
            title: 'Phone connection paused',
            description:
                'Wearable assistance continues locally. The phone reconnects once when the app resumes.',
          ),
        ],
        if (viewState.failure case final failure?) ...[
          const SizedBox(height: AppSpacing.space5),
          _FailurePanel(failure: failure),
          const SizedBox(height: AppSpacing.space3),
          SecondaryActionButton(
            key: AppKeys.raspberryPiErrorButton,
            label: 'Open Recovery Details',
            icon: AppIcons.warning,
            semanticLabel:
                'Open wearable recovery details for error ${failure.code}',
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRoute.raspberryPiError.path),
          ),
        ],
        const SizedBox(height: AppSpacing.space6),
        _SectionHeading(
          title: 'Find your wearable',
          description:
              'Search with local discovery or enter a current hostname or IP address.',
        ),
        const SizedBox(height: AppSpacing.space3),
        PrimaryActionButton(
          key: AppKeys.raspberryPiScanButton,
          label: phase == WearableConnectionPhase.discovering
              ? 'Searching…'
              : 'Search Local Network',
          icon: AppIcons.refresh,
          semanticLabel: phase == WearableConnectionPhase.discovering
              ? 'Searching the local network for Raspberry Pi wearables'
              : 'Search the local network for a Raspberry Pi wearable',
          onPressed: viewState.canRunAction && !connected
              ? controller.discover
              : null,
        ),
        if (session.discoveredDevices.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.space4),
          _DiscoveredDeviceList(
            devices: session.discoveredDevices,
            selectedDevice: selectedDevice,
            enabled: viewState.canRunAction && !connected,
            onSelected: controller.selectDevice,
          ),
        ],
        const SizedBox(height: AppSpacing.space4),
        _ManualAddressForm(
          formKey: _manualFormKey,
          hostController: _hostController,
          portController: _portController,
          enabled: viewState.canRunAction && !connected,
          onUseAddress: () => _selectManualAddress(controller),
        ),
        if (selectedDevice != null) ...[
          const SizedBox(height: AppSpacing.space5),
          _SelectedDeviceCard(device: selectedDevice),
        ],
        if (showPairing) ...[
          const SizedBox(height: AppSpacing.space6),
          _SectionHeading(
            title: 'Pair securely',
            description:
                'Generate a short-lived code on the Raspberry Pi and enter it here. The code is never saved.',
          ),
          const SizedBox(height: AppSpacing.space3),
          TextFormField(
            key: AppKeys.raspberryPiPairingCodeField,
            controller: _pairingCodeController,
            enabled: viewState.canRunAction,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            enableSuggestions: false,
            obscureText: true,
            obscuringCharacter: '•',
            keyboardType: TextInputType.visiblePassword,
            maxLength: 8,
            inputFormatters: [
              LengthLimitingTextInputFormatter(8),
              FilteringTextInputFormatter.allow(RegExp(r'[23456789A-HJ-NP-Z]')),
              _UpperCaseTextFormatter(),
            ],
            decoration: const InputDecoration(
              labelText: 'Pairing code',
              helperText: 'Eight characters; expires after a short time',
              border: OutlineInputBorder(),
            ),
            validator: WearableController.validatePairingCode,
            onFieldSubmitted: viewState.canRunAction
                ? (_) => _pair(controller)
                : null,
          ),
          const SizedBox(height: AppSpacing.space3),
          PrimaryActionButton(
            key: AppKeys.raspberryPiPairButton,
            label: phase == WearableConnectionPhase.pairing
                ? 'Pairing…'
                : 'Pair Device',
            icon: AppIcons.link,
            semanticLabel:
                'Pair the selected Raspberry Pi using the short-lived code',
            onPressed: viewState.canRunAction ? () => _pair(controller) : null,
          ),
        ],
        if (selectedDevice != null && !showPairing && !connected) ...[
          const SizedBox(height: AppSpacing.space5),
          PrimaryActionButton(
            key: AppKeys.raspberryPiConnectButton,
            label:
                phase == WearableConnectionPhase.connecting ||
                    phase == WearableConnectionPhase.authenticating ||
                    phase == WearableConnectionPhase.reconnecting
                ? 'Connecting…'
                : 'Connect',
            icon: AppIcons.link,
            semanticLabel:
                'Connect securely to ${selectedDevice.name} on the local network',
            onPressed:
                viewState.canRunAction &&
                    phase != WearableConnectionPhase.incompatible &&
                    phase != WearableConnectionPhase.authenticationFailed
                ? controller.connect
                : null,
          ),
        ],
        if (connected) ...[
          const SizedBox(height: AppSpacing.space5),
          SecondaryActionButton(
            key: AppKeys.raspberryPiDisconnectButton,
            label: 'Disconnect Phone',
            icon: AppIcons.wifiOff,
            semanticLabel:
                'Disconnect this phone without stopping wearable assistance',
            onPressed: viewState.canRunAction ? controller.disconnect : null,
          ),
        ],
        const SizedBox(height: AppSpacing.space6),
        _AssistanceControls(viewState: viewState, controller: controller),
        const SizedBox(height: AppSpacing.space6),
        _SettingsPanel(
          settings: appSettings,
          viewState: viewState,
          onSynchronize: controller.synchronizeSettings,
          onEdit: () => Navigator.of(context).pushNamed(AppRoute.settings.path),
        ),
        const SizedBox(height: AppSpacing.space6),
        _DeviceTelemetryPanel(session: session),
        const SizedBox(height: AppSpacing.space5),
        const FeatureNoteCard(
          icon: AppIcons.volume,
          title: 'Feedback stays on the wearable',
          description: AppStrings.raspberryPiFeedbackOwnership,
        ),
        const SizedBox(height: AppSpacing.space4),
        const FeatureNoteCard(
          icon: AppIcons.cloudOff,
          title: 'Local network only',
          description: AppStrings.raspberryPiLocalOnly,
        ),
        if (selectedDevice != null) ...[
          const SizedBox(height: AppSpacing.space6),
          SecondaryActionButton(
            key: AppKeys.raspberryPiForgetButton,
            label: 'Forget Paired Device',
            icon: AppIcons.warning,
            semanticLabel:
                'Forget the paired wearable and remove its phone credential',
            onPressed: viewState.canRunAction
                ? () => _confirmForget(controller, selectedDevice.name)
                : null,
          ),
        ],
        const SizedBox(height: AppSpacing.space5),
        SecondaryActionButton(
          label: 'Use Mobile Mode',
          icon: AppIcons.smartphone,
          semanticLabel:
              'Open Mobile Mode. Mobile Mode remains available without the wearable.',
          onPressed: () =>
              Navigator.of(context).pushReplacementNamed(AppRoute.home.path),
        ),
      ],
    );
  }

  void _selectManualAddress(WearableController controller) {
    if (!(_manualFormKey.currentState?.validate() ?? false)) return;
    final error = controller.selectManualDevice(
      host: _hostController.text,
      port: _portController.text,
    );
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _pair(WearableController controller) async {
    final validation = WearableController.validatePairingCode(
      _pairingCodeController.text,
    );
    if (validation != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(validation)));
      return;
    }
    await controller.pair(_pairingCodeController.text);
    if (mounted) _pairingCodeController.clear();
  }

  Future<void> _confirmForget(
    WearableController controller,
    String deviceName,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Forget paired device?'),
        content: Text(
          'This removes the saved phone credential for $deviceName. '
          'You will need a fresh Pi pairing code to reconnect.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Forget Device'),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.forgetDevice();
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          headingLevel: 2,
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        const SizedBox(height: AppSpacing.space1),
        Text(description),
      ],
    );
  }
}

class _ManualAddressForm extends StatelessWidget {
  const _ManualAddressForm({
    required this.formKey,
    required this.hostController,
    required this.portController,
    required this.enabled,
    required this.onUseAddress,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController hostController;
  final TextEditingController portController;
  final bool enabled;
  final VoidCallback onUseAddress;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            headingLevel: 2,
            child: Text(
              'Manual address',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: AppSpacing.space2),
          TextFormField(
            key: AppKeys.raspberryPiManualHostField,
            controller: hostController,
            enabled: enabled,
            autocorrect: false,
            enableSuggestions: false,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Hostname or IP address',
              hintText: 'rpi3-ml.local',
              helperText: 'Do not include ws:// or a URL path',
              border: OutlineInputBorder(),
            ),
            validator: WearableController.validateHost,
          ),
          const SizedBox(height: AppSpacing.space3),
          TextFormField(
            key: AppKeys.raspberryPiManualPortField,
            controller: portController,
            enabled: enabled,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Service port',
              border: OutlineInputBorder(),
            ),
            validator: WearableController.validatePort,
            onFieldSubmitted: enabled ? (_) => onUseAddress() : null,
          ),
          const SizedBox(height: AppSpacing.space3),
          SecondaryActionButton(
            key: AppKeys.raspberryPiUseManualAddressButton,
            label: 'Use This Address',
            icon: AppIcons.connection,
            semanticLabel:
                'Validate and select this local Raspberry Pi address',
            onPressed: enabled ? onUseAddress : null,
          ),
        ],
      ),
    );
  }
}

class _DiscoveredDeviceList extends StatelessWidget {
  const _DiscoveredDeviceList({
    required this.devices,
    required this.selectedDevice,
    required this.enabled,
    required this.onSelected,
  });

  final List<WearableDevice> devices;
  final WearableDevice? selectedDevice;
  final bool enabled;
  final ValueChanged<WearableDevice> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          headingLevel: 2,
          child: Text(
            'Discovered devices',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: AppSpacing.space2),
        for (final device in devices) ...[
          SelectableInfoCard(
            key: ValueKey('wearable_device_${device.id}'),
            title: device.name,
            description: '${device.host}:${device.port}',
            icon: AppIcons.capStatus,
            selected: device == selectedDevice,
            status: device.source == WearableDeviceSource.saved
                ? 'Saved device'
                : 'Found on local network',
            enabled: enabled,
            semanticLabel:
                '${device.name}, local address ${device.host}, port ${device.port}, '
                '${device == selectedDevice ? 'selected' : 'not selected'}',
            onTap: enabled ? () => onSelected(device) : null,
          ),
          const SizedBox(height: AppSpacing.space3),
        ],
      ],
    );
  }
}

class _SelectedDeviceCard extends StatelessWidget {
  const _SelectedDeviceCard({required this.device});

  final WearableDevice device;

  @override
  Widget build(BuildContext context) {
    return FeatureNoteCard(
      icon: AppIcons.capStatus,
      title: 'Selected: ${device.name}',
      description:
          'Local endpoint ${device.host}:${device.port}. Address changes can be rediscovered; no fixed IP is required.',
    );
  }
}

class _AssistanceControls extends StatelessWidget {
  const _AssistanceControls({
    required this.viewState,
    required this.controller,
  });

  final WearableControllerState viewState;
  final WearableController controller;

  @override
  Widget build(BuildContext context) {
    final session = viewState.session;
    final canAct = viewState.canRunAction;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeading(
          title: 'Wearable assistance',
          description:
              'Object detection runs on the Raspberry Pi. Commands require an authenticated connection and acknowledgement.',
        ),
        const SizedBox(height: AppSpacing.space3),
        const FeatureNoteCard(
          icon: AppIcons.visibility,
          title: 'Object detection',
          description:
              'This is the only supported wearable assistance mode in the current project scope.',
        ),
        const SizedBox(height: AppSpacing.space3),
        PrimaryActionButton(
          key: AppKeys.raspberryPiStartButton,
          label: session.phase == WearableConnectionPhase.starting
              ? 'Starting…'
              : 'Start Wearable Assistance',
          icon: AppIcons.play,
          semanticLabel: session.canStart
              ? 'Start local Raspberry Pi object detection assistance'
              : 'Start wearable assistance unavailable in the current state',
          onPressed: canAct && session.canStart
              ? controller.startAssistance
              : null,
        ),
        const SizedBox(height: AppSpacing.space3),
        SecondaryActionButton(
          key: AppKeys.raspberryPiPauseButton,
          label: 'Pause Assistance',
          icon: Icons.pause,
          semanticLabel: session.canPause
              ? 'Pause Raspberry Pi assistance'
              : 'Pause wearable assistance unavailable in the current state',
          onPressed: canAct && session.canPause
              ? controller.pauseAssistance
              : null,
        ),
        const SizedBox(height: AppSpacing.space3),
        SecondaryActionButton(
          key: AppKeys.raspberryPiResumeButton,
          label: 'Resume Assistance',
          icon: AppIcons.play,
          semanticLabel: session.canResume
              ? 'Resume Raspberry Pi assistance'
              : 'Resume wearable assistance unavailable in the current state',
          onPressed: canAct && session.canResume
              ? controller.resumeAssistance
              : null,
        ),
        const SizedBox(height: AppSpacing.space3),
        SecondaryActionButton(
          key: AppKeys.raspberryPiStopButton,
          label: session.phase == WearableConnectionPhase.stopping
              ? 'Stopping…'
              : 'Stop Wearable Assistance',
          icon: AppIcons.stop,
          semanticLabel: session.canStop
              ? 'Stop Raspberry Pi assistance'
              : 'Stop wearable assistance unavailable in the current state',
          onPressed: canAct && session.canStop
              ? controller.stopAssistance
              : null,
        ),
      ],
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({
    required this.settings,
    required this.viewState,
    required this.onSynchronize,
    required this.onEdit,
  });

  final AppSettings settings;
  final WearableControllerState viewState;
  final Future<void> Function() onSynchronize;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final syncLabel = switch (viewState.settingsSyncState) {
      WearableSettingsSyncState.idle => 'Not synchronized this session',
      WearableSettingsSyncState.synchronizing => 'Synchronizing',
      WearableSettingsSyncState.synchronized => 'Synchronized',
      WearableSettingsSyncState.failed => 'Synchronization failed',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeading(
          title: 'Wearable feedback settings',
          description:
              'The saved app settings are sent to the Pi and persisted after acknowledgement.',
        ),
        const SizedBox(height: AppSpacing.space3),
        _DetailCard(
          children: [
            _InfoRow(
              label: 'Confidence',
              value:
                  '${(settings.detectionSettings.confidenceThreshold * 100).round()}%',
            ),
            _InfoRow(
              label: 'Announcement cooldown',
              value:
                  '${settings.feedbackSettings.announcementCooldownSeconds} seconds',
            ),
            _InfoRow(
              label: 'Speech on Pi',
              value: settings.feedbackSettings.audioEnabled ? 'On' : 'Off',
            ),
            _InfoRow(
              label: 'Vibration preference',
              value: 'Not available on the current Pi hardware',
            ),
            _InfoRow(label: 'Sync state', value: syncLabel, isLast: true),
          ],
        ),
        const SizedBox(height: AppSpacing.space3),
        SecondaryActionButton(
          key: AppKeys.raspberryPiEditSettingsButton,
          label: 'Edit Saved Settings',
          icon: AppIcons.settings,
          onPressed: onEdit,
        ),
        const SizedBox(height: AppSpacing.space3),
        SecondaryActionButton(
          key: AppKeys.raspberryPiSyncSettingsButton,
          label: 'Synchronize Settings',
          icon: AppIcons.refresh,
          semanticLabel: viewState.session.phase.isConnected
              ? 'Synchronize saved feedback and detection settings with the Raspberry Pi'
              : 'Synchronize settings unavailable until the wearable is connected',
          onPressed:
              viewState.canRunAction && viewState.session.phase.isConnected
              ? onSynchronize
              : null,
        ),
      ],
    );
  }
}

class _DeviceTelemetryPanel extends StatelessWidget {
  const _DeviceTelemetryPanel({required this.session});

  final WearableSessionState session;

  @override
  Widget build(BuildContext context) {
    final health = session.deviceHealth;
    final status = session.deviceStatus;
    final detection = session.lastDetection;
    final lastSeen = _latestTimestamp([
      health?.measuredAt,
      status?.updatedAt,
      detection?.capturedAt,
    ]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeading(
          title: 'Device status',
          description:
              'Values below come from the Pi. Missing telemetry is shown honestly as not reported.',
        ),
        const SizedBox(height: AppSpacing.space3),
        _DetailCard(
          children: [
            _InfoRow(
              label: 'Assistance',
              value: _assistanceLabel(status?.assistanceState),
            ),
            _InfoRow(
              label: 'Camera',
              value: _componentLabel(
                health?.cameraState ?? session.cameraStatus?.state,
              ),
            ),
            _InfoRow(
              label: 'Detection model',
              value: _componentLabel(
                health?.modelState ?? session.modelStatus?.state,
              ),
            ),
            _InfoRow(
              label: 'CPU temperature',
              value: health?.cpuTemperatureCelsius == null
                  ? 'Not reported'
                  : '${health!.cpuTemperatureCelsius!.toStringAsFixed(1)} °C',
            ),
            _InfoRow(
              label: 'Memory used',
              value: health == null
                  ? 'Not reported'
                  : '${(health.memoryUsedFraction * 100).round()}%',
            ),
            _InfoRow(label: 'Battery / power', value: _powerLabel(health)),
            _InfoRow(label: 'Throttling', value: _throttlingLabel(health)),
            _InfoRow(
              label: 'Last seen',
              value: lastSeen == null
                  ? 'No telemetry received'
                  : _formatLocalTimestamp(lastSeen),
              isLast: true,
            ),
          ],
        ),
        if (detection != null) ...[
          const SizedBox(height: AppSpacing.space3),
          Semantics(
            container: true,
            label:
                'Latest wearable detection: ${detection.className}, ${detection.direction.name}, '
                '${(detection.confidence * 100).round()} percent confidence. '
                'Detection feedback is spoken by the Raspberry Pi, not repeated by the phone.',
            child: ExcludeSemantics(
              child: FeatureNoteCard(
                icon: AppIcons.visibility,
                title: 'Latest detection',
                description:
                    '${detection.className}, ${detection.direction.name}, '
                    '${(detection.confidence * 100).round()}% confidence. '
                    'Phone speech is intentionally suppressed.',
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _FailurePanel extends StatelessWidget {
  const _FailurePanel({required this.failure});

  final WearableFailure failure;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ErrorNotice(
          title: failure.userMessage,
          message: WearableController.recoveryMessageFor(failure),
          icon: AppIcons.warning,
        ),
        const SizedBox(height: AppSpacing.space2),
        Text(
          'Error code: ${failure.code}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(AppRadii.extraLarge),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space4),
        child: Column(children: children),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value',
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.space2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text(label)),
                const SizedBox(width: AppSpacing.space3),
                Expanded(
                  child: Text(
                    value,
                    textAlign: TextAlign.end,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          if (!isLast) const Divider(height: 1),
        ],
      ),
    );
  }
}

class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

IconData _phaseIcon(WearableConnectionPhase phase) {
  return switch (phase) {
    WearableConnectionPhase.connected ||
    WearableConnectionPhase.running => AppIcons.success,
    WearableConnectionPhase.discovering ||
    WearableConnectionPhase.connecting ||
    WearableConnectionPhase.authenticating ||
    WearableConnectionPhase.reconnecting => AppIcons.refresh,
    WearableConnectionPhase.paused => Icons.pause_circle_outline,
    WearableConnectionPhase.incompatible ||
    WearableConnectionPhase.authenticationFailed ||
    WearableConnectionPhase.unavailable ||
    WearableConnectionPhase.error => AppIcons.warning,
    _ => AppIcons.wifiOff,
  };
}

Color _phaseColor(WearableConnectionPhase phase) {
  return switch (phase) {
    WearableConnectionPhase.connected ||
    WearableConnectionPhase.running => AppColors.success,
    WearableConnectionPhase.incompatible ||
    WearableConnectionPhase.authenticationFailed ||
    WearableConnectionPhase.unavailable ||
    WearableConnectionPhase.error => AppColors.error,
    WearableConnectionPhase.paused => AppColors.warning,
    WearableConnectionPhase.discovering ||
    WearableConnectionPhase.deviceFound ||
    WearableConnectionPhase.pairing ||
    WearableConnectionPhase.paired ||
    WearableConnectionPhase.connecting ||
    WearableConnectionPhase.authenticating ||
    WearableConnectionPhase.reconnecting ||
    WearableConnectionPhase.starting ||
    WearableConnectionPhase.stopping => AppColors.primary,
    _ => AppColors.error,
  };
}

String _assistanceLabel(WearableAssistanceState? state) {
  return switch (state) {
    null => 'Not reported',
    WearableAssistanceState.idle => 'Idle',
    WearableAssistanceState.starting => 'Starting',
    WearableAssistanceState.running => 'Running',
    WearableAssistanceState.paused => 'Paused',
    WearableAssistanceState.stopping => 'Stopping',
    WearableAssistanceState.hardwareError => 'Hardware error',
  };
}

String _componentLabel(WearableComponentState? state) {
  return switch (state) {
    null => 'Not reported',
    WearableComponentState.unavailable => 'Unavailable',
    WearableComponentState.loading => 'Loading',
    WearableComponentState.ready => 'Ready',
    WearableComponentState.active => 'Active',
    WearableComponentState.paused => 'Paused',
    WearableComponentState.recovering => 'Recovering',
    WearableComponentState.error => 'Error',
  };
}

String _powerLabel(WearableDeviceHealth? health) {
  if (health == null) return 'Not reported';
  final source = health.powerSource;
  final battery = health.batteryFraction;
  final voltage = health.underVoltage;
  final parts = <String>[
    if (source != null && source.isNotEmpty) source,
    if (battery != null) '${(battery * 100).round()}% battery',
    if (voltage == true) 'under-voltage detected',
    if (voltage == false) 'voltage normal',
  ];
  return parts.isEmpty ? 'Not reported' : parts.join(', ');
}

String _throttlingLabel(WearableDeviceHealth? health) {
  return switch (health?.throttled) {
    true => 'Detected',
    false => 'Not detected',
    null => 'Not reported',
  };
}

DateTime? _latestTimestamp(List<DateTime?> values) {
  DateTime? latest;
  for (final value in values) {
    if (value != null && (latest == null || value.isAfter(latest))) {
      latest = value;
    }
  }
  return latest;
}

String _formatLocalTimestamp(DateTime value) {
  final local = value.toLocal();
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)} '
      '${twoDigits(local.hour)}:${twoDigits(local.minute)}:${twoDigits(local.second)}';
}
