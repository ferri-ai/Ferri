# Ferri Capabilities Reference

Every tool the Ferri agent can call, with parameter schemas, response formats, and platform availability.

**Total:** 79+ tools across 28+ capabilities.

**Destructive tools** require user approval when the "Approve destructive actions" setting is enabled.

---

## 1. Calendar

**Channel:** `ferri/calendar` | **Tier:** Core

| Tool | Description | Destructive | Android | iOS |
|---|---|---|---|---|
| `calendar_read_events` | Query events by date range | No | Done | Planned |
| `calendar_create_event` | Create a new calendar event | No | Done | Planned |
| `calendar_update_event` | Update an existing event | Yes | Done | Planned |
| `calendar_delete_event` | Delete an event by ID | Yes | Done | Planned |

<details>
<summary>Parameter schemas</summary>

**`calendar_read_events`**
```json
{
  "start_date": "(string, required) ISO 8601 date",
  "end_date": "(string, required) ISO 8601 date",
  "calendar_id": "(string, optional) specific calendar"
}
```
Response: `[{"id", "title", "start", "end", "location", "description"}]`

**`calendar_create_event`**
```json
{
  "title": "(string, required)",
  "start_time": "(string, required) ISO 8601",
  "end_time": "(string, required) ISO 8601",
  "location": "(string, optional)",
  "description": "(string, optional)",
  "calendar_id": "(string, optional)"
}
```

**`calendar_update_event`**
```json
{
  "event_id": "(string, required)",
  "title": "(string, optional)",
  "start_time": "(string, optional) ISO 8601",
  "end_time": "(string, optional) ISO 8601",
  "location": "(string, optional)",
  "description": "(string, optional)"
}
```

**`calendar_delete_event`**
```json
{
  "event_id": "(string, required)"
}
```

</details>

---

## 2. Contacts

**Channel:** `ferri/contacts` | **Tier:** Core

| Tool | Description | Destructive | Android | iOS |
|---|---|---|---|---|
| `contacts_search` | Search contacts by name | No | Done | Planned |
| `contacts_read` | Get full contact details | No | Done | Planned |
| `contacts_create` | Create a new contact | No | Done | Planned |
| `contacts_update` | Update contact fields | Yes | Done | Planned |
| `contacts_delete` | Delete a contact by ID | Yes | Done | Planned |

<details>
<summary>Parameter schemas</summary>

**`contacts_search`**
```json
{
  "query": "(string, optional) name search",
  "limit": "(integer, optional) default 20"
}
```

**`contacts_read`**
```json
{
  "contact_id": "(string, required)"
}
```

**`contacts_create`**
```json
{
  "name": "(string, required)",
  "phone": "(string, optional)",
  "email": "(string, optional)"
}
```

**`contacts_update`**
```json
{
  "contact_id": "(string, required)",
  "name": "(string, optional)",
  "phone": "(string, optional)",
  "email": "(string, optional)"
}
```

**`contacts_delete`**
```json
{
  "contact_id": "(string, required)"
}
```

</details>

---

## 3. Location

**Channel:** `ferri/location` | **Tier:** Core

| Tool | Description | Destructive | Android | iOS |
|---|---|---|---|---|
| `location_get_current` | Get current GPS coordinates | No | Done | Planned |
| `location_geocode` | Address string to coordinates | No | Done | Planned |
| `location_reverse_geocode` | Coordinates to address | No | Done | Planned |

<details>
<summary>Parameter schemas</summary>

**`location_get_current`** — No parameters.
Response: `{"latitude", "longitude", "accuracy", "altitude", "provider"}`

**`location_geocode`**
```json
{
  "address": "(string, required) e.g. '1600 Amphitheatre Parkway'",
  "max_results": "(integer, optional) default 5"
}
```

**`location_reverse_geocode`**
```json
{
  "latitude": "(number, required)",
  "longitude": "(number, required)"
}
```

</details>

---

## 4. SMS

**Channel:** `ferri/sms` | **Tier:** Core

| Tool | Description | Destructive | Android | iOS |
|---|---|---|---|---|
| `sms_read` | Read SMS messages | No | Done | N/A |
| `sms_send` | Send an SMS message | Yes | Done | Partial |

<details>
<summary>Parameter schemas</summary>

**`sms_read`**
```json
{
  "address": "(string, optional) phone number filter",
  "limit": "(integer, optional) default 20",
  "type": "(string, optional) 'inbox', 'sent', or 'all'"
}
```

**`sms_send`**
```json
{
  "to": "(string, required) recipient phone number",
  "body": "(string, required) message text"
}
```

</details>

---

## 5. Device Info

**Channel:** `ferri/device_info` | **Tier:** Core

| Tool | Description | Destructive | Android | iOS |
|---|---|---|---|---|
| `device_info` | Device model, OS version | No | Done | Planned |
| `device_battery` | Battery level, charging status | No | Done | Planned |
| `device_storage` | Total/used/free storage | No | Done | Planned |
| `device_connectivity` | Network type (wifi/cellular) | No | Done | Planned |
| `device_flashlight` | Toggle flashlight on/off | Yes | Done | Planned |
| `device_brightness` | Set screen brightness | Yes | Done | Planned |

<details>
<summary>Parameter schemas</summary>

**`device_info`** — No parameters.

**`device_battery`** — No parameters.

**`device_storage`** — No parameters.

**`device_connectivity`** — No parameters.

**`device_flashlight`**
```json
{
  "enabled": "(boolean, required) true/false"
}
```

**`device_brightness`**
```json
{
  "level": "(integer, required) 0-255"
}
```

</details>

---

## 6. Alarms

**Channel:** `ferri/alarms` | **Tier:** Core

| Tool | Description | Destructive | Android | iOS |
|---|---|---|---|---|
| `alarm_set` | Set an alarm at specific time | No | Done | Planned |
| `alarm_set_timer` | Set a countdown timer | No | Done | Planned |
| `alarm_show` | Open the alarms/clock app | No | Done | Planned |

<details>
<summary>Parameter schemas</summary>

**`alarm_set`**
```json
{
  "hour": "(integer, required) 0-23",
  "minute": "(integer, required) 0-59",
  "message": "(string, optional) alarm label"
}
```

**`alarm_set_timer`**
```json
{
  "seconds": "(integer, required) duration",
  "message": "(string, optional) timer label"
}
```

**`alarm_show`** — No parameters.

</details>

---

## 7. App Launcher

**Channel:** `ferri/app_launcher` | **Tier:** Core

| Tool | Description | Destructive | Android | iOS |
|---|---|---|---|---|
| `app_launch` | Launch an app by name/package | No | Done | Planned |
| `app_list` | List installed apps | No | Done | N/A |

<details>
<summary>Parameter schemas</summary>

**`app_launch`**
```json
{
  "app_name": "(string, optional) fuzzy name search",
  "package_name": "(string, optional) exact package name"
}
```

**`app_list`**
```json
{
  "query": "(string, optional) name filter",
  "limit": "(integer, optional) default 30"
}
```

</details>

---

## 8. Clipboard

**Channel:** `ferri/clipboard` | **Tier:** Core

| Tool | Description | Destructive | Android | iOS |
|---|---|---|---|---|
| `clipboard_read` | Read clipboard text | No | Done | Planned |
| `clipboard_write` | Write text to clipboard | No | Done | Planned |

<details>
<summary>Parameter schemas</summary>

**`clipboard_read`** — No parameters.

**`clipboard_write`**
```json
{
  "text": "(string, required)"
}
```

</details>

---

## 9. Notifications

**Channel:** `ferri/notifications` | **Tier:** Core

| Tool | Description | Destructive | Android | iOS |
|---|---|---|---|---|
| `notification_send` | Send a local notification | No | Done | Planned |
| `notification_schedule` | Schedule a future notification | No | Done | Planned |

<details>
<summary>Parameter schemas</summary>

**`notification_send`**
```json
{
  "title": "(string, optional) default 'Ferri'",
  "body": "(string, required) notification text"
}
```

**`notification_schedule`**
```json
{
  "title": "(string, optional) default 'Ferri'",
  "body": "(string, required)",
  "delay_seconds": "(integer, optional) default 60"
}
```

</details>

---

## 10. Reminders

**Channel:** `ferri/reminders` | **Tier:** Core

| Tool | Description | Destructive | Android | iOS |
|---|---|---|---|---|
| `reminder_set` | Create a reminder | No | Done | Planned |
| `reminder_list` | List active reminders | No | Done | Planned |
| `reminder_cancel` | Cancel a reminder | Yes | Done | Planned |

<details>
<summary>Parameter schemas</summary>

**`reminder_set`**
```json
{
  "message": "(string, required)",
  "title": "(string, optional) default 'Ferri Reminder'",
  "at_time": "(string, optional) ISO 8601",
  "delay_seconds": "(integer, optional) relative timing"
}
```

**`reminder_list`** — No parameters.

**`reminder_cancel`**
```json
{
  "reminder_id": "(integer, required)"
}
```

</details>

---

## 11. Camera

**Channel:** `ferri/camera` | **Tier:** Extended

| Tool | Description | Destructive | Android | iOS |
|---|---|---|---|---|
| `camera_capture_photo` | Take a photo with camera | No | Done | Planned |
| `camera_pick_image` | Pick an image from gallery | No | Done | Planned |

<details>
<summary>Parameter schemas</summary>

**`camera_capture_photo`**
```json
{
  "quality": "(integer, optional) 1-100, default 85"
}
```

**`camera_pick_image`**
```json
{
  "quality": "(integer, optional) 1-100, default 85"
}
```

</details>

---

## 12. Voice

**Channel:** `ferri/voice` | **Tier:** Extended

| Tool | Description | Destructive | Android | iOS |
|---|---|---|---|---|
| `voice_speak` | Text-to-speech | No | Done | Planned |
| `voice_listen` | Speech-to-text | No | Done | Planned |

<details>
<summary>Parameter schemas</summary>

**`voice_speak`**
```json
{
  "text": "(string, required) text to speak",
  "language": "(string, optional) default 'en-US'",
  "rate": "(number, optional) 0.0-1.0, default 0.5"
}
```

**`voice_listen`**
```json
{
  "language": "(string, optional) default 'en-US'",
  "duration_seconds": "(integer, optional) default 10"
}
```

</details>

---

## 13. Health

**Channel:** `ferri/health` | **Tier:** Extended

| Tool | Description | Destructive | Android | iOS |
|---|---|---|---|---|
| `health_check_availability` | Check if health data is available | No | Done | Planned |
| `health_read_steps` | Read step count | No | Done | Planned |
| `health_read_heart_rate` | Read heart rate data | No | Done | Planned |
| `health_read_data` | Generic health data query | No | Done | Planned |

Supported data types: steps, heart_rate, blood_glucose, blood_oxygen, blood_pressure_systolic, blood_pressure_diastolic, body_temperature, weight, height, sleep, workout, active_calories

<details>
<summary>Parameter schemas</summary>

**`health_check_availability`** — No parameters.

**`health_read_steps`**
```json
{
  "start_date": "(string, optional) ISO 8601, defaults to today midnight",
  "end_date": "(string, optional) ISO 8601, defaults to now"
}
```

**`health_read_heart_rate`**
```json
{
  "start_date": "(string, optional) ISO 8601, defaults to 24h ago",
  "end_date": "(string, optional) ISO 8601, defaults to now"
}
```

**`health_read_data`**
```json
{
  "data_type": "(string, required) e.g. 'steps', 'heart_rate', 'weight'",
  "start_date": "(string, optional) ISO 8601",
  "end_date": "(string, optional) ISO 8601",
  "limit": "(integer, optional) default 50"
}
```

</details>

---

## 14. Bluetooth

**Channel:** `ferri/bluetooth` | **Tier:** Extended

| Tool | Description | Destructive | Android | iOS |
|---|---|---|---|---|
| `bluetooth_get_state` | Check if Bluetooth is on | No | Done | Planned |
| `bluetooth_list_paired` | List paired/connected devices | No | Done | Partial |
| `bluetooth_scan` | Scan for nearby BLE devices | No | Done | Planned |

<details>
<summary>Parameter schemas</summary>

**`bluetooth_get_state`** — No parameters.

**`bluetooth_list_paired`** — No parameters.

**`bluetooth_scan`**
```json
{
  "duration_ms": "(integer, optional) default 10000, max 30000"
}
```

</details>

---

## 15. Call Log (Android only)

**Channel:** `ferri/calllog` | **Tier:** Extended

| Tool | Description | Destructive | Android | iOS |
|---|---|---|---|---|
| `calllog_read` | Read call history | No | Done | N/A |
| `calllog_summary` | Call statistics for N days | No | Done | N/A |

<details>
<summary>Parameter schemas</summary>

**`calllog_read`**
```json
{
  "number": "(string, optional) phone number filter",
  "limit": "(integer, optional) default 20",
  "type": "(string, optional) 'incoming', 'outgoing', 'missed', or 'all'",
  "after_date": "(string, optional) ISO 8601"
}
```

**`calllog_summary`**
```json
{
  "days": "(integer, optional) default 7"
}
```

</details>

---

## 16. Audio

**Channel:** `ferri/audio` | **Tier:** Core

| Tool | Description | Destructive | Android | iOS |
|---|---|---|---|---|
| `audio_get_volume` | Get current volume levels | No | Done | Planned |
| `audio_set_volume` | Set volume for a stream | Yes | Done | Planned |
| `audio_get_mode` | Get ringer mode (normal/vibrate/silent) | No | Done | Planned |
| `audio_set_mode` | Set ringer mode or DND | Yes | Done | Planned |
| `audio_media_control` | Play/pause/skip media | Yes | Done | Planned |

<details>
<summary>Parameter schemas</summary>

**`audio_get_volume`** — No parameters.

**`audio_set_volume`**
```json
{
  "stream": "(string, optional) 'music', 'ring', 'alarm', 'notification', 'call' (default: 'music')",
  "percent": "(integer, required) 0-100"
}
```

**`audio_get_mode`** — No parameters.

**`audio_set_mode`**
```json
{
  "mode": "(string, optional) 'normal', 'vibrate', 'silent'",
  "dnd": "(boolean, optional) Do Not Disturb toggle"
}
```

**`audio_media_control`**
```json
{
  "action": "(string, required) 'play', 'pause', 'play_pause', 'stop', 'skip_next', 'skip_previous'"
}
```

</details>

---

## 17. Files

**Channel:** `ferri/files` | **Tier:** Core

| Tool | Description | Destructive | Android | iOS |
|---|---|---|---|---|
| `files_list` | List files in workspace | No | Done | Planned |
| `files_read` | Read a file's contents | No | Done | Planned |
| `files_write` | Write text to a file | Yes | Done | Planned |
| `files_pick` | Pick a file from storage | No | Done | Planned |
| `files_delete` | Delete a file | Yes | Done | Planned |

Files are scoped to Ferri's workspace directory only.

<details>
<summary>Parameter schemas</summary>

**`files_list`**
```json
{
  "directory": "(string, optional) subdirectory within workspace"
}
```

**`files_read`**
```json
{
  "name": "(string, required) file name or path"
}
```

**`files_write`**
```json
{
  "name": "(string, required) file name",
  "content": "(string, required) text content"
}
```

**`files_pick`**
```json
{
  "mime_type": "(string, optional) MIME filter, default '*/*'"
}
```

**`files_delete`**
```json
{
  "name": "(string, required) file to delete"
}
```

</details>

---

## 18. Maps / Navigation

**Channel:** `ferri/maps` | **Tier:** Core

| Tool | Description | Destructive | Android | iOS |
|---|---|---|---|---|
| `maps_open` | Open a location in maps | No | Done | Planned |
| `maps_navigate` | Start navigation to a destination | No | Done | Planned |

<details>
<summary>Parameter schemas</summary>

**`maps_open`**
```json
{
  "query": "(string, optional) search query or address",
  "latitude": "(number, optional)",
  "longitude": "(number, optional)"
}
```

**`maps_navigate`**
```json
{
  "destination": "(string, required) address or place name",
  "mode": "(string, optional) 'driving', 'walking', 'bicycling', 'transit'"
}
```

</details>

---

## 19. Phone Dial

**Channel:** `ferri/phone` | **Tier:** Core

| Tool | Description | Destructive | Android | iOS |
|---|---|---|---|---|
| `phone_dial` | Open dialer with a number | No | Done | Planned |

<details>
<summary>Parameter schemas</summary>

**`phone_dial`**
```json
{
  "number": "(string, required) phone number",
  "direct": "(boolean, optional) direct call, default false"
}
```

</details>

---

## 20. Email

**Channel:** `ferri/email` | **Tier:** Core

| Tool | Description | Destructive | Android | iOS |
|---|---|---|---|---|
| `email_compose` | Open email compose intent | No | Done | Planned |

<details>
<summary>Parameter schemas</summary>

**`email_compose`**
```json
{
  "to": "(string, required) recipient email",
  "cc": "(string, optional)",
  "subject": "(string, optional)",
  "body": "(string, optional)"
}
```

</details>

---

## 21. Sharing

**Channel:** `ferri/sharing` | **Tier:** Core

| Tool | Description | Destructive | Android | iOS |
|---|---|---|---|---|
| `share_text` | Share text via share sheet | No | Done | Planned |
| `share_file` | Share a file via share sheet | No | Done | Planned |

<details>
<summary>Parameter schemas</summary>

**`share_text`**
```json
{
  "text": "(string, required) text to share",
  "subject": "(string, optional) for email apps"
}
```

**`share_file`**
```json
{
  "path": "(string, required) file path in workspace",
  "mime_type": "(string, optional) default '*/*'"
}
```

</details>

---

## 22. Sensors

**Channel:** `ferri/sensors` | **Tier:** Extended

| Tool | Description | Destructive | Android | iOS |
|---|---|---|---|---|
| `sensor_list` | List available hardware sensors | No | Done | Planned |
| `sensor_read` | Read a sensor value | No | Done | Planned |

<details>
<summary>Parameter schemas</summary>

**`sensor_list`** — No parameters.

**`sensor_read`**
```json
{
  "sensor": "(string, required) 'accelerometer', 'gyroscope', 'magnetometer', 'proximity', 'ambient_light', 'pressure', 'step_counter', 'gravity'"
}
```

</details>

---

## 23. Wi-Fi

**Channel:** `ferri/wifi` | **Tier:** Extended

| Tool | Description | Destructive | Android | iOS |
|---|---|---|---|---|
| `wifi_get_info` | Get connected Wi-Fi details | No | Done | Planned |
| `wifi_scan` | Scan for nearby networks | No | Done | Planned |
| `wifi_get_state` | Check if Wi-Fi is enabled | No | Done | Planned |

All three tools take no parameters.

---

## 24. NFC

**Channel:** `ferri/nfc` | **Tier:** Extended

| Tool | Description | Destructive | Android | iOS |
|---|---|---|---|---|
| `nfc_read` | Read an NFC tag (30s timeout) | No | Done | Planned |
| `nfc_write` | Write to an NFC tag (30s timeout) | Yes | Done | Planned |

<details>
<summary>Parameter schemas</summary>

**`nfc_read`** — No parameters. Hold tag near device within 30 seconds.

**`nfc_write`**
```json
{
  "text": "(string, optional) text to write",
  "url": "(string, optional) URL to write (takes priority over text)"
}
```

</details>

---

## 25. Geofence

**Channel:** `ferri/geofence` | **Tier:** Extended

| Tool | Description | Destructive | Android | iOS |
|---|---|---|---|---|
| `geofence_create` | Create a geofence trigger | Yes | Done | Planned |
| `geofence_list` | List active geofences | No | Done | Planned |
| `geofence_remove` | Remove a geofence | Yes | Done | Planned |

<details>
<summary>Parameter schemas</summary>

**`geofence_create`**
```json
{
  "id": "(string, optional) unique ID, auto-generated if omitted",
  "latitude": "(number, optional) use with longitude",
  "longitude": "(number, optional) use with latitude",
  "location_name": "(string, optional) name/address, auto-geocoded",
  "radius": "(number, optional) meters, default 100",
  "trigger": "(string, optional) 'enter', 'exit', 'dwell' (default: 'enter')"
}
```
Provide either `latitude`/`longitude` or `location_name`.

**`geofence_list`** — No parameters.

**`geofence_remove`**
```json
{
  "id": "(string, required)"
}
```

</details>

---

## 26. Notification Listener (Android only, Privileged)

**Channel:** `ferri/notification_listener` | **Tier:** Privileged

Requires granting Notification Listener access in Android system settings.

| Tool | Description | Destructive | Android | iOS |
|---|---|---|---|---|
| `notification_listener_read` | Read notifications from all apps | No | Done | N/A |
| `notification_listener_active` | Get current non-dismissed notifications | No | Done | N/A |

<details>
<summary>Parameter schemas</summary>

**`notification_listener_read`**
```json
{
  "package": "(string, optional) app package name filter",
  "limit": "(integer, optional) default 20",
  "after_date": "(string, optional) ISO 8601"
}
```

**`notification_listener_active`** — No parameters.

</details>

---

## 27. Usage Stats (Android only, Privileged)

**Channel:** `ferri/usage_stats` | **Tier:** Privileged

Requires granting Usage Access in Android system settings.

| Tool | Description | Destructive | Android | iOS |
|---|---|---|---|---|
| `usage_stats_query` | App usage stats for N days | No | Done | N/A |
| `usage_stats_current` | Currently active app + screen time | No | Done | N/A |

<details>
<summary>Parameter schemas</summary>

**`usage_stats_query`**
```json
{
  "days": "(integer, optional) default 1",
  "limit": "(integer, optional) default 20"
}
```

**`usage_stats_current`** — No parameters.

</details>

---

## 28. Accessibility (Android only, Privileged)

**Channel:** `ferri/accessibility` | **Tier:** Privileged

Requires granting Ferri Accessibility Service in Android system settings.

| Tool | Description | Destructive | Android | iOS |
|---|---|---|---|---|
| `accessibility_read_screen` | Read current screen content | No | Done | N/A |
| `accessibility_tap` | Tap an element by text or coordinates | Yes | Done | N/A |
| `accessibility_scroll` | Scroll in a direction | Yes | Done | N/A |
| `accessibility_type` | Type text into an editable field | Yes | Done | N/A |

<details>
<summary>Parameter schemas</summary>

**`accessibility_read_screen`** — No parameters.
Response: package name, text nodes, interactive elements.

**`accessibility_tap`**
```json
{
  "text": "(string, optional) element text to match",
  "x": "(number, optional) X coordinate in pixels",
  "y": "(number, optional) Y coordinate in pixels"
}
```
Provide either `text` or `x`/`y` coordinates.

**`accessibility_scroll`**
```json
{
  "direction": "(string, optional) 'up', 'down', 'forward', 'backward' (default: 'down')"
}
```

**`accessibility_type`**
```json
{
  "text": "(string, required) text to type",
  "field_label": "(string, optional) target field label"
}
```

</details>

---

## Summary

| Tier | Capabilities | Tools |
|---|---|---|
| Core | Calendar, Contacts, Location, SMS, Device Info, Alarms, App Launcher, Clipboard, Notifications, Reminders, Audio, Files, Maps, Phone, Email, Sharing, Wi-Fi, Sensors | 53 |
| Extended | Camera, Voice, Health, Bluetooth, Call Log, NFC, Geofence | 18 |
| Privileged | Notification Listener, Usage Stats, Accessibility | 8 |
| **Total** | **28** | **79+** |
