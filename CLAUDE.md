# Ferri

## What This Is

Mobile-native AI agent app (Flutter + Go). Adapts PicoClaw's Go agent engine inside a native app, registering phone OS capabilities as callable tools in the agent loop. An LLM that can read and act on your actual life data.

**Android first.** iOS later. The product is Ferri, the library is libferri.so.

## Architecture

```
Flutter UI (Dart/Riverpod)
    ↓ dart:ffi
libferri.so (Go, C-ABI)
    ↓ NativePort callback
Dart platform channels
    ↓
Android/iOS native APIs
    ↓
Cloud LLMs (user's API keys)
```

Tool dispatch: Go agent calls tool → Go callback → Dart via NativePort → platform channel → native API → result returns Dart → Go → agent continues. Round-trip ~5-50ms.

## SDK Paths

```bash
ANDROID_HOME=$HOME/Library/Android/sdk
NDK_HOME=$HOME/Library/Android/sdk/ndk/28.2.13676358
ADB=$HOME/Library/Android/sdk/platform-tools/adb
EMULATOR=$HOME/Library/Android/sdk/emulator/emulator
```

## Commands

```bash
# Build Go engine
NDK_HOME=$HOME/Library/Android/sdk/ndk/28.2.13676358 make build-engine-android-arm64

# Build targets
make build-engine-android-arm64
make build-engine-android-x86
make run-android
make test
make lint
```

### Physical Device (Realme RMX5313, WiFi ADB)

```bash
# Connect (already paired — port may change on phone restart)
$ADB connect 192.168.18.199:<port>

# Run app on phone
flutter run -d 192.168.18.199:45923

# Clear app data
$ADB -s 192.168.18.199:45923 shell pm clear com.ferri.ferri

# Logs
$ADB -s 192.168.18.199:45923 logcat -s ferri:* *:S             # Go engine
$ADB -s 192.168.18.199:45923 logcat -s flutter:*             # Flutter
$ADB -s 192.168.18.199:45923 logcat --pid=$($ADB -s 192.168.18.199:45923 shell pidof com.ferri.ferri)  # All app

# Install release APK
$ADB -s 192.168.18.199:45923 install build/app/outputs/flutter-apk/app-release.apk
```

### Emulator (ferri_test)

```bash
# Start/stop emulator + app
./scripts/start.sh
./scripts/stop.sh

# Clear app data
$ADB -s emulator-5554 shell pm clear com.ferri.ferri

# Logs
$ADB -s emulator-5554 logcat -s ferri:* *:S             # Go engine
$ADB -s emulator-5554 logcat -s flutter:*             # Flutter
$ADB -s emulator-5554 logcat --pid=$(adb shell pidof com.ferri.ferri)  # All app
```

```
Package: com.ferri.ferri
```

Prerequisites: Flutter 3.22+, Go 1.22+, Android SDK API 24+, NDK 28.2.13676358.

## Design Principles

1. **Tool calls visible in chat UI.** Users see what the agent accessed. Non-negotiable.
2. **One tool = one responsibility.** `calendar_read_events` not `phone_access`.
3. **Go defines interface; platform implements.** Go tool schemas → Dart platform channels execute.
4. **Platform capability flags.** Tools register only if available and permitted.
5. **Privacy-first.** On-device processing. Only LLM API calls leave the phone. No telemetry.
6. **Granular opt-in.** Each capability independently toggleable.

## Development Rules

- **Minimal code.** Achieve functionality with as little code as possible. Re-use existing modules, helpers, and patterns before writing new ones.
- **Don't break working features.** Before modifying any file, understand what it does and trace cascading effects. Never introduce regressions.
- **Explicit approval required.** Before implementing any feature or fix, present: (1) what will be done, (2) which files are affected, (3) what cascading effects it could have. Wait for approval.
- **Go engine changes need separate approval.** Any modifications to `engine/` require explicit sign-off.

## Code Conventions

- Platform channels: `ferri/<capability>` (e.g. `ferri/calendar`)
- Tool names: `snake_case` with domain prefix (e.g. `calendar_read_events`)
- Tool results: structured JSON
- State: Riverpod
- Adding a capability: Kotlin channel → Dart channel → registry entry + color → tool handlers in `capabilities_provider.dart` → `MainActivity.kt` registration

## Feature Tracking

**[docs/ferri_features_list.md](docs/ferri_features_list.md)** is the source of truth for Android vs iOS implementation status. **Update it whenever a feature/capability/tool is added, modified, or removed.**

## Brand

- **Primary:** Terracotta `#E8553A` | **Dark bg:** `#0D0E1A` | **Card:** `#14162A`
- **Fonts:** DM Serif Display (display), DM Sans (body), JetBrains Mono (code)
- **Success:** `#3AB879` | **Warning:** `#F5A623` | **Danger:** `#E05252`
- Colors defined in `lib/theme/colors.dart`

## Reference

- `docs/plans/` — Design docs and implementation plans
- `docs/ferri_features_list.md` — Cross-platform feature tracking
- `docs/ferri-capabilities.md` — Native capabilities reference
- `docs/ferri-architecture.md` — Architecture deep-dive
