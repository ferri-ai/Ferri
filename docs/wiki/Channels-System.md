# Channels System

> **Status: TO BE TESTED.** The channels UI is implemented and the Go engine has channel manager support, but end-to-end bot functionality has not been verified in manual testing. The information below describes the intended design. Actual behavior may differ until testing is complete.

---

## What Are Channels?

Channels are messaging platform bots managed by Ferri. Instead of interacting with the AI agent only through the Ferri app, you can connect bots on Telegram, Discord, or Slack. Messages sent to these bots are processed through the same agent loop as in-app chat -- the agent has the same capabilities, the same tools, and the same context regardless of which channel the message arrives on.

This means you (or others with access to the bot) can talk to Ferri from any messaging app without opening the Ferri app itself.

---

## Supported Channels (To Be Tested)

| Platform | Connection Method | Token Source |
|----------|------------------|--------------|
| **Telegram** | Long-polling via Bot API | BotFather (`t.me/BotFather`) |
| **Discord** | WebSocket (Gateway) | Discord Developer Portal |
| **Slack** | WebSocket (Socket Mode) | Slack App Configuration |

All three platforms follow the same pattern: you create a bot on the platform, get a token, and enter it in Ferri.

---

## How It Works (Architecture)

The Go engine contains a channel manager that maintains persistent connections to each enabled platform.

1. **Connection:** When a channel is toggled on, the engine opens a connection to the platform -- WebSocket for Discord and Slack, long-polling for Telegram.
2. **Message receipt:** Incoming messages arrive through the persistent connection and are queued for processing.
3. **Agent loop:** Each incoming message is sent through the same agent loop used for in-app chat. The agent can use all registered tools (calendar, contacts, health data, etc.) just as it would from the app UI.
4. **Response:** The agent's response is sent back through the same channel to the originating platform.
5. **Tool calls:** Tool calls work identically to in-app chat. The full tool dispatch pipeline (Go engine -> Dart via NativePort -> platform channel -> native API -> result back to Go) operates the same way regardless of message source.

The key difference from in-app chat is that channels require the Go engine to be running continuously in the background to maintain the persistent connections. See [Background Execution](Background-Execution) for details.

---

## Setting Up a Channel

### Prerequisites

- Create a bot on the target platform and obtain its token:
  - **Telegram:** Message `@BotFather` on Telegram, use `/newbot`, copy the token.
  - **Discord:** Go to the Discord Developer Portal, create an application, add a bot, copy the token. Enable the required Gateway Intents (Message Content).
  - **Slack:** Create a Slack App at api.slack.com, enable Socket Mode, generate an app-level token and a bot token.

### In Ferri

1. Open **Settings > Channels**.
2. Select the platform (Telegram, Discord, or Slack).
3. Paste the bot token into the token field.
4. Toggle the channel **on**.
5. The status indicator should change to **Connected**.

If the status shows **Error**, check that:
- The token is correct and has not been revoked.
- The device has internet connectivity.
- The Background Service is enabled (see below).

---

## Background Requirements

Channels require the Android Foreground Service to be enabled. Without it, Android will kill the app process, and the bot connections will drop.

1. Go to **Settings > Background Service** and enable it.
2. A persistent notification will appear in the status bar showing the number of active channels and jobs.
3. With the foreground service running, the Go engine stays alive and maintains the bot connections.

If you disable the Background Service while channels are active, the connections will be lost. The channels will attempt to reconnect the next time the app is opened and the service is re-enabled.

**iOS note:** iOS does not allow persistent background processes for third-party apps. Persistent channel listeners will not work on iOS without a companion server or the app being in the foreground. This is a platform limitation that Ferri will be transparent about. See [Background Execution](Background-Execution) for the planned iOS approach.

---

## Channel UI

The **Settings > Channels** screen displays all configured channels. Each channel entry shows:

- **Platform icon and name** (Telegram, Discord, or Slack)
- **Status:** Connected, Disconnected, or Error
- **Toggle:** Enable or disable the channel independently
- **Token field:** Visible when editing

Channels can be toggled on and off independently. Disabling a channel closes its connection but preserves the token configuration. Re-enabling reconnects using the saved token.

---

## Security Considerations

- Bot tokens are stored locally in secure storage, same as LLM API keys.
- Anyone who can message your bot on the platform can interact with the agent. The agent will have access to the same tools and data as in-app chat. Consider this when sharing bot access.
- Messages sent through channels are processed on-device. Only the LLM API call leaves the phone (to your chosen provider). Platform-specific traffic (Telegram API, Discord Gateway, Slack WebSocket) also leaves the phone to maintain the bot connection.
