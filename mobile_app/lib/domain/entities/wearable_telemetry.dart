import '../enums/wearable_assistance_state.dart';
import '../enums/wearable_component_state.dart';
import '../enums/wearable_direction.dart';
import 'bounding_box.dart';

class WearableDetectionEvent {
  const WearableDetectionEvent({
    required this.sourceDeviceId,
    required this.frameSequence,
    required this.classId,
    required this.className,
    required this.confidence,
    required this.boundingBox,
    required this.direction,
    required this.capturedAt,
    required this.priority,
    this.alertCategory = 'object',
    this.relativeProximity,
    this.feedbackTarget = WearableFeedbackTarget.pi,
    this.piAnnounced = false,
  });

  final String sourceDeviceId;
  final int frameSequence;
  final int classId;
  final String className;
  final double confidence;
  final BoundingBox boundingBox;
  final WearableDirection direction;
  final DateTime capturedAt;

  /// Protocol priority from 0 (informational) to 100 (most urgent).
  final int priority;
  final String alertCategory;

  /// Uncalibrated visual heuristic only; never a metric distance.
  final String? relativeProximity;
  final WearableFeedbackTarget feedbackTarget;
  final bool piAnnounced;

  Map<String, Object?> toPayload() => {
    'sourceDeviceId': sourceDeviceId,
    'frameSequence': frameSequence,
    'classId': classId,
    'className': className,
    'confidence': confidence,
    'boundingBox': {
      'left': boundingBox.left,
      'top': boundingBox.top,
      'right': boundingBox.right,
      'bottom': boundingBox.bottom,
    },
    'direction': direction.name,
    'capturedAt': capturedAt.toUtc().toIso8601String(),
    'priority': priority,
    'alertCategory': alertCategory,
    'relativeProximity': relativeProximity,
    'feedbackTarget': feedbackTarget.name,
    'piAnnounced': piAnnounced,
  };

  static WearableDetectionEvent fromPayload(Map<String, Object?> payload) {
    final sourceDeviceId = payload['sourceDeviceId'];
    final frameSequence = payload['frameSequence'];
    final classId = payload['classId'];
    final className = payload['className'];
    final confidence = payload['confidence'];
    final boundingBox = payload['boundingBox'];
    final direction = payload['direction'];
    final capturedAt = payload['capturedAt'];
    final priority = payload['priority'];
    final alertCategory = payload['alertCategory'];
    final relativeProximity = payload['relativeProximity'];
    final feedbackTarget = payload['feedbackTarget'];
    final piAnnounced = payload['piAnnounced'];
    if (sourceDeviceId is! String ||
        sourceDeviceId.isEmpty ||
        frameSequence is! int ||
        frameSequence < 0 ||
        classId is! int ||
        classId < 0 ||
        className is! String ||
        className.isEmpty ||
        confidence is! num ||
        !confidence.isFinite ||
        confidence < 0 ||
        confidence > 1 ||
        boundingBox is! Map ||
        direction is! String ||
        capturedAt is! String ||
        priority is! int ||
        priority < 0 ||
        priority > 100 ||
        (alertCategory != null &&
            (alertCategory is! String || alertCategory.isEmpty)) ||
        (relativeProximity != null && relativeProximity is! String) ||
        (feedbackTarget != null && feedbackTarget is! String) ||
        (piAnnounced != null && piAnnounced is! bool)) {
      throw const FormatException('Invalid wearable detection event');
    }
    final box = _parseBoundingBox(boundingBox.cast<String, Object?>());
    return WearableDetectionEvent(
      sourceDeviceId: sourceDeviceId,
      frameSequence: frameSequence,
      classId: classId,
      className: className,
      confidence: confidence.toDouble(),
      boundingBox: box,
      direction: WearableDirection.fromWireName(direction),
      capturedAt: DateTime.parse(capturedAt).toUtc(),
      priority: priority,
      alertCategory: alertCategory == null ? 'object' : alertCategory as String,
      relativeProximity: relativeProximity as String?,
      feedbackTarget: feedbackTarget == null
          ? WearableFeedbackTarget.pi
          : WearableFeedbackTarget.fromWireName(feedbackTarget as String),
      piAnnounced: piAnnounced == null ? false : piAnnounced as bool,
    );
  }

  static BoundingBox _parseBoundingBox(Map<String, Object?> payload) {
    final left = payload['left'];
    final top = payload['top'];
    final right = payload['right'];
    final bottom = payload['bottom'];
    if (left is! num || top is! num || right is! num || bottom is! num) {
      throw const FormatException('Invalid normalized bounding box');
    }
    final box = BoundingBox(
      left: left.toDouble(),
      top: top.toDouble(),
      right: right.toDouble(),
      bottom: bottom.toDouble(),
    );
    if (!box.isValid) {
      throw const FormatException('Bounding box is outside normalized bounds');
    }
    return box;
  }
}

enum WearableFeedbackTarget {
  pi,
  phone,
  none;

  static WearableFeedbackTarget fromWireName(String value) {
    return values.firstWhere(
      (target) => target.name == value,
      orElse: () => throw FormatException('Invalid feedback target: $value'),
    );
  }
}

class WearableDeviceStatus {
  const WearableDeviceStatus({
    required this.deviceId,
    required this.assistanceState,
    required this.assistanceMode,
    required this.settingsRevision,
    required this.updatedAt,
  });

  final String deviceId;
  final WearableAssistanceState assistanceState;
  final String assistanceMode;
  final int settingsRevision;
  final DateTime updatedAt;

  Map<String, Object?> toPayload() => {
    'deviceId': deviceId,
    'assistanceState': assistanceState.wireName,
    'assistanceMode': assistanceMode,
    'settingsRevision': settingsRevision,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  static WearableDeviceStatus fromPayload(Map<String, Object?> payload) {
    final deviceId = payload['deviceId'];
    final state = payload['assistanceState'];
    final mode = payload['assistanceMode'];
    final revision = payload['settingsRevision'];
    final updatedAt = payload['updatedAt'];
    if (deviceId is! String ||
        deviceId.isEmpty ||
        state is! String ||
        mode is! String ||
        mode.isEmpty ||
        revision is! int ||
        revision < 0 ||
        updatedAt is! String) {
      throw const FormatException('Invalid wearable device status');
    }
    return WearableDeviceStatus(
      deviceId: deviceId,
      assistanceState: WearableAssistanceState.fromWireName(state),
      assistanceMode: mode,
      settingsRevision: revision,
      updatedAt: DateTime.parse(updatedAt).toUtc(),
    );
  }
}

class WearableComponentStatus {
  const WearableComponentStatus({
    required this.state,
    required this.updatedAt,
    this.errorCode,
    this.message,
  });

  final WearableComponentState state;
  final DateTime updatedAt;
  final String? errorCode;
  final String? message;

  static WearableComponentStatus fromPayload(Map<String, Object?> payload) {
    final state = payload['state'];
    final updatedAt = payload['updatedAt'];
    final errorCode = payload['errorCode'];
    final message = payload['message'];
    if (state is! String ||
        updatedAt is! String ||
        (errorCode != null && errorCode is! String) ||
        (message != null && message is! String)) {
      throw const FormatException('Invalid wearable component status');
    }
    return WearableComponentStatus(
      state: WearableComponentState.fromWireName(state),
      updatedAt: DateTime.parse(updatedAt).toUtc(),
      errorCode: errorCode as String?,
      message: message as String?,
    );
  }
}

class WearableDeviceHealth {
  const WearableDeviceHealth({
    required this.deviceId,
    required this.uptimeSeconds,
    required this.memoryUsedFraction,
    required this.cameraState,
    required this.modelState,
    required this.measuredAt,
    this.cpuUsedFraction,
    this.cpuTemperatureCelsius,
    this.throttled,
    this.underVoltage,
    this.powerSource,
    this.batteryFraction,
  });

  final String deviceId;
  final int uptimeSeconds;
  final double memoryUsedFraction;
  final double? cpuUsedFraction;
  final double? cpuTemperatureCelsius;
  final bool? throttled;
  final bool? underVoltage;
  final String? powerSource;
  final double? batteryFraction;
  final WearableComponentState cameraState;
  final WearableComponentState modelState;
  final DateTime measuredAt;

  static WearableDeviceHealth fromPayload(Map<String, Object?> payload) {
    final deviceId = payload['deviceId'];
    final uptime = payload['uptimeSeconds'];
    final memory = payload['memoryUsedFraction'];
    final cpu = payload['cpuUsedFraction'];
    final temperature = payload['cpuTemperatureCelsius'];
    final throttled = payload['throttled'];
    final underVoltage = payload['underVoltage'];
    final powerSource = payload['powerSource'];
    final battery = payload['batteryFraction'];
    final camera = payload['cameraState'];
    final model = payload['modelState'];
    final measuredAt = payload['measuredAt'];
    if (deviceId is! String ||
        deviceId.isEmpty ||
        uptime is! int ||
        uptime < 0 ||
        memory is! num ||
        !memory.isFinite ||
        memory < 0 ||
        memory > 1 ||
        (cpu != null && cpu is! num) ||
        (temperature != null && temperature is! num) ||
        (throttled != null && throttled is! bool) ||
        (underVoltage != null && underVoltage is! bool) ||
        (powerSource != null && powerSource is! String) ||
        (battery != null && battery is! num) ||
        camera is! String ||
        model is! String ||
        measuredAt is! String) {
      throw const FormatException('Invalid wearable device health');
    }
    final cpuValue = cpu == null ? null : (cpu as num).toDouble();
    if (cpuValue != null &&
        (!cpuValue.isFinite || cpuValue < 0 || cpuValue > 1)) {
      throw const FormatException('Invalid wearable CPU usage');
    }
    final temperatureValue = temperature == null
        ? null
        : (temperature as num).toDouble();
    if (temperatureValue != null && !temperatureValue.isFinite) {
      throw const FormatException('Invalid wearable CPU temperature');
    }
    final batteryValue = battery == null ? null : (battery as num).toDouble();
    if (batteryValue != null &&
        (!batteryValue.isFinite || batteryValue < 0 || batteryValue > 1)) {
      throw const FormatException('Invalid wearable battery fraction');
    }
    if (powerSource is String && powerSource.length > 128) {
      throw const FormatException('Invalid wearable power source');
    }
    return WearableDeviceHealth(
      deviceId: deviceId,
      uptimeSeconds: uptime,
      memoryUsedFraction: memory.toDouble(),
      cpuUsedFraction: cpuValue,
      cpuTemperatureCelsius: temperatureValue,
      throttled: throttled as bool?,
      underVoltage: underVoltage as bool?,
      powerSource: powerSource as String?,
      batteryFraction: batteryValue,
      cameraState: WearableComponentState.fromWireName(camera),
      modelState: WearableComponentState.fromWireName(model),
      measuredAt: DateTime.parse(measuredAt).toUtc(),
    );
  }
}
