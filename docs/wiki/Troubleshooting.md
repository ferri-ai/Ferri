# Troubleshooting

Common issues and solutions when building, running, and debugging Ferri. Organized by category in problem-solution format.

---

## Build Issues

### NDK not found

**Error:** `make: *** No rule to make target` or compiler path does not exist.

**Cause:** The `NDK_HOME` environment variable is not set or points to the wrong path.

**Fix:**

```bash
export NDK_HOME=/path/to/Android/sdk/ndk/28.2.13676358
```

Verify the path exists and contains the `toolchains/llvm/prebuilt/` directory. Add the export to your shell profile so it persists.

---

### CGo compilation failed

**Error:** `cgo: C compiler not found` or linker errors during `make build-engine-android-arm64`.

**Cause:** Wrong NDK version. The Makefile expects the toolchain layout from NDK `28.2.13676358`. Other versions (especially major version changes) reorganize compiler paths and break CGo.

**Fix:** Install the exact NDK version:

```bash
sdkmanager "ndk;28.2.13676358"
```

Then set `NDK_HOME` to point to that version specifically. Do not use a symlink or generic NDK path.

---

### Go version mismatch

**Error:** `go: go.mod requires go >= 1.22` or syntax errors in Go source files.

**Cause:** Your Go installation is older than 1.22.

**Fix:**

```bash
go version  # Check current version
```

If below 1.22, upgrade from [go.dev/dl](https://go.dev/dl/). After upgrading, verify with `go version` and rebuild:

```bash
make clean && make build-engine-android-arm64
```

---

### libferri.so not found at runtime

**Error:** App crashes immediately on launch. Logcat shows `java.lang.UnsatisfiedLinkError` or `cannot open shared library`.

**Cause:** The Go engine was not built, or was built for the wrong architecture. Physical devices need `arm64-v8a`; most emulators need `x86_64`.

**Fix:** Build for the correct target:

```bash
# Physical device (ARM64)
make build-engine-android-arm64

# Emulator (x86_64)
make build-engine-android-x86
```

Confirm the `.so` file exists in the correct jniLibs subdirectory:

```bash
ls android/app/src/main/jniLibs/arm64-v8a/libferri.so   # Physical device
ls android/app/src/main/jniLibs/x86_64/libferri.so       # Emulator
```

---

### Flutter build fails after engine change

**Error:** Gradle or Flutter build errors after modifying Go engine source.

**Fix:** Clean and rebuild everything:

```bash
make clean
make build-engine-android-arm64  # or x86
flutter run
```

If that does not resolve it, also clear Flutter's build cache:

```bash
flutter clean && flutter pub get
```

---

## Runtime Issues

### Tool call failed

**Error:** Agent responds with a tool call error card showing "capability not enabled" or "permission denied."

**Cause:** Either the capability is not toggled on in Ferri's settings, or the Android OS permission was not granted.

**Fix:**

1. Open Settings > Capabilities in the app
2. Toggle on the relevant capability (e.g., Calendar, Contacts, Location)
3. When Android shows the permission dialog, tap "Allow"

For privileged capabilities (Notification Listener, Accessibility, Usage Stats), you must grant access through Android system settings. The app will guide you to the correct settings page.

---

### LLM connection failed

**Error:** Chat shows a connection error or the agent does not respond.

**Cause:** Invalid API key, network connectivity issue, or the provider endpoint is unreachable.

**Fix:**

1. Go to Settings > LLM Provider
2. Re-enter your API key
3. Tap "Test Connection" to validate
4. Ensure your device has internet access
5. If using a custom endpoint, verify the URL is correct and the server is running

---

### Agent not responding

**Error:** You send a message but nothing happens -- no streaming tokens, no tool calls, no error.

**Cause:** The Go engine may have crashed or entered a deadlock.

**Fix:** Check the engine logs:

```bash
adb logcat -s ferri:* *:S
```

Look for panic traces or error messages. If the engine crashed, restart the app. If the issue persists, clear app data and reconfigure:

```bash
adb shell pm clear com.ferri.ferri
```

---

### Notification not showing

**Error:** Scheduled notifications or automation results do not appear.

**Cause:** On Android 13+ (API 33), apps must request the `POST_NOTIFICATIONS` permission at runtime. If the user denied it (or was never prompted), notifications are silently dropped.

**Fix:**

1. Go to Android Settings > Apps > Ferri > Notifications
2. Ensure notifications are enabled
3. If using notification channels, check that the specific channel is not muted

---

### Geofence not triggering

**Error:** Location-based automations do not fire when entering or leaving a defined area.

**Cause:** Background location permission not granted, or battery optimization is killing the service.

**Fix:**

1. Ensure "Allow all the time" location permission is granted (Settings > Apps > Ferri > Permissions > Location)
2. Disable battery optimization for Ferri (Settings > Apps > Ferri > Battery > Unrestricted)
3. Verify the geofence radius is not too small (minimum recommended: 100 meters)

---

## Debugging Commands

All commands below use `adb`. If you have multiple devices connected, add `-s <device-id>` (e.g., `-s emulator-5554`).

```bash
# Go engine logs only
adb logcat -s ferri:* *:S

# Flutter framework logs only
adb logcat -s flutter:*

# All logs from the Ferri process
adb logcat --pid=$(adb shell pidof com.ferri.ferri)

# Clear all app data (resets to first-launch state)
adb shell pm clear com.ferri.ferri

# Check if the app process is running
adb shell pidof com.ferri.ferri

# Force stop the app
adb shell am force-stop com.ferri.ferri

# Install a release APK
adb install build/app/outputs/flutter-apk/app-release.apk
```

For emulator-specific debugging:

```bash
adb -s emulator-5554 logcat -s ferri:* *:S
adb -s emulator-5554 shell pm clear com.ferri.ferri
```

For physical devices over WiFi ADB:

```bash
adb connect <device-ip>:<port>
adb -s <device-ip>:<port> logcat -s ferri:* *:S
```

---

## Known Issues

These are known behaviors from testing that have not yet been resolved:

### Home screen shows "Connected" when device is offline

The connectivity status on the Home screen does not update in real time when the network state changes. It reflects the state at the time the screen was last loaded. Navigating away and back refreshes it.

### device_connectivity tool may fail on first use

The `device_connectivity` tool requires `ACCESS_NETWORK_STATE` permission. On some devices, this permission is not auto-granted at install time. If the tool fails, revoke and re-grant network permissions in Android Settings.

### Notification listener returns empty for pre-existing notifications

The notification listener service (`FerriNotificationListenerService`) only captures notifications that arrive after the service is enabled. Notifications that were already in the shade before enabling the listener are not accessible. This is an Android platform limitation.

### Revoking OS permission does not immediately sync with Ferri

If you revoke a permission (e.g., Calendar) through Android system settings while Ferri is running, the capability toggle inside the app may still show as enabled. The permission check happens at tool call time, so the next tool call will fail with a permission error. Restarting the app refreshes the capability state.

### Health Connect requires separate app on Android 13 and below

On Android 13 (API 33) and below, the Health Connect app must be installed from the Play Store for health tools to work. On Android 14+, Health Connect is built into the OS. If `health_check_availability` returns false, prompt the user to install Health Connect.

---

## Getting Help

If your issue is not listed here:

1. Check the [Go engine logs](#debugging-commands) for error details
2. Review the [Architecture Overview](Architecture-Overview.md) to understand the component that is failing
3. Search existing GitHub issues for similar problems
4. Open a new issue with: device model, Android version, the exact error message, and relevant logcat output
