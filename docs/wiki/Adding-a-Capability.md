# Adding a Capability

Step-by-step guide for adding a new native phone capability to Ferri. A capability is a domain of native phone functionality (e.g. Calendar, Bluetooth, Files) exposed as one or more tools that the AI agent can call during a conversation.

By the end of this guide, a user will be able to enable your capability in Settings, grant any required permissions, and ask the agent to use your tools in chat -- with tool call cards appearing in the conversation UI.

---

## What is a Capability?

A capability wraps a set of related native API calls behind a clean tool interface. Each tool has:

- **Name** -- `snake_case` with a domain prefix (e.g. `calendar_read_events`, `bluetooth_scan`)
- **Description** -- natural language explanation the LLM reads to decide when to use the tool
- **Schema** -- JSON Schema defining the tool's input parameters
- **Destructive flag** -- if `true`, the tool may modify data and can trigger an approval prompt

The agent calls a tool by name with JSON parameters. The call flows through the Go engine, across the FFI bridge, through Dart, into platform-specific Kotlin code, and back.

```
Go engine (tool call)
  -> NativePort callback
    -> Dart tool handler (capabilities_provider.dart)
      -> MethodChannel invocation
        -> Kotlin channel handler (Android native API)
          -> result returns via MethodChannel
            -> Dart handler returns JSON string
              -> Go engine receives result, continues agent loop
```

Round-trip latency is typically 5-50ms for most tools.

---

## Naming Conventions

| Element | Convention | Example |
|---------|-----------|---------|
| Platform channel | `ferri/<capability>` | `ferri/calendar`, `ferri/wifi` |
| Tool name | `snake_case` with domain prefix | `calendar_read_events`, `wifi_scan` |
| Kotlin channel class | `PascalCase` + `Channel` suffix | `CalendarChannel`, `WifiChannel` |
| Dart channel file | `snake_case` + `_channel.dart` | `calendar_channel.dart`, `wifi_channel.dart` |
| Kotlin method names | `camelCase` (mapped from tool names) | `readEvents`, `scan` |
| Tool results | Structured JSON | `{"event_id": 123, "title": "Meeting"}` |

---

## Step 1: Create the Kotlin Channel Handler

**File:** `android/app/src/main/kotlin/com/ferri/ferri/channels/NewCapChannel.kt`

Create a new Kotlin class that implements `MethodChannel.MethodCallHandler`. This is where you interact with Android APIs and return results.

Use `CalendarChannel.kt` as the canonical reference implementation.

```kotlin
package com.ferri.ferri.channels

import android.content.Context
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class NewCapChannel(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL_NAME = "ferri/newcap"
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "doSomething" -> doSomething(call, result)
            else -> result.notImplemented()
        }
    }

    private fun doSomething(call: MethodCall, result: MethodChannel.Result) {
        try {
            val param = call.argument<String>("param_name")
                ?: return result.error("INVALID_ARGS", "param_name is required", null)

            // Call Android APIs here...

            val response = JSONObject().apply {
                put("status", "success")
                put("data", "result value")
            }
            result.success(response.toString())
        } catch (e: SecurityException) {
            result.error("PERMISSION_DENIED", "Permission not granted", e.message)
        } catch (e: Exception) {
            result.error("ERROR", "Operation failed", e.message)
        }
    }
}
```

Key patterns to follow:

- Always define `CHANNEL_NAME` as a companion object constant matching `ferri/<capability>`
- Accept `Context` in the constructor -- you will need it for Android API calls
- Use `call.argument<Type>("key")` to read parameters from the tool call
- Return results as JSON strings via `result.success(jsonString)`
- Return errors via `result.error(code, message, details)` -- these surface as tool call errors in the agent
- Catch `SecurityException` separately to provide clear permission error messages
- Method names in `onMethodCall` should be `camelCase` versions of the action (e.g. `readEvents`, `getState`, `scan`)

---

## Step 2: Register in MainActivity

**File:** `android/app/src/main/kotlin/com/ferri/ferri/MainActivity.kt`

Add your channel registration inside the `configureFlutterEngine` method. This connects your Kotlin handler to the Dart side.

First, add the import at the top of the file:

```kotlin
import com.ferri.ferri.channels.NewCapChannel
```

Then add the registration inside `configureFlutterEngine`:

```kotlin
MethodChannel(messenger, NewCapChannel.CHANNEL_NAME)
    .setMethodCallHandler(NewCapChannel(this))
```

This follows the same pattern as every other capability. The `messenger` variable is already defined at the top of the method as `flutterEngine.dartExecutor.binaryMessenger`.

If your channel needs to handle `onActivityResult` callbacks (e.g. for file pickers, camera intents), store a reference to the channel instance and delegate from `onActivityResult`, following the `FilesChannel` pattern.

---

## Step 3: Create the Dart Channel

**File:** `lib/native/newcap_channel.dart`

Create a Dart wrapper that bridges tool call names to `MethodChannel` invocations. Every Dart channel follows the same pattern.

```dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class NewCapChannel {
  static const _channel = MethodChannel('ferri/newcap');
  NewCapChannel._();

  /// Route a tool call to the appropriate MethodChannel method.
  /// Returns a JSON string result suitable for sending back to Go.
  static Future<String> handleToolCall(
      String toolName, Map<String, dynamic> params) async {
    debugPrint('[NewCapChannel] handleToolCall: $toolName');

    switch (toolName) {
      case 'newcap_do_something':
        return _doSomething(params);
      default:
        throw PlatformException(
          code: 'UNKNOWN_TOOL',
          message: 'Unknown newcap tool: $toolName',
        );
    }
  }

  static Future<String> _doSomething(Map<String, dynamic> params) async {
    final result = await _channel.invokeMethod<String>('doSomething', {
      'param_name': params['param_name'] as String,
    });
    return result ?? jsonEncode({'error': 'No result'});
  }
}
```

Key patterns:

- The `MethodChannel` name must exactly match `CHANNEL_NAME` in the Kotlin class
- The `handleToolCall` static method is the single entry point -- it receives the tool name and parameters from the capabilities provider
- Each tool maps to a private method that calls `_channel.invokeMethod` with the matching Kotlin method name
- Always return a JSON string. The Go engine expects structured JSON results
- Use `debugPrint` with a channel-specific tag for logging
- The constructor is private (`NewCapChannel._()`) -- all methods are static

---

## Step 4: Register in the Capability Registry

**File:** `lib/capabilities/capability_registry.dart`

Add a static `Capability` entry that defines your capability's metadata and tool schemas. The capability registry is the source of truth for what the UI displays and what the Go engine registers.

```dart
// ─── New Capability ──────────────────────────────
static const newCap = Capability(
  id: 'new_cap',
  displayName: 'New Capability',
  description: 'One-line description of what this capability does',
  icon: Icons.extension,
  color: FerriColors.capNewCap, // Add to lib/theme/colors.dart
  tier: CapabilityTier.core,    // or CapabilityTier.extended
  permissions: [
    'android.permission.SOME_PERMISSION',
  ],
  tools: [
    CapabilityTool(
      name: 'newcap_do_something',
      description:
          'Detailed description the LLM reads to decide when to use this tool. '
          'Include what it returns and any important behavior.',
      schema: {
        'type': 'object',
        'properties': {
          'param_name': {
            'type': 'string',
            'description': 'What this parameter does',
          },
          'optional_param': {
            'type': 'integer',
            'description': 'Optional parameter with default (default: 10)',
          },
        },
        'required': ['param_name'],
      },
    ),
  ],
);
```

Then add it to the `allCapabilities` list at the bottom of the class:

```dart
static const List<Capability> allCapabilities = [
  // ... existing capabilities ...
  newCap,
];
```

Important details:

- **`id`** -- unique identifier, used as the SharedPreferences key (`cap_<id>_enabled`)
- **`displayName`** -- shown in the Settings UI
- **`description`** -- shown below the capability name in the toggle list
- **`icon`** -- Material icon displayed next to the capability
- **`color`** -- unique color from the brand palette. Add a new constant to `lib/theme/colors.dart` following the `capXxx` naming pattern
- **`tier`** -- `CapabilityTier.core` for standard permissions, `CapabilityTier.extended` for capabilities needing additional setup
- **`permissions`** -- list of Android permission strings requested at runtime
- **`tools`** -- list of `CapabilityTool` entries. Each tool's `description` is critical -- this is what the LLM reads to decide whether and how to use the tool
- **`destructive`** -- set to `true` on tools that modify state (delete, update, send). These may trigger user approval prompts
- **`privileged`** -- set to `true` if the capability requires a system settings grant instead of a standard runtime dialog. Also set `settingsRoute` to the Android settings intent action (e.g. `android.settings.ACCESSIBILITY_SETTINGS`)
- **`schema`** -- JSON Schema for the tool's input parameters. Must include `type`, `properties`, and `required` keys

The `Capability` model is defined in `lib/capabilities/models/capability.dart`.

---

## Step 5: Wire Tool Handlers in the Capabilities Provider

**File:** `lib/providers/capabilities_provider.dart`

Map your tool names to the Dart channel's `handleToolCall` method. This is where the tool dispatch routes calls from the Go engine to your native implementation.

First, add the import:

```dart
import '../native/newcap_channel.dart';
```

Then add handler registrations inside the `_registerToolHandlers()` method:

```dart
// New Capability tools -> NewCapChannel
_engine.toolHandlers['newcap_do_something'] =
    NewCapChannel.handleToolCall;
```

Each entry maps a tool name string to a `Future<String> Function(String, Map<String, dynamic>)` handler. The string is the tool name, the map is the parsed JSON parameters.

When the Go engine calls a tool, the `ToolDispatcher` looks up this map to find the Dart function to invoke. The result is a JSON string that gets sent back to Go.

If your capability needs special orchestration logic (e.g. geocoding a location name before creating a geofence), you can define a custom handler method directly in the `CapabilitiesNotifier` class rather than pointing to the channel's `handleToolCall`. See `_handleGeofenceCreate` for an example of multi-step tool orchestration.

---

## Step 6: Add Permissions

If your capability requires Android permissions beyond what is already declared:

### Manifest Permissions

**File:** `android/app/src/main/AndroidManifest.xml`

Add `<uses-permission>` entries inside the `<manifest>` tag, before `<application>`:

```xml
<!-- New Capability -->
<uses-permission android:name="android.permission.SOME_PERMISSION"/>
```

For optional hardware features, use `<uses-feature>` with `android:required="false"` so the app can still be installed on devices without the hardware:

```xml
<uses-feature android:name="android.hardware.nfc" android:required="false" />
```

### Permission Categories

| Category | How it works | Example |
|----------|-------------|---------|
| Normal | Auto-granted at install. No runtime prompt | `MODIFY_AUDIO_SETTINGS`, `SET_ALARM`, `NFC` |
| Dangerous | Runtime dialog. Listed in `permissions` array | `READ_CALENDAR`, `CAMERA`, `ACCESS_FINE_LOCATION` |
| Privileged | User must navigate to system settings. Set `privileged: true` | `BIND_NOTIFICATION_LISTENER_SERVICE`, `PACKAGE_USAGE_STATS` |
| Special | Requires `ACTION_MANAGE_*` settings intent | `WRITE_SETTINGS` (for brightness) |

Runtime permission requests are handled automatically by the capabilities framework. When a user enables a capability, `PermissionManager.requestPermissions()` is called with the permissions list from the registry. If permissions are denied, the capability status is set to `permissionRequired`.

For privileged capabilities, the framework opens the system settings screen specified in `settingsRoute` so the user can manually grant access. The capability checks access via `PermissionsChannel` methods (e.g. `checkNotificationListener()`, `checkUsageStats()`).

---

## Step 7: Test End-to-End

### Testing Procedure

1. **Build and run** the app on a device or emulator:
   ```
   flutter run -d <device-id>
   ```

2. **Enable the capability** in Settings > Capabilities. Grant any permission dialogs that appear.

3. **Ask the agent to use the tool** in chat. For example:
   ```
   "Read my calendar events for today"
   "What's the current battery level?"
   "Scan for Bluetooth devices nearby"
   ```

4. **Verify the tool call card** appears in the chat UI. The card shows the tool name, parameters, and result.

5. **Verify the result** is correct and matches what the native API returned.

6. **Check logs** for timing and errors:
   ```bash
   # Go engine logs (tool dispatch timing)
   adb logcat -s ferri:* *:S

   # Flutter/Dart logs (channel invocations)
   adb logcat -s flutter:*

   # All app logs
   adb logcat --pid=$(adb shell pidof com.ferri.ferri)
   ```

### Common Issues

| Issue | Cause | Fix |
|-------|-------|-----|
| Tool not appearing in agent's available tools | Capability not enabled, or tool not registered in `allCapabilities` | Check `CapabilityRegistry.allCapabilities` includes your capability |
| `MissingPluginException` | Channel name mismatch between Dart and Kotlin | Verify `CHANNEL_NAME` constant matches the `MethodChannel` constructor in Dart |
| `PlatformException(PERMISSION_DENIED)` | Permission not declared in manifest or not granted | Check `AndroidManifest.xml` and that `permissions` list in the registry is correct |
| Tool call returns `null` | Kotlin handler returned `null` instead of a JSON string | Always return `result.success(jsonString)` with a valid JSON object |
| Tool call hangs | Kotlin handler never called `result.success()` or `result.error()` | Ensure every code path in the Kotlin handler terminates with a result call |

---

## File Summary

Every new capability touches these files:

| Step | File | Action |
|------|------|--------|
| 1 | `android/app/src/main/kotlin/com/ferri/ferri/channels/NewCapChannel.kt` | Create Kotlin handler |
| 2 | `android/app/src/main/kotlin/com/ferri/ferri/MainActivity.kt` | Register MethodChannel |
| 3 | `lib/native/newcap_channel.dart` | Create Dart channel wrapper |
| 4 | `lib/capabilities/capability_registry.dart` | Define capability + tool schemas |
| 4 | `lib/theme/colors.dart` | Add capability color constant |
| 5 | `lib/providers/capabilities_provider.dart` | Wire tool handlers |
| 6 | `android/app/src/main/AndroidManifest.xml` | Declare permissions (if needed) |
| 7 | `docs/ferri_features_list.md` | Update feature tracking |

---

## Checklist

Before submitting your capability:

- [ ] Kotlin channel implements `MethodChannel.MethodCallHandler` with a `CHANNEL_NAME` constant
- [ ] Kotlin channel handles all errors with `result.error()` -- never throws unhandled exceptions
- [ ] Kotlin channel returns JSON strings via `result.success()` for every code path
- [ ] `MainActivity.kt` registers the channel in `configureFlutterEngine`
- [ ] Dart channel file has a static `handleToolCall` method matching the `Future<String> Function(String, Map<String, dynamic>)` signature
- [ ] Dart channel's `MethodChannel` name matches the Kotlin `CHANNEL_NAME`
- [ ] Capability is defined in `CapabilityRegistry` with all tool schemas
- [ ] Capability is added to `CapabilityRegistry.allCapabilities`
- [ ] Capability has a unique color added to `lib/theme/colors.dart`
- [ ] Tool handlers are wired in `CapabilitiesNotifier._registerToolHandlers()`
- [ ] Required permissions are declared in `AndroidManifest.xml`
- [ ] Permissions are listed in the `permissions` array of the `Capability` definition
- [ ] Destructive tools have `destructive: true` set
- [ ] Tool descriptions are detailed enough for the LLM to understand when and how to use each tool
- [ ] End-to-end test passes: enable capability, ask agent, verify tool card and result
- [ ] `docs/ferri_features_list.md` is updated with the new capability and its tools
- [ ] No regressions in existing capabilities
