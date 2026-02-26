import 'dart:convert';
import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

import 'ferri_bindings.dart';

/// Callback type for handling tool requests.
/// Returns a JSON string result, or throws on error.
typedef ToolHandler = Future<String> Function(
    String toolName, Map<String, dynamic> params);

/// Represents a tool dispatch request from Go.
class ToolRequest {
  final String requestId;
  final String toolName;
  final Map<String, dynamic> params;

  ToolRequest({
    required this.requestId,
    required this.toolName,
    required this.params,
  });

  factory ToolRequest.fromJson(Map<String, dynamic> json) {
    return ToolRequest(
      requestId: json['request_id'] as String,
      toolName: json['tool_name'] as String,
      params: (json['params'] as Map<String, dynamic>?) ?? {},
    );
  }
}

/// Listens on a NativePort for tool dispatch requests from Go.
/// Routes requests to registered handlers, then calls ferri_tool_result()
/// to unblock the waiting Go goroutine.
///
/// Supports an approval gate for destructive tools — when [requireApproval]
/// is true and a tool is marked destructive, the [onApprovalRequired] callback
/// is invoked before execution. If it returns false, the tool call is rejected.
class ToolDispatcher {
  final ReceivePort _receivePort = ReceivePort();
  final FerriBindings _bindings;
  final Map<String, ToolHandler> _handlers = {};
  final Set<String> _destructiveTools = {};

  /// When true, destructive tools require user approval before execution.
  bool requireApproval = true;

  /// Callback invoked when a destructive tool needs user approval.
  /// Returns true to approve, false to deny.
  Future<bool> Function(ToolRequest)? onApprovalRequired;

  ToolDispatcher(this._bindings);

  int get port => _receivePort.sendPort.nativePort;

  void registerHandler(String toolName, ToolHandler handler,
      {bool destructive = false}) {
    _handlers[toolName] = handler;
    if (destructive) {
      _destructiveTools.add(toolName);
    }
  }

  void unregisterHandler(String toolName) {
    _handlers.remove(toolName);
    _destructiveTools.remove(toolName);
  }

  void listen() {
    _receivePort.listen((dynamic message) async {
      if (message is! String) {
        debugPrint(
            '[ToolDispatcher] non-string message: ${message.runtimeType}');
        return;
      }

      try {
        final json = jsonDecode(message) as Map<String, dynamic>;
        final request = ToolRequest.fromJson(json);
        debugPrint(
            '[ToolDispatcher] request: ${request.toolName} (${request.requestId})');

        await _handleRequest(request);
      } catch (e) {
        debugPrint('[ToolDispatcher] parse error: $e');
      }
    });
  }

  Future<void> _handleRequest(ToolRequest request) async {
    final handler = _handlers[request.toolName];

    String responseJson;
    if (handler == null) {
      responseJson = jsonEncode({
        'request_id': request.requestId,
        'success': false,
        'data': '',
        'error': 'No handler registered for tool: ${request.toolName}',
      });
    } else {
      // Approval gate for destructive tools
      if (requireApproval &&
          _destructiveTools.contains(request.toolName) &&
          onApprovalRequired != null) {
        debugPrint(
            '[ToolDispatcher] approval required for ${request.toolName}');
        final approved = await onApprovalRequired!(request);
        if (!approved) {
          debugPrint(
              '[ToolDispatcher] DENIED by user: ${request.toolName}');
          responseJson = jsonEncode({
            'request_id': request.requestId,
            'success': false,
            'data': '',
            'error':
                'User denied this operation. The user chose not to allow '
                '${request.toolName}. Do not retry — inform the user the '
                'action was cancelled.',
          });
          // Send denial back to Go and return early
          final requestIdPtr = request.requestId.toNativeUtf8();
          final resultPtr = responseJson.toNativeUtf8();
          _bindings.ferriToolResult(requestIdPtr, resultPtr);
          calloc.free(requestIdPtr);
          calloc.free(resultPtr);
          debugPrint('[ToolDispatcher] resolved (denied): ${request.requestId}');
          return;
        }
        debugPrint(
            '[ToolDispatcher] APPROVED by user: ${request.toolName}');
      }

      try {
        final resultData =
            await handler(request.toolName, request.params);
        responseJson = jsonEncode({
          'request_id': request.requestId,
          'success': true,
          'data': resultData,
          'error': '',
        });
      } catch (e) {
        responseJson = jsonEncode({
          'request_id': request.requestId,
          'success': false,
          'data': '',
          'error': e.toString(),
        });
      }
    }

    // Call back into Go to resolve the pending request
    final requestIdPtr = request.requestId.toNativeUtf8();
    final resultPtr = responseJson.toNativeUtf8();
    _bindings.ferriToolResult(requestIdPtr, resultPtr);
    calloc.free(requestIdPtr);
    calloc.free(resultPtr);

    debugPrint('[ToolDispatcher] resolved: ${request.requestId}');
  }

  void dispose() {
    _receivePort.close();
  }
}
