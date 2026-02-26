# Getting Started with Ferri

This guide walks you through setting up Ferri from a fresh clone to a running app on your Android device or emulator. Ferri is a mobile-native AI agent app built with Flutter and Go. It compiles a Go agent engine into a shared library (`libferri.so`) via CGo, which Flutter loads at runtime through `dart:ffi`. The engine runs the AI agent loop and dispatches tool calls to native Android APIs via NativePort callbacks and platform channels.

---

## Prerequisites

Before you begin, make sure you have the following installed:

| Dependency | Version | Notes |
|---|---|---|
| Flutter | 3.22+ | Includes Dart SDK |
| Go | 1.22+ | Required for building the agent engine |
| Android SDK | API 24+ (Android 7.0) | Target and minimum SDK level |
| Android NDK | **28.2.13676358** | Exact version required -- CGo cross-compilation depends on specific NDK toolchain paths |
| Java / JDK | 17 | Required by the Android Gradle plugin |
| A physical Android device or emulator | API 26+ | API 26 is the minimum for the engine build; physical devices recommended for full capability testing |
| An LLM API key | Any supported provider | OpenRouter recommended for beginners (cheapest multi-model access) |

### Installing the NDK

The NDK version must be **exactly** `28.2.13676358`. Install it via Android Studio:

1. Open Android Studio > Settings > Languages & Frameworks > Android SDK > SDK Tools
2. Check "Show Package Details"
3. Under NDK (Side by side), select version `28.2.13676358`
4. Click Apply

Or install via the command line:

```bash
sdkmanager "ndk;28.2.13676358"
```

---

## Clone and Build

### 1. Clone the repository

```bash
git clone https://github.com/ferri-ai/ferri.git
cd ferri
```

### 2. Set the NDK path

Export the `NDK_HOME` environment variable pointing to the exact NDK version:

```bash
export NDK_HOME=/path/to/Android/sdk/ndk/28.2.13676358
```

Add this to your shell profile (`.bashrc`, `.zshrc`, etc.) so it persists across sessions.

### 3. Build the Go engine

The engine must be compiled as a C-shared library for the target architecture before Flutter can use it. The Makefile handles all the CGo cross-compilation flags.

**For physical devices (ARM64):**

```bash
make build-engine-android-arm64
```

This produces `android/app/src/main/jniLibs/arm64-v8a/libferri.so`.

**For emulators (x86_64):**

```bash
make build-engine-android-x86
```

This produces `android/app/src/main/jniLibs/x86_64/libferri.so`.

**For both architectures (release builds):**

```bash
make build-engine-android-all
```

### 4. Run the app

Connect a device or start an emulator, then:

```bash
flutter run
```

Or use the combined Make target that builds the engine and runs the app:

```bash
make run-android      # Builds arm64 engine, then runs
make run-android-emu  # Builds x86_64 engine, then runs
```

---

## Emulator Setup

You can use any Android emulator with API 26+. To create one:

1. Open Android Studio > Device Manager > Create Device
2. Select a device profile (e.g., Pixel 7)
3. Choose a system image with API 26 or higher (x86_64 recommended for performance)
4. Name it (e.g., `ferri_test`) and finish

Ferri includes convenience scripts that handle the emulator lifecycle and engine build automatically:

```bash
# Start emulator, detect architecture, build engine, run app
./scripts/start.sh

# Stop the emulator
./scripts/stop.sh
```

The `start.sh` script detects whether a device is already connected, launches the emulator if needed, waits for boot, detects the device architecture (arm64 vs x86_64), builds the correct engine variant, and runs the Flutter app.

---

## First Launch Walkthrough

When you open Ferri for the first time, you will go through a short onboarding flow:

### 1. Welcome Screen

A brief introduction to Ferri -- what it is and what it can do. Tap to continue.

### 2. Provider Selection

Choose your LLM provider and enter your API key. Supported providers:

- **OpenRouter** -- recommended for beginners; provides access to multiple models (Claude, GPT, Llama, etc.) through a single API key at competitive rates
- **Anthropic** -- direct access to Claude models
- **OpenAI** -- GPT models
- **Groq** -- fast inference for Llama and Mixtral models
- **DeepSeek** -- DeepSeek models
- **SambaNova** -- high-throughput inference
- **Google Gemini** -- Gemini models
- **Custom Endpoint** -- any OpenAI-compatible API endpoint

Enter your API key in the field provided.

### 3. Test Connection

Tap "Test Connection" to validate that your API key works before proceeding. The app sends a minimal request to the provider and confirms connectivity. You cannot proceed until this validation passes.

### 4. Main App Shell

After onboarding, you land in the main app with four tabs:

- **Home** -- status overview and quick actions
- **Chat** -- the main agent conversation interface with streaming responses and visible tool call cards
- **Automate** -- cron jobs and geofence-triggered automations
- **Settings** -- LLM provider config, capabilities, memory, and app preferences

### 5. Enable Capabilities

Navigate to **Settings > Capabilities** to enable the native phone capabilities you want the agent to use. Each capability (calendar, contacts, location, etc.) is independently toggleable. Enabling a capability will prompt for the corresponding Android permission on first use.

---

## Verifying the Build

### Check the Go engine initialized

```bash
adb logcat -s ferri:* *:S
```

On a successful launch, you should see output like:

```
[ferri] init: starting
[ferri] init: success
```

If you see no output, the engine failed to load. See the Troubleshooting guide.

### Test a basic prompt

Open the Chat tab and type:

```
What day is it?
```

The agent should respond with the current date. This confirms the engine is running, the FFI bridge is working, and the LLM API connection is active.

### Test a tool call

Enable the Calendar capability in Settings, then ask:

```
What's on my calendar today?
```

You should see a tool call card appear in the chat UI showing `calendar_read_events` being invoked. The agent will then summarize your calendar events. This confirms the full tool dispatch round-trip: Go engine -> NativePort callback -> Dart platform channel -> Kotlin native API -> result back to the agent.

---

## Useful Commands

```bash
# Run tests (Go engine + Dart)
make test

# Lint (Go vet + Flutter analyze)
make lint

# Build release APK
make build-apk

# Clean all build artifacts
make clean

# View Go engine logs
adb logcat -s ferri:* *:S

# View Flutter logs
adb logcat -s flutter:*

# View all app logs
adb logcat --pid=$(adb shell pidof com.ferri.ferri)

# Clear app data for a fresh start
adb shell pm clear com.ferri.ferri
```

---

## Common Setup Issues

### NDK not found / wrong version

**Symptom:** `make build-engine-android-arm64` fails with "NDK_HOME not set" or the compiler path does not exist.

**Fix:** Ensure `NDK_HOME` points to the exact NDK version directory:

```bash
export NDK_HOME=/path/to/Android/sdk/ndk/28.2.13676358
```

The NDK version must be `28.2.13676358`. Other versions have different toolchain layouts that break CGo cross-compilation.

### Go version mismatch

**Symptom:** Build errors referencing Go module version or language features.

**Fix:** Ferri requires Go 1.22 or later. Check your version:

```bash
go version
```

Upgrade if needed from [go.dev/dl](https://go.dev/dl/).

### libferri.so not found at runtime

**Symptom:** App crashes on launch with "cannot find libferri.so" or similar dynamic library loading errors.

**Fix:** You built the engine for the wrong architecture. Physical devices need `arm64`; emulators typically need `x86_64`:

```bash
# For physical device
make build-engine-android-arm64

# For emulator
make build-engine-android-x86
```

Rebuild the engine for the correct target and run the app again.

### Permission denied on first tool call

**Symptom:** A tool call returns an error like "permission denied" or "capability not enabled."

**Fix:** Two things must be true for a tool call to work:
1. The capability must be **enabled** in Settings > Capabilities
2. The corresponding **Android permission** must be granted when prompted

Go to Settings > Capabilities, toggle on the relevant capability, and grant the system permission when Android asks.

### Emulator not connecting

**Symptom:** `flutter devices` shows no connected devices; `./scripts/start.sh` times out.

**Fix:** Ensure the emulator is actually booted. Try launching it manually from Android Studio's Device Manager, then run `flutter devices` to confirm it appears. If using a physical device over WiFi ADB, make sure the device and your machine are on the same network.

---

## Next Steps

- Read the [Architecture Overview](Architecture-Overview) for a deep dive into the FFI bridge, tool dispatch, and engine internals.
- See [Capabilities Reference](Capabilities-Reference) for the full list of native APIs Ferri can access.
- Check [Troubleshooting](Troubleshooting) if you hit any issues.
