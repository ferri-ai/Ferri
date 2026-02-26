---
name: morning-briefing
description: Generate a personalized morning briefing with calendar, health, weather, reminders, and headlines
---

# Morning Briefing

Compile a concise, scannable morning briefing for the user. Gather data from multiple sources and present it in a clean format.

## Workflow

### Step 1: Today's Schedule

Call `calendar_read_events` for today's date range (start of day to end of day). Note the number of events, first event time, and any conflicts.

### Step 2: Yesterday's Health Summary

Call `health_read_steps` for yesterday's date to get step count. Then call `health_read_heart_rate` for yesterday to get resting and average heart rate. If health data is unavailable, skip this section gracefully and note it.

### Step 3: Current Weather

Call `location_get_current` to get the user's coordinates. Then call `web_search` with a query like "weather today {city}" using the location result. Extract temperature, conditions, and any alerts.

### Step 4: Active Reminders

Call `reminder_list` to fetch all active reminders. Include any that are due today or overdue.

### Step 5: News Headlines

Call `web_search` for "top news headlines today" to get 2-3 current headlines. Keep them brief -- just the headline and source.

### Step 6: Present the Briefing

Format everything as a clean briefing:

```
Good morning! Here's your briefing for {date}:

SCHEDULE ({count} events)
- {time} — {event title}
- {time} — {event title}
{First event is in X hours}

HEALTH (yesterday)
- Steps: {count} ({comparison to goal if available})
- Resting HR: {bpm}

WEATHER
- {temp}, {conditions}
- {alerts if any}

REMINDERS
- {reminder 1}
- {reminder 2}

HEADLINES
- {headline 1} — {source}
- {headline 2} — {source}

Have a great day!
```

## Error Handling

- If any single data source fails, include that section with a note like "Could not retrieve calendar data" rather than failing the entire briefing.
- Health data requires prior permission. If unavailable, omit the section.
- If location is unavailable, ask the user for their city to fetch weather.

## When to Activate

Trigger when the user says things like:
- "Good morning"
- "Morning briefing"
- "What's my day look like?"
- "Give me my daily briefing"
- "Brief me"
- "Start my day"
