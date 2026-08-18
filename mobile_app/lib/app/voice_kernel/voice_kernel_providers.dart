import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/services/intelligent_intent_resolver.dart';
import 'command_circuit_breaker.dart';
import 'command_deduplicator.dart';
import 'command_executor.dart';
import 'vision_voice_kernel_v3.dart';
export 'vision_voice_kernel_v3.dart';

/// Provider for [IntelligentIntentResolver].
final intelligentIntentResolverProvider =
    Provider<IntelligentIntentResolver>((ref) {
  return IntelligentIntentResolver();
});

/// Provider for [CommandDeduplicator].
final commandDeduplicatorProvider = Provider<CommandDeduplicator>((ref) {
  return CommandDeduplicator();
});

/// Provider for [CommandCircuitBreaker].
final commandCircuitBreakerProvider =
    Provider<CommandCircuitBreaker>((ref) {
  return CommandCircuitBreaker();
});

/// Provider for [CommandExecutor].
final commandExecutorProvider = Provider<CommandExecutor>((ref) {
  return CommandExecutor(ref);
});

/// Central provider for [VisionVoiceKernelV3].
final visionVoiceKernelProvider =
    NotifierProvider<VisionVoiceKernelV3, VoiceKernelState>(
  VisionVoiceKernelV3.new,
);
