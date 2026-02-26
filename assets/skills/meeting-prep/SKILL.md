---
name: meeting-prep
description: Prepare for an upcoming meeting with attendee profiles, context research, and talking points
---

# Meeting Prep

Research and compile a preparation brief for an upcoming meeting. Gather attendee information, relevant context, and generate talking points.

## Workflow

### Step 1: Find the Meeting

Call `calendar_read_events` to find upcoming events. If the user specified a meeting, match it by title or time. If not, present the next few meetings and ask which one to prepare for. Extract:
- Meeting title
- Date and time
- Duration
- Attendee list (names and/or email addresses)
- Description or agenda (if present)

### Step 2: Research Attendees

For each attendee in the meeting:
1. Call `contacts_search` with their name or email to find local contact info (title, company, notes).
2. If the attendee has a company listed, call `web_search` for "{person name} {company}" to find their role or recent activity.

Compile a short profile for each attendee:
- Name and title
- Company
- Relevant notes from contacts
- Any recent news or context

Limit web searches to 3-4 attendees maximum to keep the process efficient. Prioritize external attendees over internal colleagues.

### Step 3: Research Meeting Context

Based on the meeting title and description:
1. Call `web_search` for relevant context. For example:
   - If the meeting mentions a company: search for recent news about that company
   - If the meeting has a specific topic: search for recent developments on that topic
   - If the meeting is a recurring 1:1: skip this step

Limit to 2 web searches maximum for context.

### Step 4: Compile the Briefing

Present the preparation brief:

```
MEETING PREP: {title}
{date} at {time} ({duration})

ATTENDEES
- {Name} — {Title at Company}
  {Relevant note or context}
- {Name} — {Title at Company}
  {Relevant note or context}

CONTEXT
- {Relevant news item or background}
- {Relevant news item or background}

SUGGESTED TALKING POINTS
1. {Based on agenda/context}
2. {Based on attendee profiles}
3. {Open question or follow-up}

AGENDA (from invite)
{Original meeting description if available}
```

### Step 5: Set a Reminder (Optional)

If the meeting is more than 2 hours away, offer to set a reminder 15 minutes before using `reminder_set`.

## Error Handling

- If no attendees are listed on the calendar event, note this and focus on topic research.
- If contacts_search returns no results for an attendee, rely on web search or note them as "No local contact info."
- If the meeting has no description, focus the briefing on attendee profiles.

## When to Activate

Trigger when the user says things like:
- "Prepare me for my next meeting"
- "Meeting prep for..."
- "Who am I meeting with?"
- "Brief me on my {time} meeting"
- "Help me prepare for the call with..."
- "What should I know before my meeting?"
