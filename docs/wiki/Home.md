# Ferri

Ferri is a mobile-native AI agent app built with Flutter and a Go agent engine. It registers phone OS capabilities as callable tools in an LLM agent loop, giving an AI model the ability to read and act on your real life data -- calendar, contacts, location, health, notifications, and more -- directly from your phone.

Android is the primary platform. iOS support is planned.

---

## Working Features (Android)

### LLM Providers

Onboarding supports 7 providers plus custom endpoints, configured via metadata-driven setup:

- OpenRouter, Anthropic, OpenAI, Groq, DeepSeek, SambaNova, Gemini
- Custom endpoint (any OpenAI-compatible API)

### Chat

- Streaming token responses from the Go engine via FFI and NativePort
- Tool call visualization -- every tool invocation is displayed as an expandable card in the chat UI so users see exactly what the agent accessed

### Capabilities (28+ domains, 79+ tools)

| Domain | Tools |
|---|---|
| Calendar | Read, create, update, delete events |
| Contacts | Search, read, create, update, delete |
| Location | Current position, geocode, reverse geocode |
| SMS | Read inbox, send messages |
| Call Log | Read history, summary |
| Device Info | Info, battery, storage, connectivity, flashlight, brightness |
| Alarms | Set alarm, set timer, show alarms |
| Reminders | Set, list, cancel |
| App Launcher | Launch app, list installed apps |
| Camera | Capture photo, pick image from gallery |
| Voice | Text-to-speech, speech-to-text |
| Health Connect | Availability check, steps, heart rate, generic data reads |
| Clipboard | Read, write |
| Notifications | Send, schedule |
| Audio | Get/set volume, get/set mode, media control |
| Files | List, read, write, pick, delete |
| Maps | Open location, navigate |
| Phone Dialer | Dial number |
| Email Compose | Compose email |
| Sharing | Share text, share file |
| Sensors | List sensors, read sensor data |
| Bluetooth | State, paired devices, scan |
| WiFi | Get info, scan, get state |
| NFC | Read, write tags |
| Geofence | Create, list, remove geofences |
| Notification Listener | Read all app notifications (privileged) |
| Usage Stats | Query app usage, current foreground app (privileged) |
| Accessibility | Read screen, tap, scroll, type text (privileged) |

### Automation

- Cron jobs with visual builder
- Geofence triggers (create, list, remove) with automation wiring
- Heartbeat service (30-minute interval)

### Background Execution

Android Foreground Service keeps the agent, channels, cron scheduler, and automations alive when the app is not in the foreground. User-togglable in Settings.

### Settings

- LLM provider configuration and model selection
- Preferences
- Memory editor (view and edit the agent's workspace files)

---

## To Be Tested

- **Channels** -- Telegram, Discord, and Slack bot integration. The channel infrastructure (Go-side channel manager, Dart channel screens, background service wiring) is implemented but has not completed end-to-end testing across all three platforms.

---

## Coming Soon

- **iOS support** -- 58 parity tools plus 15 iOS-exclusive tools (73 total planned)
- **iOS-exclusive capabilities:**
  - Siri and App Intents integration
  - HomeKit smart home control
  - Focus Filters (adapt agent behavior to Focus mode)
  - Live Activities and Dynamic Island
  - WidgetKit home and lock screen widgets

---

## Quick Start

See **[Getting Started](Getting-Started)** for prerequisites, build instructions, and first-run setup.

---

## Wiki Pages

- [Getting Started](Getting-Started) -- Prerequisites, SDK setup, build and run
- [Architecture Overview](Architecture-Overview) -- System layers and data flow
- [Go Engine Internals](Go-Engine-Internals) -- Agent loop, tool registry, memory, cron
- [FFI Bridge and NativePort](FFI-Bridge-and-NativePort) -- Go-to-Dart bridge via C ABI and isolate ports
- [Tool Dispatch Pipeline](Tool-Dispatch-Pipeline) -- How a tool call travels from LLM to native API and back
- [State Management](State-Management) -- Riverpod provider architecture
- [Adding a Capability](Adding-a-Capability) -- Step-by-step guide to wiring a new native tool
  - [Adding a Capability: Kotlin](Adding-a-Capability-Kotlin) -- Android native handler
  - [Adding a Capability: Dart](Adding-a-Capability-Dart) -- Dart bridge and registration
  - [Adding a Capability: Go](Adding-a-Capability-Go) -- Go engine integration
- [Capabilities Reference](Capabilities-Reference) -- All 79+ tools with schemas and platform notes
- [LLM Providers](LLM-Providers) -- Supported providers, configuration, and custom endpoints
- [System Prompt](System-Prompt) -- How the system prompt is constructed
- [Channels System](Channels-System) -- Telegram, Discord, Slack bot integration
- [Automation System](Automation-System) -- Cron jobs, geofence triggers, heartbeat
- [Background Execution](Background-Execution) -- Android Foreground Service and iOS background strategies
- [Building for Release](Building-for-Release) -- APK/AAB build process and signing
- [Security Model](Security-Model) -- Privacy architecture, on-device processing, key storage
- [Android vs iOS](Android-vs-iOS) -- Platform parity tracking and platform-specific constraints
- [Troubleshooting](Troubleshooting) -- Common issues and debugging
- [FAQ](FAQ)
- [Glossary](Glossary)
