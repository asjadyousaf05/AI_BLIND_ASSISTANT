import '../entities/protocol_envelope.dart';
import '../enums/wearable_transport_status.dart';

typedef WearableEnvelopeSigner =
    ProtocolEnvelope Function(ProtocolEnvelope envelope);
typedef WearableEnvelopeVerifier = bool Function(ProtocolEnvelope envelope);

abstract interface class WearableTransport {
  WearableTransportStatus get status;

  Stream<WearableTransportStatus> get statuses;

  Stream<ProtocolEnvelope> get messages;

  Future<void> connect(Uri endpoint);

  /// Enables per-envelope integrity checks after a credential is available.
  /// The transport then signs every outbound envelope (including heartbeats)
  /// and rejects any inbound envelope that does not verify.
  void configureAuthentication({
    required WearableEnvelopeSigner signer,
    required WearableEnvelopeVerifier verifier,
  });

  void clearAuthentication();

  /// Sends [message] and, by default, resolves only after a correlated
  /// acknowledgement arrives. Returns `null` when no acknowledgement was
  /// requested.
  Future<ProtocolEnvelope?> send(
    ProtocolEnvelope message, {
    bool requireAcknowledgement = true,
    Duration? acknowledgementTimeout,
  });

  Future<void> disconnect({String reason = 'client_disconnect'});

  Future<void> dispose();
}
