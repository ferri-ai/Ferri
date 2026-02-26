import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/memory_provider.dart';
import '../../theme/colors.dart';

class MemoryScreen extends ConsumerStatefulWidget {
  const MemoryScreen({super.key});

  @override
  ConsumerState<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends ConsumerState<MemoryScreen> {
  late TextEditingController _controller;
  bool _dirty = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    // Reload fresh content when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(memoryProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    ref.read(memoryProvider.notifier).saveRaw(_controller.text);
    setState(() => _dirty = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Saved'),
        duration: Duration(seconds: 1),
        backgroundColor: FerriColors.bgElevated,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final memState = ref.watch(memoryProvider);

    // Sync controller text once after load completes
    if (!memState.loading && !_initialized) {
      _controller.text = memState.rawContent;
      _initialized = true;
    }

    return Scaffold(
      backgroundColor: FerriColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back,
                        color: FerriColors.text, size: 22),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Text(
                      'Memory',
                      style: TextStyle(
                        color: FerriColors.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (_dirty)
                    TextButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.save,
                          color: FerriColors.primary, size: 18),
                      label: const Text(
                        'Save',
                        style: TextStyle(
                          color: FerriColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Editor
            Expanded(
              child: memState.loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: FerriColors.primary),
                    )
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: TextField(
                        controller: _controller,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        style: const TextStyle(
                          color: FerriColors.text,
                          fontSize: 13,
                          fontFamily: 'monospace',
                          height: 1.5,
                        ),
                        decoration: InputDecoration(
                          hintText: 'No memories yet. Ferri will add entries here as you chat.',
                          hintStyle: const TextStyle(
                              color: FerriColors.textFaint, fontSize: 13),
                          filled: true,
                          fillColor: FerriColors.bgCard,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: FerriColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: FerriColors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: FerriColors.borderFocus),
                          ),
                          contentPadding: const EdgeInsets.all(14),
                        ),
                        onChanged: (_) {
                          if (!_dirty) setState(() => _dirty = true);
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
