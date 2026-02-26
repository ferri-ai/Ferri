import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/settings_provider.dart';
import '../../services/api_validator.dart';
import '../../services/provider_metadata.dart';
import '../../theme/colors.dart';

class LlmConfigScreen extends ConsumerStatefulWidget {
  const LlmConfigScreen({super.key});

  @override
  ConsumerState<LlmConfigScreen> createState() => _LlmConfigScreenState();
}

class _LlmConfigScreenState extends ConsumerState<LlmConfigScreen> {
  final _apiKeyController = TextEditingController();
  final _modelController = TextEditingController();
  final _baseUrlController = TextEditingController();
  bool _obscureKey = true;
  bool _saving = false;
  bool _customModelMode = false;
  String? _savedMessage;
  ProviderMetadata? _metadata;

  @override
  void initState() {
    super.initState();
    _loadApiKey();
    _loadMetadata();
    final settings = ref.read(settingsProvider);
    _modelController.text = settings.model;
    _baseUrlController.text = settings.apiBase;
  }

  Future<void> _loadMetadata() async {
    final metadata = await loadProviderMetadata();
    if (mounted) setState(() => _metadata = metadata);
  }

  Future<void> _loadApiKey() async {
    final key = await ref.read(settingsProvider.notifier).getApiKey();
    if (key != null && mounted) {
      _apiKeyController.text = key;
    }
  }

  Future<void> _testAndSave() async {
    if (_saving) return;
    final settings = ref.read(settingsProvider);
    final key = _apiKeyController.text.trim();

    if (key.isEmpty && settings.provider != 'custom') {
      setState(() => _savedMessage = 'API key cleared');
      await ref.read(settingsProvider.notifier).setApiKey('');
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _savedMessage = null);
      });
      return;
    }

    setState(() {
      _saving = true;
      _savedMessage = null;
    });

    try {
      final result = await validateApiKey(
        provider: settings.provider,
        apiKey: key,
        model: _modelController.text.trim(),
        apiBase: settings.provider == 'custom'
            ? _baseUrlController.text.trim()
            : null,
      );

      if (!mounted) return;

      if (result.success) {
        await ref.read(settingsProvider.notifier).setApiKey(key);
        setState(() => _savedMessage = 'Connected — key saved');
      } else {
        setState(
            () => _savedMessage = result.error ?? 'Connection failed');
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _savedMessage = null);
        });
      }
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _modelController.dispose();
    _baseUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: FerriColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back,
                        color: FerriColors.text, size: 22),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'LLM Configuration',
                    style: TextStyle(
                      color: FerriColors.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _metadata == null
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: FerriColors.primary))
                  : ListView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                      children: [
                        // Provider
                        _label('PROVIDER'),
                        const SizedBox(height: 8),
                        _buildProviderDropdown(settings),
                        const SizedBox(height: 16),

                        // Base URL (custom only)
                        if (settings.provider == 'custom') ...[
                          _label('BASE URL'),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _baseUrlController,
                            style: const TextStyle(
                              color: FerriColors.text,
                              fontSize: 14,
                              fontFamily: 'monospace',
                            ),
                            decoration: _inputDecoration(
                                'https://your-server:11434/v1'),
                            onChanged: (v) {
                              final trimmed = v.trim();
                              ref
                                  .read(settingsProvider.notifier)
                                  .setApiBase(trimmed);
                            },
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Model
                        _label('MODEL'),
                        const SizedBox(height: 8),
                        _buildModelField(settings),
                        const SizedBox(height: 20),

                        // API Key
                        _label(settings.provider == 'custom'
                            ? 'API KEY (OPTIONAL)'
                            : 'API KEY'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _apiKeyController,
                          obscureText: _obscureKey,
                          style: const TextStyle(
                            color: FerriColors.text,
                            fontSize: 14,
                            fontFamily: 'monospace',
                          ),
                          decoration: _inputDecoration('Enter your API key')
                              .copyWith(
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureKey
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: FerriColors.textFaint,
                                size: 20,
                              ),
                              onPressed: () => setState(
                                  () => _obscureKey = !_obscureKey),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildSaveButton(),
                        if (_savedMessage != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _savedMessage!,
                            style: const TextStyle(
                              color: FerriColors.success,
                              fontSize: 13,
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),

                        // Info note
                        _buildInfoNote(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderDropdown(AppSettings settings) {
    final items = <Map<String, String>>[
      ...(_metadata?.providers ?? [])
          .map((p) => {'value': p.id, 'label': p.displayName}),
      {'value': 'custom', 'label': 'Custom Endpoint'},
    ];

    final hasValue = items.any((i) => i['value'] == settings.provider);
    final effectiveValue =
        hasValue ? settings.provider : items.first['value']!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: FerriColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FerriColors.border),
      ),
      child: DropdownButton<String>(
        value: effectiveValue,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        dropdownColor: FerriColors.bgCard,
        style: const TextStyle(
          color: FerriColors.text,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        icon: const Icon(Icons.expand_more, color: FerriColors.textFaint),
        items: items.map((item) {
          return DropdownMenuItem<String>(
            value: item['value'],
            child: Text(item['label']!),
          );
        }).toList(),
        onChanged: (v) {
          if (v == null) return;
          ref.read(settingsProvider.notifier).setProvider(v);

          if (v == 'custom') {
            ref.read(settingsProvider.notifier).setApiBase(
                _baseUrlController.text.trim());
            setState(() => _customModelMode = true);
          } else {
            final provider = _metadata?.getProvider(v);
            if (provider != null) {
              _modelController.text = provider.recommendedModel;
              ref
                  .read(settingsProvider.notifier)
                  .setModel(provider.recommendedModel);
              ref.read(settingsProvider.notifier).setApiBase('');
            }
            setState(() => _customModelMode = false);
          }
        },
      ),
    );
  }

  Widget _buildModelField(AppSettings settings) {
    if (settings.provider == 'custom') {
      return TextField(
        controller: _modelController,
        style: const TextStyle(
          color: FerriColors.text,
          fontSize: 14,
          fontFamily: 'monospace',
        ),
        decoration: _inputDecoration('model name (e.g. llama3:8b)'),
        onChanged: (v) {
          final trimmed = v.trim();
          if (trimmed.isNotEmpty) {
            ref.read(settingsProvider.notifier).setModel(trimmed);
          }
        },
      );
    }

    final provider = _metadata?.getProvider(settings.provider);
    final presets = provider?.models ?? [];
    final isPreset = presets.any((p) => p.id == settings.model);

    final showTextField = presets.isEmpty ||
        _customModelMode ||
        (!isPreset && settings.model.isNotEmpty);

    if (showTextField) {
      return TextField(
        controller: _modelController,
        style: const TextStyle(
          color: FerriColors.text,
          fontSize: 14,
          fontFamily: 'monospace',
        ),
        decoration:
            _inputDecoration('Enter model name (e.g. provider/model-name)')
                .copyWith(
          suffixIcon: presets.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.list,
                      color: FerriColors.textFaint),
                  tooltip: 'Choose from presets',
                  onPressed: () {
                    final model =
                        provider?.recommendedModel ?? presets.first.id;
                    _modelController.text = model;
                    ref
                        .read(settingsProvider.notifier)
                        .setModel(model);
                    setState(() => _customModelMode = false);
                  },
                )
              : null,
        ),
        onChanged: (v) {
          final trimmed = v.trim();
          if (trimmed.isNotEmpty) {
            ref.read(settingsProvider.notifier).setModel(trimmed);
          }
        },
        onSubmitted: (v) {
          final trimmed = v.trim();
          if (trimmed.isNotEmpty) {
            ref.read(settingsProvider.notifier).setModel(trimmed);
          }
        },
      );
    }

    final dropdownItems = [
      ...presets.map((m) => {'value': m.id, 'label': m.label}),
      {'value': '_custom', 'label': 'Custom...'},
    ];

    final hasValue =
        dropdownItems.any((i) => i['value'] == settings.model);
    final effectiveValue =
        hasValue ? settings.model : dropdownItems.first['value']!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: FerriColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FerriColors.border),
      ),
      child: DropdownButton<String>(
        value: effectiveValue,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        dropdownColor: FerriColors.bgCard,
        style: const TextStyle(
          color: FerriColors.text,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        icon: const Icon(Icons.expand_more, color: FerriColors.textFaint),
        items: dropdownItems.map((item) {
          return DropdownMenuItem<String>(
            value: item['value'],
            child: Text(item['label']!),
          );
        }).toList(),
        onChanged: (v) {
          if (v == '_custom') {
            _modelController.text = settings.model;
            setState(() => _customModelMode = true);
          } else if (v != null) {
            _modelController.text = v;
            ref.read(settingsProvider.notifier).setModel(v);
          }
        },
      ),
    );
  }

  Widget _buildSaveButton() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _saving ? null : _testAndSave,
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: FerriColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Test Connection',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoNote() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FerriColors.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: FerriColors.border),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline,
              size: 16, color: FerriColors.textFaint),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Changes take effect on the next conversation. '
              'Restart the app if the current session has errors.',
              style: TextStyle(
                color: FerriColors.textSoft,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: FerriColors.textFaint,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: FerriColors.textFaint),
      filled: true,
      fillColor: FerriColors.bgCard,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: FerriColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: FerriColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: FerriColors.borderFocus),
      ),
    );
  }
}
