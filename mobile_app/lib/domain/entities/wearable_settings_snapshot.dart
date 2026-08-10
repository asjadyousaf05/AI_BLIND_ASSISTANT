enum WearableSettingsSource {
  phone,
  pi;

  static WearableSettingsSource fromWireName(String value) {
    return values.firstWhere(
      (source) => source.name == value,
      orElse: () =>
          throw FormatException('Unsupported settings source: $value'),
    );
  }
}

class WearableSettingsVersion {
  const WearableSettingsVersion({
    required this.revision,
    required this.updatedAt,
    required this.source,
    required this.sourceId,
  });

  final int revision;
  final DateTime updatedAt;
  final WearableSettingsSource source;
  final String sourceId;

  Map<String, Object?> toPayload() => {
    'revision': revision,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'source': source.name,
    'sourceId': sourceId,
  };

  static WearableSettingsVersion fromPayload(Map<String, Object?> payload) {
    final revision = payload['revision'];
    final updatedAt = payload['updatedAt'];
    final source = payload['source'];
    final sourceId = payload['sourceId'];
    if (revision is! int ||
        revision < 0 ||
        updatedAt is! String ||
        source is! String ||
        sourceId is! String ||
        sourceId.isEmpty) {
      throw const FormatException('Invalid wearable settings version');
    }
    return WearableSettingsVersion(
      revision: revision,
      updatedAt: DateTime.parse(updatedAt).toUtc(),
      source: WearableSettingsSource.fromWireName(source),
      sourceId: sourceId,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is WearableSettingsVersion &&
        other.revision == revision &&
        other.updatedAt == updatedAt &&
        other.source == source &&
        other.sourceId == sourceId;
  }

  @override
  int get hashCode => Object.hash(revision, updatedAt, source, sourceId);
}

class WearableSettingsSnapshot {
  const WearableSettingsSnapshot({
    required this.version,
    required this.confidenceThreshold,
    required this.announcementCooldownSeconds,
    required this.speechEnabled,
    required this.vibrationEnabled,
    required this.assistanceMode,
  });

  final WearableSettingsVersion version;
  final double confidenceThreshold;
  final int announcementCooldownSeconds;
  final bool speechEnabled;
  final bool vibrationEnabled;
  final String assistanceMode;

  Map<String, Object?> toPayload() => {
    'version': version.toPayload(),
    'confidenceThreshold': confidenceThreshold,
    'announcementCooldownSeconds': announcementCooldownSeconds,
    'speechEnabled': speechEnabled,
    'vibrationEnabled': vibrationEnabled,
    'assistanceMode': assistanceMode,
  };

  static WearableSettingsSnapshot fromPayload(Map<String, Object?> payload) {
    final version = payload['version'];
    final confidence = payload['confidenceThreshold'];
    final cooldown = payload['announcementCooldownSeconds'];
    final speechEnabled = payload['speechEnabled'];
    final vibrationEnabled = payload['vibrationEnabled'];
    final assistanceMode = payload['assistanceMode'];
    if (version is! Map ||
        confidence is! num ||
        !confidence.isFinite ||
        confidence < 0.05 ||
        confidence > 0.95 ||
        cooldown is! int ||
        cooldown < 1 ||
        cooldown > 300 ||
        speechEnabled is! bool ||
        vibrationEnabled is! bool ||
        assistanceMode is! String ||
        assistanceMode.isEmpty) {
      throw const FormatException('Invalid wearable settings snapshot');
    }
    return WearableSettingsSnapshot(
      version: WearableSettingsVersion.fromPayload(
        version.cast<String, Object?>(),
      ),
      confidenceThreshold: confidence.toDouble(),
      announcementCooldownSeconds: cooldown,
      speechEnabled: speechEnabled,
      vibrationEnabled: vibrationEnabled,
      assistanceMode: assistanceMode,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is WearableSettingsSnapshot &&
        other.version == version &&
        other.confidenceThreshold == confidenceThreshold &&
        other.announcementCooldownSeconds == announcementCooldownSeconds &&
        other.speechEnabled == speechEnabled &&
        other.vibrationEnabled == vibrationEnabled &&
        other.assistanceMode == assistanceMode;
  }

  @override
  int get hashCode => Object.hash(
    version,
    confidenceThreshold,
    announcementCooldownSeconds,
    speechEnabled,
    vibrationEnabled,
    assistanceMode,
  );
}
