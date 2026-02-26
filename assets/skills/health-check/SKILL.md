---
name: health-check
description: Analyze health trends over the past week and month with steps, heart rate, sleep, calories, and weight data
---

# Health Check

Analyze the user's health data trends and present actionable insights. Pull data across multiple health metrics and identify patterns.

## Workflow

### Step 1: Check Health Availability

Call `health_check_availability` to confirm which health data types are accessible. If health data is not available at all, inform the user that they need to grant Health permissions in the app settings and stop.

### Step 2: Gather Weekly Data (Past 7 Days)

Make the following calls for the past 7 days:

1. `health_read_data` with type "steps" -- daily step counts
2. `health_read_data` with type "heart_rate" -- heart rate readings
3. `health_read_data` with type "sleep" -- sleep duration per night
4. `health_read_data` with type "active_calories" -- calories burned through activity

If any individual metric is unavailable, skip it and note it in the report.

### Step 3: Gather Monthly Weight Data

Call `health_read_data` with type "weight" for the past 30 days. Weight changes are more meaningful over longer periods.

### Step 4: Analyze Trends

For each available metric, calculate and assess:

**Steps:**
- Daily average over the 7 days
- Best and worst day
- Trend direction (increasing, decreasing, stable)
- Comparison to 10,000 steps general guideline

**Heart Rate:**
- Average resting heart rate
- Any notable spikes or dips
- Range (lowest to highest)

**Sleep:**
- Average nightly duration
- Most and least sleep
- Consistency (similar times vs erratic)
- Comparison to 7-9 hours general guideline

**Active Calories:**
- Daily average
- Most active day
- Trend direction

**Weight (30 days):**
- Change over the period
- Trend direction
- Stability

### Step 5: Present the Report

Format the analysis clearly:

```
HEALTH CHECK — {date range}

STEPS (7-day)
  Average: {avg}/day
  Best: {best} ({day})  |  Lowest: {worst} ({day})
  Trend: {direction}
  {insight — e.g., "Consistently above 8,000 steps. Strong baseline."}

HEART RATE (7-day)
  Resting avg: {bpm}
  Range: {low}–{high} bpm
  {insight — e.g., "Resting HR is stable, within healthy range."}

SLEEP (7-day)
  Average: {hours}h {minutes}m/night
  Best: {best} ({day})  |  Least: {worst} ({day})
  {insight — e.g., "Averaging under 7 hours. Consider earlier bedtimes."}

CALORIES (7-day)
  Average: {avg}/day active
  Most active: {day} ({cal})
  {insight}

WEIGHT (30-day)
  Current: {weight}
  Change: {change} over 30 days
  Trend: {direction}
  {insight}

SUMMARY
{2-3 sentence overall assessment highlighting strengths and areas for improvement}
```

### Step 6: Save to Memory (Optional)

Offer to save the health summary for future reference. If the user agrees, use `write_file` to save to `notes/health-check-{date}.md`. This allows tracking progress over time.

## Important Notes

- **Do not give medical advice.** Present data and general wellness observations only. Suggest consulting a healthcare provider for concerns.
- **Use general guidelines,** not prescriptive targets. Phrases like "general guideline" and "many health organizations suggest" are appropriate.
- **Be encouraging.** Highlight positive trends alongside areas for improvement.
- **Respect missing data.** If a metric has gaps, note it rather than making assumptions.

## Error Handling

- If health_check_availability indicates no data access, explain the situation clearly and stop.
- If individual metrics fail, produce the report with whatever data is available.
- If all weekly data calls fail, suggest the user check their health app sync and permissions.

## When to Activate

Trigger when the user says things like:
- "How's my health?"
- "Health check"
- "Show me my health data"
- "How did I sleep this week?"
- "What are my step trends?"
- "Give me a health report"
- "Analyze my fitness data"
