import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

class MemoryEntry {
  final int lineIndex;
  final String text;

  const MemoryEntry({required this.lineIndex, required this.text});
}

class DailyNote {
  final String date;       // e.g. "2026-02-19"
  final String fileName;   // e.g. "20260219.md"
  final String filePath;

  DailyNote({required this.date, required this.fileName, required this.filePath});
}

class MemoryState {
  final List<MemoryEntry> entries;
  final String rawContent;
  final bool loading;
  final List<DailyNote> dailyNotes;

  const MemoryState({
    this.entries = const [],
    this.rawContent = '',
    this.loading = true,
    this.dailyNotes = const [],
  });

  MemoryState copyWith({
    List<MemoryEntry>? entries,
    String? rawContent,
    bool? loading,
    List<DailyNote>? dailyNotes,
  }) {
    return MemoryState(
      entries: entries ?? this.entries,
      rawContent: rawContent ?? this.rawContent,
      loading: loading ?? this.loading,
      dailyNotes: dailyNotes ?? this.dailyNotes,
    );
  }
}

class MemoryNotifier extends StateNotifier<MemoryState> {
  MemoryNotifier() : super(const MemoryState()) {
    load();
  }

  String? _memoryPath;

  Future<String> _getMemoryPath() async {
    if (_memoryPath != null) return _memoryPath!;
    final docsDir = await getApplicationDocumentsDirectory();
    _memoryPath = '${docsDir.path}/ferri_workspace/memory/MEMORY.md';
    return _memoryPath!;
  }

  Future<void> load() async {
    state = state.copyWith(loading: true);
    try {
      final path = await _getMemoryPath();
      final file = File(path);
      if (await file.exists()) {
        final content = await file.readAsString();
        final entries = _parseEntries(content);
        state = MemoryState(entries: entries, rawContent: content, loading: false);
      } else {
        state = const MemoryState(entries: [], rawContent: '', loading: false);
      }
    } catch (e) {
      state = const MemoryState(entries: [], rawContent: '', loading: false);
    }
    await _loadDailyNotes();
  }

  List<MemoryEntry> _parseEntries(String content) {
    final lines = content.split('\n');
    final entries = <MemoryEntry>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.startsWith('- ') && line.length > 2) {
        entries.add(MemoryEntry(lineIndex: i, text: line.substring(2)));
      }
    }
    return entries;
  }

  Future<void> _loadDailyNotes() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final memoryDir = Directory('${docsDir.path}/ferri_workspace/memory');
    if (!await memoryDir.exists()) return;

    final notes = <DailyNote>[];
    await for (final entity in memoryDir.list()) {
      if (entity is Directory) {
        final dirName = entity.path.split('/').last;
        if (RegExp(r'^\d{6}$').hasMatch(dirName)) {
          await for (final file in entity.list()) {
            if (file is File && file.path.endsWith('.md')) {
              final name = file.path.split('/').last;
              final match = RegExp(r'^(\d{4})(\d{2})(\d{2})\.md$').firstMatch(name);
              if (match != null) {
                final date = '${match.group(1)}-${match.group(2)}-${match.group(3)}';
                notes.add(DailyNote(date: date, fileName: name, filePath: file.path));
              }
            }
          }
        }
      }
    }
    notes.sort((a, b) => b.date.compareTo(a.date));
    state = state.copyWith(dailyNotes: notes);
  }

  Future<String> loadDailyNoteContent(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      return await file.readAsString();
    }
    return '';
  }

  Future<void> addEntry(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final path = await _getMemoryPath();
    final file = File(path);
    await file.parent.create(recursive: true);

    String content = '';
    if (await file.exists()) {
      content = await file.readAsString();
      if (content.isNotEmpty && !content.endsWith('\n')) {
        content += '\n';
      }
    }
    content += '- $trimmed\n';
    await file.writeAsString(content);
    await load();
  }

  Future<void> deleteEntry(int lineIndex) async {
    final path = await _getMemoryPath();
    final file = File(path);
    if (!await file.exists()) return;

    final lines = (await file.readAsString()).split('\n');
    if (lineIndex < 0 || lineIndex >= lines.length) return;

    lines.removeAt(lineIndex);
    await file.writeAsString(lines.join('\n'));
    await load();
  }

  Future<void> clearAll() async {
    final path = await _getMemoryPath();
    final file = File(path);
    if (await file.exists()) {
      await file.writeAsString('');
    }
    await load();
  }

  Future<void> saveRaw(String content) async {
    final path = await _getMemoryPath();
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
    await load();
  }
}

final memoryProvider = StateNotifierProvider<MemoryNotifier, MemoryState>((ref) {
  return MemoryNotifier();
});
