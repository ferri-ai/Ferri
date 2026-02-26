# Ferri Features List — Android vs iOS

**Last updated:** 2026-02-23
**Purpose:** Single source of truth for what's implemented on each platform. Update this document every time a feature is implemented, modified, or removed on either platform.

**Status key:** Done = implemented and working | Planned = designed, not yet built | N/A = not possible on this platform | Partial = partially implemented

---

## 1. Core Infrastructure

| Feature | Android | iOS | Notes |
|---|---|---|---|
| Go engine (libferri) | Done | Planned | Same source. Android = `.so` (dynamic), iOS = `.a` (static archive via XCFramework) |
| FFI bridge (dart:ffi) | Done | Planned | Android = `DynamicLibrary.open()`, iOS = `DynamicLibrary.process()` |
| Streaming token port | Done | Planned | NativePort, platform-agnostic |
| Tool dispatch port | Done | Planned | NativePort, platform-agnostic |
| Channel event port | Done | Planned | NativePort, platform-agnostic |
| Platform tool registration | Done | Planned | `ferri_register_platform_tool` — same API both platforms |

---

## 2. Screens & UI

All screens are Flutter/Dart and shared between platforms. Platform-specific UI adjustments noted.

| Screen | Android | iOS | Notes |
|---|---|---|---|
| Onboarding (Welcome) | Done | Planned | Shared Dart code |
| Onboarding (Provider Setup) | Done | Planned | Shared — supports OpenRouter, Anthropic, OpenAI, Groq, DeepSeek, SambaNova, Gemini, Custom Endpoint. Reads from bundled `assets/provider-metadata.json`. |
| Chat | Done | Planned | Shared — streaming, tool call cards, message bubbles, persistent JSONL chat log with tool call history |
| Capabilities | Done | Planned | Shared — iOS needs `Platform.isIOS` guards to hide Android-only caps and show iOS-exclusive caps |
| Channels | Done | Planned | iOS needs different background status indicator (periodic vs live) |
| Automation | Done | Planned | Shared — cron jobs and geofence triggers |
| Settings | Done | Planned | iOS needs companion server section for background execution. Android: includes background service toggle for cron/automation keep-alive. Clear Chat in DATA section. |
| Search Settings | Done | Planned | Shared — configure web search provider (Brave Search with API key). DuckDuckGo as fallback. |
| Memory | Done | Planned | Shared |

---

## 3. Capabilities & Tools

### 3.1 Calendar

**Channel:** `ferri/calendar`
**Tier:** Core

| Tool | Description | Android | iOS | Notes |
|---|---|---|---|---|
| `calendar_read_events` | Query events by date range | Done | Planned | Android: CalendarContract. iOS: EventKit `EKEventStore` |
| `calendar_create_event` | Create new calendar event | Done | Planned | Android returns Long ID, iOS returns string `eventIdentifier` |
| `calendar_update_event` | Update existing event | Done | Planned | Same contract |
| `calendar_delete_event` | Delete event by ID | Done | Planned | Same contract |

### 3.2 Contacts

**Channel:** `ferri/contacts`
**Tier:** Core

| Tool | Description | Android | iOS | Notes |
|---|---|---|---|---|
| `contacts_search` | Search contacts by name | Done | Planned | Android: ContactsContract. iOS: CNContactStore |
| `contacts_read` | Get full contact details | Done | Planned | Android uses integer ID, iOS uses string UUID |
| `contacts_create` | Create new contact | Done | Planned | Same contract |
| `contacts_update` | Update contact fields | Done | Planned | Same contract |
| `contacts_delete` | Delete contact by ID | Done | Planned | Same contract |

### 3.3 Location

**Channel:** `ferri/location`
**Tier:** Core

| Tool | Description | Android | iOS | Notes |
|---|---|---|---|---|
| `location_get_current` | Get current GPS coordinates | Done | Planned | Android: LocationManager. iOS: CLLocationManager (delegate-based, async) |
| `location_geocode` | Address string → coordinates | Done | Planned | Android: Geocoder. iOS: CLGeocoder |
| `location_reverse_geocode` | Coordinates → address | Done | Planned | Same pattern |

### 3.4 SMS

**Channel:** `ferri/sms`
**Tier:** Core

| Tool | Description | Android | iOS | Notes |
|---|---|---|---|---|
| `sms_read` | Read SMS inbox/sent messages | Done | N/A | iOS has no SMS inbox API. Returns structured error on iOS. |
| `sms_send` | Send SMS message | Done | Partial | Android: `SmsManager.sendTextMessage()` (silent). iOS: `MFMessageComposeViewController` (user must tap Send). |

### 3.5 Device Info

**Channel:** `ferri/device_info`
**Tier:** Core

| Tool | Description | Android | iOS | Notes |
|---|---|---|---|---|
| `device_info` | Get device model, OS version | Done | Planned | Android: `Build`. iOS: `UIDevice.current` |
| `device_battery` | Battery level, charging status | Done | Planned | Android: BatteryManager. iOS: `UIDevice.batteryLevel` (no charging source detail on iOS). |
| `device_storage` | Total/used/free storage | Done | Planned | Android: `StatFs`. iOS: `FileManager.attributesOfFileSystem` |
| `device_connectivity` | Network type (wifi/cellular) | Done | Planned | Android: ConnectivityManager. iOS: `NWPathMonitor` |
| `device_flashlight` | Toggle flashlight on/off | Done | Planned | Android: CameraManager. iOS: `AVCaptureDevice.torchMode` |
| `device_brightness` | Set screen brightness | Done | Planned | Android: 0-255. iOS: 0.0-1.0 (normalized in Swift). |

### 3.6 Alarms

**Channel:** `ferri/alarms`
**Tier:** Core

| Tool | Description | Android | iOS | Notes |
|---|---|---|---|---|
| `alarm_set` | Set alarm at specific time | Done | Planned | Android: AlarmClock intent (delegates to Clock app). iOS: EventKit Reminder with due date + alarm. |
| `alarm_set_timer` | Set countdown timer | Done | Planned | Android: timer intent. iOS: Reminder with due = now + duration. |
| `alarm_show` | Open alarms/reminders app | Done | Planned | Android: Clock app. iOS: Reminders app via URL scheme. |

### 3.7 App Launcher

**Channel:** `ferri/app_launcher`
**Tier:** Core

| Tool | Description | Android | iOS | Notes |
|---|---|---|---|---|
| `app_launch` | Launch app by name/package | Done | Planned | Android: `PackageManager.getLaunchIntentForPackage()`. iOS: URL schemes only — curated map of common apps. |
| `app_list` | List installed apps | Done | N/A | iOS doesn't allow listing installed apps. Returns structured error. |

### 3.8 Camera

**Channel:** `ferri/camera`
**Tier:** Extended

| Tool | Description | Android | iOS | Notes |
|---|---|---|---|---|
| `camera_capture_photo` | Take photo with camera | Done | Planned | Both use Flutter `camera`/`image_picker` plugins. iOS: AVCaptureSession. |
| `camera_pick_image` | Pick image from gallery | Done | Planned | iOS: `PHPickerViewController` preferred (no full library permission needed). |

### 3.9 Voice

**Channel:** `ferri/voice`
**Tier:** Extended

| Tool | Description | Android | iOS | Notes |
|---|---|---|---|---|
| `voice_speak` | Text-to-speech | Done | Planned | Android: TTS engine. iOS: `AVSpeechSynthesizer`. |
| `voice_listen` | Speech-to-text | Done | Planned | Both: `speech_to_text` plugin. iOS also: `SFSpeechRecognizer` with on-device option. |

### 3.10 Health

**Channel:** `ferri/health`
**Tier:** Extended

| Tool | Description | Android | iOS | Notes |
|---|---|---|---|---|
| `health_check_availability` | Check if health data available | Done | Planned | Android: Health Connect app check. iOS: `HKHealthStore.isHealthDataAvailable()` (false on iPad). |
| `health_read_steps` | Read step count | Done | Planned | Android: Health Connect. iOS: HealthKit `stepCount`. |
| `health_read_heart_rate` | Read heart rate data | Done | Planned | Android: Health Connect. iOS: HealthKit `heartRate`. |
| `health_read_data` | Generic health data query | Done | Planned | Supports 12+ data types. iOS requires per-type authorization (unlike Android bulk). |

**Supported data types (both platforms):** steps, heart_rate, blood_glucose, blood_oxygen, blood_pressure_systolic, blood_pressure_diastolic, body_temperature, weight, height, sleep, workout, active_calories

### 3.11 Clipboard

**Channel:** `ferri/clipboard`
**Tier:** Core

| Tool | Description | Android | iOS | Notes |
|---|---|---|---|---|
| `clipboard_read` | Read clipboard text | Done | Planned | iOS 16+: triggers system paste permission banner. |
| `clipboard_write` | Write text to clipboard | Done | Planned | Same on both platforms. |

### 3.12 Notifications (Send)

**Channel:** `ferri/notifications`
**Tier:** Core

| Tool | Description | Android | iOS | Notes |
|---|---|---|---|---|
| `notification_send` | Send local notification | Done | Planned | Android: NotificationManager. iOS: `UNUserNotificationCenter`. |
| `notification_schedule` | Schedule future notification | Done | Planned | Android: AlarmManager. iOS: `UNCalendarNotificationTrigger`. |

### 3.13 Reminders

**Channel:** `ferri/reminders`
**Tier:** Core

| Tool | Description | Android | iOS | Notes |
|---|---|---|---|---|
| `reminder_set` | Create a reminder | Done | Planned | Android: AlarmManager + notification. iOS: EventKit `EKReminder`. |
| `reminder_list` | List active reminders | Done | Planned | Android: SharedPreferences. iOS: `EKEventStore.fetchReminders()`. |
| `reminder_cancel` | Cancel a reminder | Done | Planned | Same pattern. |

### 3.14 Bluetooth

**Channel:** `ferri/bluetooth`
**Tier:** Extended

| Tool | Description | Android | iOS | Notes |
|---|---|---|---|---|
| `bluetooth_get_state` | Check if Bluetooth is on | Done | Planned | Android: BluetoothAdapter. iOS: `CBCentralManager.state`. |
| `bluetooth_list_paired` | List paired/connected devices | Done | Partial | Android: `getBondedDevices()`. iOS: no paired list — returns `retrieveConnectedPeripherals()` instead. |
| `bluetooth_scan` | Scan for nearby BLE devices | Done | Planned | Android: BLE scanner. iOS: `CBCentralManager.scanForPeripherals()`. BLE only on iOS (no classic Bluetooth). |

### 3.15 Call Log (Android Only)

**Channel:** `ferri/calllog`
**Tier:** Extended

| Tool | Description | Android | iOS | Notes |
|---|---|---|---|---|
| `calllog_read` | Read call history | Done | N/A | iOS has no call history API. |
| `calllog_summary` | Call statistics for N days | Done | N/A | iOS has no call history API. |

### 3.16 Notification Listener (Android Only)

**Channel:** `ferri/notification_listener`
**Tier:** Privileged

| Tool | Description | Android | iOS | Notes |
|---|---|---|---|---|
| `notification_listener_read` | Read notifications from all apps | Done | N/A | No iOS equivalent. iOS `UNUserNotificationCenter` only manages own notifications. |
| `notification_listener_active` | Get current non-dismissed notifications | Done | N/A | No iOS equivalent. |

### 3.17 Usage Stats (Android Only)

**Channel:** `ferri/usage_stats`
**Tier:** Privileged

| Tool | Description | Android | iOS | Notes |
|---|---|---|---|---|
| `usage_stats_query` | App usage stats for N days | Done | N/A | iOS Screen Time data is not accessible to third-party apps. |
| `usage_stats_current` | Currently active app + screen time | Done | N/A | No iOS equivalent. |

### 3.18 Accessibility (Android Only)

**Channel:** `ferri/accessibility`
**Tier:** Privileged

| Tool | Description | Android | iOS | Notes |
|---|---|---|---|---|
| `accessibility_read_screen` | Read current screen content | Done | N/A | iOS doesn't allow third-party apps to read other apps' UI. |
| `accessibility_tap` | Tap element by text or coordinates | Done | N/A | No iOS equivalent. |
| `accessibility_scroll` | Scroll in a direction | Done | N/A | No iOS equivalent. |
| `accessibility_type` | Type text into editable field | Done | N/A | No iOS equivalent. |

### 3.19 Phone (Dial)

**Channel:** `ferri/phone`
**Tier:** Core

| Tool | Description | Android | iOS | Notes |
|---|---|---|---|---|
| `phone_dial` | Open dialer with pre-filled number | Done | Planned | Android: `ACTION_DIAL` (user taps call). Optional `CALL_PHONE` permission for direct call mode. iOS: `tel:` URL scheme. |

### 3.20 Email

**Channel:** `ferri/email`
**Tier:** Core

| Tool | Description | Android | iOS | Notes |
|---|---|---|---|---|
| `email_compose` | Open email app with pre-filled fields | Done | Planned | Android: `ACTION_SENDTO` intent. iOS: `MFMailComposeViewController`. User reviews and sends manually. |

### 3.21 Maps

**Channel:** `ferri/maps`
**Tier:** Core

| Tool | Description | Android | iOS | Notes |
|---|---|---|---|---|
| `maps_open` | Open location in maps by query/address/coordinates | Done | Planned | Android: `geo:` intent. iOS: MapKit URL scheme. |
| `maps_navigate` | Start turn-by-turn navigation | Done | Planned | Modes: driving (default), walking, bicycling, transit. Android: Google Maps intent. iOS: Apple Maps URL. |

### 3.22 Sharing

**Channel:** `ferri/sharing`
**Tier:** Core

| Tool | Description | Android | iOS | Notes |
|---|---|---|---|---|
| `share_text` | Share text via Sharesheet | Done | Planned | Optional `subject` line for email apps. iOS: `UIActivityViewController`. |
| `share_file` | Share file from workspace | Done | Planned | Uses `FileProvider` for secure URI. Known limitation: may share path as text on some targets. |

### 3.23 Audio

**Channel:** `ferri/audio`
**Tier:** Core

| Tool | Description | Android | iOS | Notes |
|---|---|---|---|---|
| `audio_get_volume` | Get volume levels for all streams | Done | Planned | Returns current, max, percentage for music, ring, alarm, notification, call. |
| `audio_set_volume` | Set volume for a stream (0-100%) | Done | Planned | Streams: music, ring, alarm, notification, call. iOS: limited to `AVAudioSession` output volume. |
| `audio_get_mode` | Get ringer mode and DND status | Done | Planned | Returns normal/vibrate/silent and DND enabled state. |
| `audio_set_mode` | Set ringer mode or toggle DND | Done | Planned | DND requires notification policy access on Android. iOS: limited DND control. |
| `audio_media_control` | Control media playback | Done | Planned | Actions: play, pause, play_pause, stop, skip_next, skip_previous. Returns now-playing metadata. |

### 3.24 Wi-Fi

**Channel:** `ferri/wifi`
**Tier:** Core

| Tool | Description | Android | iOS | Notes |
|---|---|---|---|---|
| `wifi_get_info` | Get current Wi-Fi connection details | Done | Planned | Android: WifiManager. iOS: `NEHotspotNetwork` (requires entitlement). Returns SSID, BSSID, RSSI, link speed, IP. |
| `wifi_scan` | List nearby Wi-Fi networks | Done | N/A | iOS does not allow Wi-Fi scanning by third-party apps. |
| `wifi_get_state` | Check if Wi-Fi is enabled/connected | Done | Planned | Android: WifiManager. iOS: `NWPathMonitor` (connection type only, no enable/disable). |

### 3.25 Sensors

**Channel:** `ferri/sensors`
**Tier:** Core

| Tool | Description | Android | iOS | Notes |
|---|---|---|---|---|
| `sensor_list` | List all available hardware sensors | Done | Planned | Returns name, type, vendor, resolution, max range, power. iOS: `CMMotionManager` covers a subset. |
| `sensor_read` | Read a single sensor value | Done | Planned | Types: accelerometer, gyroscope, magnetometer, proximity, ambient_light, pressure, step_counter, gravity. |

### 3.26 Files

**Channel:** `ferri/files`
**Tier:** Core

| Tool | Description | Android | iOS | Notes |
|---|---|---|---|---|
| `files_list` | List files in workspace directory | Done | Planned | Scoped to app sandbox. Returns name, path, size, modified date, type. |
| `files_read` | Read a file from workspace | Done | Planned | Text files return content. Binary files return metadata. |
| `files_write` | Create/overwrite a text file in workspace | Done | Planned | Scoped to app sandbox. |
| `files_pick` | Open system file picker | Done | Planned | iOS: `UIDocumentPickerViewController`. Returns name, size, MIME type, URI. |
| `files_delete` | Delete a file from workspace | Done | Planned | Scoped to app sandbox. |

### 3.27 NFC

**Channel:** `ferri/nfc`
**Tier:** Extended

| Tool | Description | Android | iOS | Notes |
|---|---|---|---|---|
| `nfc_read` | Read next tapped NFC tag (30s timeout) | Done | Partial | Android: full NFC access. iOS: NDEF read only (foreground, `NFCNDEFReaderSession`). |
| `nfc_write` | Write NDEF message to next tapped tag | Done | N/A | iOS does not support NFC tag writing from third-party apps. |

### 3.28 Geofence

**Channel:** `ferri/geofence`
**Tier:** Extended

| Tool | Description | Android | iOS | Notes |
|---|---|---|---|---|
| `geofence_create` | Create geofence at location | Done | Planned | Accepts lat/lng or location name (geocoded). Triggers: enter, exit, dwell. Android: GMS `GeofencingClient`. iOS: `CLLocationManager` region monitoring. |
| `geofence_list` | List active geofences | Done | Planned | Returns coordinates, radius, trigger type. |
| `geofence_remove` | Remove geofence by ID | Done | Planned | Also deletes associated cron job. |

---

## 4. iOS-Exclusive Capabilities (Planned)

### 4.1 Siri & App Intents

**Channel:** `ferri/siri`
**Tier:** Extended

| Tool | Description | Android | iOS | Notes |
|---|---|---|---|---|
| `siri_get_voice_shortcut` | Get Siri shortcut phrase for an action | N/A | Planned | App Intents framework |
| `siri_list_shortcuts` | List all registered Ferri shortcuts | N/A | Planned | |

**App Intents (inbound — Siri triggers Ferri):** AskFerriIntent, ReadCalendarIntent, SendMessageIntent, CheckHealthIntent, ControlHomeIntent

### 4.2 HomeKit

**Channel:** `ferri/homekit`
**Tier:** Extended

| Tool | Description | Android | iOS | Notes |
|---|---|---|---|---|
| `homekit_list_homes` | List all HomeKit homes | N/A | Planned | `HMHomeManager` |
| `homekit_list_accessories` | List accessories in a room/home | N/A | Planned | |
| `homekit_get_characteristic` | Read a device characteristic | N/A | Planned | |
| `homekit_set_characteristic` | Control a device | N/A | Planned | Destructive — actuates physical devices |
| `homekit_execute_scene` | Trigger a HomeKit scene | N/A | Planned | Destructive |
| `homekit_list_scenes` | List available scenes | N/A | Planned | |

### 4.3 Focus Filters

**Channel:** `ferri/focus`
**Tier:** Extended

| Tool | Description | Android | iOS | Notes |
|---|---|---|---|---|
| `focus_get_current` | Get current Focus mode | N/A | Planned | Requires Focus Filter extension |
| `focus_get_filter_config` | Get Ferri's behavior config for a Focus | N/A | Planned | |

### 4.4 Live Activities & Dynamic Island

**Channel:** `ferri/live_activity`
**Tier:** Extended

| Tool | Description | Android | iOS | Notes |
|---|---|---|---|---|
| `live_activity_start` | Start a Live Activity on Lock Screen | N/A | Planned | ActivityKit |
| `live_activity_update` | Update an active Live Activity | N/A | Planned | |
| `live_activity_end` | End a Live Activity | N/A | Planned | |

### 4.5 WidgetKit

**Channel:** `ferri/widget`
**Tier:** Extended

| Tool | Description | Android | iOS | Notes |
|---|---|---|---|---|
| `widget_update_data` | Push data to home/lock screen widgets | N/A | Planned | 4 widget types: Agent Status, Quick Ask, Today Briefing, Lock Screen |

---

## 5. Services & Background Execution

| Service | Android | iOS | Notes |
|---|---|---|---|
| Foreground Service | Done (`FerriService.kt`) | N/A | Android-specific. Keeps app alive 24/7 for channels, cron jobs, and automations. User-togglable in Settings. |
| Accessibility Service | Done (`FerriAccessibilityService.kt`) | N/A | Android-specific. Reads screen, taps, scrolls. |
| Notification Listener | Done (`FerriNotificationListenerService.kt`) | N/A | Android-specific. Reads all system notifications. |
| BGAppRefreshTask | N/A | Planned | iOS periodic background check (15-60 min, OS controlled). |
| BGProcessingTask | N/A | Planned | iOS heavy background work (charging + WiFi). |
| Silent Push (companion server) | N/A | Planned | iOS real-time channel delivery via APNs. Optional. |

---

## 6. Channels (Messaging Integrations)

| Channel | Android | iOS | Notes |
|---|---|---|---|
| Telegram bot | Done | Planned | Android: runs in foreground service. iOS: periodic BGTask or companion server push. |
| Discord bot | Done | Planned | Same pattern as Telegram. |
| Slack bot | Done | Planned | Same pattern as Telegram. |

---

## 7. Automation

| Feature | Android | iOS | Notes |
|---|---|---|---|
| Cron jobs | Done | Planned | Go-side cron scheduler. Same on both platforms. |
| Geofence triggers | Done | Planned | Android: LocationManager. iOS: CLLocationManager region monitoring. |
| Heartbeat service | Done | Planned | Go-side. 30-min interval, reads HEARTBEAT.md. |

---

## 8. Build & Distribution

| Item | Android | iOS | Notes |
|---|---|---|---|
| Go engine build | Done (arm64, x86_64) | Planned (arm64, sim-arm64, sim-x86, XCFramework) | |
| Release signing | Done (keystore) | Planned (Apple Developer cert + provisioning) | |
| App store submission | Planned (Play Store) | Planned (App Store) | |
| Privacy nutrition labels | N/A | Planned | iOS App Store requirement. Competitive advantage: "Data Not Collected". |

---

## Summary Counts

| Metric | Android | iOS |
|---|---|---|
| Total capabilities | 28+ | 14 parity + 5 exclusive = 19 (planned) |
| Total tools | 79+ | 67+ parity + 15 exclusive = 82+ (planned). 12 Android-only tools excluded. |
| Kotlin/Swift channel files | 23 | 18 (planned, including iOS-exclusive) |
| Native services | 3 | 3 (planned, different: BGTask, Push, LiveActivity) |
| App extensions | 0 | 3 (planned: Intents, Widget, Focus Filter) |
