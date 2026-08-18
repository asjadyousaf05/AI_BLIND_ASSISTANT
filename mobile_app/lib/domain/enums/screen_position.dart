enum ScreenPosition {
  left,
  centerLeft,
  center,
  centerRight,
  right;

  String get label {
    switch (this) {
      case ScreenPosition.left:
        return 'far left';
      case ScreenPosition.centerLeft:
        return 'left';
      case ScreenPosition.center:
        return 'ahead';
      case ScreenPosition.centerRight:
        return 'right';
      case ScreenPosition.right:
        return 'far right';
    }
  }

  bool get isCenter =>
      this == ScreenPosition.center ||
      this == ScreenPosition.centerLeft ||
      this == ScreenPosition.centerRight;
}
