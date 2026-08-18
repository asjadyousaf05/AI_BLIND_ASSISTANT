import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/repositories/wearable_credential_repository.dart';
import '../domain/repositories/wearable_repository.dart';
import '../domain/services/wearable_discovery_service.dart';
import '../domain/services/wearable_transport.dart';
import '../infrastructure/networking/method_channel_wearable_credential_repository.dart';
import '../infrastructure/networking/method_channel_wearable_discovery_service.dart';
import '../infrastructure/networking/web_socket_wearable_repository.dart';
import '../infrastructure/networking/web_socket_wearable_transport.dart';

final wearableDiscoveryServiceProvider = Provider<WearableDiscoveryService>((
  ref,
) {
  return MethodChannelWearableDiscoveryService();
});

final wearableCredentialRepositoryProvider =
    Provider<WearableCredentialRepository>((ref) {
      return MethodChannelWearableCredentialRepository();
    });

final wearableTransportProvider = Provider<WearableTransport>((ref) {
  return WebSocketWearableTransport();
});

final wearableRepositoryProvider = Provider<WearableRepository>((ref) {
  final repository = WebSocketWearableRepository(
    discoveryService: ref.watch(wearableDiscoveryServiceProvider),
    credentialRepository: ref.watch(wearableCredentialRepositoryProvider),
    transport: ref.watch(wearableTransportProvider),
  );
  ref.onDispose(() => unawaited(repository.dispose()));
  return repository;
});

final wearableClientIdProvider = FutureProvider<String>((ref) {
  return ref.watch(wearableCredentialRepositoryProvider).getOrCreateClientId();
});
