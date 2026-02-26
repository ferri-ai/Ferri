package platform

import (
	"context"
	"encoding/json"
	"time"

	"ferri/engine/core/tools"
)

// NotifyFunc sends a notification string (JSON) to the UI layer.
type NotifyFunc func(jsonStr string)

// PlatformTool implements tools.Tool for platform-dispatched tools.
// When the LLM calls this tool, it dispatches the request through the
// platform dispatcher to Dart, which routes it to the appropriate Android API.
type PlatformTool struct {
	name        string
	description string
	parameters  map[string]interface{}
	dispatcher  *Dispatcher
	notify      NotifyFunc
}

func NewPlatformTool(name, description string, parameters map[string]interface{}, dispatcher *Dispatcher) *PlatformTool {
	return &PlatformTool{
		name:        name,
		description: description,
		parameters:  parameters,
		dispatcher:  dispatcher,
	}
}

// SetNotifyFunc sets the callback for tool_start/tool_end notifications.
func (t *PlatformTool) SetNotifyFunc(fn NotifyFunc) {
	t.notify = fn
}

func (t *PlatformTool) Name() string                       { return t.name }
func (t *PlatformTool) Description() string                { return t.description }
func (t *PlatformTool) Parameters() map[string]interface{} { return t.parameters }

func (t *PlatformTool) Execute(ctx context.Context, args map[string]interface{}) *tools.ToolResult {
	// Notify UI: tool_start
	t.sendNotification("tool_start", args, "", 0)

	start := time.Now()
	data, err := t.dispatcher.Dispatch(ctx, t.name, args)
	elapsed := time.Since(start)

	if err != nil {
		t.sendNotification("tool_end", args, err.Error(), elapsed)
		return tools.ErrorResult(err.Error()).WithError(err)
	}

	// Notify UI: tool_end
	t.sendNotification("tool_end", args, data, elapsed)
	return tools.NewToolResult(data)
}

func (t *PlatformTool) sendNotification(eventType string, params map[string]interface{}, result string, duration time.Duration) {
	if t.notify == nil {
		return
	}
	msg := map[string]interface{}{
		"type":       eventType,
		"tool_name":  t.name,
		"params":     params,
		"result":     result,
		"duration_ms": duration.Milliseconds(),
	}
	data, err := json.Marshal(msg)
	if err != nil {
		return
	}
	t.notify(string(data))
}
