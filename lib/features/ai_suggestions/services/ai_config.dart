/// Singleton configuration for the AI layer.
/// Call [AiConfig.init] once at startup (e.g., after reading from Settings).
class AiConfig {
  AiConfig._();

  static AiConfig? _instance;
  static AiConfig get instance => _instance ??= AiConfig._();

  String? _apiKey;
  String _model = 'claude-haiku-4-5-20251001';

  /// Whether the AI layer has been configured with an API key.
  bool get isConfigured => _apiKey != null && _apiKey!.isNotEmpty;

  String? get apiKey => _apiKey;
  String get model => _model;

  /// Call once after reading the API key from secure storage or settings.
  void init({required String apiKey, String? model}) {
    _apiKey = apiKey;
    if (model != null && model.isNotEmpty) {
      _model = model;
    }
  }

  /// Clear the API key (e.g., on sign-out).
  void clear() {
    _apiKey = null;
    _model = 'claude-haiku-4-5-20251001';
  }

  @override
  String toString() => 'AiConfig(model: $_model, configured: $isConfigured)';
}
