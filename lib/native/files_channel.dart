/// Files capability — provides tools for managing files in the app workspace
/// and picking files from the system file picker.
///
/// Channel: `ferri/files`
/// Kotlin handler: `FilesChannel.kt`
///
/// Tools:
/// - `files_list` — List files in the workspace directory
/// - `files_read` — Read a file's contents (text) or metadata (binary)
/// - `files_write` — Write text content to a file in the workspace
/// - `files_pick` — Open the system file picker to select a file
/// - `files_delete` — Delete a file from the workspace
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

/// Dart wrapper for file operations.
/// Workspace operations (list, read, write, delete) run directly in Dart.
/// File picking delegates to Kotlin via MethodChannel('ferri/files').
class FilesChannel {
  static const _channel = MethodChannel('ferri/files');
  FilesChannel._();

  static String? _workspacePath;

  static String _getWorkspace() {
    _workspacePath ??= '/data/user/0/com.ferri.ferri/files/workspace';
    final dir = Directory(_workspacePath!);
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return _workspacePath!;
  }

  static Future<String> handleToolCall(
      String toolName, Map<String, dynamic> params) async {
    debugPrint('[FilesChannel] handleToolCall: $toolName');
    switch (toolName) {
      case 'files_list':
        return _listFiles(params);
      case 'files_read':
        return _readFile(params);
      case 'files_write':
        return _writeFile(params);
      case 'files_pick':
        return _pickFile(params);
      case 'files_delete':
        return _deleteFile(params);
      default:
        throw PlatformException(
          code: 'UNKNOWN_TOOL',
          message: 'Unknown files tool: $toolName',
        );
    }
  }

  static Future<String> _listFiles(Map<String, dynamic> params) async {
    final subdir = params['directory'] as String? ?? '';
    final dirPath =
        subdir.isEmpty ? _getWorkspace() : path.join(_getWorkspace(), subdir);
    final dir = Directory(dirPath);

    if (!dir.existsSync()) {
      return jsonEncode(
          {'files': [], 'count': 0, 'error': 'Directory not found'});
    }

    final files = <Map<String, dynamic>>[];
    await for (final entity in dir.list()) {
      final stat = await entity.stat();
      files.add({
        'name': path.basename(entity.path),
        'path': entity.path,
        'size': stat.size,
        'modified': stat.modified.toIso8601String(),
        'type': entity is Directory ? 'directory' : 'file',
      });
    }

    return jsonEncode({'files': files, 'count': files.length});
  }

  static Future<String> _readFile(Map<String, dynamic> params) async {
    final name = params['name'] as String? ?? params['path'] as String? ?? '';
    final filePath =
        name.startsWith('/') ? name : path.join(_getWorkspace(), name);
    final file = File(filePath);

    if (!file.existsSync()) {
      return jsonEncode({'error': 'File not found: $name'});
    }

    final stat = await file.stat();
    final mime = _guessMime(filePath);

    if (mime.startsWith('text/') || mime == 'application/json') {
      final content = await file.readAsString();
      return jsonEncode({
        'name': path.basename(filePath),
        'size': stat.size,
        'mime_type': mime,
        'content': content,
      });
    }

    return jsonEncode({
      'name': path.basename(filePath),
      'size': stat.size,
      'mime_type': mime,
      'path': filePath,
      'message': 'Binary file — use path to reference it.',
    });
  }

  static Future<String> _writeFile(Map<String, dynamic> params) async {
    final name = params['name'] as String?;
    if (name == null) return jsonEncode({'error': 'name is required'});
    final content = params['content'] as String?;
    if (content == null) return jsonEncode({'error': 'content is required'});

    final filePath = path.join(_getWorkspace(), name);
    final file = File(filePath);
    await file.parent.create(recursive: true);
    await file.writeAsString(content);

    return jsonEncode({
      'success': true,
      'path': filePath,
      'size': await file.length(),
    });
  }

  static Future<String> _pickFile(Map<String, dynamic> params) async {
    final result = await _channel.invokeMethod<String>('pickFile', {
      'mime_type': params['mime_type'] ?? '*/*',
    });
    return result ?? jsonEncode({'error': 'No result from file picker'});
  }

  static Future<String> _deleteFile(Map<String, dynamic> params) async {
    final name = params['name'] as String?;
    if (name == null) return jsonEncode({'error': 'name is required'});
    final filePath =
        name.startsWith('/') ? name : path.join(_getWorkspace(), name);
    final file = File(filePath);

    if (!file.existsSync()) {
      return jsonEncode({'error': 'File not found: $name'});
    }

    await file.delete();
    return jsonEncode({'success': true, 'deleted': path.basename(filePath)});
  }

  static String _guessMime(String filePath) {
    final ext = path.extension(filePath).toLowerCase();
    return switch (ext) {
      '.txt' => 'text/plain',
      '.json' => 'application/json',
      '.md' => 'text/markdown',
      '.csv' => 'text/csv',
      '.html' => 'text/html',
      '.xml' => 'text/xml',
      '.jpg' || '.jpeg' => 'image/jpeg',
      '.png' => 'image/png',
      '.gif' => 'image/gif',
      '.pdf' => 'application/pdf',
      _ => 'application/octet-stream',
    };
  }
}
