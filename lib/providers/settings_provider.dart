import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  final String provider;
  final String model;
  final String apiBase;
  final bool hasApiKey;
  final bool hasBraveApiKey;
  final bool onboardingComplete;
  final bool loaded;
  final bool toolApprovalRequired;
  final bool showVisualBuilder;
  final bool backgroundServiceEnabled;

  const AppSettings({
    this.provider = 'openrouter',
    this.model = 'anthropic/claude-sonnet-4.5',
    this.apiBase = '',
    this.hasApiKey = false,
    this.hasBraveApiKey = false,
    this.onboardingComplete = false,
    this.loaded = false,
    this.toolApprovalRequired = true,
    this.showVisualBuilder = false,
    this.backgroundServiceEnabled = false,
  });

  AppSettings copyWith({
    String? provider,
    String? model,
    String? apiBase,
    bool? hasApiKey,
    bool? hasBraveApiKey,
    bool? onboardingComplete,
    bool? loaded,
    bool? toolApprovalRequired,
    bool? showVisualBuilder,
    bool? backgroundServiceEnabled,
  }) {
    return AppSettings(
      provider: provider ?? this.provider,
      model: model ?? this.model,
      apiBase: apiBase ?? this.apiBase,
      hasApiKey: hasApiKey ?? this.hasApiKey,
      hasBraveApiKey: hasBraveApiKey ?? this.hasBraveApiKey,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      loaded: loaded ?? this.loaded,
      toolApprovalRequired: toolApprovalRequired ?? this.toolApprovalRequired,
      showVisualBuilder: showVisualBuilder ?? this.showVisualBuilder,
      backgroundServiceEnabled: backgroundServiceEnabled ?? this.backgroundServiceEnabled,
    );
  }
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  final FlutterSecureStorage _secureStorage;
  final SharedPreferences _prefs;

  SettingsNotifier(this._secureStorage, this._prefs)
      : super(const AppSettings()) {
    _load();
  }

  Future<void> _load() async {
    final apiKey = await _secureStorage.read(key: 'llm_api_key');
    final braveApiKey = await _secureStorage.read(key: 'brave_api_key');
    state = AppSettings(
      provider: _prefs.getString('llm_provider') ?? 'openrouter',
      model:
          _prefs.getString('llm_model') ?? 'anthropic/claude-sonnet-4.5',
      apiBase: _prefs.getString('llm_api_base') ?? '',
      hasApiKey: apiKey != null && apiKey.isNotEmpty,
      hasBraveApiKey: braveApiKey != null && braveApiKey.isNotEmpty,
      onboardingComplete: _prefs.getBool('onboarding_complete') ?? false,
      toolApprovalRequired:
          _prefs.getBool('tool_approval_required') ?? true,
      showVisualBuilder:
          _prefs.getBool('show_visual_builder') ?? false,
      backgroundServiceEnabled:
          _prefs.getBool('background_service_enabled') ?? false,
      loaded: true,
    );
  }

  Future<void> setProvider(String provider) async {
    await _prefs.setString('llm_provider', provider);
    state = state.copyWith(provider: provider);
  }

  Future<void> setModel(String model) async {
    await _prefs.setString('llm_model', model);
    state = state.copyWith(model: model);
  }

  Future<void> setApiBase(String apiBase) async {
    await _prefs.setString('llm_api_base', apiBase);
    state = state.copyWith(apiBase: apiBase);
  }

  Future<void> setApiKey(String apiKey) async {
    await _secureStorage.write(key: 'llm_api_key', value: apiKey);
    state = state.copyWith(hasApiKey: apiKey.isNotEmpty);
  }

  Future<String?> getApiKey() async {
    return await _secureStorage.read(key: 'llm_api_key');
  }

  Future<void> setBraveApiKey(String apiKey) async {
    await _secureStorage.write(key: 'brave_api_key', value: apiKey);
    state = state.copyWith(hasBraveApiKey: apiKey.isNotEmpty);
  }

  Future<String?> getBraveApiKey() async {
    return await _secureStorage.read(key: 'brave_api_key');
  }

  Future<void> setToolApprovalRequired(bool required_) async {
    await _prefs.setBool('tool_approval_required', required_);
    state = state.copyWith(toolApprovalRequired: required_);
  }

  Future<void> setShowVisualBuilder(bool v) async {
    await _prefs.setBool('show_visual_builder', v);
    state = state.copyWith(showVisualBuilder: v);
  }

  Future<void> setBackgroundServiceEnabled(bool v) async {
    await _prefs.setBool('background_service_enabled', v);
    state = state.copyWith(backgroundServiceEnabled: v);
  }

  Future<void> completeOnboarding() async {
    await _prefs.setBool('onboarding_complete', true);
    state = state.copyWith(onboardingComplete: true);
  }
}

/// Initialized in main() before runApp and passed via ProviderScope overrides.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be overridden in main()');
});

const _secureStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SettingsNotifier(_secureStorage, prefs);
});
