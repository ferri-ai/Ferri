# Adding a Capability: Dart Channel

> Detailed guide to implementing the Dart bridge layer for a new capability.

---

## Overview

Each capability has a **Dart channel class** that bridges Go tool calls to Kotlin platform channels. It receives a tool name and parameters from the Go engine, calls the appropriate platform channel method, and returns the result as a JSON string.

**File location:** `lib/native/<capability>_channel.dart`

**Reference implementation:** `calendar_channel.dart`

---

## Class Structure

```dart
import 'package:flutter/services.dart';

class NewCapChannel {
  static const _channel = MethodChannel('ferri/new_cap');

  NewCapChannel._(); // Private constructor — all methods are static

  /// Route a tool call to the appropriate method.
  /// Returns a JSON string result for the Go engine.
  static Future<String> handleToolCall(
      String toolName, Map<String, dynamic> params) async {
    switch (toolName) {
      case 'newcap_read_data':
        return _readData(params);
      case 'newcap_write_data':
        return _writeData(params);
      default:
        throw PlatformException(
          code: 'UNKNOWN_TOOL',
          message: 'Unknown new_cap tool: $toolName',
        );
    }
  }
}
```

**Key conventions:**
- Static class with private constructor (`NewCapChannel._()`)
- Single static `MethodChannel` matching the Kotlin `CHANNEL_NAME`
- `handleToolCall(toolName, params)` is the entry point from the Go engine
- Routes tool names to private static methods
- Returns `Future<String>` (JSON string)

---

## Method Implementation Pattern

```dart
static Future<String> _readData(Map<String, dynamic> params) async {
  final result = await _channel.invokeMethod<String>('readData', {
    'query': params['query'] as String,
    if (params['limit'] != null) 'limit': params['limit'] as int,
  });
  return result ?? '[]';
}
```

**Rules:**
- Use `_channel.invokeMethod<String>()` — type parameter is `String`
- Method name (first arg) matches the Kotlin `when` branch
- Pass arguments as a `Map<String, dynamic>`
- Required params: cast directly (`as String`)
- Optional params: use conditional spread (`if (... != null) key: value`)
- Always provide a fallback for null result (`?? '[]'` or `?? '{}'`)

---

## Handling Different Result Types

```dart
// List results (most common)
static Future<String> _listItems(Map<String, dynamic> params) async {
  final result = await _channel.invokeMethod<String>('listItems', {});
  return result ?? '[]';
}

// Single object result
static Future<String> _getItem(Map<String, dynamic> params) async {
  final result = await _channel.invokeMethod<String>('getItem', {
    'id': params['id'] as String,
  });
  return result ?? '{}';
}

// Action result (no data returned)
static Future<String> _doAction(Map<String, dynamic> params) async {
  await _channel.invokeMethod<String>('doAction', {
    'target': params['target'] as String,
  });
  return '{"success": true}';
}
```

---

## Registration in capabilities_provider.dart

After creating the channel class, register its tool handlers:

```dart
// In lib/providers/capabilities_provider.dart
// Inside CapabilitiesNotifier._registerToolHandlers()

_engine.toolHandlers['newcap_read_data'] = NewCapChannel.handleToolCall;
_engine.toolHandlers['newcap_write_data'] = NewCapChannel.handleToolCall;
```

**Key points:**
- Multiple tool names can point to the same `handleToolCall` (routing happens internally)
- Tool names follow `<capability>_<action>` snake_case convention
- The handler signature is `Future<String> Function(String toolName, Map<String, dynamic> params)`

---

## Platform Tool Registration

Also in `capabilities_provider.dart`, register the tools with the Go engine when the capability is enabled:

```dart
// Inside the capability's enable logic in capabilities_provider.dart
// registerCapabilityTools iterates all tools in the Capability and registers them with Go
engine.registerCapabilityTools(CapabilityRegistry.newCap);
```

Tool schemas are defined in `CapabilityRegistry` and automatically passed to Go during registration. The schema is JSON Schema format — this is what the LLM sees when deciding how to call the tool.

---

## Error Handling

Errors from Kotlin are automatically converted to `PlatformException` by Flutter:

```dart
// Kotlin: result.error("PERMISSION_DENIED", "Not granted", null)
// → Dart: PlatformException(code: "PERMISSION_DENIED", message: "Not granted")
```

You generally don't need try-catch in the Dart channel. Exceptions propagate to the Go engine's dispatcher, which converts them to tool errors for the LLM.

If you need to handle errors explicitly:

```dart
static Future<String> _readData(Map<String, dynamic> params) async {
  try {
    final result = await _channel.invokeMethod<String>('readData', {
      'query': params['query'] as String,
    });
    return result ?? '[]';
  } on PlatformException catch (e) {
    return '{"error": "${e.message}"}';
  }
}
```

---

## Capability Registry Entry

Add the capability to `lib/capabilities/capability_registry.dart`:

```dart
static const newCap = Capability(
  id: 'new_cap',
  displayName: 'New Capability',
  description: 'What this capability does',
  icon: Icons.new_releases,
  color: FerriColors.capNewCap,        // Define in colors.dart
  tier: CapabilityTier.core,           // core, extended, or privileged
  permissions: [
    'android.permission.SOME_PERMISSION',
  ],
  tools: [
    CapabilityTool(
      name: 'newcap_read_data',
      description: 'Detailed description for the LLM',
      schema: {
        'type': 'object',
        'properties': {
          'query': {'type': 'string', 'description': 'Search query'},
        },
        'required': ['query'],
      },
    ),
  ],
);
```

The registry connects the capability to its tools, UI metadata, and required permissions.

---

## Testing the Dart Layer

1. **Unit test with mock platform channel:**
   ```dart
   TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
       .setMockMethodCallHandler(
     const MethodChannel('ferri/new_cap'),
     (call) async => '{"id": 1, "name": "test"}',
   );

   final result = await NewCapChannel.handleToolCall(
     'newcap_read_data',
     {'query': 'test'},
   );
   expect(result, contains('"name"'));
   ```

2. **Integration test on device:**
   - Enable the capability
   - Ask the agent to use the tool
   - Check Flutter logs: `adb logcat -s flutter:*`

---

**See also:** [Adding a Capability (Kotlin)](Adding-a-Capability-Kotlin), [Adding a Capability (Go)](Adding-a-Capability-Go), [Adding a Capability](Adding-a-Capability)
