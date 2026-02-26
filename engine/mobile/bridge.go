package main

/*
#include <stdint.h>
#include <stdlib.h>
#include <android/log.h>

// Dart_Port is an int64 in Dart FFI
typedef int64_t Dart_Port;

// Dart_PostCObject is provided by Dart runtime, we call it via function pointer
typedef struct {
    int type;   // Dart_CObject enum: 0=Null,1=Bool,2=Int32,3=Int64,4=Double,5=String
    union {
        int64_t as_int;
        char* as_string;
    } value;
} Dart_CObject;

// We'll receive this function pointer from Dart
typedef int (*Dart_PostCObject_Type)(Dart_Port port, Dart_CObject* object);
static Dart_PostCObject_Type dart_post_c_object = NULL;
static Dart_Port token_port = 0;
static Dart_Port tool_dispatch_port = 0;
static Dart_Port channel_event_port = 0;

static void set_dart_post_fn(Dart_PostCObject_Type fn) {
    dart_post_c_object = fn;
}

static void set_token_port(Dart_Port port) {
    token_port = port;
}

static void set_tool_dispatch_port(Dart_Port port) {
    tool_dispatch_port = port;
}

static void set_channel_event_port(Dart_Port port) {
    channel_event_port = port;
}

static void post_channel_event(const char* str) {
    if (dart_post_c_object == NULL || channel_event_port == 0) return;
    Dart_CObject obj;
    obj.type = 5;  // Dart_CObject_kString
    obj.value.as_string = (char*)str;
    dart_post_c_object(channel_event_port, &obj);
}

static void post_string(const char* str) {
    if (dart_post_c_object == NULL || token_port == 0) return;
    Dart_CObject obj;
    obj.type = 5;  // Dart_CObject_kString
    obj.value.as_string = (char*)str;
    dart_post_c_object(token_port, &obj);
}

static void post_tool_request(const char* str) {
    if (dart_post_c_object == NULL || tool_dispatch_port == 0) return;
    Dart_CObject obj;
    obj.type = 5;  // Dart_CObject_kString
    obj.value.as_string = (char*)str;
    dart_post_c_object(tool_dispatch_port, &obj);
}

static void android_log(const char* msg) {
    __android_log_write(ANDROID_LOG_INFO, "ferri", msg);
}
*/
import "C"
import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"
	"unsafe"

	"ferri/engine/core/agent"
	"ferri/engine/core/bus"
	"ferri/engine/core/channels"
	"ferri/engine/core/config"
	"ferri/engine/core/cron"
	"ferri/engine/core/heartbeat"
	"ferri/engine/core/providers"
	"ferri/engine/core/skills"
	"ferri/engine/core/tools"
	"ferri/engine/platform"
)

// logcatWriter routes Go's log package output to Android logcat.
type logcatWriter struct{}

func (w logcatWriter) Write(p []byte) (n int, err error) {
	msg := strings.TrimRight(string(p), "\n")
	cStr := C.CString(msg)
	defer C.free(unsafe.Pointer(cStr))
	C.android_log(cStr)
	return len(p), nil
}

// logf writes to Android's logcat via __android_log_write.
func logf(format string, args ...interface{}) {
	msg := fmt.Sprintf(format, args...)
	cStr := C.CString(msg)
	defer C.free(unsafe.Pointer(cStr))
	C.android_log(cStr)
}

// TokenMessage is sent back to Dart via NativePort
type TokenMessage struct {
	Type      string `json:"type"`       // "token", "done", "error"
	Content   string `json:"content"`
	SessionID string `json:"session_id"`
}

// MobileConfig is the simplified config JSON that Dart sends via FFI.
type MobileConfig struct {
	Workspace   string `json:"workspace"`
	Provider    string `json:"provider"`
	Model       string `json:"model"`
	APIKey      string `json:"api_key"`
	APIBase     string `json:"api_base"`
	BraveAPIKey string `json:"brave_api_key"`
}

var (
	mu                    sync.Mutex
	agentLoop             *agent.AgentLoop
	parentCtx             context.Context
	parentCancel          context.CancelFunc
	platformDispatcher    *platform.Dispatcher
	platformToolNames     = make(map[string]bool) // tracks registered platform tools to avoid duplicate events
)

var (
	channelManager        *channels.Manager
	channelConsumerCancel context.CancelFunc
	bridgeDrainCancel     context.CancelFunc
)

var (
	cronService      *cron.CronService
	heartbeatService *heartbeat.HeartbeatService
)

//export ferri_init
func ferri_init(configJSON *C.char) C.int {
	mu.Lock()
	defer mu.Unlock()

	// Route Go's log package to Android logcat so log.Printf in
	// sub-packages (e.g. tools/web.go DDG search) appears in logcat.
	log.SetOutput(logcatWriter{})
	log.SetFlags(0) // logcat already adds timestamps

	logf("[ferri] init: starting")

	// Stop previous instance if re-initializing
	if agentLoop != nil {
		if bridgeDrainCancel != nil {
			bridgeDrainCancel()
			bridgeDrainCancel = nil
		}
		if channelConsumerCancel != nil {
			channelConsumerCancel()
			channelConsumerCancel = nil
		}
		if channelManager != nil {
			channelManager.StopAll(context.Background())
			channelManager = nil
		}
		if cronService != nil {
			cronService.Stop()
			cronService = nil
		}
		if heartbeatService != nil {
			heartbeatService.Stop()
			heartbeatService = nil
		}
		agentLoop.Stop()
		agentLoop = nil
	}
	if parentCancel != nil {
		parentCancel()
	}

	jsonStr := C.GoString(configJSON)

	// Parse mobile config
	var mc MobileConfig
	if err := json.Unmarshal([]byte(jsonStr), &mc); err != nil {
		logf("[ferri] init: config parse error: %s", err)
		sendToken(TokenMessage{Type: "error", Content: "Invalid config: " + err.Error()})
		return -1
	}

	logf("[ferri] init: provider=%s model=%s workspace=%s", mc.Provider, mc.Model, mc.Workspace)

	// Validate workspace path
	if err := os.MkdirAll(mc.Workspace, 0755); err != nil {
		logf("[ferri] init: workspace error: %s", err)
		sendToken(TokenMessage{Type: "error", Content: "Invalid workspace path: " + err.Error()})
		return -3
	}

	// Build full config from mobile config
	cfg := mobileConfigToConfig(&mc)

	// Create LLM provider
	provider, err := providers.CreateProvider(cfg)
	if err != nil {
		logf("[ferri] init: provider creation error: %s", err)
		sendToken(TokenMessage{Type: "error", Content: "Failed to create provider: " + err.Error()})
		return -2
	}

	// Create cancellable parent context for all in-flight operations
	parentCtx, parentCancel = context.WithCancel(context.Background())

	// Build web search options — Brave if key is provided, DDG always as fallback
	searchOpts := tools.WebSearchToolOptions{
		DuckDuckGoEnabled:    true,
		DuckDuckGoMaxResults: 5,
	}
	if mc.BraveAPIKey != "" {
		searchOpts.BraveEnabled = true
		searchOpts.BraveAPIKey = mc.BraveAPIKey
		searchOpts.BraveMaxResults = 5
		logf("[ferri] init: Brave Search enabled")
	}

	// Create mobile agent loop
	agentLoop = agent.NewMobileAgentLoop(
		mc.Workspace,
		provider,
		mc.Model,
		cfg.Agents.Defaults.MaxTokens,
		cfg.Agents.Defaults.MaxToolIterations,
		searchOpts,
	)

	// Wire tool event callbacks so Go-native tool executions (web_search,
	// web_fetch, filesystem) emit tool_event tokens for the Dart UI.
	// Platform tools already emit their own events via PlatformTool.sendNotification,
	// so we skip those here to avoid duplicates.
	agentLoop.OnToolStart = func(toolName string, args map[string]interface{}) {
		// Skip platform tools — they emit their own notifications
		if platformToolNames[toolName] {
			return
		}
		evt := map[string]interface{}{
			"type":        "tool_start",
			"tool_name":   toolName,
			"params":      args,
			"result":      "",
			"duration_ms": 0,
		}
		evtJSON, _ := json.Marshal(evt)
		sendToken(TokenMessage{Type: "tool_event", Content: string(evtJSON)})
	}
	agentLoop.OnToolEnd = func(toolName string, args map[string]interface{}, result string, elapsed time.Duration, isError bool) {
		if platformToolNames[toolName] {
			return
		}
		evt := map[string]interface{}{
			"type":        "tool_end",
			"tool_name":   toolName,
			"params":      args,
			"result":      result,
			"duration_ms": elapsed.Milliseconds(),
		}
		evtJSON, _ := json.Marshal(evt)
		sendToken(TokenMessage{Type: "tool_event", Content: string(evtJSON)})
	}

	// Replace the default bus drain with a goroutine that forwards outbound
	// messages to Dart as channel_response events (for cron, heartbeat, etc.)
	// This drain is stopped when a channel manager is created (enable_channel),
	// since the manager's dispatchOutbound takes over bus consumption.
	agentLoop.StopDraining()
	msgBus := agentLoop.GetBus()
	drainCtx, drainCancel := context.WithCancel(parentCtx)
	bridgeDrainCancel = drainCancel
	go func() {
		for {
			msg, ok := msgBus.SubscribeOutbound(drainCtx)
			if !ok {
				return
			}
			content := msg.Content
			if content == "" {
				continue
			}
			sendChannelEvent("channel_response", map[string]interface{}{
				"channel": msg.Channel,
				"chat_id": msg.ChatID,
				"content": content,
			})
		}
	}()

	// Create platform dispatcher for tool calls to Dart
	platformDispatcher = platform.NewDispatcher(func(jsonStr string) {
		cStr := C.CString(jsonStr)
		defer C.free(unsafe.Pointer(cStr))
		C.post_tool_request(cStr)
	}, 30*time.Second)

	// Initialize CronService
	cronService = cron.NewCronService(filepath.Join(mc.Workspace, "cron_store.json"), nil)
	cronTool := tools.NewCronTool(cronService, agentLoop, agentLoop.GetBus(), mc.Workspace, true, 60*time.Second, cfg)
	agentLoop.RegisterTool(cronTool)
	cronService.SetOnJob(func(job *cron.CronJob) (string, error) {
		ctx, cancel := context.WithTimeout(parentCtx, 120*time.Second)
		defer cancel()
		result := cronTool.ExecuteJob(ctx, job)
		return result, nil
	})
	if err := cronService.Start(); err != nil {
		logf("[ferri] init: cron service start error: %s", err)
	}

	// Initialize HeartbeatService (disabled by default, user enables via FFI)
	heartbeatService = heartbeat.NewHeartbeatService(mc.Workspace, 30, false)
	heartbeatService.SetBus(agentLoop.GetBus())
	heartbeatService.SetHandler(func(prompt, channel, chatID string) *tools.ToolResult {
		ctx, cancel := context.WithTimeout(parentCtx, 120*time.Second)
		defer cancel()
		response, err := agentLoop.ProcessHeartbeat(ctx, prompt, channel, chatID)
		if err != nil {
			return tools.ErrorResult(fmt.Sprintf("heartbeat error: %v", err))
		}
		return tools.SilentResult(response)
	})

	logf("[ferri] init: cron + heartbeat services initialized")
	logf("[ferri] init: success")
	return 0
}

//export ferri_init_dart_api
func ferri_init_dart_api(postCObject unsafe.Pointer) {
	C.set_dart_post_fn(C.Dart_PostCObject_Type(postCObject))
}

//export ferri_set_token_port
func ferri_set_token_port(port C.int64_t) {
	C.set_token_port(C.Dart_Port(port))
}

//export ferri_set_tool_dispatch_port
func ferri_set_tool_dispatch_port(port C.int64_t) {
	C.set_tool_dispatch_port(C.Dart_Port(port))
}

//export ferri_set_channel_event_port
func ferri_set_channel_event_port(port C.int64_t) {
	C.set_channel_event_port(C.Dart_Port(port))
}

//export ferri_send_message
func ferri_send_message(message *C.char, sessionID *C.char) C.int {
	mu.Lock()
	al := agentLoop
	pCtx := parentCtx
	mu.Unlock()

	if al == nil {
		sendToken(TokenMessage{Type: "error", Content: "Engine not initialized"})
		return -1
	}

	msg := C.GoString(message)
	sid := C.GoString(sessionID)

	go func() {
		logf("[ferri] send: processing message (session=%s)", sid)

		// Derive cancellable context with 90s timeout so the UI never gets stuck
		ctx, cancel := context.WithTimeout(pCtx, 90*time.Second)
		defer cancel()

		response, err := al.ProcessDirect(ctx, msg, sid)
		if err != nil {
			logf("[ferri] send: error: %s", err)
			sendToken(TokenMessage{
				Type:      "error",
				Content:   err.Error(),
				SessionID: sid,
			})
			return
		}

		logf("[ferri] send: response received (len=%d)", len(response))

		// Send the full response as a token
		sendToken(TokenMessage{
			Type:      "token",
			Content:   response,
			SessionID: sid,
		})

		// Send done signal
		sendToken(TokenMessage{
			Type:      "done",
			Content:   "",
			SessionID: sid,
		})
	}()

	return 0
}

//export ferri_get_history
func ferri_get_history(sessionKeyC *C.char) *C.char {
	mu.Lock()
	al := agentLoop
	mu.Unlock()

	if al == nil {
		return C.CString("[]")
	}

	sessionKey := C.GoString(sessionKeyC)
	history := al.GetSessions().GetHistory(sessionKey)

	data, err := json.Marshal(history)
	if err != nil {
		return C.CString("[]")
	}
	return C.CString(string(data))
}

//export ferri_register_platform_tool
func ferri_register_platform_tool(nameC *C.char, descC *C.char, schemaC *C.char) C.int {
	mu.Lock()
	defer mu.Unlock()

	if agentLoop == nil || platformDispatcher == nil {
		logf("[ferri] register_platform_tool: engine not initialized")
		return -1
	}

	name := C.GoString(nameC)
	desc := C.GoString(descC)
	schemaStr := C.GoString(schemaC)

	var schema map[string]interface{}
	if err := json.Unmarshal([]byte(schemaStr), &schema); err != nil {
		logf("[ferri] register_platform_tool: schema parse error: %s", err)
		return -2
	}

	tool := platform.NewPlatformTool(name, desc, schema, platformDispatcher)
	tool.SetNotifyFunc(func(jsonStr string) {
		sendToken(TokenMessage{Type: "tool_event", Content: jsonStr})
	})
	agentLoop.RegisterTool(tool)
	platformToolNames[name] = true

	logf("[ferri] register_platform_tool: registered %s", name)
	return 0
}

//export ferri_unregister_platform_tool
func ferri_unregister_platform_tool(nameC *C.char) C.int {
	mu.Lock()
	defer mu.Unlock()

	if agentLoop == nil {
		return -1
	}

	name := C.GoString(nameC)
	agentLoop.UnregisterTool(name)
	delete(platformToolNames, name)
	logf("[ferri] unregister_platform_tool: unregistered %s", name)
	return 0
}

//export ferri_tool_result
func ferri_tool_result(requestIDC *C.char, resultJSONC *C.char) {
	requestID := C.GoString(requestIDC)
	resultJSON := C.GoString(resultJSONC)

	if platformDispatcher == nil {
		logf("[ferri] tool_result: dispatcher not initialized")
		return
	}

	if err := platformDispatcher.Resolve(requestID, resultJSON); err != nil {
		logf("[ferri] tool_result: resolve error: %s", err)
	}
}

//export ferri_enable_channel
func ferri_enable_channel(nameC *C.char, configJSONC *C.char) C.int {
	mu.Lock()
	defer mu.Unlock()

	if agentLoop == nil {
		logf("[ferri] enable_channel: engine not initialized")
		return -1
	}

	name := C.GoString(nameC)
	configJSON := C.GoString(configJSONC)
	msgBus := agentLoop.GetBus()

	logf("[ferri] enable_channel: %s", name)

	// First channel: set up channel manager and consumer
	if channelManager == nil {
		// Stop the bridge drain goroutine so the channel manager's
		// dispatchOutbound becomes the sole bus consumer
		if bridgeDrainCancel != nil {
			bridgeDrainCancel()
			bridgeDrainCancel = nil
		}

		// Create channel manager with empty config (no auto-init channels)
		cfg := config.DefaultConfig()
		var err error
		channelManager, err = channels.NewManager(cfg, msgBus)
		if err != nil {
			logf("[ferri] enable_channel: manager creation error: %s", err)
			return -3
		}

		// Forward internal channel messages (cli, cron, heartbeat) to Dart
		// so they still appear in the mobile UI even after the bridge drain
		// is replaced by the channel manager's dispatcher.
		channelManager.SetInternalMessageHandler(func(msg bus.OutboundMessage) {
			if msg.Content == "" {
				return
			}
			sendChannelEvent("channel_response", map[string]interface{}{
				"channel": msg.Channel,
				"chat_id": msg.ChatID,
				"content": msg.Content,
			})
		})

		// Start only the outbound dispatcher (not StartAll, which exits early
		// when no channels are registered yet — channels are added dynamically)
		channelManager.StartDispatcher(parentCtx)

		// Start channel consumer goroutine (pass agentLoop to avoid global access race)
		consumerCtx, cancel := context.WithCancel(parentCtx)
		channelConsumerCancel = cancel
		go runChannelConsumer(consumerCtx, agentLoop)

		logf("[ferri] enable_channel: manager and consumer started")
	}

	// Create and register the channel based on name
	var ch channels.Channel
	var err error

	switch name {
	case "telegram":
		var tc config.TelegramConfig
		if err := json.Unmarshal([]byte(configJSON), &tc); err != nil {
			logf("[ferri] enable_channel: telegram config parse error: %s", err)
			return -2
		}
		tc.Enabled = true
		cfg := config.DefaultConfig()
		cfg.Channels.Telegram = tc
		ch, err = channels.NewTelegramChannel(cfg, msgBus)

	case "discord":
		var dc config.DiscordConfig
		if err := json.Unmarshal([]byte(configJSON), &dc); err != nil {
			logf("[ferri] enable_channel: discord config parse error: %s", err)
			return -2
		}
		dc.Enabled = true
		ch, err = channels.NewDiscordChannel(dc, msgBus)

	case "slack":
		var sc config.SlackConfig
		if err := json.Unmarshal([]byte(configJSON), &sc); err != nil {
			logf("[ferri] enable_channel: slack config parse error: %s", err)
			return -2
		}
		sc.Enabled = true
		ch, err = channels.NewSlackChannel(sc, msgBus)

	default:
		logf("[ferri] enable_channel: unsupported channel: %s", name)
		return -4
	}

	if err != nil {
		logf("[ferri] enable_channel: creation error: %s", err)
		sendChannelEvent("channel_status", map[string]interface{}{
			"channel": name,
			"status":  "error",
			"error":   err.Error(),
		})
		return -5
	}

	// Stop existing channel if re-enabling (prevents goroutine leak)
	if existingCh, exists := channelManager.GetChannel(name); exists {
		existingCh.Stop(context.Background())
		channelManager.UnregisterChannel(name)
	}

	// Register and start
	channelManager.RegisterChannel(name, ch)
	if err := ch.Start(parentCtx); err != nil {
		logf("[ferri] enable_channel: start error: %s", err)
		channelManager.UnregisterChannel(name)
		sendChannelEvent("channel_status", map[string]interface{}{
			"channel": name,
			"status":  "error",
			"error":   err.Error(),
		})
		return -6
	}

	logf("[ferri] enable_channel: %s started successfully", name)
	sendChannelEvent("channel_status", map[string]interface{}{
		"channel": name,
		"status":  "connected",
	})
	return 0
}

//export ferri_disable_channel
func ferri_disable_channel(nameC *C.char) C.int {
	mu.Lock()
	defer mu.Unlock()

	if channelManager == nil {
		return -1
	}

	name := C.GoString(nameC)
	logf("[ferri] disable_channel: %s", name)

	ch, exists := channelManager.GetChannel(name)
	if !exists {
		return -2
	}

	ch.Stop(context.Background())
	channelManager.UnregisterChannel(name)

	sendChannelEvent("channel_status", map[string]interface{}{
		"channel": name,
		"status":  "disconnected",
	})

	logf("[ferri] disable_channel: %s stopped", name)
	return 0
}

//export ferri_get_channel_status
func ferri_get_channel_status() *C.char {
	mu.Lock()
	defer mu.Unlock()

	status := make(map[string]interface{})
	if channelManager != nil {
		status = channelManager.GetStatus()
	}

	data, _ := json.Marshal(status)
	return C.CString(string(data))
}

// ---- Cron FFI exports ----

//export ferri_cron_list
func ferri_cron_list() *C.char {
	mu.Lock()
	cs := cronService
	mu.Unlock()

	if cs == nil {
		errJSON, _ := json.Marshal(map[string]interface{}{"error": "cron service not initialized"})
		return C.CString(string(errJSON))
	}

	jobs := cs.ListJobs(true)
	resp := map[string]interface{}{
		"jobs":  jobs,
		"count": len(jobs),
	}
	data, _ := json.Marshal(resp)
	return C.CString(string(data))
}

//export ferri_cron_create
func ferri_cron_create(jobJSONC *C.char) *C.char {
	mu.Lock()
	cs := cronService
	mu.Unlock()

	if cs == nil {
		errJSON, _ := json.Marshal(map[string]interface{}{"error": "cron service not initialized"})
		return C.CString(string(errJSON))
	}

	jobJSON := C.GoString(jobJSONC)

	var req struct {
		Name     string            `json:"name"`
		Schedule cron.CronSchedule `json:"schedule"`
		Payload  struct {
			Message string `json:"message"`
			Deliver bool   `json:"deliver"`
			Channel string `json:"channel"`
			To      string `json:"to"`
		} `json:"payload"`
	}
	if err := json.Unmarshal([]byte(jobJSON), &req); err != nil {
		errJSON, _ := json.Marshal(map[string]interface{}{"error": fmt.Sprintf("invalid JSON: %v", err)})
		return C.CString(string(errJSON))
	}

	job, err := cs.AddJob(req.Name, req.Schedule, req.Payload.Message, req.Payload.Deliver, req.Payload.Channel, req.Payload.To)
	if err != nil {
		errJSON, _ := json.Marshal(map[string]interface{}{"error": fmt.Sprintf("failed to add job: %v", err)})
		return C.CString(string(errJSON))
	}

	resp := map[string]interface{}{
		"success": true,
		"job":     job,
	}
	data, _ := json.Marshal(resp)
	logf("[ferri] cron_create: job %s created", job.ID)
	return C.CString(string(data))
}

//export ferri_cron_delete
func ferri_cron_delete(jobIDC *C.char) *C.char {
	mu.Lock()
	cs := cronService
	mu.Unlock()

	if cs == nil {
		errJSON, _ := json.Marshal(map[string]interface{}{"error": "cron service not initialized"})
		return C.CString(string(errJSON))
	}

	jobID := C.GoString(jobIDC)
	removed := cs.RemoveJob(jobID)

	resp := map[string]interface{}{
		"success": removed,
	}
	if !removed {
		resp["error"] = fmt.Sprintf("job %s not found", jobID)
	}
	data, _ := json.Marshal(resp)
	logf("[ferri] cron_delete: job %s removed=%v", jobID, removed)
	return C.CString(string(data))
}

//export ferri_cron_toggle
func ferri_cron_toggle(jobIDC *C.char, enabled C.int) *C.char {
	mu.Lock()
	cs := cronService
	mu.Unlock()

	if cs == nil {
		errJSON, _ := json.Marshal(map[string]interface{}{"error": "cron service not initialized"})
		return C.CString(string(errJSON))
	}

	jobID := C.GoString(jobIDC)
	en := enabled != 0
	job := cs.EnableJob(jobID, en)

	if job == nil {
		errJSON, _ := json.Marshal(map[string]interface{}{
			"success": false,
			"error":   fmt.Sprintf("job %s not found", jobID),
		})
		return C.CString(string(errJSON))
	}

	resp := map[string]interface{}{
		"success": true,
		"enabled": job.Enabled,
	}
	data, _ := json.Marshal(resp)
	logf("[ferri] cron_toggle: job %s enabled=%v", jobID, en)
	return C.CString(string(data))
}

//export ferri_trigger_geofence
func ferri_trigger_geofence(jobIDC *C.char) *C.char {
	mu.Lock()
	cs := cronService
	mu.Unlock()

	if cs == nil {
		errJSON, _ := json.Marshal(map[string]interface{}{"error": "cron service not initialized"})
		return C.CString(string(errJSON))
	}

	jobID := C.GoString(jobIDC)
	err := cs.TriggerJob(jobID)

	if err != nil {
		errJSON, _ := json.Marshal(map[string]interface{}{
			"success": false,
			"error":   err.Error(),
		})
		return C.CString(string(errJSON))
	}

	resp := map[string]interface{}{
		"success": true,
	}
	data, _ := json.Marshal(resp)
	logf("[ferri] trigger_geofence: job %s triggered", jobID)
	return C.CString(string(data))
}

// ---- Heartbeat FFI exports ----

//export ferri_heartbeat_set_enabled
func ferri_heartbeat_set_enabled(enabled C.int) *C.char {
	mu.Lock()
	hs := heartbeatService
	mu.Unlock()

	if hs == nil {
		errJSON, _ := json.Marshal(map[string]interface{}{"error": "heartbeat service not initialized"})
		return C.CString(string(errJSON))
	}

	en := enabled != 0
	hs.SetEnabled(en)
	if en {
		if err := hs.Start(); err != nil {
			errJSON, _ := json.Marshal(map[string]interface{}{
				"success": false,
				"error":   fmt.Sprintf("failed to start heartbeat: %v", err),
			})
			return C.CString(string(errJSON))
		}
	} else {
		hs.Stop()
	}

	resp := map[string]interface{}{
		"success": true,
		"enabled": en,
	}
	data, _ := json.Marshal(resp)
	logf("[ferri] heartbeat_set_enabled: enabled=%v", en)
	return C.CString(string(data))
}

//export ferri_heartbeat_set_interval
func ferri_heartbeat_set_interval(minutes C.int) *C.char {
	mu.Lock()
	hs := heartbeatService
	mu.Unlock()

	if hs == nil {
		errJSON, _ := json.Marshal(map[string]interface{}{"error": "heartbeat service not initialized"})
		return C.CString(string(errJSON))
	}

	m := int(minutes)
	hs.SetInterval(m)

	resp := map[string]interface{}{
		"success":          true,
		"interval_minutes": hs.GetIntervalMinutes(),
	}
	data, _ := json.Marshal(resp)
	logf("[ferri] heartbeat_set_interval: %d min", hs.GetIntervalMinutes())
	return C.CString(string(data))
}

//export ferri_heartbeat_get_status
func ferri_heartbeat_get_status() *C.char {
	mu.Lock()
	hs := heartbeatService
	mu.Unlock()

	if hs == nil {
		errJSON, _ := json.Marshal(map[string]interface{}{"error": "heartbeat service not initialized"})
		return C.CString(string(errJSON))
	}

	resp := map[string]interface{}{
		"enabled":          hs.IsRunning(),
		"interval_minutes": hs.GetIntervalMinutes(),
	}
	data, _ := json.Marshal(resp)
	return C.CString(string(data))
}

//export ferri_heartbeat_get_prompt
func ferri_heartbeat_get_prompt() *C.char {
	mu.Lock()
	al := agentLoop
	mu.Unlock()

	if al == nil {
		errJSON, _ := json.Marshal(map[string]interface{}{"error": "engine not initialized"})
		return C.CString(string(errJSON))
	}

	heartbeatPath := filepath.Join(al.GetWorkspace(), "HEARTBEAT.md")
	data, err := os.ReadFile(heartbeatPath)
	if err != nil {
		if os.IsNotExist(err) {
			resp := map[string]interface{}{
				"prompt": "",
			}
			respJSON, _ := json.Marshal(resp)
			return C.CString(string(respJSON))
		}
		errJSON, _ := json.Marshal(map[string]interface{}{"error": fmt.Sprintf("failed to read HEARTBEAT.md: %v", err)})
		return C.CString(string(errJSON))
	}

	resp := map[string]interface{}{
		"prompt": string(data),
	}
	respJSON, _ := json.Marshal(resp)
	return C.CString(string(respJSON))
}

//export ferri_heartbeat_set_prompt
func ferri_heartbeat_set_prompt(markdownC *C.char) *C.char {
	mu.Lock()
	al := agentLoop
	mu.Unlock()

	if al == nil {
		errJSON, _ := json.Marshal(map[string]interface{}{"error": "engine not initialized"})
		return C.CString(string(errJSON))
	}

	markdown := C.GoString(markdownC)
	heartbeatPath := filepath.Join(al.GetWorkspace(), "HEARTBEAT.md")

	if err := os.WriteFile(heartbeatPath, []byte(markdown), 0644); err != nil {
		errJSON, _ := json.Marshal(map[string]interface{}{"error": fmt.Sprintf("failed to write HEARTBEAT.md: %v", err)})
		return C.CString(string(errJSON))
	}

	resp := map[string]interface{}{
		"success": true,
	}
	data, _ := json.Marshal(resp)
	logf("[ferri] heartbeat_set_prompt: updated HEARTBEAT.md (%d bytes)", len(markdown))
	return C.CString(string(data))
}

// ---- Skills FFI exports ----

//export ferri_list_skills
func ferri_list_skills() *C.char {
	mu.Lock()
	al := agentLoop
	mu.Unlock()

	if al == nil {
		errJSON, _ := json.Marshal(map[string]interface{}{"error": "engine not initialized"})
		return C.CString(string(errJSON))
	}

	loader := al.GetContextBuilder().GetSkillsLoader()
	skillsList := loader.ListSkills()

	var items []map[string]interface{}
	for _, s := range skillsList {
		items = append(items, map[string]interface{}{
			"name":        s.Name,
			"description": s.Description,
			"source":      s.Source,
			"path":        s.Path,
		})
	}

	resp := map[string]interface{}{
		"skills": items,
		"count":  len(items),
	}
	data, _ := json.Marshal(resp)
	return C.CString(string(data))
}

//export ferri_install_skill
func ferri_install_skill(repoC *C.char) *C.char {
	mu.Lock()
	al := agentLoop
	mu.Unlock()

	if al == nil {
		errJSON, _ := json.Marshal(map[string]interface{}{"error": "engine not initialized"})
		return C.CString(string(errJSON))
	}

	repo := C.GoString(repoC)
	installer := skills.NewSkillInstaller(al.GetWorkspace())

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if err := installer.InstallFromGitHub(ctx, repo); err != nil {
		errJSON, _ := json.Marshal(map[string]interface{}{
			"success": false,
			"error":   err.Error(),
		})
		return C.CString(string(errJSON))
	}

	resp := map[string]interface{}{
		"success": true,
		"name":    filepath.Base(repo),
	}
	data, _ := json.Marshal(resp)
	logf("[ferri] install_skill: installed %s", repo)
	return C.CString(string(data))
}

//export ferri_uninstall_skill
func ferri_uninstall_skill(nameC *C.char) *C.char {
	mu.Lock()
	al := agentLoop
	mu.Unlock()

	if al == nil {
		errJSON, _ := json.Marshal(map[string]interface{}{"error": "engine not initialized"})
		return C.CString(string(errJSON))
	}

	name := C.GoString(nameC)
	installer := skills.NewSkillInstaller(al.GetWorkspace())

	if err := installer.Uninstall(name); err != nil {
		errJSON, _ := json.Marshal(map[string]interface{}{
			"success": false,
			"error":   err.Error(),
		})
		return C.CString(string(errJSON))
	}

	resp := map[string]interface{}{
		"success": true,
		"name":    name,
	}
	data, _ := json.Marshal(resp)
	logf("[ferri] uninstall_skill: removed %s", name)
	return C.CString(string(data))
}

//export ferri_clear_session
func ferri_clear_session(sessionKeyC *C.char) *C.char {
	mu.Lock()
	al := agentLoop
	mu.Unlock()

	if al == nil {
		errJSON, _ := json.Marshal(map[string]interface{}{"error": "engine not initialized"})
		return C.CString(string(errJSON))
	}

	sessionKey := C.GoString(sessionKeyC)
	sessions := al.GetSessions()
	sessions.TruncateHistory(sessionKey, 0)
	sessions.SetSummary(sessionKey, "")
	if err := sessions.Save(sessionKey); err != nil {
		errJSON, _ := json.Marshal(map[string]interface{}{
			"success": false,
			"error":   fmt.Sprintf("failed to save session: %v", err),
		})
		return C.CString(string(errJSON))
	}

	resp := map[string]interface{}{"success": true}
	data, _ := json.Marshal(resp)
	logf("[ferri] clear_session: cleared session %s", sessionKey)
	return C.CString(string(data))
}

//export ferri_free_string
func ferri_free_string(s *C.char) {
	C.free(unsafe.Pointer(s))
}

//export ferri_stop
func ferri_stop() {
	mu.Lock()
	defer mu.Unlock()

	// Stop channel consumer and manager
	if channelConsumerCancel != nil {
		channelConsumerCancel()
		channelConsumerCancel = nil
	}
	if channelManager != nil {
		channelManager.StopAll(context.Background())
		channelManager = nil
	}

	// Stop cron and heartbeat services
	if cronService != nil {
		cronService.Stop()
		cronService = nil
	}
	if heartbeatService != nil {
		heartbeatService.Stop()
		heartbeatService = nil
	}

	// Cancel all in-flight LLM operations first
	if parentCancel != nil {
		parentCancel()
		parentCancel = nil
	}
	// Then stop the agent loop (closes bus, drain goroutine)
	if agentLoop != nil {
		agentLoop.Stop()
		agentLoop = nil
	}
	platformDispatcher = nil
	platformToolNames = make(map[string]bool)
}

func sendToken(msg TokenMessage) {
	data, err := json.Marshal(msg)
	if err != nil {
		return
	}
	cStr := C.CString(string(data))
	defer C.free(unsafe.Pointer(cStr))
	C.post_string(cStr)
}

func sendChannelEvent(eventType string, data map[string]interface{}) {
	evt := map[string]interface{}{
		"type": eventType,
	}
	for k, v := range data {
		evt[k] = v
	}
	evtJSON, err := json.Marshal(evt)
	if err != nil {
		return
	}
	cStr := C.CString(string(evtJSON))
	defer C.free(unsafe.Pointer(cStr))
	C.post_channel_event(cStr)
}

// runChannelConsumer processes inbound messages from channels.
// It consumes from the message bus, sends events to Dart, processes via the agent,
// and publishes responses back to the bus for channel dispatch.
// The AgentLoop is passed as a parameter to avoid accessing the global without mutex.
func runChannelConsumer(ctx context.Context, al *agent.AgentLoop) {
	logf("[ferri] channel consumer: started")
	msgBus := al.GetBus()
	for {
		// ConsumeInbound blocks until a message arrives or ctx is cancelled.
		// No select{default:} wrapper — we want this to block properly.
		msg, ok := msgBus.ConsumeInbound(ctx)
		if !ok {
			logf("[ferri] channel consumer: stopped")
			return
		}

		logf("[ferri] channel consumer: message from %s (sender=%s)", msg.Channel, msg.SenderID)

		// Notify Dart: channel_message (for notification)
		sendChannelEvent("channel_message", map[string]interface{}{
			"channel":   msg.Channel,
			"sender":    msg.SenderID,
			"chat_id":   msg.ChatID,
			"content":   msg.Content,
			"timestamp": time.Now().UnixMilli(),
		})

		// Process through agent
		msgCtx, msgCancel := context.WithTimeout(ctx, 120*time.Second)
		response, err := al.ProcessDirectWithChannel(
			msgCtx, msg.Content, msg.SessionKey, msg.Channel, msg.ChatID,
		)
		msgCancel()

		if err != nil {
			logf("[ferri] channel consumer: error: %s", err)
			response = fmt.Sprintf("Error processing message: %v", err)
		}

		if response != "" {
			// Publish to bus outbound for channel manager to dispatch
			msgBus.PublishOutbound(bus.OutboundMessage{
				Channel: msg.Channel,
				ChatID:  msg.ChatID,
				Content: response,
			})

			// Notify Dart: channel_response
			sendChannelEvent("channel_response", map[string]interface{}{
				"channel": msg.Channel,
				"chat_id": msg.ChatID,
				"content": response[:min(len(response), 200)],
			})
		}
	}
}

func mobileConfigToConfig(mc *MobileConfig) *config.Config {
	cfg := config.DefaultConfig()
	cfg.Agents.Defaults.Workspace = mc.Workspace
	cfg.Agents.Defaults.Provider = mc.Provider
	cfg.Agents.Defaults.Model = mc.Model
	cfg.Agents.Defaults.RestrictToWorkspace = true

	// Set API key on the appropriate provider config
	switch strings.ToLower(mc.Provider) {
	case "openrouter":
		cfg.Providers.OpenRouter.APIKey = mc.APIKey
		if mc.APIBase != "" {
			cfg.Providers.OpenRouter.APIBase = mc.APIBase
		}
	case "anthropic", "claude":
		cfg.Providers.Anthropic.APIKey = mc.APIKey
		if mc.APIBase != "" {
			cfg.Providers.Anthropic.APIBase = mc.APIBase
		}
	case "openai", "gpt":
		cfg.Providers.OpenAI.APIKey = mc.APIKey
		if mc.APIBase != "" {
			cfg.Providers.OpenAI.APIBase = mc.APIBase
		}
	case "groq":
		cfg.Providers.Groq.APIKey = mc.APIKey
		if mc.APIBase != "" {
			cfg.Providers.Groq.APIBase = mc.APIBase
		}
	case "gemini", "google":
		cfg.Providers.Gemini.APIKey = mc.APIKey
		if mc.APIBase != "" {
			cfg.Providers.Gemini.APIBase = mc.APIBase
		}
	case "deepseek":
		cfg.Providers.DeepSeek.APIKey = mc.APIKey
		if mc.APIBase != "" {
			cfg.Providers.DeepSeek.APIBase = mc.APIBase
		}
	case "sambanova":
		cfg.Providers.OpenRouter.APIKey = mc.APIKey
		cfg.Providers.OpenRouter.APIBase = "https://api.sambanova.ai/v1"
		if mc.APIBase != "" {
			cfg.Providers.OpenRouter.APIBase = mc.APIBase
		}
		cfg.Agents.Defaults.Provider = "openrouter"
	case "custom":
		// Custom endpoints route through OpenRouter's HTTPProvider with the
		// user-supplied base URL. This works because HTTPProvider handles any
		// OpenAI-compatible endpoint.
		cfg.Providers.OpenRouter.APIKey = mc.APIKey
		if mc.APIBase != "" {
			cfg.Providers.OpenRouter.APIBase = mc.APIBase
		}
		cfg.Agents.Defaults.Provider = "openrouter"
	default:
		// Fallback: try openrouter
		cfg.Providers.OpenRouter.APIKey = mc.APIKey
		if mc.APIBase != "" {
			cfg.Providers.OpenRouter.APIBase = mc.APIBase
		}
	}

	return cfg
}

func main() {} // Required for cgo
