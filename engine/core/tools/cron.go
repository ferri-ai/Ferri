package tools

import (
	"context"
	"fmt"
	"sync"
	"time"

	"ferri/engine/core/bus"
	"ferri/engine/core/config"
	"ferri/engine/core/cron"
	"ferri/engine/core/utils"
)

// JobExecutor is the interface for executing cron jobs through the agent
type JobExecutor interface {
	ProcessDirectWithChannel(ctx context.Context, content, sessionKey, channel, chatID string) (string, error)
}

// CronTool provides scheduling capabilities for the agent
type CronTool struct {
	cronService *cron.CronService
	executor    JobExecutor
	msgBus      *bus.MessageBus
	execTool    *ExecTool
	restrict    bool // true on mobile — disables shell command execution
	channel     string
	chatID      string
	mu          sync.RWMutex
}

// NewCronTool creates a new CronTool
// execTimeout: 0 means no timeout, >0 sets the timeout duration
func NewCronTool(cronService *cron.CronService, executor JobExecutor, msgBus *bus.MessageBus, workspace string, restrict bool, execTimeout time.Duration, config *config.Config) *CronTool {
	var execTool *ExecTool
	if !restrict {
		// Only create ExecTool on desktop — Android has no shell
		execTool = NewExecToolWithConfig(workspace, restrict, config)
		execTool.SetTimeout(execTimeout)
	}
	return &CronTool{
		cronService: cronService,
		executor:    executor,
		msgBus:      msgBus,
		execTool:    execTool,
		restrict:    restrict,
	}
}

// Name returns the tool name
func (t *CronTool) Name() string {
	return "cron"
}

// Description returns the tool description
func (t *CronTool) Description() string {
	base := "Schedule future reminders or recurring tasks. Use this ONLY when the user wants to be actively notified or prompted at a specific time (e.g., 'remind me in 10 minutes', 'alert me every day at 9am'). Do NOT use this when the user wants you to remember/store a fact about them — that goes in memory (MEMORY.md). Example: 'remember I go to gym at 9am' = memory, 'remind me to go to gym at 9am' = cron. Use 'at_seconds' for one-time reminders. Use 'every_seconds' for recurring tasks. Use 'cron_expr' for complex schedules."
	if !t.restrict {
		base += " Use 'command' to execute shell commands directly."
	}
	return base
}

// Parameters returns the tool parameters schema
func (t *CronTool) Parameters() map[string]interface{} {
	props := map[string]interface{}{
		"action": map[string]interface{}{
			"type":        "string",
			"enum":        []string{"add", "list", "remove", "enable", "disable"},
			"description": "Action to perform. Use 'add' when user wants to schedule a reminder or task.",
		},
		"message": map[string]interface{}{
			"type":        "string",
			"description": "The reminder/task message to display when triggered.",
		},
		"at_seconds": map[string]interface{}{
			"type":        "integer",
			"description": "One-time reminder: seconds from now when to trigger (e.g., 600 for 10 minutes later). Use this for one-time reminders like 'remind me in 10 minutes'.",
		},
		"every_seconds": map[string]interface{}{
			"type":        "integer",
			"description": "Recurring interval in seconds (e.g., 3600 for every hour). Use this ONLY for recurring tasks like 'every 2 hours' or 'daily reminder'.",
		},
		"cron_expr": map[string]interface{}{
			"type":        "string",
			"description": "Cron expression for complex recurring schedules (e.g., '0 9 * * *' for daily at 9am). Use this for complex recurring schedules.",
		},
		"job_id": map[string]interface{}{
			"type":        "string",
			"description": "Job ID (for remove/enable/disable)",
		},
		"deliver": map[string]interface{}{
			"type":        "boolean",
			"description": "If true, send message directly to channel (for simple channel bots). If false (default), let agent process the message — this allows the agent to call tools like voice_speak, send notifications, etc. Use false for mobile/voice tasks.",
		},
	}

	// Only expose 'command' parameter on desktop (shell not available on mobile)
	if !t.restrict {
		props["command"] = map[string]interface{}{
			"type":        "string",
			"description": "Optional: Shell command to execute directly (e.g., 'df -h'). If set, the agent will run this command and report output instead of just showing the message. 'deliver' will be forced to false for commands.",
		}
	}

	return map[string]interface{}{
		"type":       "object",
		"properties": props,
		"required":   []string{"action"},
	}
}

// SetContext sets the current session context for job creation
func (t *CronTool) SetContext(channel, chatID string) {
	t.mu.Lock()
	defer t.mu.Unlock()
	t.channel = channel
	t.chatID = chatID
}

// Execute runs the tool with the given arguments
func (t *CronTool) Execute(ctx context.Context, args map[string]interface{}) *ToolResult {
	action, ok := args["action"].(string)
	if !ok {
		return ErrorResult("action is required")
	}

	switch action {
	case "add":
		return t.addJob(args)
	case "list":
		return t.listJobs()
	case "remove":
		return t.removeJob(args)
	case "enable":
		return t.enableJob(args, true)
	case "disable":
		return t.enableJob(args, false)
	default:
		return ErrorResult(fmt.Sprintf("unknown action: %s", action))
	}
}

func (t *CronTool) addJob(args map[string]interface{}) *ToolResult {
	t.mu.RLock()
	channel := t.channel
	chatID := t.chatID
	t.mu.RUnlock()

	if channel == "" || chatID == "" {
		return ErrorResult("no session context (channel/chat_id not set). Use this tool in an active conversation.")
	}

	message, ok := args["message"].(string)
	if !ok || message == "" {
		return ErrorResult("message is required for add")
	}

	var schedule cron.CronSchedule

	// Check for at_seconds (one-time), every_seconds (recurring), or cron_expr
	atSeconds, hasAt := args["at_seconds"].(float64)
	everySeconds, hasEvery := args["every_seconds"].(float64)
	cronExpr, hasCron := args["cron_expr"].(string)

	// Priority: at_seconds > every_seconds > cron_expr
	if hasAt {
		atMS := time.Now().UnixMilli() + int64(atSeconds)*1000
		schedule = cron.CronSchedule{
			Kind: "at",
			AtMS: &atMS,
		}
	} else if hasEvery {
		everyMS := int64(everySeconds) * 1000
		schedule = cron.CronSchedule{
			Kind:    "every",
			EveryMS: &everyMS,
		}
	} else if hasCron {
		schedule = cron.CronSchedule{
			Kind: "cron",
			Expr: cronExpr,
		}
	} else {
		return ErrorResult("one of at_seconds, every_seconds, or cron_expr is required")
	}

	// Read deliver parameter, default to false (agent processes the message,
	// enabling platform tools like voice_speak, notifications, etc.)
	deliver := false
	if d, ok := args["deliver"].(bool); ok {
		deliver = d
	}

	command, _ := args["command"].(string)
	if command != "" {
		if t.restrict {
			return ErrorResult("Shell commands are not available on mobile. Use 'message' with 'deliver: false' to let the agent process tasks instead.")
		}
		deliver = false
	}

	// Truncate message for job name (max 30 chars)
	messagePreview := utils.Truncate(message, 30)

	job, err := t.cronService.AddJob(
		messagePreview,
		schedule,
		message,
		deliver,
		channel,
		chatID,
	)
	if err != nil {
		return ErrorResult(fmt.Sprintf("Error adding job: %v", err))
	}

	if command != "" {
		job.Payload.Command = command
		// Need to save the updated payload
		t.cronService.UpdateJob(job)
	}

	return SilentResult(fmt.Sprintf("Cron job added: %s (id: %s)", job.Name, job.ID))
}

func (t *CronTool) listJobs() *ToolResult {
	jobs := t.cronService.ListJobs(false)

	if len(jobs) == 0 {
		return SilentResult("No scheduled jobs")
	}

	result := "Scheduled jobs:\n"
	for _, j := range jobs {
		var scheduleInfo string
		if j.Schedule.Kind == "every" && j.Schedule.EveryMS != nil {
			scheduleInfo = fmt.Sprintf("every %ds", *j.Schedule.EveryMS/1000)
		} else if j.Schedule.Kind == "cron" {
			scheduleInfo = j.Schedule.Expr
		} else if j.Schedule.Kind == "at" {
			scheduleInfo = "one-time"
		} else {
			scheduleInfo = "unknown"
		}
		result += fmt.Sprintf("- %s (id: %s, %s)\n", j.Name, j.ID, scheduleInfo)
	}

	return SilentResult(result)
}

func (t *CronTool) removeJob(args map[string]interface{}) *ToolResult {
	jobID, ok := args["job_id"].(string)
	if !ok || jobID == "" {
		return ErrorResult("job_id is required for remove")
	}

	if t.cronService.RemoveJob(jobID) {
		return SilentResult(fmt.Sprintf("Cron job removed: %s", jobID))
	}
	return ErrorResult(fmt.Sprintf("Job %s not found", jobID))
}

func (t *CronTool) enableJob(args map[string]interface{}, enable bool) *ToolResult {
	jobID, ok := args["job_id"].(string)
	if !ok || jobID == "" {
		return ErrorResult("job_id is required for enable/disable")
	}

	job := t.cronService.EnableJob(jobID, enable)
	if job == nil {
		return ErrorResult(fmt.Sprintf("Job %s not found", jobID))
	}

	status := "enabled"
	if !enable {
		status = "disabled"
	}
	return SilentResult(fmt.Sprintf("Cron job '%s' %s", job.Name, status))
}

// ExecuteJob executes a cron job through the agent
func (t *CronTool) ExecuteJob(ctx context.Context, job *cron.CronJob) string {
	// Get channel/chatID from job payload
	channel := job.Payload.Channel
	chatID := job.Payload.To

	// Default values if not set
	if channel == "" {
		channel = "chat"
	}
	if chatID == "" {
		chatID = "direct"
	}

	// Execute command if present (desktop only — no shell on mobile)
	if job.Payload.Command != "" {
		if t.execTool == nil {
			t.msgBus.PublishOutbound(bus.OutboundMessage{
				Channel: channel,
				ChatID:  chatID,
				Content: fmt.Sprintf("Scheduled command '%s' skipped: shell execution is not available on this platform.", job.Payload.Command),
			})
			return "ok"
		}

		args := map[string]interface{}{
			"command": job.Payload.Command,
		}

		result := t.execTool.Execute(ctx, args)
		var output string
		if result.IsError {
			output = fmt.Sprintf("Error executing scheduled command: %s", result.ForLLM)
		} else {
			output = fmt.Sprintf("Scheduled command '%s' executed:\n%s", job.Payload.Command, result.ForLLM)
		}

		t.msgBus.PublishOutbound(bus.OutboundMessage{
			Channel: channel,
			ChatID:  chatID,
			Content: output,
		})
		return "ok"
	}

	// If deliver=true, send message directly without agent processing
	if job.Payload.Deliver {
		t.msgBus.PublishOutbound(bus.OutboundMessage{
			Channel: channel,
			ChatID:  chatID,
			Content: job.Payload.Message,
		})
		return "ok"
	}

	// For deliver=false, process through agent (for complex tasks)
	sessionKey := fmt.Sprintf("cron-%s", job.ID)

	// Call agent with job's message
	response, err := t.executor.ProcessDirectWithChannel(
		ctx,
		job.Payload.Message,
		sessionKey,
		channel,
		chatID,
	)

	if err != nil {
		return fmt.Sprintf("Error: %v", err)
	}

	// Publish the agent response to the bus so the mobile bridge
	// forwarder can send it to Dart as a channel_response event.
	if response != "" {
		t.msgBus.PublishOutbound(bus.OutboundMessage{
			Channel: channel,
			ChatID:  chatID,
			Content: response,
		})
	}
	return "ok"
}
