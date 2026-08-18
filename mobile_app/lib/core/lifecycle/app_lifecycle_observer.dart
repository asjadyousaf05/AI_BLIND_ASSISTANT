import 'package:flutter/widgets.dart';

typedef LifecycleCallback = void Function(AppLifecycleState state);

class AppLifecycleObserver extends WidgetsBindingObserver {
  AppLifecycleObserver({required this.onStateChanged});

  final LifecycleCallback onStateChanged;
  AppLifecycleState _lastState = AppLifecycleState.resumed;

  AppLifecycleState get lastState => _lastState;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lastState = state;
    onStateChanged(state);
  }
}
