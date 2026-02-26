/// Camera capability — provides tools for capturing photos and picking
/// images from the gallery.
///
/// Channel: none (pure-Dart via `image_picker`)
/// Kotlin handler: none
///
/// Tools:
/// - `camera_capture_photo` — Capture a photo using the device camera
/// - `camera_pick_image` — Pick an image from the device gallery
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

/// Handles camera operations using image_picker.
/// Captures photos via system camera intent — no CameraX preview needed.
class CameraChannel {
  static final ImagePicker _picker = ImagePicker();

  CameraChannel._();

  static Future<String> handleToolCall(
      String toolName, Map<String, dynamic> params) async {
    debugPrint('[CameraChannel] handleToolCall: $toolName');

    switch (toolName) {
      case 'camera_capture_photo':
        return _capturePhoto(params);
      case 'camera_pick_image':
        return _pickImage(params);
      default:
        throw Exception('Unknown camera tool: $toolName');
    }
  }

  /// Capture a photo using the device camera.
  static Future<String> _capturePhoto(Map<String, dynamic> params) async {
    final quality = params['quality'] as int? ?? 85;

    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: quality,
    );

    if (photo == null) {
      return jsonEncode({
        'captured': false,
        'error': 'User cancelled or camera unavailable',
      });
    }

    final file = File(photo.path);
    final sizeBytes = await file.length();

    return jsonEncode({
      'captured': true,
      'path': photo.path,
      'name': photo.name,
      'size_bytes': sizeBytes,
    });
  }

  /// Pick an image from the device gallery.
  static Future<String> _pickImage(Map<String, dynamic> params) async {
    final quality = params['quality'] as int? ?? 85;

    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: quality,
    );

    if (image == null) {
      return jsonEncode({
        'picked': false,
        'error': 'User cancelled',
      });
    }

    final file = File(image.path);
    final sizeBytes = await file.length();

    return jsonEncode({
      'picked': true,
      'path': image.path,
      'name': image.name,
      'size_bytes': sizeBytes,
    });
  }
}
