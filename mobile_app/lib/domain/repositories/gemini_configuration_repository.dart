import '../entities/gemini_configuration.dart';

/// Separate encrypted storage; removing Gemini never unpairs the laptop/Pi.
abstract interface class GeminiConfigurationRepository {
  Future<GeminiConfiguration?> load();
  Future<void> save(GeminiConfiguration configuration);
  Future<void> delete();
}
