# State Management

Ferri uses Riverpod for all state management across the Flutter layer. This document covers the provider architecture, dependency graph, and conventions.

## Why Riverpod

Riverpod was chosen over alternatives (Provider, Bloc, GetX) for several reasons:

- **Compile-safe dependency injection.** Provider dependencies are resolved at compile time. If a provider is missing or incorrectly typed, the app fails to compile rather than crashing at runtime.
- **Built-in async support.** `FutureProvider` and `StreamProvider` handle loading and error states without boilerplate. The engine initialization, settings loading, and channel event streams all benefit from this.
- **Provider scoping and overrides.** Providers can be overridden in tests without modifying production code. This enables unit testing of providers in isolation from the Go engine.
- **Clean separation of business logic from UI.** All business logic lives in `StateNotifier` subclasses in `lib/providers/`. Screens are purely reactive -- they read state via `ref.watch()` and dispatch actions via `ref.read().method()`.

## Key Providers

All providers live in `lib/providers/`. Each file contains a `StateNotifier` subclass and a corresponding `StateNotifierProvider`.

### Settings Provider (`settings_provider.dart`)

Manages application configuration: LLM provider name, model, API base URL, and preference flags. API keys are stored in `FlutterSecureStorage` (Android Keystore-backed). Non-sensitive preferences use `SharedPreferences`.

State class: `AppSettings` with fields for `provider`, `model`, `apiBase`, `hasApiKey`, `onboardingComplete`, `toolApprovalRequired`, `showVisualBuilder`, and `backgroundServiceEnabled`.

### Engine Provider (`engine_provider.dart`)

Manages the Go engine lifecycle. Wraps `FerriEngine` (the FFI binding class) and exposes `EngineStatus` as state (`uninitialized`, `ready`).

Responsibilities:
- Initialize the engine with config JSON (workspace path, provider, model, API key)
- Forward token messages to the chat provider via `onTokenCallback`
- Register and unregister platform tools for capabilities
- Expose cron, heartbeat, and channel operations to other providers
- Handle destructive tool approval via `onApprovalRequired` callback

The engine re-initializes only when the API key changes, avoiding unnecessary restarts.

### Chat Provider (`chat_provider.dart`)

Manages the conversation UI state. State class: `ChatState` containing `List<ChatMessage>`, a `streamingMessage` for partial responses, and `AgentStatus` (`idle`, `thinking`, `streaming`).

Each `ChatMessage` has a `role` (`user`, `assistant`, `tool_call`, `automation`), `content`, `timestamp`, and optional `ToolCallInfo` for rendering tool call cards in the UI. The provider listens to token messages from the engine and appends them to the message list, managing the streaming lifecycle (start on first token, accumulate, finalize on `done`).

### Capabilities Provider (`capabilities_provider.dart`)

Manages which phone capabilities are enabled and their tool registrations. State class: `CapabilitiesState` with a `Map<String, CapabilityStatus>` tracking each capability's status.

On construction, this provider registers all Dart-side tool handlers with the engine. Each tool name maps to a static handler on the corresponding platform channel class (e.g., `calendar_read_events` maps to `CalendarChannel.handleToolCall`). When a capability is toggled:
1. Checks OS permission status via `PermissionManager`
2. Requests permission if not granted
3. On grant: calls `engine.registerCapabilityTools()` to register all tools for that capability with the Go engine via FFI
4. On disable: calls `engine.unregisterCapabilityTools()` to remove them
5. Persists enabled state to `SharedPreferences`

### Channels Provider (`channels_provider.dart`)

Manages bot connections for Telegram, Discord, and Slack. State class: `ChannelsState` with a `Map<ChannelType, ChannelState>` tracking each channel's `enabled`, `connectionStatus` (`disconnected`, `connecting`, `connected`, `error`), and `messageCount`.

Handles the connect/disconnect lifecycle: stores bot tokens in secure storage, calls `engine.enableChannel()` / `engine.disableChannel()`, listens to channel events from the Go engine (status changes, incoming messages, outbound responses), and manages the Android foreground service for persistent connections.

### Automation Provider (`automation_provider.dart`)

Manages cron jobs and geofence automations. Exposes CRUD operations that delegate to the engine's FFI exports: `cronList()`, `cronCreate()`, `cronDelete()`, `cronToggle()`, `triggerGeofence()`.

Data models (`CronScheduleModel`, `CronJobModel`) mirror the Go-side `CronJob` struct. The provider loads the job list from the engine on initialization and refreshes after mutations. Geofence jobs additionally interact with `GeofenceChannel` for native location monitoring registration.

### Memory Provider (`memory_provider.dart`)

Manages the agent's memory files. Reads and writes `MEMORY.md` and other workspace files through the filesystem. Used by the Settings > Memory screen to let users view and edit the agent's persistent memory.

### Skills Provider (`skills_provider.dart`)

Manages agent skills (loadable prompt/tool packages). State class: `SkillsState` with a `List<SkillInfo>` tracking each skill's name, description, source (`workspace`, `global`, `builtin`), and path. Delegates to the engine's FFI exports: `listSkills()`, `installSkill()`, `uninstallSkill()`.

### Connectivity Provider (`connectivity_provider.dart`)

Tracks whether the device currently has network connectivity. Uses the `connectivity_plus` package to listen for connectivity changes and exposes a simple `bool` state. Other providers can check this before attempting LLM API calls.

### App Lifecycle Provider (`app_lifecycle_provider.dart`)

Observes the Flutter app lifecycle (`resumed`, `paused`, `inactive`, `detached`) via `WidgetsBindingObserver`. Exposes the current `AppLifecycleState` so other providers and screens can react to the app being backgrounded or foregrounded.

## Provider Dependency Graph

```
Settings Provider
    └── Engine Provider (needs API key + provider config to initialize)
            ├── Chat Provider (needs engine to send messages, receives tokens)
            ├── Capabilities Provider (needs engine to register/unregister tools)
            ├── Channels Provider (needs engine for bot connections)
            ├── Automation Provider (needs engine for cron/geofence operations)
            └── Skills Provider (needs engine for skill install/uninstall)

Connectivity Provider (standalone, no dependencies)
App Lifecycle Provider (standalone, no dependencies)
```

`SettingsProvider` is the root -- it loads first from secure storage and shared preferences. `EngineProvider` depends on settings to construct the engine config JSON. All other providers depend on the engine being in the `ready` state before they can perform their operations.

## State Flow Example

**Trace: User enables the Calendar capability.**

1. User toggles Calendar on the Capabilities screen. The UI calls `ref.read(capabilitiesProvider.notifier).toggle('calendar')`.

2. `CapabilitiesNotifier.toggle()` checks current status. If disabled, it proceeds to enable.

3. The notifier calls `PermissionManager.request()` for the calendar permission group. This invokes the Android `ActivityCompat.requestPermissions()` via platform channel.

4. If the user grants permission, the notifier retrieves the `Capability` definition for calendar from `CapabilityRegistry`. This definition includes the tool list: `calendar_read_events`, `calendar_create_event`, `calendar_update_event`, `calendar_delete_event`.

5. The notifier calls `engine.registerCapabilityTools(capability)`. For each tool, the engine provider calls `FerriEngine.registerPlatformTool()`, which invokes the `ferri_register_platform_tool` FFI export. Go creates a `PlatformTool` and adds it to the agent's tool registry.

6. The tool handlers were already mapped during `CapabilitiesNotifier` construction: `calendar_read_events` routes to `CalendarChannel.handleToolCall`, which uses the `ferri/calendar` platform channel to invoke Kotlin code that queries the Android Calendar Provider.

7. The notifier updates state: `statuses['calendar'] = CapabilityStatus.enabled`. This triggers a UI rebuild -- the Capabilities screen shows Calendar as enabled.

8. The agent now has calendar tools available. When the user asks "What's on my calendar today?", the agent loop includes `calendar_read_events` in the tool definitions sent to the LLM, and the LLM can call it.

## Conventions

- Providers live in `lib/providers/`. Each file contains one `StateNotifier` and one `StateNotifierProvider`.
- Each provider has a single responsibility. Business logic stays in the notifier; screens are reactive.
- UI screens read providers via `ref.watch(providerName)` for reactive rebuilds.
- UI screens trigger actions via `ref.read(providerName.notifier).method()`.
- Sensitive data (API keys, bot tokens) is stored in `FlutterSecureStorage`, never in `SharedPreferences`.
- Provider state classes are immutable and use `copyWith` for updates.
- Async initialization (settings loading, engine init) uses the `loaded` flag pattern -- screens show loading indicators until the provider signals readiness.
