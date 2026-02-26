---
name: skill-creator
description: Create new skills from chat by guiding the user through workflow design and writing the SKILL.md file
---

# Skill Creator

You help the user design and create a new Ferri skill. A skill is a SKILL.md file that teaches you a reusable workflow composed of tool calls. Walk the user through the process step by step.

## Process

### Step 1: Understand the Goal

Ask the user:
- What should this skill do? (one sentence)
- When should it activate? (trigger phrases)
- What end result does the user expect?

### Step 2: Identify Required Tools

Review the available tools and determine which ones the skill needs. Present the selected tools to the user for confirmation.

Available tool domains:
- **Calendar:** calendar_read_events, calendar_create_event, calendar_update_event, calendar_delete_event
- **Contacts:** contacts_search, contacts_read, contacts_create, contacts_update, contacts_delete
- **Location:** location_get_current, location_geocode, location_reverse_geocode
- **SMS:** sms_read, sms_send
- **Device:** device_info, device_battery, device_storage, device_connectivity, device_flashlight, device_brightness
- **Alarms:** alarm_set, alarm_set_timer, alarm_show
- **App Launcher:** app_launch, app_list
- **Camera:** camera_capture_photo, camera_pick_image
- **Voice:** voice_speak, voice_listen
- **Health:** health_check_availability, health_read_steps, health_read_heart_rate, health_read_data
- **Clipboard:** clipboard_read, clipboard_write
- **Notifications:** notification_send, notification_schedule
- **Reminders:** reminder_set, reminder_list, reminder_cancel
- **Bluetooth:** bluetooth_get_state, bluetooth_list_paired, bluetooth_scan
- **Web:** web_search, web_fetch
- **Filesystem:** read_file, write_file, list_dir, edit_file, append_file

### Step 3: Design the Workflow

Map out the sequence of tool calls. Consider:
- What data is needed first? (dependencies between steps)
- What can run independently?
- How should errors be handled?
- What should be presented to the user at each stage?

### Step 4: Write the SKILL.md

Use `write_file` to create the skill at `skills/{skill-name}/SKILL.md`.

The file MUST follow this exact format:

```
---
name: {skill-name}
description: {One-line description, max 200 characters, action-oriented}
---

# {Skill Title}

{Instructions for the agent workflow...}

## When to Activate

Trigger when the user says things like:
- "{example phrase 1}"
- "{example phrase 2}"
- "{example phrase 3}"
```

### Step 5: Confirm

After writing the file, read it back with `read_file` to verify correctness. Tell the user the skill is ready and explain how to trigger it.

## Rules

- **Naming:** Use lowercase kebab-case for skill names (e.g., `expense-tracker`, `workout-log`).
- **Description:** Must be under 200 characters. Start with a verb (e.g., "Track daily expenses..." not "A skill that tracks...").
- **Tool references:** Use exact tool names from the list above. Do not invent tool names.
- **Single responsibility:** Each skill should do one coherent thing well.
- **No hardcoded values:** Use variables and context from tool results, not assumptions.
- **Frontmatter required:** The YAML frontmatter with `name` and `description` is mandatory.

## Example Creation Session

User: "I want a skill that texts my partner when I'm running late"

1. **Goal:** Send an SMS to a specific contact when the user is running late, with context from their calendar.
2. **Tools needed:** calendar_read_events, contacts_search, sms_send, location_get_current
3. **Workflow:**
   - Use calendar_read_events to find the next upcoming event
   - Use contacts_search to find the partner's contact
   - Use location_get_current to estimate current position
   - Compose a message with the event name and estimated delay
   - Use sms_send to send the message
   - Confirm to the user that the message was sent
4. **Write** the SKILL.md to `skills/running-late-alert/SKILL.md`

## When to Activate

Trigger when the user says things like:
- "Create a new skill"
- "Make a skill that..."
- "I want to build a skill for..."
- "Help me design a workflow"
- "Can you create a custom skill?"
