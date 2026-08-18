import '../../core/result/result.dart';
import '../entities/app_settings.dart';

abstract interface class SettingsRepository {
  Future<Result<AppSettings>> loadSettings();

  Future<Result<void>> saveSettings(AppSettings settings);
}
