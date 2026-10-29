import '../entities/smart_ai_cloud_configuration.dart';

abstract interface class SmartAiCloudConfigurationRepository {
  Future<SmartAiCloudConfiguration?> load();
  Future<void> save(SmartAiCloudConfiguration configuration);
  Future<void> delete();
}
