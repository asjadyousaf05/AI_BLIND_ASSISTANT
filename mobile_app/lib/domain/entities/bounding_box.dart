/// Normalized bounding box with coordinates in [0, 1] range.
class BoundingBox {
  const BoundingBox({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final double left;
  final double top;
  final double right;
  final double bottom;

  double get width => (right - left).clamp(0.0, 1.0);
  double get height => (bottom - top).clamp(0.0, 1.0);
  double get area => width * height;
  double get centerX => (left + right) / 2;
  double get centerY => (top + bottom) / 2;

  bool get isValid =>
      left >= 0 &&
      top >= 0 &&
      right <= 1 &&
      bottom <= 1 &&
      width > 0 &&
      height > 0;

  double iou(BoundingBox other) {
    final intersectLeft = left > other.left ? left : other.left;
    final intersectTop = top > other.top ? top : other.top;
    final intersectRight = right < other.right ? right : other.right;
    final intersectBottom = bottom < other.bottom ? bottom : other.bottom;

    if (intersectLeft >= intersectRight || intersectTop >= intersectBottom) {
      return 0.0;
    }

    final intersectArea =
        (intersectRight - intersectLeft) * (intersectBottom - intersectTop);
    final unionArea = area + other.area - intersectArea;

    if (unionArea <= 0) return 0.0;
    return intersectArea / unionArea;
  }

  @override
  bool operator ==(Object other) {
    return other is BoundingBox &&
        other.left == left &&
        other.top == top &&
        other.right == right &&
        other.bottom == bottom;
  }

  @override
  int get hashCode => Object.hash(left, top, right, bottom);

  @override
  String toString() =>
      'BoundingBox(l:${left.toStringAsFixed(3)}, t:${top.toStringAsFixed(3)}, r:${right.toStringAsFixed(3)}, b:${bottom.toStringAsFixed(3)})';
}
