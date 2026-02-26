# Ferri

## What This Is

Mobile-native AI agent app (Flutter + Go). Wraps a Go agent engine inside a native app, registering phone OS capabilities as callable tools in the agent loop. An LLM that can read and act on your actual life data.

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

## Commands

```bash
# Build Go engine (set NDK_HOME to your NDK path)
NDK_HOME=$ANDROID_HOME/ndk/<version> make build-engine-android-arm64

# Build targets
make build-engine-android-arm64
make build-engine-android-x86
make run-android
make test
make lint
```

### ADB (Physical Device or Emulator)

```bash
# Clear app data
adb shell pm clear com.ferri.ferri

# Logs
adb logcat -s ferri:* *:S                                    # Go engine
adb logcat -s flutter:*                                      # Flutter
adb logcat --pid=$(adb shell pidof com.ferri.ferri)          # All app

# Install release APK
adb install build/app/outputs/flutter-apk/app-release.apk
```

```
Package: com.ferri.ferri
```

Prerequisites: Flutter 3.22+, Go 1.22+, Android SDK API 24+, NDK 28.x.

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
- **Understand before changing.** Before implementing any feature or fix, identify: (1) what will be done, (2) which files are affected, (3) what cascading effects it could have.
- **Go engine changes are sensitive.** Modifications to `engine/` should be reviewed carefully — they affect the core agent loop and FFI bridge.

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

- `docs/ferri_features_list.md` — Cross-platform feature tracking
- `docs/CAPABILITIES.md` — Native capabilities reference
- `docs/ARCHITECTURE.md` — Architecture deep-dive
