# Glossary

Term definitions for the Ferri project.

---

| Term | Definition |
|---|---|
| **Agent loop** | The core execution cycle: user prompt is sent to the LLM, the LLM decides to call tools, tools execute on-device, results return to the LLM, and the LLM generates a response. This repeats until the LLM has enough information to answer. |
| **Automation** | A scheduled (cron) or location-triggered (geofence) agent task that runs without manual user input. |
| **BYOK** | Bring Your Own Key. Users provide their own LLM API keys. Ferri has no backend and does not proxy API calls. |
| **Capability** | A domain of native phone functionality (e.g., Calendar, Contacts, Health) exposed as one or more tools. Each capability maps to a platform channel and can be independently enabled or disabled. |
| **Channel** | A messaging platform integration (Telegram, Discord, Slack) that allows interaction with the agent from outside the Ferri app. |
| **Cron job** | A time-scheduled automation using standard cron expressions (e.g., `0 9 * * *` for daily at 9 AM). |
| **FFI** | Foreign Function Interface. The mechanism by which Dart calls Go's C-exported functions directly, without going through platform channels. Used to invoke the Go engine. |
| **Foreground service** | An Android service type that keeps the app alive in the background with a persistent notification. Used for channels, automations, and heartbeats. |
| **Geofence** | A virtual geographic boundary that triggers an automation when the device enters or exits the defined area. |
| **Heartbeat** | A periodic agent check-in that runs a user-defined prompt on a configurable schedule. Uses the foreground service to execute reliably. |
| **libferri.so** | The compiled Go engine as an Android shared library, loaded at runtime via `dart:ffi`. On iOS (planned), this will be `libferri.a` (static library). |
| **Memory** | Persistent context files that the agent reads across conversations. User-editable in Settings. Sent to the LLM as part of the system prompt. |
| **NativePort** | A Dart mechanism for receiving asynchronous callbacks from native or FFI code. Used by the Go engine to send tool call requests back to Dart. |
| **PicoClaw** | The Go-based AI agent framework that Ferri's engine is derived from. Invisible to users; exists only in source attribution and LICENSE. |
| **Platform channel** | Flutter's mechanism for communication between Dart and native code (Kotlin on Android, Swift on iOS). Named with the `ferri/` prefix (e.g., `ferri/calendar`). |
| **Privileged capability** | A capability requiring manual activation in Android Settings rather than a standard runtime permission dialog. Includes Notification Listener, Accessibility Service, and Usage Stats. |
| **Tool** | A single callable function that the LLM can invoke during the agent loop (e.g., `calendar_read_events`, `contacts_search`). Each tool has a defined schema, parameters, and return type. |
| **Tool call card** | A UI element in the chat interface showing which tool was called, what parameters were sent, and what result was returned. Provides full transparency into agent data access. |
| **Tool dispatch** | The process of routing a Go-side tool call through the FFI bridge to Dart, then via platform channel to native APIs, and returning the result back through the same path. Round-trip latency is typically 5-50ms. |
