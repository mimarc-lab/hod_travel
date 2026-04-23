import 'package:shared_preferences/shared_preferences.dart';
import 'ai_config.dart';

/// Persists and loads the Anthropic API key via SharedPreferences.
/// On web this is localStorage; on desktop it's platform storage.
abstract class AiKeyStore {
  static const _keyApiKey = 'ai_anthropic_api_key';
  static const _keyModel = 'ai_model';

  /// Load the saved key (if any) and configure [AiConfig].
  /// Call once at app startup, after Supabase initialises.
  static Future<void> loadAndConfigure() async {
    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString(_keyApiKey) ?? '';
    var model = prefs.getString(_keyModel);

    // Migrate any incorrect model IDs stored from previous sessions
    // back to the correct Anthropic model identifier.
    const wrongModels = {
      'claude-3-5-haiku-20241022',
      'claude-3-haiku-20240307',
    };
    if (model != null && wrongModels.contains(model)) {
      model = 'claude-haiku-4-5-20251001';
      await prefs.setString(_keyModel, model);
    }

    if (apiKey.isNotEmpty) {
      AiConfig.instance.init(apiKey: apiKey, model: model);
    }
  }

  /// Persist and immediately apply the key.
  static Future<void> save({required String apiKey, String? model}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyApiKey, apiKey);
    if (model != null && model.isNotEmpty) {
      await prefs.setString(_keyModel, model);
    }
    AiConfig.instance.init(apiKey: apiKey, model: model);
  }

  /// Remove the stored key and clear [AiConfig].
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyApiKey);
    await prefs.remove(_keyModel);
    AiConfig.instance.clear();
  }

  /// Read the stored key without configuring (for UI display only).
  static Future<String?> read() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyApiKey);
  }
}
