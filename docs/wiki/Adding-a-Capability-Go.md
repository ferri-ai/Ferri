# Adding a Capability: Go Tool Schema

> Detailed guide to the Go engine layer — how platform tools are defined, registered, and dispatched.

---

## Overview

Most capabilities **don't require Go code changes**. Tools are registered dynamically from Dart via FFI. This page explains how that works and when you might need to touch Go code.

**Key files:**
- `engine/platform/tool.go` — `PlatformTool` implementation
- `engine/platform/dispatcher.go` — request/response dispatch to Dart
- `engine/platform/types.go` — `PlatformRequest` and `PlatformResponse` types
- `engine/mobile/bridge.go` — C-ABI FFI exports

---

## When You Don't Need Go Changes

If your capability follows the standard pattern (Dart channel calls Kotlin via platform channel), you don't need to modify Go code at all. The Dart layer registers tools with the engine via the existing `ferri_register_platform_tool` FFI function.

This covers the vast majority of capabilities.

---

## When You Do Need Go Changes

- Adding a **new built-in tool** that runs entirely in Go (no native API needed)
- Modifying the **agent loop** behavior
- Adding a new **LLM provider adapter**
- Changing the **tool dispatch mechanism**
- Modifying **cron/channel/memory** subsystems

**Important:** Engine changes require explicit maintainer approval per project rules.

---

## PlatformTool Structure

```go
// engine/platform/tool.go

type PlatformTool struct {
    name        string
    description string
    parameters  map[string]interface{}
    dispatcher  *Dispatcher
    notify      NotifyFunc
}

func NewPlatformTool(name, description string,
    parameters map[string]interface{},
    dispatcher *Dispatcher) *PlatformTool {
    return &PlatformTool{
        name:        name,
        description: description,
        parameters:  parameters,
        dispatcher:  dispatcher,
    }
}
```

`PlatformTool` implements the `tools.Tool` interface. The LLM sees `name`, `description`, and `parameters` when deciding which tools to call.

---

## Tool Execution Flow

When the LLM calls a platform tool:

```go
func (t *PlatformTool) Execute(ctx context.Context, args map[string]interface{}) *tools.ToolResult {
    // 1. Notify UI: tool starting
    t.sendNotification("tool_start", args, "", 0)

    start := time.Now()

    // 2. Dispatch to Dart (blocks until response)
    data, err := t.dispatcher.Dispatch(ctx, t.name, args)
    elapsed := time.Since(start)

    // 3. Notify UI: tool finished
    if err != nil {
        t.sendNotification("tool_end", args, err.Error(), elapsed)
        return tools.ErrorResult(err.Error()).WithError(err)
    }

    t.sendNotification("tool_end", args, data, elapsed)

    // 4. Return result to LLM
    return tools.NewToolResult(data)
}
```

**Key points:**
- `Dispatch()` blocks the goroutine until Dart responds or timeout
- UI notifications are sent for tool call cards in the chat
- Results are JSON strings passed through to the LLM

---

## The Dispatcher

The dispatcher handles async communication between Go and Dart:

```go
// engine/platform/dispatcher.go

func (d *Dispatcher) Dispatch(ctx context.Context, toolName string,
    params map[string]interface{}) (string, error) {

    // Generate unique request ID
    requestID := uuid.New().String()

    // Create result channel
    resultCh := make(chan PlatformResponse, 1)
    d.pending.Store(requestID, resultCh)
    defer d.pending.Delete(requestID)

    // Build and send request to Dart via NativePort
    req := PlatformRequest{
        RequestID: requestID,
        ToolName:  toolName,
        Params:    params,
    }
    reqJSON, _ := json.Marshal(req)
    d.postFunc(string(reqJSON))

    // Block until response, timeout, or cancellation
    select {
    case resp := <-resultCh:
        if !resp.Success {
            return "", fmt.Errorf("platform tool error: %s", resp.Error)
        }
        return resp.Data, nil
    case <-ctx.Done():
        return "", ctx.Err()
    case <-time.After(d.timeout):
        return "", fmt.Errorf("platform tool %q timed out", toolName)
    }
}
```

When Dart finishes processing, it calls `Resolve()` which sends the response to the waiting channel:

```go
func (d *Dispatcher) Resolve(requestID string, responseJSON string) error {
    val, ok := d.pending.Load(requestID)
    if !ok {
        return fmt.Errorf("no pending request for ID %s", requestID)
    }
    ch := val.(chan PlatformResponse)

    var resp PlatformResponse
    json.Unmarshal([]byte(responseJSON), &resp)
    ch <- resp
    return nil
}
```

---

## Request/Response Types

```go
// engine/platform/types.go

type PlatformRequest struct {
    RequestID string                 `json:"request_id"`
    ToolName  string                 `json:"tool_name"`
    Params    map[string]interface{} `json:"params"`
}

type PlatformResponse struct {
    RequestID string `json:"request_id"`
    Success   bool   `json:"success"`
    Data      string `json:"data"`   // JSON string of the tool result
    Error     string `json:"error"`  // Non-empty if success=false
}
```

`Data` is always a JSON string — not a parsed object. This allows tools to return any JSON structure.

---

## FFI Registration

Tools are registered from Dart via the C-ABI export in `bridge.go`:

```go
//export ferri_register_platform_tool
func ferri_register_platform_tool(
    cName *C.char,
    cDescription *C.char,
    cParametersJSON *C.char,
) {
    name := C.GoString(cName)
    description := C.GoString(cDescription)
    parametersJSON := C.GoString(cParametersJSON)

    var parameters map[string]interface{}
    json.Unmarshal([]byte(parametersJSON), &parameters)

    tool := NewPlatformTool(name, description, parameters, globalDispatcher)
    globalAgent.RegisterTool(tool)
}
```

Dart calls this function for each tool when a capability is enabled. The schema JSON becomes what the LLM sees.

---

## Tool Parameter Schema Format

Schemas use JSON Schema format:

```json
{
  "type": "object",
  "properties": {
    "query": {
      "type": "string",
      "description": "Search query"
    },
    "limit": {
      "type": "integer",
      "description": "Max results to return"
    }
  },
  "required": ["query"]
}
```

The `description` field in each property helps the LLM understand what to pass. Write clear, specific descriptions.

---

## Adding a Built-in Go Tool

If you need a tool that runs entirely in Go (no native API):

```go
// engine/core/tools/my_tool.go

type MyTool struct{}

func (t *MyTool) Name() string        { return "my_tool" }
func (t *MyTool) Description() string { return "Does something useful" }
func (t *MyTool) Parameters() map[string]interface{} {
    return map[string]interface{}{
        "type": "object",
        "properties": map[string]interface{}{
            "input": map[string]interface{}{
                "type":        "string",
                "description": "The input to process",
            },
        },
        "required": []string{"input"},
    }
}

func (t *MyTool) Execute(ctx context.Context, args map[string]interface{}) *tools.ToolResult {
    input, _ := args["input"].(string)
    // ... do work ...
    return tools.NewToolResult(`{"result": "done"}`)
}
```

Register it in the agent's tool list during initialization.

---

## Debugging

- **Go logs:** `adb logcat -s ferri:* *:S`
- **Dispatch issues:** Add `log.Printf` in `Dispatch()` and `Resolve()`
- **Timeout:** Default is 30 seconds. If a native API is slow, the tool will timeout.
- **Crash investigation:** Go panics show in logcat as `signal: SIGSEGV` — check for nil pointers in FFI boundary

---

**See also:** [Adding a Capability (Kotlin)](Adding-a-Capability-Kotlin), [Adding a Capability (Dart)](Adding-a-Capability-Dart), [Adding a Capability](Adding-a-Capability), [Go Engine Internals](Go-Engine-Internals)
