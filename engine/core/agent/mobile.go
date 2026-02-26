// Ferri — Mobile-specific agent constructor
//
// Copyright (c) 2026 Ferri contributors

package agent

import (
	"context"
	"os"
	"path/filepath"
	"sync"

	"ferri/engine/core/bus"
	"ferri/engine/core/providers"
	"ferri/engine/core/session"
	"ferri/engine/core/state"
	"ferri/engine/core/tools"
)

// NewMobileAgentLoop creates an agent loop optimized for mobile.
// It skips bus-dependent features and desktop-only tools (shell, I2C, SPI, spawn, subagent).
// Tools included: filesystem (workspace-restricted), web search, web fetch.
func NewMobileAgentLoop(workspace string, provider providers.LLMProvider, model string, maxTokens, maxIterations int, searchOpts tools.WebSearchToolOptions) *AgentLoop {
	os.MkdirAll(workspace, 0755)

	// Create a mobile-appropriate tool registry (no shell, I2C, SPI, spawn, subagent)
	registry := tools.NewToolRegistry()

	// Filesystem tools — restricted to workspace
	registry.Register(tools.NewReadFileTool(workspace, true))
	registry.Register(tools.NewWriteFileTool(workspace, true))
	registry.Register(tools.NewListDirTool(workspace, true))
	registry.Register(tools.NewEditFileTool(workspace, true))
	registry.Register(tools.NewAppendFileTool(workspace, true))

	// Web tools — search provider priority: Perplexity > Brave > DuckDuckGo
	if searchTool := tools.NewWebSearchTool(searchOpts); searchTool != nil {
		registry.Register(searchTool)
	}
	registry.Register(tools.NewWebFetchTool(50000))

	// Session and state managers
	sessionsManager := session.NewSessionManager(filepath.Join(workspace, "sessions"))
	stateManager := state.NewManager(workspace)

	// Context builder with tools registry
	contextBuilder := NewContextBuilder(workspace)
	contextBuilder.SetToolsRegistry(registry)

	// Create a message bus — needed because some internal code paths reference it.
	// We drain outbound so it never blocks.
	msgBus := bus.NewMessageBus()
	drainCtx, drainCancel := context.WithCancel(context.Background())
	go func() {
		for {
			_, ok := msgBus.SubscribeOutbound(drainCtx)
			if !ok {
				return
			}
		}
	}()

	al := &AgentLoop{
		bus:            msgBus,
		provider:       provider,
		workspace:      workspace,
		model:          model,
		contextWindow:  maxTokens,
		maxIterations:  maxIterations,
		sessions:       sessionsManager,
		state:          stateManager,
		contextBuilder: contextBuilder,
		tools:          registry,
		summarizing:    sync.Map{},
		drainCancel:    drainCancel,
		cleanupFn: func() {
			drainCancel()
			msgBus.Close()
		},
	}

	return al
}
