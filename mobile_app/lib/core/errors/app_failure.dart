sealed class AppFailure {
  const AppFailure({
    required this.code,
    required this.userMessage,
    this.logMessage,
  });

  final String code;
  final String userMessage;
  final String? logMessage;
}

class ConfigurationFailure extends AppFailure {
  const ConfigurationFailure({
    super.code = 'configuration_failure',
    super.userMessage = 'The app configuration is incomplete.',
    super.logMessage,
  });
}

class PermissionFailure extends AppFailure {
  const PermissionFailure({
    super.code = 'permission_failure',
    super.userMessage = 'A required permission is unavailable.',
    super.logMessage,
  });
}

class DeviceFailure extends AppFailure {
  const DeviceFailure({
    super.code = 'device_failure',
    super.userMessage = 'A required device service is unavailable.',
    super.logMessage,
  });
}

class StorageFailure extends AppFailure {
  const StorageFailure({
    super.code = 'storage_failure',
    super.userMessage = 'Local settings could not be loaded or saved.',
    super.logMessage,
  });
}

class CameraFailure extends AppFailure {
  const CameraFailure({
    super.code = 'camera_failure',
    super.userMessage = 'Camera support is unavailable.',
    super.logMessage,
  });
}

class InferenceFailure extends AppFailure {
  const InferenceFailure({
    super.code = 'inference_failure',
    super.userMessage = 'Object detection is unavailable.',
    super.logMessage,
  });
}

class FeedbackFailure extends AppFailure {
  const FeedbackFailure({
    super.code = 'feedback_failure',
    super.userMessage = 'Audio or vibration feedback is unavailable.',
    super.logMessage,
  });
}

class ConnectionFailure extends AppFailure {
  const ConnectionFailure({
    super.code = 'connection_failure',
    super.userMessage = 'The local wearable connection is unavailable.',
    super.logMessage,
  });
}

class UnknownFailure extends AppFailure {
  const UnknownFailure({
    super.code = 'unknown_failure',
    super.userMessage = 'Something went wrong. Please try again.',
    super.logMessage,
  });
}
