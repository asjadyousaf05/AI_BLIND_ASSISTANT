import 'dart:collection';

/// Rejects replayed message IDs and stale/out-of-order source sequences while
/// keeping memory bounded. A new Pi boot/session should use a new source ID or
/// call [resetSource] before its sequence restarts.
class SequenceDeduplicator {
  SequenceDeduplicator({
    this.maximumSources = 32,
    this.maximumMessageIds = 1024,
  }) {
    if (maximumSources < 1 || maximumMessageIds < 1) {
      throw ArgumentError('Deduplicator bounds must be positive');
    }
  }

  final int maximumSources;
  final int maximumMessageIds;
  final LinkedHashMap<String, int> _highestSequenceBySource = LinkedHashMap();
  final LinkedHashSet<String> _messageIds = LinkedHashSet();

  bool accept({
    required String sourceId,
    required int sequence,
    required String messageId,
  }) {
    if (sourceId.isEmpty || sequence < 0 || messageId.isEmpty) {
      return false;
    }
    if (_messageIds.contains(messageId)) {
      return false;
    }
    final highest = _highestSequenceBySource[sourceId];
    if (highest != null && sequence <= highest) {
      return false;
    }

    _highestSequenceBySource.remove(sourceId);
    _highestSequenceBySource[sourceId] = sequence;
    while (_highestSequenceBySource.length > maximumSources) {
      _highestSequenceBySource.remove(_highestSequenceBySource.keys.first);
    }

    _messageIds.add(messageId);
    while (_messageIds.length > maximumMessageIds) {
      _messageIds.remove(_messageIds.first);
    }
    return true;
  }

  void resetSource(String sourceId) {
    _highestSequenceBySource.remove(sourceId);
  }

  void clear() {
    _highestSequenceBySource.clear();
    _messageIds.clear();
  }
}
