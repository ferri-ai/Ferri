# Go Engine Internals

Ferri's Go agent engine is derived from [PicoClaw](https://github.com/sipeed/picoclaw), adapted for mobile use.

## Origin

The engine originated as a desktop/server AI agent framework with CLI tools, shell execution, and hardware integrations. Ferri adapted it for mobile by stripping desktop-only subsystems (shell execution, I2C, SPI) and replacing them with a platform tool dispatch mechanism. Spawn and subagent capabilities exist in the codebase (pure Go goroutines) and are planned for future inclusion but are not registered in the current mobile build. Instead of calling native Linux APIs or shell commands, the engine dispatches tool calls across the FFI boundary to Dart, which routes them to Android and iOS native APIs via platform channels. The core agent loop, provider system, cron scheduler, channel manager, and memory system remain largely intact.

## Directory Structure

```
engine/
├── core/                  # Agent loop, tools, providers, memory, cron, channels
│   ├── agent/             # The agent loop itself
│   │   ├── loop.go        # Main agent loop and LLM iteration logic
│   │   ├── mobile.go      # Mobile-specific agent constructor
│   │   ├── context.go     # System prompt and context builder
│   │   └── memory.go      # Persistent memory store (MEMORY.md, daily notes)
│   ├── tools/             # Built-in tools (filesystem, web, cron, registry)
│   ├── providers/         # LLM provider adapters (HTTP, Anthropic, OpenAI-compat)
│   │   ├── factory.go     # Provider creation and selection logic
│   │   ├── http_provider.go   # Generic OpenAI-compatible HTTP provider
│   │   ├── anthropic/     # Native Anthropic API adapter
│   │   └── openai_compat/ # OpenAI-compatible provider adapter
│   ├── channels/          # Telegram, Discord, Slack integrations
│   │   ├── manager.go     # Channel lifecycle and message dispatch
│   │   ├── telegram.go    # Telegram bot via long-polling
│   │   ├── discord.go     # Discord bot via WebSocket
│   │   └── slack.go       # Slack bot via Socket Mode
│   ├── cron/              # Cron scheduler (1-second tick)
│   │   └── service.go     # Job store, scheduler loop, geofence triggers
│   ├── session/           # Conversation session management
│   │   └── manager.go     # Session history, summaries, persistence
│   ├── bus/               # Internal message bus (inbound/outbound channels)
│   ├── config/            # Configuration structs and defaults
│   ├── state/             # Atomic state persistence (last channel, etc.)
│   └── ...                # auth, logger, heartbeat, skills, utils
├── mobile/                # C-ABI bridge for FFI
│   └── bridge.go          # All //export functions, NativePort wiring
├── platform/              # Platform tool dispatch (Go side)
│   ├── dispatcher.go      # Routes tool calls to Dart, blocks for results
│   ├── tool.go            # PlatformTool — implements tools.Tool interface
│   └── types.go           # PlatformRequest / PlatformResponse structs
├── go.mod
└── go.sum
```

## The Agent Loop

The agent loop lives in `core/agent/loop.go` and is the central processing unit of the engine. It implements a standard LLM tool-use loop:

1. **Receive message.** A user message arrives either from the Flutter UI (via `ferri_send_message` FFI call), from a messaging channel (Telegram, Discord, Slack), or from the cron scheduler.

2. **Build context.** The `ContextBuilder` (`core/agent/context.go`) assembles the full prompt:
   - System prompt with agent identity, current time, runtime info, workspace path
   - Available tools section (dynamically generated from the tool registry)
   - Bootstrap files (`AGENTS.md`, `SOUL.md`, `USER.md`, `IDENTITY.md`) if present in workspace
   - Skills summary (loadable skill definitions from `skills/` directory)
   - Memory context: long-term memory (`memory/MEMORY.md`) and recent daily notes (last 3 days)
   - Conversation summary (if the session was previously summarized)
   - Session history (previous messages in this conversation)

3. **Call LLM.** The assembled messages and tool definitions are sent to the configured LLM provider via `provider.Chat()`. The call includes parameters like `max_tokens: 8192` and `temperature: 0.7`.

4. **Parse response.** If the LLM response contains no tool calls, the text content is the final answer. If it contains tool calls, execution continues.

5. **Execute tools.** For each tool call in the response:
   - The tool registry looks up the tool by name
   - `OnToolStart` callback fires (notifies Flutter UI)
   - The tool's `Execute` method is called with the parsed arguments
   - For platform tools, this triggers the dispatch-to-Dart round trip
   - For built-in tools (filesystem, web), execution happens in Go
   - `OnToolEnd` callback fires with the result and elapsed time
   - The result is appended to the message history as a `tool` role message

6. **Iterate.** The updated messages (now including tool call and result) are sent back to the LLM. This loop continues until the LLM produces a final text response without tool calls, or until `maxIterations` is reached.

7. **Return result.** The final text response is sent back to the caller. For mobile, this goes through the token NativePort as a JSON message with `type: "done"`.

The loop includes safeguards: a same-tool loop detector breaks if the LLM calls the same tool with identical arguments 3 times consecutively. Context window errors trigger automatic history compression, dropping the oldest 50% of messages and retrying.

The mobile variant (`core/agent/mobile.go`) constructs a stripped-down `AgentLoop` with only workspace-restricted filesystem tools and web tools (DuckDuckGo search, web fetch). Desktop-only tools (shell execution, I2C, SPI) are removed from the codebase. Spawn and subagent tools exist in the codebase but are not registered in the mobile build yet (planned for a future release). Platform tools (calendar, contacts, location, etc.) are registered dynamically at runtime via FFI.

## Platform Tool Registration

The `ferri_register_platform_tool` C export in `mobile/bridge.go` is the entry point for adding native phone capabilities as agent tools:

```go
//export ferri_register_platform_tool
func ferri_register_platform_tool(nameC *C.char, descC *C.char, schemaC *C.char) C.int
```

When Dart calls this function, Go:
1. Parses the tool name (`snake_case`, e.g. `calendar_read_events`), description, and JSON parameter schema
2. Creates a `platform.PlatformTool` wrapping the dispatcher
3. Sets a notification callback so tool start/end events reach the Flutter UI
4. Registers the tool with the agent loop's tool registry
5. Tracks the tool name in `platformToolNames` to avoid duplicate UI notifications

The corresponding `ferri_unregister_platform_tool` removes a tool from the registry when a capability is disabled.

## Tool Dispatch

When the agent loop calls a platform tool, the execution crosses the FFI boundary through the following sequence:

1. **Go: PlatformTool.Execute()** (`platform/tool.go`) is called by the agent loop. It emits a `tool_start` notification, then calls `dispatcher.Dispatch()`.

2. **Go: Dispatcher.Dispatch()** (`platform/dispatcher.go`) generates a UUID request ID, creates a buffered channel, stores it in a `sync.Map`, serializes the request as JSON (`PlatformRequest` with `request_id`, `tool_name`, `params`), and calls the `postFunc` to send it via NativePort. The goroutine then blocks on the channel with a 30-second timeout.

3. **Dart: ToolDispatcher** receives the JSON on the tool dispatch NativePort, deserializes it, looks up the handler by tool name, and invokes the appropriate platform channel method (e.g., `CalendarChannel.handleToolCall`).

4. **Dart to Native:** The platform channel invokes Kotlin/Swift code that calls the actual Android/iOS API.

5. **Dart: ToolDispatcher** receives the native result, wraps it in a `PlatformResponse` JSON with the original `request_id`, and calls `ferri_tool_result` via FFI.

6. **Go: Dispatcher.Resolve()** looks up the pending channel by request ID, deserializes the response, and sends it on the channel, unblocking the waiting goroutine.

7. **Go: PlatformTool.Execute()** receives the result, emits a `tool_end` notification, and returns a `ToolResult` to the agent loop.

The entire round trip typically takes 5-50ms for most API calls. The 30-second timeout prevents goroutine leaks if Dart fails to respond.

## Provider System

The engine supports multiple LLM providers through `core/providers/`. All mobile-relevant providers ultimately use the OpenAI-compatible chat completions API format. The provider factory (`factory.go`) selects the right provider based on configuration:

- **OpenRouter** -- Routes to `HTTPProvider` with `https://openrouter.ai/api/v1`
- **Anthropic** -- Routes to `HTTPProvider` with `https://api.anthropic.com/v1` (or a dedicated `ClaudeProvider` for OAuth flows)
- **OpenAI** -- Routes to `HTTPProvider` with `https://api.openai.com/v1`
- **Groq** -- Routes to `HTTPProvider` with `https://api.groq.com/openai/v1`
- **DeepSeek** -- Routes to `HTTPProvider` with `https://api.deepseek.com/v1`
- **SambaNova** -- Routes through `HTTPProvider` via `https://api.sambanova.ai/v1` (uses OpenRouter adapter internally)
- **Gemini** -- Routes to `HTTPProvider` with `https://generativelanguage.googleapis.com/v1beta`
- **Custom** -- Any OpenAI-compatible endpoint; routes through `HTTPProvider` with the user-supplied base URL

On mobile, the provider and API key are passed from Dart via the `MobileConfig` JSON in `ferri_init`. The `mobileConfigToConfig` function maps the mobile config to the full engine config struct, setting the appropriate provider fields. The provider is then created via `providers.CreateProvider(cfg)`.

Provider configuration metadata is shipped as a Flutter asset (`provider-metadata.json`) and rendered in the onboarding and settings screens. This file defines display names, required fields, default models, and placeholder text for each provider -- it is purely a UI concern and does not affect the Go engine.

## Cron Scheduler

The cron scheduler (`core/cron/service.go`) manages time-based and location-based automation jobs:

**Tick loop.** `CronService.runLoop` creates a `time.NewTicker(1 * time.Second)` and calls `checkJobs()` on every tick. Jobs whose `NextRunAtMS` is in the past are collected, their next-run times are cleared (preventing double execution), and they are executed outside the lock.

**Job types.** Each job has a `CronSchedule` with a `kind` field:
- `"at"` -- One-time execution at a specific Unix millisecond timestamp. Deleted after execution if `deleteAfterRun` is set.
- `"every"` -- Recurring execution at a fixed interval in milliseconds. Next run = now + interval.
- `"cron"` -- Standard cron expression (parsed by the `gronx` library). Next run computed via `gronx.NextTickAfter`.
- `"geofence"` -- No time-based scheduling. Triggered externally when the device enters or exits a geographic area. The `TriggerJob` method validates the job is enabled and of kind `"geofence"` before executing.

**Execution.** When a job fires, its prompt (`Payload.Message`) is sent through the agent loop via the `onJob` callback. On mobile, this callback calls `cronTool.ExecuteJob`, which processes the prompt with a 120-second timeout via `agentLoop.ProcessDirect`.

**Persistence.** Jobs are stored in `cron_store.json` within the workspace directory. The store is loaded on startup and saved after every mutation (add, remove, toggle, execution state update).

**FFI exports.** `ferri_cron_list`, `ferri_cron_create`, `ferri_cron_delete`, `ferri_cron_toggle`, and `ferri_trigger_geofence` expose full CRUD and trigger operations to Dart.

## Channel Manager

The channel manager (`core/channels/manager.go`) handles persistent connections to messaging platforms:

- **Telegram** -- Long-polling via the Telegram Bot API
- **Discord** -- WebSocket gateway connection
- **Slack** -- Socket Mode (WebSocket-based)

On mobile, channels are enabled dynamically via `ferri_enable_channel`. The first channel creation triggers setup of the `channels.Manager`, starts the outbound message dispatcher, and launches a consumer goroutine (`runChannelConsumer` in `bridge.go`).

The consumer goroutine reads from the message bus's inbound queue. When a message arrives from a channel, it:
1. Notifies Dart via the channel event NativePort (for Android notification display)
2. Processes the message through the agent loop with a 120-second timeout
3. Publishes the response to the bus's outbound queue
4. The channel manager's dispatcher picks up outbound messages and sends them back through the appropriate channel

Channels require the Android foreground service to maintain persistent connections when the app is backgrounded.

## Memory System

The memory system (`core/agent/memory.go`) provides persistent storage within the app's sandboxed workspace:

- **Long-term memory** -- `memory/MEMORY.md`. A single markdown file the agent can read and write. Used for persistent facts, preferences, and notes.
- **Daily notes** -- `memory/YYYYMM/YYYYMMDD.md`. Automatically organized by month. The agent can append to today's note.

The `ContextBuilder` loads memory into the system prompt automatically: long-term memory and the last 3 days of daily notes are included in every agent invocation. Users can view and edit memory files directly via the Settings > Memory screen in the Flutter UI.

Additionally, the workspace supports bootstrap files (`AGENTS.md`, `SOUL.md`, `USER.md`, `IDENTITY.md`) that are loaded into the system prompt if present. These allow users to customize the agent's personality and behavior.

## Building the Engine

The engine is cross-compiled from Go to a C shared library using CGo and the Android NDK:

```bash
# Cross-compile for Android ARM64 (physical devices)
NDK_HOME=/path/to/ndk/28.2.13676358 make build-engine-android-arm64

# Cross-compile for Android x86_64 (emulator)
NDK_HOME=/path/to/ndk/28.2.13676358 make build-engine-android-x86
```

The build process:
1. Sets `CGO_ENABLED=1`, `GOOS=android`, and `GOARCH=arm64` (or `amd64` for x86)
2. Uses the NDK's clang as the C compiler (`CC=aarch64-linux-android26-clang`)
3. Builds with `-buildmode=c-shared` to produce a shared library
4. Applies `-trimpath` and `-ldflags="-s -w"` to strip debug info and reduce binary size
5. Outputs `libferri.so` to `android/app/src/main/jniLibs/<abi>/`

The minimum Android API level is 26. The NDK version used is 28.2.13676358.

## Modifying the Engine

Most new capabilities do not require Go engine changes. The typical workflow for adding a new phone capability is:

1. Add the Kotlin platform channel handler (Android native API)
2. Add the Dart platform channel bridge
3. Register the capability and its tools in `capabilities_provider.dart`
4. Register tool handlers that route to the platform channel

The platform tool dispatch mechanism handles everything else -- the Go engine treats all platform tools uniformly.

Go engine changes are needed when:
- Adding new FFI exports (new `//export` functions in `bridge.go`)
- Modifying agent loop behavior (iteration limits, context building, summarization)
- Changing the provider system (new provider types, auth mechanisms)
- Modifying the cron scheduler (new job types, schedule kinds)
- Changing the channel manager (new channel integrations)

Engine changes require explicit maintainer review due to the cross-compilation complexity and the risk of breaking the FFI contract between Go and Dart.
