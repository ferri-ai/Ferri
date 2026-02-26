/// Contacts capability — provides tools for searching, reading, creating,
/// updating, and deleting contacts.
///
/// Channel: `ferri/contacts`
/// Kotlin handler: `ContactsChannel.kt`
///
/// Tools:
/// - `contacts_search` — Search contacts by query string
/// - `contacts_read` — Read a single contact by ID
/// - `contacts_create` — Create a new contact
/// - `contacts_update` — Update an existing contact
/// - `contacts_delete` — Delete a contact by ID
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Dart wrapper around MethodChannel('ferri/contacts').
class ContactsChannel {
  static const _channel = MethodChannel('ferri/contacts');

  ContactsChannel._();

  static Future<String> handleToolCall(
      String toolName, Map<String, dynamic> params) async {
    debugPrint('[ContactsChannel] handleToolCall: $toolName');

    switch (toolName) {
      case 'contacts_search':
        return _searchContacts(params);
      case 'contacts_read':
        return _readContact(params);
      case 'contacts_create':
        return _createContact(params);
      case 'contacts_update':
        return _updateContact(params);
      case 'contacts_delete':
        return _deleteContact(params);
      default:
        throw PlatformException(
          code: 'UNKNOWN_TOOL',
          message: 'Unknown contacts tool: $toolName',
        );
    }
  }

  static Future<String> _searchContacts(Map<String, dynamic> params) async {
    final result = await _channel.invokeMethod<String>('searchContacts', {
      if (params['query'] != null) 'query': params['query'] as String,
      if (params['limit'] != null) 'limit': params['limit'] as int,
    });
    return result ?? '[]';
  }

  static Future<String> _readContact(Map<String, dynamic> params) async {
    final result = await _channel.invokeMethod<String>('readContact', {
      'contact_id': params['contact_id'] as String,
    });
    return result ?? jsonEncode({'error': 'No result'});
  }

  static Future<String> _createContact(Map<String, dynamic> params) async {
    final result = await _channel.invokeMethod<String>('createContact', {
      'name': params['name'] as String,
      if (params['phone'] != null) 'phone': params['phone'] as String,
      if (params['email'] != null) 'email': params['email'] as String,
    });
    return result ?? jsonEncode({'error': 'No result'});
  }

  static Future<String> _updateContact(Map<String, dynamic> params) async {
    final result = await _channel.invokeMethod<String>('updateContact', {
      'contact_id': params['contact_id'] as String,
      if (params['name'] != null) 'name': params['name'] as String,
      if (params['phone'] != null) 'phone': params['phone'] as String,
      if (params['email'] != null) 'email': params['email'] as String,
    });
    return result ?? jsonEncode({'error': 'No result'});
  }

  static Future<String> _deleteContact(Map<String, dynamic> params) async {
    final result = await _channel.invokeMethod<String>('deleteContact', {
      'contact_id': params['contact_id'] as String,
    });
    return result ?? jsonEncode({'error': 'No result'});
  }
}
