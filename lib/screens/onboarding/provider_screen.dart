import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/settings_provider.dart';
import '../../services/api_validator.dart';
import '../../services/provider_metadata.dart';
import '../../theme/colors.dart';

class ProviderScreen extends ConsumerStatefulWidget {
  final VoidCallback onNext;

  const ProviderScreen({super.key, required this.onNext});

  @override
  ConsumerState<ProviderScreen> createState() => _ProviderScreenState();
}

class _ProviderScreenState extends ConsumerState<ProviderScreen> {
  ProviderMetadata? _metadata;
  String _selectedProvider = 'openrouter';
  bool _isCustom = false;
  final _apiKeyController = TextEditingController();
  final _modelController = TextEditingController();
  final _baseUrlController = TextEditingController();
  bool _saving = false;
  String? _apiKeyError;
  bool _customModelMode = false;

  @override
  void initState() {
    super.initState();
    _loadMetadata();
  }

  Future<void> _loadMetadata() async {
    final metadata = await loadProviderMetadata();
    if (!mounted) return;
    setState(() {
      _metadata = metadata;
      _modelController.text =
          metadata.providers.first.recommendedModel;
    });
  }

  ProviderInfo? get _currentProvider {
    if (_isCustom) return null;
    return _metadata?.getProvider(_selectedProvider);
  }

  void _selectProvider(String id) {
    final provider = _metadata?.getProvider(id);
    if (provider == null) return;
    setState(() {
      _selectedProvider = id;
      _isCustom = false;
      _modelController.text = provider.recommendedModel;
      _apiKeyError = null;
      _customModelMode = false;
    });
  }

  void _selectCustom() {
    setState(() {
      _isCustom = true;
      _selectedProvider = 'custom';
      _modelController.text = '';
      _apiKeyError = null;
      _customModelMode = false;
    });
  }

  Future<void> _continue() async {
    if (_saving) return;

    final apiKey = _apiKeyController.text.trim();
    final model = _modelController.text.trim();
    final baseUrl = _baseUrlController.text.trim();

    if (_isCustom) {
      if (baseUrl.isEmpty) {
        setState(() => _apiKeyError = 'Base URL is required');
        return;
      }
      if (model.isEmpty) {
        setState(() => _apiKeyError = 'Model name is required');
        return;
      }
    } else {
      final provider = _currentProvider;
      if (provider != null && provider.requiresKey && apiKey.isEmpty) {
        setState(() => _apiKeyError = 'API key is required');
        return;
      }
    }

    setState(() {
      _saving = true;
      _apiKeyError = null;
    });

    try {
      final providerStr = _isCustom ? 'custom' : _selectedProvider;
      final needsKey = _isCustom ? apiKey.isNotEmpty : (_currentProvider?.requiresKey ?? true);

      if (needsKey && apiKey.isNotEmpty) {
        final result = await validateApiKey(
          provider: providerStr,
          apiKey: apiKey,
          model: model,
          apiBase: _isCustom ? baseUrl : null,
        );
        if (!mounted) return;

        if (!result.success) {
          setState(() => _apiKeyError = result.error ?? 'Invalid API key');
          return;
        }
      }

      if (!mounted) return;
      final notifier = ref.read(settingsProvider.notifier);

      if (_isCustom) {
        await notifier.setProvider('custom');
        await notifier.setApiBase(baseUrl);
      } else {
        await notifier.setProvider(_selectedProvider);
        await notifier.setApiBase('');
      }
      await notifier.setModel(model);
      if (apiKey.isNotEmpty) {
        await notifier.setApiKey(apiKey);
      }

      if (mounted) widget.onNext();
    } finally {
      if (mounted) setState(() => _saving = false);
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
    if (_metadata == null) {
      return const Center(
        child: CircularProgressIndicator(color: FerriColors.primary),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 48),
            const Text(
              'Connect an LLM',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: FerriColors.text,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Any provider. Your keys. Your data.',
              style: TextStyle(
                fontSize: 15,
                color: FerriColors.textSoft,
              ),
            ),
            const SizedBox(height: 28),

            Expanded(
              child: ListView(
                children: [
                  // Provider grid — 2 columns
                  _buildProviderGrid(),

                  const SizedBox(height: 16),

                  // Config fields based on selection
                  if (_isCustom) ..._buildCustomFields() else ..._buildProviderFields(),
                ],
              ),
            ),

            // Continue button
            _buildContinueButton(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderGrid() {
    final providers = _metadata!.providers;
    final List<Widget> rows = [];

    for (int i = 0; i < providers.length; i += 2) {
      final left = providers[i];
      final right = i + 1 < providers.length ? providers[i + 1] : null;
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Expanded(child: _providerCard(left.id, left.displayName, left.tagline)),
              const SizedBox(width: 10),
              Expanded(
                child: right != null
                    ? _providerCard(right.id, right.displayName, right.tagline)
                    : _customCard(),
              ),
            ],
          ),
        ),
      );
    }

    // If provider count is even, add custom card on its own row
    if (providers.length % 2 == 0) {
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Expanded(child: _customCard()),
              const SizedBox(width: 10),
              const Expanded(child: SizedBox()),
            ],
          ),
        ),
      );
    }

    return Column(children: rows);
  }

  Widget _providerCard(String id, String name, String tagline) {
    final selected = !_isCustom && id == _selectedProvider;
    return GestureDetector(
      onTap: () => _selectProvider(id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: FerriColors.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? FerriColors.primary : FerriColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected ? FerriColors.primary : FerriColors.text,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              tagline,
              style: const TextStyle(
                fontSize: 11,
                color: FerriColors.textSoft,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _customCard() {
    final selected = _isCustom;
    return GestureDetector(
      onTap: _selectCustom,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: FerriColors.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? FerriColors.primary : FerriColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Custom Endpoint',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected ? FerriColors.primary : FerriColors.text,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'Any OpenAI-compatible URL',
              style: TextStyle(
                fontSize: 11,
                color: FerriColors.textSoft,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildProviderFields() {
    final provider = _currentProvider;
    if (provider == null) return [];

    return [
      // API key
      if (provider.requiresKey) ...[
        _sectionLabel('API Key'),
        const SizedBox(height: 8),
        _textField(
          controller: _apiKeyController,
          hint: '${provider.keyPrefix}...',
          obscure: true,
          onChanged: (_) {
            if (_apiKeyError != null) setState(() => _apiKeyError = null);
          },
        ),
        if (_apiKeyError != null) ...[
          const SizedBox(height: 6),
          Text(
            _apiKeyError!,
            style: const TextStyle(color: FerriColors.danger, fontSize: 12),
          ),
        ],
        const SizedBox(height: 20),
      ],

      // Model
      _sectionLabel('Model'),
      const SizedBox(height: 8),
      _buildModelSelector(provider),
    ];
  }

  List<Widget> _buildCustomFields() {
    return [
      _sectionLabel('Base URL'),
      const SizedBox(height: 8),
      _textField(
        controller: _baseUrlController,
        hint: 'https://your-server:11434/v1',
        onChanged: (_) {
          if (_apiKeyError != null) setState(() => _apiKeyError = null);
        },
      ),
      const SizedBox(height: 16),

      _sectionLabel('API Key (optional)'),
      const SizedBox(height: 8),
      _textField(
        controller: _apiKeyController,
        hint: 'sk-...',
        obscure: true,
        onChanged: (_) {
          if (_apiKeyError != null) setState(() => _apiKeyError = null);
        },
      ),
      if (_apiKeyError != null) ...[
        const SizedBox(height: 6),
        Text(
          _apiKeyError!,
          style: const TextStyle(color: FerriColors.danger, fontSize: 12),
        ),
      ],
      const SizedBox(height: 16),

      _sectionLabel('Model'),
      const SizedBox(height: 8),
      _textField(
        controller: _modelController,
        hint: 'llama3:8b',
      ),
    ];
  }

  Widget _buildModelSelector(ProviderInfo provider) {
    if (_customModelMode || provider.models.isEmpty) {
      return _textField(
        controller: _modelController,
        hint: 'Enter model ID',
        suffix: provider.models.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.list,
                    color: FerriColors.textFaint, size: 20),
                onPressed: () {
                  _modelController.text = provider.recommendedModel;
                  setState(() => _customModelMode = false);
                },
              )
            : null,
        onChanged: (_) {},
      );
    }

    final items = [
      ...provider.models.map((m) => {'value': m.id, 'label': m.label}),
      {'value': '_custom', 'label': 'Custom...'},
    ];

    final currentModel = _modelController.text;
    final hasValue = items.any((i) => i['value'] == currentModel);
    final effectiveValue = hasValue ? currentModel : items.first['value']!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: FerriColors.bgInput,
        borderRadius: BorderRadius.circular(10),
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
          fontFamily: 'monospace',
        ),
        icon: const Icon(Icons.expand_more, color: FerriColors.textFaint),
        items: items.map((item) {
          return DropdownMenuItem<String>(
            value: item['value'],
            child: Text(
              item['label']!,
              style: TextStyle(
                fontFamily:
                    item['value'] == '_custom' ? null : 'monospace',
              ),
            ),
          );
        }).toList(),
        onChanged: (v) {
          if (v == '_custom') {
            _modelController.text = '';
            setState(() => _customModelMode = true);
          } else if (v != null) {
            _modelController.text = v;
            setState(() {});
          }
        },
      ),
    );
  }

  Widget _buildContinueButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [FerriColors.primary, FerriColors.primaryDark],
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: ElevatedButton(
          onPressed: _saving ? null : _continue,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
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
                  'Continue',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: FerriColors.textSoft,
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    bool obscure = false,
    Widget? suffix,
    void Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      onChanged: onChanged,
      style: const TextStyle(
        fontSize: 14,
        color: FerriColors.text,
        fontFamily: 'monospace',
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          color: FerriColors.textFaint,
          fontFamily: 'monospace',
        ),
        filled: true,
        fillColor: FerriColors.bgInput,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: FerriColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: FerriColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: FerriColors.borderFocus),
        ),
        suffixIcon: suffix,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}
