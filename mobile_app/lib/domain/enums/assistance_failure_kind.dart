enum AssistanceFailureKind {
  permissionDenied,
  permissionPermanentlyDenied,
  camera,
  model,
  inference,
  feedback,
  unexpected;

  String get label => switch (this) {
    AssistanceFailureKind.permissionDenied => 'Permission denied',
    AssistanceFailureKind.permissionPermanentlyDenied =>
      'Permission permanently denied',
    AssistanceFailureKind.camera => 'Camera error',
    AssistanceFailureKind.model => 'Model error',
    AssistanceFailureKind.inference => 'Detection error',
    AssistanceFailureKind.feedback => 'Feedback error',
    AssistanceFailureKind.unexpected => 'Assistance error',
  };
}
