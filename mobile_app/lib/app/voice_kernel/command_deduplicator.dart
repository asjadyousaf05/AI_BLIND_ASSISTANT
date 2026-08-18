/// Bounded cache for command deduplication.
///
/// Each accepted recognition ID is stored with its consumption timestamp.
/// The cache is bounded in size and entries automatically expire.
class CommandDeduplicator {
  CommandDeduplicator({
    this.maxEntries = 50,
    this.entryTtl = const Duration(seconds: 30),
  });

  final int maxEntries;
  final Duration entryTtl;

  final Map<String, DateTime> _consumed = {};

  /// Returns true if this recognition ID has already been consumed.
  bool isDuplicate(String recognitionId) {
    _pruneExpired();
    return _consumed.containsKey(recognitionId);
  }

  /// Marks a recognition ID as consumed. Returns false if already consumed.
  bool consume(String recognitionId) {
    _pruneExpired();
    if (_consumed.containsKey(recognitionId)) return false;
    _consumed[recognitionId] = DateTime.now();
    // Evict oldest if over capacity.
    while (_consumed.length > maxEntries) {
      _consumed.remove(_consumed.keys.first);
    }
    return true;
  }

  /// Clears all consumed entries (e.g. on context change).
  void clear() => _consumed.clear();

  /// Number of currently tracked entries.
  int get length => _consumed.length;

  void _pruneExpired() {
    final now = DateTime.now();
    _consumed.removeWhere(
      (_, timestamp) => now.difference(timestamp) > entryTtl,
    );
  }
}
