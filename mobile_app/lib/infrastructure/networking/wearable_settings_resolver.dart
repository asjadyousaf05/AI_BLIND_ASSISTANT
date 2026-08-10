import '../../domain/entities/wearable_settings_snapshot.dart';

class WearableSettingsResolver {
  const WearableSettingsResolver();

  /// Deterministic conflict order: higher revision, then later UTC timestamp,
  /// then phone ownership, then lexicographically greater source ID.
  WearableSettingsSnapshot resolve(
    WearableSettingsSnapshot first,
    WearableSettingsSnapshot second,
  ) {
    return compare(first.version, second.version) >= 0 ? first : second;
  }

  int compare(WearableSettingsVersion first, WearableSettingsVersion second) {
    final revision = first.revision.compareTo(second.revision);
    if (revision != 0) return revision;

    final timestamp = first.updatedAt.toUtc().compareTo(
      second.updatedAt.toUtc(),
    );
    if (timestamp != 0) return timestamp;

    final source = _priority(first.source).compareTo(_priority(second.source));
    if (source != 0) return source;

    return first.sourceId.compareTo(second.sourceId);
  }

  int _priority(WearableSettingsSource source) => switch (source) {
    WearableSettingsSource.phone => 2,
    WearableSettingsSource.pi => 1,
  };
}
