import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'engine_provider.dart';

class SkillInfo {
  final String name;
  final String description;
  final String source; // "workspace", "global", "builtin"
  final String path;

  const SkillInfo({
    required this.name,
    required this.description,
    required this.source,
    required this.path,
  });

  factory SkillInfo.fromJson(Map<String, dynamic> json) {
    return SkillInfo(
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      source: json['source'] as String? ?? 'workspace',
      path: json['path'] as String? ?? '',
    );
  }

  bool get isBundled => source == 'workspace';
  bool get isUserCreated => source == 'workspace';
}

class SkillsState {
  final List<SkillInfo> skills;
  final bool loading;
  final String? error;

  const SkillsState({
    this.skills = const [],
    this.loading = false,
    this.error,
  });

  SkillsState copyWith({
    List<SkillInfo>? skills,
    bool? loading,
    String? error,
  }) {
    return SkillsState(
      skills: skills ?? this.skills,
      loading: loading ?? this.loading,
      error: error,
    );
  }
}

class SkillsNotifier extends StateNotifier<SkillsState> {
  final Ref _ref;

  SkillsNotifier(this._ref) : super(const SkillsState());

  EngineNotifier get _engine => _ref.read(engineProvider.notifier);

  /// Load skills from the Go engine.
  void refresh() {
    state = state.copyWith(loading: true, error: null);
    final result = _engine.listSkills();

    if (result.containsKey('error')) {
      state = state.copyWith(
        loading: false,
        error: result['error'] as String?,
      );
      return;
    }

    final rawList = result['skills'] as List<dynamic>? ?? [];
    final skills = rawList
        .map((e) => SkillInfo.fromJson(e as Map<String, dynamic>))
        .toList();

    state = state.copyWith(skills: skills, loading: false);
    debugPrint('[SkillsNotifier] loaded ${skills.length} skills');
  }

  /// Install a skill from GitHub (e.g. "user/repo-name").
  Future<bool> install(String repo) async {
    final result = _engine.installSkill(repo);
    if (result['success'] == true) {
      refresh();
      return true;
    }
    state = state.copyWith(error: result['error'] as String?);
    return false;
  }

  /// Uninstall a skill by name.
  Future<bool> uninstall(String name) async {
    final result = _engine.uninstallSkill(name);
    if (result['success'] == true) {
      refresh();
      return true;
    }
    state = state.copyWith(error: result['error'] as String?);
    return false;
  }
}

final skillsProvider =
    StateNotifierProvider<SkillsNotifier, SkillsState>((ref) {
  return SkillsNotifier(ref);
});
