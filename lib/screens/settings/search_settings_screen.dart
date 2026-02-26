import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/settings_provider.dart';
import '../../theme/colors.dart';

class SearchSettingsScreen extends ConsumerStatefulWidget {
  const SearchSettingsScreen({super.key});

  @override
  ConsumerState<SearchSettingsScreen> createState() =>
      _SearchSettingsScreenState();
}

class _SearchSettingsScreenState extends ConsumerState<SearchSettingsScreen> {
  final _braveKeyController = TextEditingController();
  bool _obscureKey = true;
  bool _braveEnabled = false;
  bool _saving = false;
  String? _statusMessage;
  bool _statusIsError = false;

  @override
  void initState() {
    super.initState();
    _loadBraveKey();
  }

  Future<void> _loadBraveKey() async {
    final key = await ref.read(settingsProvider.notifier).getBraveApiKey();
    if (key != null && key.isNotEmpty && mounted) {
      setState(() {
        _braveKeyController.text = key;
        _braveEnabled = true;
      });
    }
  }

  Future<void> _save() async {
    if (_saving) return;

    final key = _braveKeyController.text.trim();

    if (_braveEnabled && key.isEmpty) {
      setState(() {
        _statusMessage = 'API key is required when Brave is enabled';
        _statusIsError = true;
      });
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _statusMessage = null);
      });
      return;
    }

    setState(() {
      _saving = true;
      _statusMessage = null;
    });

    try {
      if (_braveEnabled) {
        await ref.read(settingsProvider.notifier).setBraveApiKey(key);
        setState(() {
          _statusMessage = 'Brave Search key saved';
          _statusIsError = false;
        });
      } else {
        await ref.read(settingsProvider.notifier).setBraveApiKey('');
        setState(() {
          _statusMessage = 'Brave Search disabled — using DuckDuckGo';
          _statusIsError = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _statusMessage = null);
        });
      }
    }
  }

  @override
  void dispose() {
    _braveKeyController.dispose();
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
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Search',
                          style: TextStyle(
                            color: FerriColors.text,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Web search provider for Ferri',
                          style: TextStyle(
                            color: FerriColors.textFaint,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                children: [
                  // ─── BRAVE SEARCH ───
                  _label('BRAVE SEARCH'),
                  const SizedBox(height: 8),
                  _buildBraveToggle(settings),
                  const SizedBox(height: 12),

                  if (_braveEnabled) ...[
                    // API key field
                    _label('API KEY'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _braveKeyController,
                      obscureText: _obscureKey,
                      style: const TextStyle(
                        color: FerriColors.text,
                        fontSize: 14,
                        fontFamily: 'monospace',
                      ),
                      decoration:
                          _inputDecoration('Enter your Brave Search API key')
                              .copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureKey
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: FerriColors.textFaint,
                            size: 20,
                          ),
                          onPressed: () =>
                              setState(() => _obscureKey = !_obscureKey),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildGetKeyLink(),
                    const SizedBox(height: 12),
                  ],

                  // Save button
                  _buildSaveButton(),
                  if (_statusMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _statusMessage!,
                      style: TextStyle(
                        color: _statusIsError
                            ? FerriColors.danger
                            : FerriColors.success,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),

                  // ─── COMING SOON ───
                  _label('COMING SOON'),
                  const SizedBox(height: 8),
                  _buildComingSoonTile(
                    icon: Icons.auto_awesome,
                    title: 'Perplexity',
                    description: 'AI-powered search with citations',
                  ),
                  const SizedBox(height: 8),
                  _buildComingSoonTile(
                    icon: Icons.search,
                    title: 'Google Search',
                    description: 'Google Custom Search API',
                  ),
                  const SizedBox(height: 12),
                  _buildInfoNote(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBraveToggle(AppSettings settings) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: FerriColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FerriColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield_outlined,
              size: 18, color: Color(0xFFFF6B2C)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enable Brave Search',
                  style: TextStyle(
                    color: FerriColors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  settings.hasBraveApiKey
                      ? 'Configured — Brave is primary search'
                      : 'Requires API key from Brave',
                  style: const TextStyle(
                    color: FerriColors.textFaint,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: _braveEnabled,
            activeTrackColor: const Color(0xFFFF6B2C),
            onChanged: (v) => setState(() => _braveEnabled = v),
          ),
        ],
      ),
    );
  }

  Widget _buildGetKeyLink() {
    return GestureDetector(
      onTap: () {
        Clipboard.setData(
          const ClipboardData(
              text: 'https://api-dashboard.search.brave.com'),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('URL copied to clipboard'),
            duration: Duration(seconds: 2),
          ),
        );
      },
      child: const Row(
        children: [
          Icon(Icons.open_in_new, size: 14, color: FerriColors.textSoft),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              'Get a free key at api-dashboard.search.brave.com',
              style: TextStyle(
                color: FerriColors.textSoft,
                fontSize: 12,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return GestureDetector(
      onTap: _saving ? null : _save,
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
                'Save',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Widget _buildComingSoonTile({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Opacity(
      opacity: 0.45,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: FerriColors.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: FerriColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: FerriColors.textFaint),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: FerriColors.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    description,
                    style: const TextStyle(
                      color: FerriColors.textFaint,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: FerriColors.bgElevated,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Soon',
                style: TextStyle(
                  color: FerriColors.textFaint,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
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
          Icon(Icons.info_outline, size: 16, color: FerriColors.textFaint),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'More search providers will be added in future updates. '
              'DuckDuckGo is used as fallback when no provider is configured.',
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
