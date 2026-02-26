# Automation System

Ferri supports automated agent tasks that run without manual interaction. There are three automation mechanisms: cron jobs (time-based), geofence triggers (location-based), and the heartbeat system (periodic check-in). All three are tested and functional on Android.

---

## Cron Automations (Tested)

Cron automations are time-based scheduled tasks. When a cron job fires, its prompt is sent through the agent loop, and the agent executes it with full tool access.

### Creating Cron Jobs

There are two ways to create cron jobs:

**Via chat (natural language):**
Tell the agent what you want scheduled. Examples:
- "Every day at 9am, summarize my calendar for today."
- "Every Monday at 8am, check my unread emails and give me a summary."
- "At 6pm on weekdays, remind me to log my work hours."

The agent parses the request, creates a cron job with the appropriate schedule, and confirms.

**Via the visual automation builder:**
1. Enable the visual builder in **Settings > Visual automation builder**.
2. A "New Automation" FAB appears on the Automate tab.
3. Tap it, select "Time-based," fill in the schedule and prompt.
4. Save. The job appears in the automation list.

### How Cron Jobs Work

- The Go engine runs an internal cron scheduler with a 1-second tick interval.
- Jobs use standard 5-field cron expressions (minute, hour, day-of-month, month, day-of-week).
- Each job has: an ID, a name, a cron schedule, a prompt, and an enabled flag.
- When a job's schedule matches, the prompt is sent through the agent loop.
- The agent processes the prompt, executes any tool calls, and produces a result.
- Results appear in the chat history and as notification cards (tapping the notification opens the result in chat).

### Managing Cron Jobs

- The **Automate tab** lists all cron jobs with their schedule and enabled state.
- Toggle individual jobs on or off.
- Delete jobs you no longer need.
- Pull-to-refresh updates the list from the Go engine.

### Known Limitation

Cron jobs created by the LLM that populate the `command` field (instead of the `prompt` field) may produce a "sh not found" error. This happens because the Go engine attempts shell execution for command-type jobs, which is not available on mobile. Jobs that use the `prompt` field work correctly. If you encounter this, delete the job and recreate it -- the agent usually gets it right on retry.

---

## Geofence Automations (Tested)

Geofence automations trigger agent tasks based on physical location. When you enter, exit, or dwell in a defined area, the associated prompt runs through the agent loop.

### Creating Geofences

**Via chat:**
- "When I arrive at the office (latitude, longitude), remind me to check my calendar."
- "When I leave home, send me a weather summary."

**Via the visual automation builder:**
1. Enable the builder in Settings.
2. Tap "New Automation" on the Automate tab.
3. Select "Geofence-based."
4. Set the location (coordinates), radius, trigger type (enter/exit/dwell), and prompt.
5. Save.

### How Geofences Work

- **Android implementation:** Uses Google Play Services `GeofencingClient` for location monitoring.
- `GeofenceBroadcastReceiver` receives transition events (enter, exit, dwell) from the OS.
- The receiver calls `ferri_trigger_geofence` via Dart FFI, which sends the associated prompt through the agent loop.
- Creating a geofence also creates a paired cron job entry (visible in the Automate tab). This is an implementation detail -- the geofence and its paired job are managed together.
- Deleting a geofence removes both the native GMS fence and the paired cron job.
- **Dwell delay** is hardcoded at 30 seconds. The trigger fires after the user has been inside the geofence area for 30 continuous seconds.
- Geofences work even when the app is not in the foreground, as long as the Background Service is running. See [Background Execution](Background-Execution).

### GMS Requirement

Geofences require Google Play Services (GMS). They will not work on devices without GMS, such as Huawei AppGallery-only devices or custom ROMs without microG.

---

## Heartbeat System (Tested)

The heartbeat is a periodic agent check-in. It runs a user-defined prompt on a recurring schedule, functioning as a lightweight "how are things going" loop.

### Configuration

- **Enable/disable toggle:** Found on the Automate tab's Heartbeat card.
- **Interval options:** 15 minutes, 30 minutes, 1 hour, or 4 hours.
- **Prompt:** A free-text prompt that defines what the agent should do on each heartbeat tick. Write it like you would any other agent instruction.

### How It Works

1. The user writes a heartbeat prompt (e.g., "Check if I have any upcoming meetings in the next hour and notify me").
2. The user selects an interval and enables the heartbeat.
3. The Go engine fires the heartbeat on the selected interval.
4. On each tick, the prompt is sent through the agent loop.
5. The agent processes it with full tool access and produces a result.
6. Results appear in chat and as notifications.

### Persistence

Heartbeat state (enabled/disabled, interval) is persisted in SharedPreferences. When the app restarts and the Go engine initializes, the saved heartbeat configuration is restored automatically. The heartbeat prompt is stored in a HEARTBEAT.md file managed by the engine.

---

## Managing Automations

The **Automate tab** is the central place for viewing and managing all automations.

- **Cron jobs** are listed with their name, schedule, and enabled state.
- **Geofences** appear alongside their paired cron jobs.
- **Heartbeat** has its own card at the top of the tab.
- Each automation can be individually toggled on or off.
- Deleting a geofence automation cleans up both the native fence and the cron entry.
- Pull-to-refresh synchronizes the list with the Go engine's current state.

All automation results -- whether from cron jobs, geofence triggers, or heartbeat ticks -- flow through the same agent loop and appear in the chat history. Notifications are posted for each result, and tapping a notification opens the corresponding result card in chat.
