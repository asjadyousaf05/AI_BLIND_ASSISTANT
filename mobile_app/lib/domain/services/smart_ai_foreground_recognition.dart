/// Optional phone-local capability, enabled only on the foreground Smart AI view.
abstract interface class SmartAiForegroundRecognition {
  Stream<void> get smartAiGoodbyes;
  Future<void> setSmartAiControlsActive(bool active);
}
