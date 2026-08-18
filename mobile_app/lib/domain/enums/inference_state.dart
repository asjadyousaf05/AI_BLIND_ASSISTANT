enum InferenceState {
  unloaded,
  loading,
  ready,
  processing,
  error;

  String get label => switch (this) {
    InferenceState.unloaded => 'Model not loaded',
    InferenceState.loading => 'Loading model',
    InferenceState.ready => 'Model ready',
    InferenceState.processing => 'Running inference',
    InferenceState.error => 'Inference error',
  };
}
