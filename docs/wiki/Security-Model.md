# Security Model

How Ferri handles security, privacy, and user data protection.

---

## Privacy-First Architecture

Ferri has no backend server. There is zero server infrastructure -- no relay, no proxy, no analytics endpoint. The app runs entirely on-device with one exception: outbound LLM API calls.

- **No telemetry.** No usage analytics, no crash reporting, no tracking of any kind.
- **No Ferri servers.** There is nothing to breach because there is nothing hosted.
- **The only network traffic is LLM API calls** to the provider the user configures (OpenAI, Anthropic, Google, OpenRouter, Groq, DeepSeek, SambaNova, or a custom endpoint).
- **All tool execution happens on-device.** When the agent reads your calendar, queries your contacts, or checks your health data, that data is processed locally. It never leaves the phone except as context sent to the LLM.
- **Minimal context sent to the LLM.** Only the data needed for the current conversation is included in API calls. Tool results are included as context so the LLM can reason about them, but raw data dumps are avoided.

This is not a privacy policy -- it is an architectural constraint. There is no server to send data to even if the code wanted to.

---

## API Key Storage

User-provided LLM API keys are stored using `flutter_secure_storage`, which is backed by platform-specific secure storage:

- **Android:** Android Keystore system (hardware-backed on supported devices)
- **iOS (planned):** iOS Keychain Services

Keys are never written to SharedPreferences, plain files, or any other unencrypted storage. They are sent only to the configured LLM provider endpoint during API calls. There is no key validation server -- when a user tests their key, the validation request goes directly to the provider (e.g., OpenAI, Anthropic) without any intermediary.

---

## Permission Model

Ferri uses granular opt-in permissions. Each capability is independently toggleable, and capabilities are grouped into three tiers:

### Core Capabilities
Standard Android runtime permissions requested via the OS dialog:
- Calendar, Contacts, Location, Camera, Microphone, Phone, Files, Sensors

### Extended Capabilities
Additional permissions that may require specific declarations:
- SMS, Bluetooth, NFC, WiFi, Audio Control

### Privileged Capabilities
Permissions that cannot be granted via a standard dialog. The user must navigate to Android Settings and manually enable them:
- **Notification Listener** -- read incoming notifications from all apps
- **Accessibility Service** -- interact with other app UIs
- **Usage Stats** -- access app usage history

The permission model enforces a strict rule: **tools register only when their capability is enabled AND the corresponding permission is granted.** If a user disables the Calendar capability in Ferri's settings, the `calendar_read_events`, `calendar_create_event`, and related tools are unregistered from the agent. The LLM cannot call them because it does not know they exist -- they are removed from the tool schema entirely, not just blocked at execution time.

Re-enabling a capability re-registers its tools and prompts for any missing OS permissions.

---

## Tool Call Transparency

Every tool call the agent makes is visible in the chat UI as an expandable card. This is a non-negotiable design principle, not optional UI chrome.

Each tool call card shows:
- **Tool name** -- which tool was invoked (e.g., `calendar_read_events`)
- **Parameters** -- what arguments were sent to the tool (e.g., date range, search query)
- **Result** -- what data the tool returned

Users see exactly what the agent accessed and what data it received before reading the LLM's response. There is no hidden data access. If the agent read your contacts, you see the contact query and the results in the chat.

---

## Destructive Action Approval

Ferri distinguishes between read and write operations. Modifying operations -- creating, updating, or deleting calendar events, contacts, reminders, and other user data -- can require explicit approval.

This is configurable in Settings under "Approve destructive actions":

- **When enabled:** Any modifying tool call (e.g., `calendar_update_event`, `contacts_delete`) displays an approval dialog before execution. The user must tap "Approve" for the action to proceed. Declining cancels the operation and the agent is informed the action was rejected.
- **When disabled:** All tool calls execute without prompting. This is faster but removes the safety net for write operations.

The default is enabled. Power users who trust their prompts and want faster execution can disable it.

---

## Data Flow Summary

Understanding what stays on the device and what crosses the network:

### Stays on device
- All capability data (calendar events, contacts, health metrics, location history, sensor readings, files, clipboard, notifications, call logs, app usage stats)
- Tool execution logic and results
- Chat history and conversation state
- Memory files (persistent context the agent reads across sessions)
- API keys (encrypted in secure storage)
- Automation definitions (cron jobs, geofences)
- All configuration and settings

### Sent to LLM provider
- The user's message text
- Tool call results included as context for the LLM to reason about
- System prompt and memory content (so the LLM has persistent context)
- Conversation history within the current session (for multi-turn context)

The user chooses which LLM provider receives this data. Using a local LLM (via the Custom Endpoint provider pointed at Ollama, llama.cpp, or similar running on the local network) means nothing leaves the device at all.

---

## Threat Model Boundaries

Ferri's security model protects against:
- **Data exfiltration to Ferri** -- impossible, no server exists
- **Unauthorized capability access** -- tools only register when permitted
- **Silent data access** -- tool call cards make all access visible
- **Accidental destructive actions** -- approval dialogs gate write operations

Ferri's security model does NOT protect against:
- **LLM provider data handling** -- once data reaches OpenAI, Anthropic, etc., their privacy policies apply
- **Device compromise** -- if the phone itself is compromised, all bets are off
- **Prompt injection** -- the LLM may be manipulated by crafted input; tool call transparency mitigates but does not prevent this
