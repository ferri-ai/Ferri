# Adding a Capability: Kotlin Channel

> Detailed guide to implementing the native Android layer for a new capability.

---

## Overview

Each capability has a **Kotlin channel handler** that implements `MethodChannel.MethodCallHandler`. It receives method calls from Dart via platform channels, interacts with Android APIs, and returns results as JSON strings.

**File location:** `android/app/src/main/kotlin/com/ferri/ferri/channels/<Capability>Channel.kt`

**Reference implementation:** `CalendarChannel.kt` is the cleanest example.

---

## Class Structure

```kotlin
class NewCapChannel(private val context: Context) : MethodChannel.MethodCallHandler {
    companion object {
        const val CHANNEL_NAME = "ferri/new_cap"
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "readData"   -> readData(call, result)
            "writeData"  -> writeData(call, result)
            else         -> result.notImplemented()
        }
    }
}
```

**Key conventions:**
- Implement `MethodChannel.MethodCallHandler`
- Define `CHANNEL_NAME` as `ferri/<capability>` (matches Dart channel)
- Accept `Context` in the constructor (usually the Activity)
- Route methods with `when` statement
- Always include `else -> result.notImplemented()`

---

## Method Handler Pattern

Every method handler follows this structure:

```kotlin
private fun readData(call: MethodCall, result: MethodChannel.Result) {
    try {
        // 1. Extract and validate parameters
        val query = call.argument<String>("query")
            ?: return result.error("INVALID_ARGS", "query is required", null)
        val limit = call.argument<Int>("limit") ?: 20

        // 2. Call Android APIs
        val cursor = context.contentResolver.query(
            uri, projection, selection, selectionArgs, sortOrder
        )

        // 3. Build JSON response
        val items = JSONArray()
        cursor?.use { c ->
            while (c.moveToNext()) {
                val item = JSONObject().apply {
                    put("id", c.getLong(0))
                    put("name", c.getString(1) ?: "")
                }
                items.put(item)
            }
        }

        // 4. Return as JSON string
        result.success(items.toString())

    } catch (e: SecurityException) {
        result.error("PERMISSION_DENIED", "Permission not granted", e.message)
    } catch (e: Exception) {
        result.error("READ_ERROR", "Failed to read data", e.message)
    }
}
```

**Rules:**
- Required params: use `?: return result.error(...)` for early exit
- Optional params: use `?: defaultValue`
- Results **must be JSON strings** — call `.toString()` on `JSONObject`/`JSONArray`
- Always catch `SecurityException` explicitly (permission denied)
- Always catch generic `Exception` as fallback

---

## Returning Results

```kotlin
// Success: JSON string
result.success(jsonObject.toString())
result.success(jsonArray.toString())

// Error: code + message + optional details
result.error("PERMISSION_DENIED", "Calendar permission not granted", null)
result.error("INVALID_ARGS", "start_date is required", null)
result.error("NOT_FOUND", "Event not found", "id=$eventId")
```

Error codes used across capabilities:
- `PERMISSION_DENIED` — Android runtime permission not granted
- `INVALID_ARGS` — Missing or malformed required parameters
- `NOT_FOUND` — Requested resource doesn't exist
- `PARSE_ERROR` — Date/input parsing failed
- `UNAVAILABLE` — Hardware/service not available

---

## Registration in MainActivity

```kotlin
// MainActivity.kt
override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    val messenger = flutterEngine.dartExecutor.binaryMessenger

    // Add your channel here:
    MethodChannel(messenger, NewCapChannel.CHANNEL_NAME)
        .setMethodCallHandler(NewCapChannel(this))
}
```

Add the registration line alongside existing channels. Order doesn't matter.

---

## Common Patterns

### Date Handling

```kotlin
companion object {
    private val iso8601Format = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.US).apply {
        timeZone = TimeZone.getDefault()
    }
}

private fun formatMillis(millis: Long): String = iso8601Format.format(Date(millis))
private fun parseDate(dateStr: String): Long? = iso8601Format.parse(dateStr)?.time
```

### ContentResolver Queries

```kotlin
val cursor = context.contentResolver.query(
    contentUri,                    // e.g., CalendarContract.Events.CONTENT_URI
    arrayOf("_id", "title"),      // projection
    "start >= ?",                 // selection
    arrayOf(startMillis.toString()), // selectionArgs
    "start ASC"                   // sortOrder
)
```

### Intent-Based Tools

```kotlin
private fun launchApp(call: MethodCall, result: MethodChannel.Result) {
    val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    context.startActivity(intent)
    result.success("""{"success": true}""")
}
```

---

## Permissions

Permissions are declared in `AndroidManifest.xml` and requested at runtime via `PermissionsChannel`. By the time a tool call reaches your Kotlin handler, the permission should already be granted.

```xml
<!-- AndroidManifest.xml -->
<uses-permission android:name="android.permission.READ_CALENDAR" />
<uses-permission android:name="android.permission.WRITE_CALENDAR" />
```

Handle the case where permission was revoked between grant and tool call:

```kotlin
catch (e: SecurityException) {
    result.error("PERMISSION_DENIED", "Permission was revoked", e.message)
}
```

---

## Testing the Kotlin Layer

1. **Build and run** on a device or emulator
2. **Enable the capability** in the Capabilities screen
3. **Ask the agent** to use a tool (e.g., "What's on my calendar?")
4. **Check logcat** for errors:
   ```bash
   adb logcat -s flutter:* | grep "ferri/new_cap"
   ```
5. Verify the JSON response is well-formed and contains expected data

---

**See also:** [Adding a Capability (Dart)](Adding-a-Capability-Dart), [Adding a Capability (Go)](Adding-a-Capability-Go), [Adding a Capability](Adding-a-Capability)
