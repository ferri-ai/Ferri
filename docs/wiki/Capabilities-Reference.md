# Capabilities Reference

Exhaustive reference of every capability domain and tool available in Ferri. Each capability is a domain of native phone functionality exposed as one or more tools that the AI agent can call during a conversation. Tools are registered with the Go engine at runtime when the user enables a capability in Settings.

**79+ tools** are implemented on Android. iOS parity is planned.

---

## How to Read This Document

Each capability section lists:

- **Channel** -- the platform channel identifier (e.g. `ferri/calendar`)
- **Tier** -- Core (standard OS permissions) or Extended (additional setup or privileged access)
- **Permissions** -- Android permissions required at runtime
- **Tools table** -- every tool in the capability with its test status

**Test status key:**

| Status | Meaning |
|--------|---------|
| Tested | Passed manual testing on physical Android device |
| Known Issue | Has a specific bug documented in the Notes column |
| Skipped | Could not be tested due to hardware or account limitations |
| To Be Tested | Not yet tested on device |

**Destructive tools** are marked with `[D]` in the tool name column. These tools may modify data and can trigger an approval prompt before execution if the user has enabled approval mode.

---

## Core Capabilities

### Calendar

**Channel:** `ferri/calendar`
**Tier:** Core
**Android:** Tested | **iOS:** Coming Soon
**Permissions:** `READ_CALENDAR`, `WRITE_CALENDAR`

Reads, creates, updates, and deletes calendar events via Android's `CalendarContract`. Handles recurring events through the Instances URI. If no writable calendar exists on the device, Ferri creates a local `ACCOUNT_TYPE_LOCAL` calendar automatically.

| Tool | Description | Status | Notes |
|------|-------------|--------|-------|
| `calendar_read_events` | Query events by date range | Tested | Returns event_id, title, start, end, location, description, calendar_id, all_day |
| `calendar_create_event` | Create a new calendar event | Tested | Returns created event ID. Falls back to creating a local calendar if none exist |
| `calendar_update_event` [D] | Update an existing event by ID | Tested | Partial updates supported -- only changed fields required |
| `calendar_delete_event` [D] | Delete an event by ID | Tested | Approval prompt if enabled |

**Parameters (read):** `start_date` (required), `end_date` (required), `calendar_id` (optional). Dates in ISO 8601 format.

---

### Contacts

**Channel:** `ferri/contacts`
**Tier:** Core
**Android:** Tested | **iOS:** Coming Soon
**Permissions:** `READ_CONTACTS`, `WRITE_CONTACTS`

Full CRUD on the device contact book via Android's `ContactsContract`. Search supports fuzzy name matching. Contact IDs are integer-based on Android (string UUIDs on iOS when implemented).

| Tool | Description | Status | Notes |
|------|-------------|--------|-------|
| `contacts_search` | Search contacts by name | Tested | Empty query returns all contacts. Supports `limit` parameter (default 20) |
| `contacts_read` | Get full contact details by ID | Tested | Returns display_name, phone numbers, email addresses |
| `contacts_create` | Create a new contact | Tested | Returns raw contact ID |
| `contacts_update` [D] | Update contact fields | Tested | Replaces existing phone/email with provided values |
| `contacts_delete` [D] | Delete a contact by ID | Tested | |

---

### Location

**Channel:** `ferri/location`
**Tier:** Core
**Android:** Tested | **iOS:** Coming Soon
**Permissions:** `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`

GPS positioning and geocoding via Android's `LocationManager` and `Geocoder`. Also used internally by the geofence capability to resolve location names to coordinates.

| Tool | Description | Status | Notes |
|------|-------------|--------|-------|
| `location_get_current` | Get current GPS coordinates | Tested | Returns latitude, longitude, accuracy, altitude, provider |
| `location_geocode` | Address string to coordinates | Tested | Returns array of matches with lat, lng, full address. `max_results` param (default 5) |
| `location_reverse_geocode` | Coordinates to street address | Tested | Returns address, city, state, country, postal code |

---

### SMS

**Channel:** `ferri/sms`
**Tier:** Core
**Android:** Tested | **iOS:** Partial (send only)
**Permissions:** `READ_SMS`, `SEND_SMS`

Read and send text messages. On Android, `sms_send` uses `SmsManager.sendTextMessage()` which sends silently without user confirmation. Long messages are automatically split into multi-part SMS.

| Tool | Description | Status | Notes |
|------|-------------|--------|-------|
| `sms_read` | Read SMS inbox/sent messages | Tested | Reports "no messages" on devices without SIM. Supports `address`, `limit`, `type` filters |
| `sms_send` [D] | Send an SMS message | Tested | Fire-and-forget -- no delivery confirmation returned. iOS requires user tap to confirm |

---

### Device Info

**Channel:** `ferri/device_info`
**Tier:** Core
**Android:** Tested | **iOS:** Coming Soon
**Permissions:** None (basic info). `WRITE_SETTINGS` special permission for brightness.

Exposes device hardware information, battery status, storage, network connectivity, flashlight, and screen brightness. Six tools in one capability.

| Tool | Description | Status | Notes |
|------|-------------|--------|-------|
| `device_info` | Get manufacturer, model, Android version, SDK version | Tested | |
| `device_battery` | Battery level, charging state, source, temperature | Tested | |
| `device_storage` | Total, used, and free storage in GB | Tested | |
| `device_connectivity` | Network type (wifi/cellular/ethernet) | Known Issue | Missing `ACCESS_NETWORK_STATE` in earlier builds. Fix added to manifest, needs rebuild to verify |
| `device_flashlight` [D] | Toggle flashlight on/off | Tested | Uses CameraManager torch mode |
| `device_brightness` [D] | Set screen brightness (0-255) | Tested | Requires `WRITE_SETTINGS` special permission. Switches to manual brightness mode |

---

### Alarms

**Channel:** `ferri/alarms`
**Tier:** Core
**Android:** Tested | **iOS:** Coming Soon
**Permissions:** `SET_ALARM` (normal permission, auto-granted)

Delegates to the system Clock app via `AlarmClock` intents. Alarms persist even if Ferri is closed.

| Tool | Description | Status | Notes |
|------|-------------|--------|-------|
| `alarm_set` | Set alarm at specific hour:minute | Tested | Uses 24-hour format. Optional `message` label |
| `alarm_set_timer` | Set countdown timer in seconds | Tested | Opens system Clock timer UI |
| `alarm_show` | Open the system alarms app | Tested | |

---

### App Launcher

**Channel:** `ferri/app_launcher`
**Tier:** Core
**Android:** Tested | **iOS:** Partial
**Permissions:** None

Launch installed apps by name (fuzzy match) or exact package name. List installed apps with optional name filter.

| Tool | Description | Status | Notes |
|------|-------------|--------|-------|
| `app_launch` | Launch app by name or package | Tested | Fuzzy name search (e.g. "Spotify") or exact package (e.g. "com.spotify.music") |
| `app_list` | List installed applications | Tested | Returns app name and package name. `query` filter, `limit` param (default 30). iOS: N/A |

---

### Notifications (Send)

**Channel:** `ferri/notification`
**Tier:** Core
**Android:** Tested | **iOS:** Coming Soon
**Permissions:** `POST_NOTIFICATIONS` (Android 13+)

Send and schedule local notifications via Android's `NotificationManager` and `AlarmManager`.

| Tool | Description | Status | Notes |
|------|-------------|--------|-------|
| `notification_send` | Send immediate notification | Tested | 71ms response time. Returns notification ID. Default title: "Ferri" |
| `notification_schedule` | Schedule notification after delay | Tested | `delay_seconds` param (default 60) |

---

### Reminders

**Channel:** `ferri/reminder`
**Tier:** Core
**Android:** Tested | **iOS:** Coming Soon
**Permissions:** `POST_NOTIFICATIONS`

Persistent reminders backed by `AlarmManager` and `SharedPreferences`. Supports absolute time (`at_time`) or relative delay (`delay_seconds`).

| Tool | Description | Status | Notes |
|------|-------------|--------|-------|
| `reminder_set` | Create a reminder | Tested | Accepts `at_time` (ISO 8601) or `delay_seconds`. Returns reminder ID |
| `reminder_list` | List all pending reminders | Tested | Returns ID, message, trigger time |
| `reminder_cancel` [D] | Cancel a pending reminder | Tested | By reminder ID |

---

### Clipboard

**Channel:** `ferri/clipboard`
**Tier:** Core
**Android:** Tested | **iOS:** Coming Soon
**Permissions:** None

Read from and write to the system clipboard. No permissions required on Android. iOS 16+ triggers a system paste permission banner on read.

| Tool | Description | Status | Notes |
|------|-------------|--------|-------|
| `clipboard_read` | Read clipboard text content | Tested | |
| `clipboard_write` | Write text to clipboard | Tested | |

---

### Phone

**Channel:** `ferri/phone`
**Tier:** Core
**Android:** Tested | **iOS:** Coming Soon
**Permissions:** None (dialer). `CALL_PHONE` for direct calls.

Opens the phone dialer with a pre-filled number. By default uses `ACTION_DIAL` (opens dialer UI for user confirmation). If `direct` is true and `CALL_PHONE` permission is granted, initiates the call automatically.

| Tool | Description | Status | Notes |
|------|-------------|--------|-------|
| `phone_dial` | Open dialer with number | Tested | Default: opens dialer UI, does not auto-call |

---

### Email

**Channel:** `ferri/email`
**Tier:** Core
**Android:** Skipped | **iOS:** Coming Soon
**Permissions:** None

Opens the default email app with pre-filled fields. User reviews and sends manually.

| Tool | Description | Status | Notes |
|------|-------------|--------|-------|
| `email_compose` | Compose email with to, cc, subject, body | Skipped | Requires Gmail/email app sign-in on device. Not testable on test device without account |

---

### Maps

**Channel:** `ferri/maps`
**Tier:** Core
**Android:** Tested | **iOS:** Coming Soon
**Permissions:** None

Open locations in the maps app or start turn-by-turn navigation. Uses Google Maps intents on Android.

| Tool | Description | Status | Notes |
|------|-------------|--------|-------|
| `maps_open` | Open location by query, address, or coordinates | Tested | Supports search queries like "coffee shops near me" |
| `maps_navigate` | Start navigation to destination | Tested | Modes: driving (default), walking, bicycling, transit |

---

### Sharing

**Channel:** `ferri/sharing`
**Tier:** Core
**Android:** Tested | **iOS:** Coming Soon
**Permissions:** None

Share text and files to other apps via the Android Sharesheet. File sharing uses `FileProvider` for secure URI generation.

| Tool | Description | Status | Notes |
|------|-------------|--------|-------|
| `share_text` | Share text via Sharesheet | Tested | Optional `subject` line for email apps |
| `share_file` [D] | Share file from workspace | Tested | Known limitation: shares file path as text, not the file content itself on some targets |

---

### Audio

**Channel:** `ferri/audio`
**Tier:** Core
**Android:** Tested | **iOS:** Coming Soon
**Permissions:** `MODIFY_AUDIO_SETTINGS` (normal, auto-granted)

Volume control for all audio streams, ringer mode management, Do Not Disturb toggle, and media playback control. DND requires notification policy access permission.

| Tool | Description | Status | Notes |
|------|-------------|--------|-------|
| `audio_get_volume` | Get volume levels for all streams | Tested | Returns current, max, and percentage for music, ring, alarm, notification, call |
| `audio_set_volume` [D] | Set volume for a stream (0-100%) | Tested | Streams: music, ring, alarm, notification, call |
| `audio_get_mode` | Get ringer mode and DND status | Tested | Returns normal/vibrate/silent and DND enabled state |
| `audio_set_mode` [D] | Set ringer mode or toggle DND | Tested | DND requires notification policy access |
| `audio_media_control` [D] | Control media playback | Tested | Actions: play, pause, play_pause, stop, skip_next, skip_previous. Returns now-playing metadata |

---

### Sensors

**Channel:** `ferri/sensors`
**Tier:** Core
**Android:** Tested | **iOS:** Coming Soon
**Permissions:** None

Read hardware sensor data on demand. Supports accelerometer, gyroscope, magnetometer (compass), proximity, ambient light, barometer, step counter, and gravity.

| Tool | Description | Status | Notes |
|------|-------------|--------|-------|
| `sensor_list` | List all available hardware sensors | Tested | Returns name, type, vendor, resolution, max range, power consumption |
| `sensor_read` | Read a single sensor value | Tested | Types: accelerometer, gyroscope, magnetometer, proximity, ambient_light, pressure, step_counter, gravity |

---

### Files

**Channel:** `ferri/files`
**Tier:** Core
**Android:** Tested | **iOS:** Coming Soon
**Permissions:** None (scoped to Ferri workspace)

File operations scoped to Ferri's private workspace directory. No broad storage permissions required. The `files_pick` tool uses the system file picker to import files into the workspace.

| Tool | Description | Status | Notes |
|------|-------------|--------|-------|
| `files_list` | List files in workspace | Tested | Returns name, path, size, modified date, type. Optional `directory` subdirectory param |
| `files_read` | Read a file from workspace | Tested | Text files return content directly. Binary files return metadata and path |
| `files_write` [D] | Create or overwrite a text file | Tested | Within workspace directory only |
| `files_pick` | Open system file picker | Tested | Returns name, size, MIME type, URI. Text content included for text files. Images copied to workspace |
| `files_delete` [D] | Delete a file from workspace | Tested | |

---

### Wi-Fi

**Channel:** `ferri/wifi`
**Tier:** Core
**Android:** Tested | **iOS:** Coming Soon
**Permissions:** `ACCESS_FINE_LOCATION` (for scan results), `ACCESS_WIFI_STATE`, `CHANGE_WIFI_STATE`

View current Wi-Fi connection details and scan for nearby networks.

| Tool | Description | Status | Notes |
|------|-------------|--------|-------|
| `wifi_get_info` | Get current Wi-Fi connection details | Tested | Returns SSID, BSSID, RSSI (dBm), link speed, frequency, IP address |
| `wifi_scan` | List nearby Wi-Fi networks | Tested | Returns SSID, BSSID, signal strength, frequency, security capabilities |
| `wifi_get_state` | Check if Wi-Fi is enabled/connected | Tested | |

---

## Extended Capabilities

### Camera

**Channel:** `ferri/camera`
**Tier:** Extended
**Android:** Tested | **iOS:** Coming Soon
**Permissions:** `CAMERA`

Capture photos with the device camera or pick existing images from the gallery. Returns file path, name, and size.

| Tool | Description | Status | Notes |
|------|-------------|--------|-------|
| `camera_capture_photo` | Take photo with camera | Tested | `quality` param (1-100, default 85). User is prompted to take the photo |
| `camera_pick_image` | Pick image from gallery | Tested | Returns path and size. `quality` param for compression |

---

### Voice

**Channel:** `ferri/voice`
**Tier:** Extended
**Android:** Tested | **iOS:** Coming Soon
**Permissions:** `RECORD_AUDIO`

Text-to-speech and speech-to-text. TTS uses the Android TTS engine. STT uses the `speech_to_text` plugin.

| Tool | Description | Status | Notes |
|------|-------------|--------|-------|
| `voice_speak` | Speak text aloud (TTS) | Tested | 93-239ms response time. `language` (default en-US), `rate` (0.0-1.0, default 0.5) |
| `voice_listen` | Speech-to-text (STT) | Tested | 3645ms typical. `duration_seconds` (default 10), `language` params |

---

### Health

**Channel:** `ferri/health`
**Tier:** Extended
**Android:** Tested | **iOS:** Coming Soon
**Permissions:** `ACTIVITY_RECOGNITION`, plus Health Connect read permissions for each data type

Reads health and fitness data from Health Connect (Android) or HealthKit (iOS). Requires the Health Connect app to be installed. Supports 12+ data types: steps, heart_rate, blood_glucose, blood_oxygen, blood_pressure_systolic, blood_pressure_diastolic, body_temperature, weight, height, sleep, workout, active_calories.

| Tool | Description | Status | Notes |
|------|-------------|--------|-------|
| `health_check_availability` | Check if Health Connect is available | Tested | 44ms response. Returns availability status |
| `health_read_steps` | Read step count for date range | Tested | Defaults to today. No data returned if no tracking app connected |
| `health_read_heart_rate` | Read heart rate measurements | Tested | Defaults to last 24 hours. No data returned if no tracking app connected |
| `health_read_data` | Generic health data query by type | Tested | `data_type` required. `limit` param (default 50). No data if no tracking app connected |

---

### Bluetooth

**Channel:** `ferri/bluetooth`
**Tier:** Extended
**Android:** Tested | **iOS:** Coming Soon
**Permissions:** `BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT` (Android 12+)

Check Bluetooth state, list paired devices, and scan for nearby BLE devices.

| Tool | Description | Status | Notes |
|------|-------------|--------|-------|
| `bluetooth_get_state` | Check if Bluetooth is enabled | Tested | Returns availability, enabled state, adapter name |
| `bluetooth_list_paired` | List paired/bonded devices | Tested | Returns name, MAC address, type (classic/le/dual), bond state |
| `bluetooth_scan` | Scan for nearby BLE devices | Tested | `duration_ms` param (default 10000, max 30000). BLE devices may show "Unknown" name |

---

### Call Log (Android Only)

**Channel:** `ferri/calllog`
**Tier:** Extended
**Android:** Tested | **iOS:** N/A
**Permissions:** `READ_CALL_LOG`

Read call history and generate call statistics. Not available on iOS (no call history API).

| Tool | Description | Status | Notes |
|------|-------------|--------|-------|
| `calllog_read` | Read recent call history | Tested | Returns number, contact_name, type (incoming/outgoing/missed), date, duration_seconds. Supports filters |
| `calllog_summary` | Call statistics for N days | Tested | Returns total calls, type breakdown, durations, unique contacts, top 5 most-called |

---

### NFC

**Channel:** `ferri/nfc`
**Tier:** Extended
**Android:** Skipped | **iOS:** Coming Soon
**Permissions:** `NFC`

Read and write NDEF messages on NFC tags. Declared as `android:required="false"` in the manifest so the app installs on devices without NFC hardware.

| Tool | Description | Status | Notes |
|------|-------------|--------|-------|
| `nfc_read` | Read NFC tag (30s timeout) | Skipped | No NFC hardware on test device |
| `nfc_write` [D] | Write NDEF text/URL to tag | Skipped | No NFC hardware on test device |

---

### Geofence

**Channel:** `ferri/geofence`
**Tier:** Extended
**Android:** Tested | **iOS:** Coming Soon
**Permissions:** `ACCESS_FINE_LOCATION`, `ACCESS_BACKGROUND_LOCATION`

Location-based automation triggers. Creating a geofence sets up both a cron job (with `schedule.kind = 'geofence'`) and a native Google Mobile Services geofence. Removing a geofence cleans up both the cron job and the native GMS fence.

| Tool | Description | Status | Notes |
|------|-------------|--------|-------|
| `geofence_create` [D] | Create a geofence | Tested | Accepts lat/lng OR `location_name` (geocoded automatically). Triggers: enter, exit, dwell. Default radius: 100m |
| `geofence_list` | List all active geofences | Tested | Returns coordinates, radius, trigger type |
| `geofence_remove` [D] | Remove a geofence by ID | Tested | Removes both cron job and native GMS fence |

---

## Privileged Capabilities

These capabilities require the user to grant access through Android system settings screens rather than standard runtime permission dialogs. The `privileged` flag is set to `true` in the capability registry, and each has a `settingsRoute` pointing to the appropriate system settings activity.

### Notification Listener (Android Only)

**Channel:** `ferri/notification_listener`
**Tier:** Privileged
**Android:** Tested | **iOS:** N/A
**Permissions:** `BIND_NOTIFICATION_LISTENER_SERVICE` (system settings grant)
**Settings:** `android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS`

Reads notifications from all apps on the device via `NotificationListenerService`. Only captures notifications that arrive after the service is started.

| Tool | Description | Status | Notes |
|------|-------------|--------|-------|
| `notification_listener_read` | Read recent device notifications | Tested | Returns title, text, app name, date, category. Supports `package`, `limit`, `after_date` filters. Only captures post-service-start notifications |
| `notification_listener_active` | Get current non-dismissed notifications | Known Issue | Returns `[]` for notifications that existed before the service started. Only shows new notifications |

---

### Usage Stats (Android Only)

**Channel:** `ferri/usage_stats`
**Tier:** Privileged
**Android:** Tested | **iOS:** N/A
**Permissions:** `PACKAGE_USAGE_STATS` (system settings grant)
**Settings:** `android.settings.USAGE_ACCESS_SETTINGS`

App usage statistics and screen time data via Android's `UsageStatsManager`.

| Tool | Description | Status | Notes |
|------|-------------|--------|-------|
| `usage_stats_query` | App usage stats for N days | Tested | Returns per-app foreground time, last used date, sorted by most used. `days` param (default 1), `limit` (default 20) |
| `usage_stats_current` | Currently active app + screen time | Tested | `current_app` may show "Unknown" on some Android versions depending on manufacturer overlay |

---

### Accessibility (Android Only)

**Channel:** `ferri/accessibility`
**Tier:** Privileged
**Android:** Tested | **iOS:** N/A
**Permissions:** `BIND_ACCESSIBILITY_SERVICE` (system settings grant)
**Settings:** `android.settings.ACCESSIBILITY_SETTINGS`

Read screen content and interact with other apps. Uses Android's `AccessibilityService` to inspect the UI tree and perform actions. All interaction tools are destructive.

| Tool | Description | Status | Notes |
|------|-------------|--------|-------|
| `accessibility_read_screen` | Read structured snapshot of current screen | Tested | Returns app package, text nodes with bounds, interactive elements (clickable, scrollable, editable) |
| `accessibility_tap` [D] | Tap element by text or coordinates | Tested | Fuzzy text match, or fall back to x/y coordinates. Use `read_screen` first to find targets |
| `accessibility_scroll` [D] | Scroll in a direction | Tested | Directions: up, down, forward, backward. Known limitation: cannot find scrollable containers inside Flutter's own SurfaceView |
| `accessibility_type` [D] | Type text into editable field | Tested | Targets focused field or searches by `field_label`. Known limitation: cannot find EditText in Flutter's own UI |

---

## iOS Status

All iOS implementations are marked **Coming Soon**. The plan includes:

**Parity tools (67+ tools):** All Android tools that have iOS equivalents will be implemented using the corresponding iOS frameworks:

| Android API | iOS Framework |
|-------------|---------------|
| CalendarContract | EventKit (`EKEventStore`) |
| ContactsContract | CNContactStore |
| LocationManager | CLLocationManager |
| SmsManager | MFMessageComposeViewController (user confirmation required) |
| Health Connect | HealthKit |
| BluetoothAdapter | CoreBluetooth (`CBCentralManager`) |
| NotificationManager | UNUserNotificationCenter |
| CameraManager (torch) | AVCaptureDevice |

**Android-only tools (12 tools):** The following tools have no iOS equivalent and will return a structured error on iOS:

- `sms_read` -- iOS has no SMS inbox API
- `app_list` -- iOS does not allow listing installed apps
- `calllog_read`, `calllog_summary` -- iOS has no call history API
- `notification_listener_read`, `notification_listener_active` -- iOS only manages own notifications
- `usage_stats_query`, `usage_stats_current` -- Screen Time data not accessible to third-party apps
- `accessibility_read_screen`, `accessibility_tap`, `accessibility_scroll`, `accessibility_type` -- iOS does not allow third-party apps to read other apps' UI

**iOS-exclusive tools (15 tools planned):**

- **Siri & App Intents** (`ferri/siri`) -- `siri_get_voice_shortcut`, `siri_list_shortcuts`, plus 5 inbound App Intents
- **HomeKit** (`ferri/homekit`) -- `homekit_list_homes`, `homekit_list_accessories`, `homekit_get_characteristic`, `homekit_set_characteristic`, `homekit_execute_scene`, `homekit_list_scenes`
- **Focus Filters** (`ferri/focus`) -- `focus_get_current`, `focus_get_filter_config`
- **Live Activities** (`ferri/live_activity`) -- `live_activity_start`, `live_activity_update`, `live_activity_end`
- **WidgetKit** (`ferri/widget`) -- `widget_update_data`

---

## Summary

| Metric | Count |
|--------|-------|
| Total capabilities (Android) | 28+ |
| Total tools (Android) | 79+ |
| Tools tested | 74 |
| Tools with known issues | 3 (`device_connectivity`, `notification_listener_active`, `share_file`) |
| Tools skipped (hardware) | 3 (`nfc_read`, `nfc_write`, `email_compose`) |
| Kotlin channel files | 23 |
| Dart channel files | 30 |
| Privileged capabilities | 3 (Notification Listener, Usage Stats, Accessibility) |
| iOS parity tools planned | 58 |
| iOS exclusive tools planned | 15 |
