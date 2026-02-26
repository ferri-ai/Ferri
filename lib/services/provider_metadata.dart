import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class ProviderModel {
  final String id;
  final String label;

  const ProviderModel({required this.id, required this.label});

  factory ProviderModel.fromJson(Map<String, dynamic> json) {
    return ProviderModel(
      id: json['id'] as String,
      label: json['label'] as String,
    );
  }
}

class ProviderInfo {
  final String id;
  final String displayName;
  final String tagline;
  final String keyUrl;
  final String keyPrefix;
  final String baseUrl;
  final String recommendedModel;
  final bool requiresKey;
  final List<ProviderModel> models;

  const ProviderInfo({
    required this.id,
    required this.displayName,
    required this.tagline,
    required this.keyUrl,
    required this.keyPrefix,
    required this.baseUrl,
    required this.recommendedModel,
    required this.requiresKey,
    required this.models,
  });

  factory ProviderInfo.fromJson(String id, Map<String, dynamic> json) {
    final modelsList = (json['models'] as List<dynamic>?)
            ?.map((m) => ProviderModel.fromJson(m as Map<String, dynamic>))
            .toList() ??
        [];
    return ProviderInfo(
      id: id,
      displayName: json['display_name'] as String,
      tagline: json['tagline'] as String,
      keyUrl: (json['key_url'] as String?) ?? '',
      keyPrefix: (json['key_prefix'] as String?) ?? '',
      baseUrl: (json['base_url'] as String?) ?? '',
      recommendedModel: json['recommended_model'] as String,
      requiresKey: (json['requires_key'] as bool?) ?? true,
      models: modelsList,
    );
  }
}

class ProviderMetadata {
  final String version;
  final List<ProviderInfo> providers;

  const ProviderMetadata({required this.version, required this.providers});

  ProviderInfo? getProvider(String id) {
    try {
      return providers.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }
}

/// Loads provider metadata from bundled asset.
Future<ProviderMetadata> loadProviderMetadata() async {
  final jsonStr =
      await rootBundle.loadString('assets/provider-metadata.json');
  final data = jsonDecode(jsonStr) as Map<String, dynamic>;
  final providersMap = data['providers'] as Map<String, dynamic>;

  final providers = providersMap.entries
      .map((e) => ProviderInfo.fromJson(e.key, e.value as Map<String, dynamic>))
      .toList();

  return ProviderMetadata(
    version: data['version'] as String,
    providers: providers,
  );
}
