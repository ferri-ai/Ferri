# System Prompt

> How Ferri assembles the system prompt, how capabilities modify it, and how users can customize it.

---

## Overview

Ferri's system prompt is **dynamically assembled** each time the agent processes a message. It combines identity, user-defined files, skills, memory, and the available tool list into a single prompt sent to the LLM.

---

## Prompt Structure

The system prompt is built by `ContextBuilder.BuildSystemPrompt()` in the Go engine:

```
[Identity]           → Core system identity ("You are Ferri...")
[Bootstrap Files]    → User-defined AGENTS.md, SOUL.md, USER.md, IDENTITY.md
[Skills Summary]     → List of available skills (name + description)
[Memory Context]     → MEMORY.md + recent daily notes
[Available Tools]    → All registered tools (capability tools + built-in)
```

Each section is separated by markdown headers and horizontal rules.

---

## How Capabilities Affect the Prompt

Capabilities don't directly modify the prompt text. Instead, they **register tools** with the Go engine's tool registry:

1. User enables a capability in the Capabilities screen
2. Dart calls `registerPlatformTool()` via FFI for each tool in that capability
3. The tool registry accumulates all registered tools
4. When the agent builds its next message, `buildToolsSection()` queries the registry
5. All registered tools appear in the "Available Tools" section with name + description

Disabling a capability unregisters its tools — the next LLM call will no longer see them. This means the LLM's available actions change dynamically based on what the user has granted.

---

## Customization

Users can customize the agent's behavior in several ways:

### Memory (Recommended)

The Memory screen (Settings > Memory) provides a raw text editor for `MEMORY.md`. This file is injected into every prompt.

Use it for:
- Personal context ("I live in Jakarta, I work at Acme Corp")
- Preferences ("Always respond in Bahasa Indonesia")
- Recurring context ("My partner's name is Alex, their birthday is March 15")

The agent can also write to memory via tools (`memory_save`), building context over time.

**Daily notes** (`workspace/memory/YYYYMM/YYYYMMDD.md`) from the last 3 days are also included, giving the agent short-term recall.

### Bootstrap Files

Create these files in the workspace root to define persistent instructions:

| File | Purpose |
|---|---|
| `IDENTITY.md` | Override the agent's personality and role |
| `USER.md` | Describe yourself — context the agent should always know |
| `SOUL.md` | Define the agent's values, communication style, guardrails |
| `AGENTS.md` | Multi-agent configuration (advanced) |

Bootstrap files are loaded in order and injected after the identity section. They take priority over memory for prompt placement.

### Skills

Skills extend the agent's capabilities with structured workflows. Each skill is a `SKILL.md` file with YAML frontmatter (name + description). The prompt includes a summary list — the agent reads the full skill content via `read_file` when needed.

Users can:
- Create skills in chat ("Create a skill that tracks my water intake")
- Install skills from GitHub via the Skills screen
- Skills live in `workspace/skills/{skill-name}/SKILL.md`

---

## What the LLM Sees

A simplified example of what the assembled prompt looks like:

```
You are Ferri, a mobile AI assistant...
Current time: 2026-02-24T10:30:00+07:00
Workspace: /data/user/0/com.ferri.ferri/files/workspace

---

# Memory
I live in Jakarta. I work as a software engineer.
Preferred language: English.

---

# Skills
- `morning-briefing` - Start your day with calendar, weather, and health summary
- `health-check` - Quick health data review

---

# Available Tools
- calendar_read_events: Query events by date range
- calendar_create_event: Create a new calendar event
- contacts_search: Search contacts by name
- location_get_current: Get current GPS coordinates
- device_battery: Battery level, charging status
... (all registered tools)
```

---

**See also:** [Architecture Overview](Architecture-Overview), [Adding a Capability](Adding-a-Capability), [LLM Providers](LLM-Providers)
