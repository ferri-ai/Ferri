---
name: travel-assistant
description: Plan trips with destination research, calendar conflict checks, itinerary creation, and packing reminders
---

# Travel Assistant

Help the user plan a trip by checking calendar availability, researching the destination, creating itinerary events, and setting up reminders.

## Workflow

### Step 1: Gather Trip Details

Ask the user for (if not already provided):
- Destination
- Travel dates (departure and return)
- Purpose (business, leisure, both)
- Any specific interests or requirements

### Step 2: Check Calendar Conflicts

Call `calendar_read_events` for the travel date range. Report any existing events that conflict with the trip:
- List conflicting events with dates and times
- Ask if the user wants to cancel, reschedule, or keep them
- If events need to be moved, use `calendar_update_event` or `calendar_delete_event`

### Step 3: Destination Research

Call `location_geocode` with the destination to get coordinates and confirm the location.

Call `web_search` for practical travel info (limit to 3 searches):
1. "{destination} travel tips {current year}" -- practical advice, visa requirements, safety
2. "{destination} weather {travel month}" -- expected conditions and what to pack
3. "{destination} top things to do" -- activities and attractions

Summarize findings for the user:
- Weather expectations
- Key travel tips or requirements
- Top recommended activities

### Step 4: Build the Itinerary

Based on the research and user preferences, create calendar events:

1. **Travel day events:** Use `calendar_create_event` for departure and return travel. Include flight numbers, times, or transport details if provided.
2. **Activity blocks:** Suggest a rough daily plan and create events for confirmed activities using `calendar_create_event`.
3. **Buffer time:** Leave gaps for spontaneity -- do not overpack the schedule.

Each event should include relevant details in the description (addresses, booking references, tips).

### Step 5: Set Reminders

Use `reminder_set` to create helpful reminders:
- **Packing reminder:** 2 days before departure. Include a packing list based on weather research and trip purpose.
- **Departure reminder:** Morning of travel day with transport details.
- **Document check:** 1 day before departure ("Confirm passport, tickets, hotel booking").

### Step 6: Present the Plan

Compile everything into a clear summary:

```
TRIP TO {destination}
{departure date} — {return date} ({N} days)

CALENDAR
- {N} conflicts resolved
- {N} itinerary events created

WEATHER
- Expected: {conditions}, {temp range}
- Pack: {recommendations}

HIGHLIGHTS
- {Activity/attraction 1}
- {Activity/attraction 2}
- {Activity/attraction 3}

REMINDERS SET
- {date}: {reminder description}
- {date}: {reminder description}

TRAVEL TIPS
- {tip 1}
- {tip 2}
```

## Error Handling

- If calendar access fails, skip conflict checking and note it.
- If location_geocode fails for the destination, proceed with web search using the destination name.
- If the user doesn't provide exact dates, help them pick dates by showing their calendar availability.

## When to Activate

Trigger when the user says things like:
- "Help me plan a trip to..."
- "I'm traveling to... next week"
- "Plan my vacation"
- "Travel assistant"
- "I need to plan a work trip"
- "What do I need to know about visiting...?"
