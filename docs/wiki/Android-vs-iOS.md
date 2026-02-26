# Android vs iOS

Platform differences, current implementation status, and iOS roadmap.

---

## Current Status

- **Android:** 79+ tools implemented and tested across 28+ capability domains. This is the primary platform.
- **iOS:** Planned. 67+ parity tools + 15 iOS-exclusive tools = 82+ total planned tools.

Android is the development and testing platform. iOS support will follow, leveraging the same Go engine compiled as a static library instead of a shared library.

---

## Feature Matrix

Android capabilities are tested. iOS capabilities are planned unless noted otherwise.

| Capability | Android | iOS | Notes |
|---|---|---|---|
| Calendar | Tested | Coming Soon | Android: CalendarProvider / iOS: EventKit |
| Contacts | Tested | Coming Soon | Android: ContactsContract / iOS: CNContactStore |
| Location | Tested | Coming Soon | Android: LocationManager / iOS: CoreLocation |
| SMS | Tested | Limited | iOS: compose-only via MFMessageComposeViewController |
| Camera | Tested | Coming Soon | Android: CameraX / iOS: AVFoundation |
| Health | Tested | Coming Soon | Android: Health Connect / iOS: HealthKit |
| Voice | Tested | Coming Soon | Cross-platform TTS/STT |
| Clipboard | Tested | Coming Soon | |
| Notifications | Tested | Coming Soon | |
| Bluetooth | Tested | Coming Soon | |
| Files | Tested | Coming Soon | |
| Sensors | Tested | Coming Soon | |
| Alarms | Tested | Coming Soon | |
| Device Info | Tested | Coming Soon | |
| Reminders | Tested | Coming Soon | |
| Call Log | Tested | N/A | Android only -- iOS has no call log API |
| Notification Listener | Tested | N/A | Android only -- iOS has no equivalent |
| Accessibility Service | Tested | N/A | Android only -- iOS has no equivalent |
| Usage Stats | Tested | N/A | Android only |
| Geofence | Tested | Coming Soon | |
| NFC | Skipped* | Coming Soon | *No NFC hardware on test device |
| Audio Control | Tested | Coming Soon | |
| WiFi | Tested | Coming Soon | |
| Maps | Tested | Coming Soon | |
| Phone | Tested | Limited | iOS: VoIP only via CallKit |
| Sharing | Tested | Coming Soon | |
| App Launcher | Tested | N/A | Android only |
| Email | Skipped* | Coming Soon | *Requires Gmail on device |

**Skipped*** means the capability is implemented but could not be tested on the current test device due to hardware or software constraints.

**N/A** means the capability is not possible on the platform due to OS restrictions.

**Limited** means partial functionality is possible but with significant restrictions compared to Android.

---

## iOS-Exclusive Features

These capabilities have no Android equivalent and will be unique to the iOS version.

| Feature | Description | Framework |
|---|---|---|
| Siri / App Intents | Voice integration, Spotlight indexing, Action Button support | App Intents (iOS 16+) |
| HomeKit | Smart home device control -- lights, locks, thermostats, cameras | HomeKit framework |
| Focus Filters | Adapt agent behavior based on the active Focus mode (Work, Personal, Sleep, etc.) | FocusFilter API |
| Live Activities | Real-time information on Lock Screen and Dynamic Island | ActivityKit (iOS 16+) |
| WidgetKit | Home screen widgets showing agent status, quick actions, or data summaries | WidgetKit |

These features represent areas where iOS provides APIs that Android does not, giving the iOS version unique capabilities once implemented.

---

## Architecture Differences

The core agent engine is the same Go codebase on both platforms. The differences are in how it is compiled, loaded, and how platform capabilities are accessed.

| Aspect | Android | iOS |
|---|---|---|
| Engine binary | `libferri.so` (shared library) | `libferri.a` (static library, planned) |
| Binary location | `android/app/src/main/jniLibs/` | `ios/Runner/libferri.a` (planned) |
| Build tool | NDK + CGo cross-compilation | Xcode + CGo cross-compilation |
| Background execution | Foreground Service (persistent, always-on) | BGProcessingTask (time-limited, OS-managed) |
| Channel bots | Always-on via foreground service | Requires companion server push notification |
| Permissions | Runtime dialogs + manual Settings grants | Purpose strings in Info.plist + system prompts |
| Privileged access | Accessibility, NotificationListener, UsageStats | No equivalents exist |
| Package format | APK / AAB | IPA |

### Engine Compilation

On Android, the Go engine is compiled to a shared library (`libferri.so`) using CGo with the Android NDK. The library is loaded at runtime via `dart:ffi`. Each architecture (arm64, x86_64) requires a separate compilation.

On iOS, the Go engine will be compiled to a static library (`libferri.a`) linked directly into the app binary at build time. This is required because iOS does not allow loading dynamic libraries at runtime (outside of system frameworks).

### Background Execution

This is the most significant platform difference for Ferri's functionality.

**Android** supports foreground services, which allow the app to run continuously in the background with a persistent notification. This enables:
- Always-on channel bots (Telegram, Discord, Slack)
- Continuous geofence monitoring
- Reliable cron-based automations
- Heartbeat prompts on schedule

**iOS** restricts background execution to specific, time-limited task types via BGProcessingTask and BGAppRefreshTask. The OS decides when and for how long background tasks run. This means:
- Channel bots cannot run persistently; they require a companion server to receive webhooks and send push notifications to wake the app
- Cron automations may have delayed execution depending on OS scheduling
- Geofence monitoring works natively via CoreLocation (the OS handles it)
- Heartbeat reliability depends on OS background task scheduling

### Permission Models

**Android** uses a mix of runtime permission dialogs (for standard permissions like Calendar, Contacts, Location) and manual Settings navigation (for privileged capabilities like Notification Listener, Accessibility Service, Usage Stats). Some capabilities require Play Store declaration forms (e.g., SMS read access).

**iOS** uses purpose strings (NSUsageDescription keys in Info.plist) that explain why the app needs each permission. The OS presents a system dialog with the purpose string. There are no "privileged" capabilities equivalent to Android's -- iOS simply does not expose Notification Listener, Accessibility Service, or Usage Stats APIs to third-party apps.

---

## Known Platform Constraints

Issues that affect functionality on each platform and how they are handled.

| Constraint | Platform | Impact | Mitigation |
|---|---|---|---|
| No persistent background execution | iOS | Channel bots, cron jobs may be delayed | BGProcessingTask + companion server push for channels |
| No call log API | iOS | Cannot read call history | Documented as N/A; not possible |
| No Accessibility Service equivalent | iOS | Cannot interact with other app UIs | Documented as N/A; not possible |
| No Notification Listener equivalent | iOS | Cannot read notifications from other apps | Documented as N/A; not possible |
| No Usage Stats equivalent | iOS | Cannot read app usage history | Documented as N/A; not possible |
| Health Connect app required | Android | Health tools fail without Health Connect installed | Runtime check with Play Store redirect prompt |
| SMS read restricted | Android | Reading SMS requires Play Store declaration form | Must submit use-case justification to Google |
| NFC background scanning | iOS | NFC only works in foreground, user-initiated | Document limitation; no background NFC triggers |
| SMS compose-only | iOS | Cannot read SMS, only open compose sheet | MFMessageComposeViewController is the only API available |
| VoIP-only phone calls | iOS | Cannot initiate standard phone calls programmatically | CallKit supports VoIP; standard calls require user action |

---

## iOS Development Roadmap

iOS implementation will proceed in phases:

1. **Engine port** -- Compile Go engine as static library for iOS arm64, verify FFI bridge
2. **Core capabilities** -- Calendar, Contacts, Location, Camera, Health, Voice, Clipboard, Notifications
3. **Extended capabilities** -- Bluetooth, Files, Sensors, Device Info, Reminders, Geofence, Maps, Sharing
4. **iOS-exclusive features** -- Siri/App Intents, HomeKit, Focus Filters, Live Activities, WidgetKit
5. **Background and channels** -- BGProcessingTask integration, companion server for channel push notifications
