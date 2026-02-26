import 'package:flutter/material.dart';
import '../theme/colors.dart';
import 'models/capability.dart';

/// Static registry of all available capabilities and their tool schemas.
/// New capabilities are added here — the rest of the system discovers them
/// automatically via [allCapabilities].
class CapabilityRegistry {
  CapabilityRegistry._();

  static const calendar = Capability(
    id: 'calendar',
    displayName: 'Calendar',
    description: 'Read, create, update, and delete calendar events',
    icon: Icons.calendar_month,
    color: FerriColors.capCalendar,
    tier: CapabilityTier.core,
    permissions: [
      'android.permission.READ_CALENDAR',
      'android.permission.WRITE_CALENDAR',
    ],
    tools: [
      CapabilityTool(
        name: 'calendar_read_events',
        description:
            'Read calendar events within a date range. Returns a JSON array of events with title, start, end, location, and description.',
        schema: {
          'type': 'object',
          'properties': {
            'start_date': {
              'type': 'string',
              'description':
                  'Start date in ISO 8601 format (e.g. 2026-02-19T00:00:00)',
            },
            'end_date': {
              'type': 'string',
              'description':
                  'End date in ISO 8601 format (e.g. 2026-02-20T00:00:00)',
            },
            'calendar_id': {
              'type': 'string',
              'description': 'Optional calendar ID to filter by',
            },
          },
          'required': ['start_date', 'end_date'],
        },
      ),
      CapabilityTool(
        name: 'calendar_create_event',
        description:
            'Create a new calendar event. Returns the created event ID.',
        schema: {
          'type': 'object',
          'properties': {
            'title': {
              'type': 'string',
              'description': 'Event title',
            },
            'start_time': {
              'type': 'string',
              'description':
                  'Start time in ISO 8601 format (e.g. 2026-02-19T14:00:00)',
            },
            'end_time': {
              'type': 'string',
              'description':
                  'End time in ISO 8601 format (e.g. 2026-02-19T15:00:00)',
            },
            'location': {
              'type': 'string',
              'description': 'Optional event location',
            },
            'description': {
              'type': 'string',
              'description': 'Optional event description',
            },
            'calendar_id': {
              'type': 'string',
              'description':
                  'Optional calendar ID. Uses default calendar if omitted.',
            },
          },
          'required': ['title', 'start_time', 'end_time'],
        },
      ),
      CapabilityTool(
        name: 'calendar_update_event',
        destructive: true,
        description:
            'Update an existing calendar event. Provide the event_id and any fields to change. Returns the updated event.',
        schema: {
          'type': 'object',
          'properties': {
            'event_id': {
              'type': 'string',
              'description': 'The ID of the event to update',
            },
            'title': {
              'type': 'string',
              'description': 'New event title',
            },
            'start_time': {
              'type': 'string',
              'description':
                  'New start time in ISO 8601 format (e.g. 2026-02-19T14:00:00)',
            },
            'end_time': {
              'type': 'string',
              'description':
                  'New end time in ISO 8601 format (e.g. 2026-02-19T15:00:00)',
            },
            'location': {
              'type': 'string',
              'description': 'New event location',
            },
            'description': {
              'type': 'string',
              'description': 'New event description',
            },
          },
          'required': ['event_id'],
        },
      ),
      CapabilityTool(
        name: 'calendar_delete_event',
        destructive: true,
        description:
            'Delete a calendar event by its ID. Returns confirmation of deletion.',
        schema: {
          'type': 'object',
          'properties': {
            'event_id': {
              'type': 'string',
              'description': 'The ID of the event to delete',
            },
          },
          'required': ['event_id'],
        },
      ),
    ],
  );

  // ─── Contacts ─────────────────────────────────────

  static const contacts = Capability(
    id: 'contacts',
    displayName: 'Contacts',
    description: 'Search, read, create, update, and delete contacts',
    icon: Icons.contacts,
    color: FerriColors.capContacts,
    tier: CapabilityTier.core,
    permissions: [
      'android.permission.READ_CONTACTS',
      'android.permission.WRITE_CONTACTS',
    ],
    tools: [
      CapabilityTool(
        name: 'contacts_search',
        description:
            'Search contacts by name. Returns a JSON array of matching contacts with contact_id, display_name, has_phone, and starred.',
        schema: {
          'type': 'object',
          'properties': {
            'query': {
              'type': 'string',
              'description':
                  'Search query to match against contact names. Leave empty to list all contacts.',
            },
            'limit': {
              'type': 'integer',
              'description': 'Maximum number of results (default 20)',
            },
          },
          'required': [],
        },
      ),
      CapabilityTool(
        name: 'contacts_read',
        description:
            'Read full details of a contact by ID. Returns display_name, phone numbers, and email addresses.',
        schema: {
          'type': 'object',
          'properties': {
            'contact_id': {
              'type': 'string',
              'description': 'The contact ID to read',
            },
          },
          'required': ['contact_id'],
        },
      ),
      CapabilityTool(
        name: 'contacts_create',
        description: 'Create a new contact. Returns the created raw contact ID.',
        schema: {
          'type': 'object',
          'properties': {
            'name': {
              'type': 'string',
              'description': 'Contact display name',
            },
            'phone': {
              'type': 'string',
              'description': 'Optional phone number',
            },
            'email': {
              'type': 'string',
              'description': 'Optional email address',
            },
          },
          'required': ['name'],
        },
      ),
      CapabilityTool(
        name: 'contacts_update',
        destructive: true,
        description:
            'Update an existing contact. Provide contact_id and any fields to change.',
        schema: {
          'type': 'object',
          'properties': {
            'contact_id': {
              'type': 'string',
              'description': 'The contact ID to update',
            },
            'name': {
              'type': 'string',
              'description': 'New display name',
            },
            'phone': {
              'type': 'string',
              'description': 'New phone number (replaces existing)',
            },
            'email': {
              'type': 'string',
              'description': 'New email address (replaces existing)',
            },
          },
          'required': ['contact_id'],
        },
      ),
      CapabilityTool(
        name: 'contacts_delete',
        destructive: true,
        description: 'Delete a contact by ID.',
        schema: {
          'type': 'object',
          'properties': {
            'contact_id': {
              'type': 'string',
              'description': 'The contact ID to delete',
            },
          },
          'required': ['contact_id'],
        },
      ),
    ],
  );

  // ─── Location ─────────────────────────────────────

  static const location = Capability(
    id: 'location',
    displayName: 'Location',
    description: 'Get current location, geocode addresses, and reverse geocode',
    icon: Icons.location_on,
    color: FerriColors.capLocation,
    tier: CapabilityTier.core,
    permissions: [
      'android.permission.ACCESS_FINE_LOCATION',
      'android.permission.ACCESS_COARSE_LOCATION',
    ],
    tools: [
      CapabilityTool(
        name: 'location_get_current',
        description:
            'Get the device\'s current GPS location. Returns latitude, longitude, accuracy, altitude, and provider.',
        schema: {
          'type': 'object',
          'properties': {},
          'required': [],
        },
      ),
      CapabilityTool(
        name: 'location_geocode',
        description:
            'Convert an address string to GPS coordinates. Returns an array of matching locations with latitude, longitude, and full address.',
        schema: {
          'type': 'object',
          'properties': {
            'address': {
              'type': 'string',
              'description':
                  'Address to geocode (e.g. "1600 Amphitheatre Parkway, Mountain View, CA")',
            },
            'max_results': {
              'type': 'integer',
              'description': 'Maximum results to return (default 5)',
            },
          },
          'required': ['address'],
        },
      ),
      CapabilityTool(
        name: 'location_reverse_geocode',
        description:
            'Convert GPS coordinates to a street address. Returns address, city, state, country, and postal code.',
        schema: {
          'type': 'object',
          'properties': {
            'latitude': {
              'type': 'number',
              'description': 'Latitude coordinate',
            },
            'longitude': {
              'type': 'number',
              'description': 'Longitude coordinate',
            },
          },
          'required': ['latitude', 'longitude'],
        },
      ),
    ],
  );

  // ─── SMS ──────────────────────────────────────────

  static const sms = Capability(
    id: 'sms',
    displayName: 'SMS',
    description: 'Read and send text messages',
    icon: Icons.sms,
    color: FerriColors.capSms,
    tier: CapabilityTier.core,
    permissions: [
      'android.permission.READ_SMS',
      'android.permission.SEND_SMS',
    ],
    tools: [
      CapabilityTool(
        name: 'sms_read',
        description:
            'Read SMS messages. Returns a JSON array of messages with address, body, date, type (inbox/sent), and read status.',
        schema: {
          'type': 'object',
          'properties': {
            'address': {
              'type': 'string',
              'description':
                  'Optional phone number to filter messages by sender/recipient',
            },
            'limit': {
              'type': 'integer',
              'description': 'Maximum number of messages to return (default 20)',
            },
            'type': {
              'type': 'string',
              'description':
                  'Message type filter: "inbox", "sent", or "all" (default "all")',
            },
          },
          'required': [],
        },
      ),
      CapabilityTool(
        name: 'sms_send',
        destructive: true,
        description:
            'Send an SMS message to a phone number. Long messages are automatically split into multiple parts.',
        schema: {
          'type': 'object',
          'properties': {
            'to': {
              'type': 'string',
              'description': 'Recipient phone number',
            },
            'body': {
              'type': 'string',
              'description': 'Message text',
            },
          },
          'required': ['to', 'body'],
        },
      ),
    ],
  );

  // ─── Call Log ────────────────────────────────────

  static const callLog = Capability(
    id: 'call_log',
    displayName: 'Call Log',
    description: 'Read call history and call statistics',
    icon: Icons.call,
    color: FerriColors.capCallLog,
    tier: CapabilityTier.extended,
    permissions: [
      'android.permission.READ_CALL_LOG',
    ],
    tools: [
      CapabilityTool(
        name: 'calllog_read',
        description:
            'Read recent call history. Returns a JSON array of calls with number, contact_name, type (incoming/outgoing/missed), date, and duration_seconds.',
        schema: {
          'type': 'object',
          'properties': {
            'number': {
              'type': 'string',
              'description': 'Optional phone number to filter calls by',
            },
            'limit': {
              'type': 'integer',
              'description': 'Maximum number of calls to return (default 20)',
            },
            'type': {
              'type': 'string',
              'description':
                  'Call type filter: "incoming", "outgoing", "missed", or "all" (default "all")',
            },
            'after_date': {
              'type': 'string',
              'description':
                  'Only return calls after this date (ISO 8601 format, e.g. 2026-02-19T00:00:00)',
            },
          },
          'required': [],
        },
      ),
      CapabilityTool(
        name: 'calllog_summary',
        description:
            'Get call statistics for a recent period. Returns total calls, incoming/outgoing/missed counts, total and average duration, unique contacts, and top 5 most-called contacts.',
        schema: {
          'type': 'object',
          'properties': {
            'days': {
              'type': 'integer',
              'description': 'Number of days to summarize (default 7)',
            },
          },
          'required': [],
        },
      ),
    ],
  );

  // ─── Bluetooth ──────────────────────────────────

  static const bluetooth = Capability(
    id: 'bluetooth',
    displayName: 'Bluetooth',
    description: 'Scan for nearby devices and list paired devices',
    icon: Icons.bluetooth,
    color: FerriColors.capBluetooth,
    tier: CapabilityTier.extended,
    permissions: [
      'android.permission.BLUETOOTH_SCAN',
      'android.permission.BLUETOOTH_CONNECT',
    ],
    tools: [
      CapabilityTool(
        name: 'bluetooth_get_state',
        description:
            'Check if Bluetooth is enabled or disabled on the device. Returns availability, enabled state, and adapter name.',
        schema: {
          'type': 'object',
          'properties': {},
          'required': [],
        },
      ),
      CapabilityTool(
        name: 'bluetooth_list_paired',
        description:
            'List all paired/bonded Bluetooth devices. Returns name, MAC address, type (classic/le/dual), and bond state.',
        schema: {
          'type': 'object',
          'properties': {},
          'required': [],
        },
      ),
      CapabilityTool(
        name: 'bluetooth_scan',
        description:
            'Scan for nearby discoverable Bluetooth devices for ~10 seconds. Returns discovered devices with name, address, RSSI signal strength, and type.',
        schema: {
          'type': 'object',
          'properties': {
            'duration_ms': {
              'type': 'integer',
              'description':
                  'Scan duration in milliseconds (default 10000, max 30000)',
            },
          },
          'required': [],
        },
      ),
    ],
  );

  // ─── Notification Listener (Privileged) ─────────

  static const notificationListener = Capability(
    id: 'notification_listener',
    displayName: 'Notification Reader',
    description: 'Read all device notifications from any app',
    icon: Icons.notifications_none,
    color: FerriColors.capNotificationListener,
    tier: CapabilityTier.extended,
    privileged: true,
    settingsRoute: 'android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS',
    permissions: [],
    tools: [
      CapabilityTool(
        name: 'notification_listener_read',
        description:
            'Read recent device notifications. Returns title, text, app name, date, and category. Optionally filter by app package or time range.',
        schema: {
          'type': 'object',
          'properties': {
            'package': {
              'type': 'string',
              'description':
                  'Optional app package name to filter (e.g. "com.google.android.gm" for Gmail)',
            },
            'limit': {
              'type': 'integer',
              'description': 'Maximum notifications to return (default 20)',
            },
            'after_date': {
              'type': 'string',
              'description':
                  'Only return notifications after this date (ISO 8601)',
            },
          },
          'required': [],
        },
      ),
      CapabilityTool(
        name: 'notification_listener_active',
        description:
            'Get currently active (not dismissed) notifications in the status bar.',
        schema: {
          'type': 'object',
          'properties': {},
          'required': [],
        },
      ),
    ],
  );

  // ─── App Usage Stats (Privileged) ───────────────

  static const usageStats = Capability(
    id: 'usage_stats',
    displayName: 'App Usage',
    description: 'View app usage statistics and screen time',
    icon: Icons.bar_chart,
    color: FerriColors.capUsageStats,
    tier: CapabilityTier.extended,
    privileged: true,
    settingsRoute: 'android.settings.USAGE_ACCESS_SETTINGS',
    permissions: [],
    tools: [
      CapabilityTool(
        name: 'usage_stats_query',
        description:
            'Get app usage statistics for a time period. Returns per-app foreground time, last used date, sorted by most used. Default is today.',
        schema: {
          'type': 'object',
          'properties': {
            'days': {
              'type': 'integer',
              'description': 'Number of days to query (default 1 = today only)',
            },
            'limit': {
              'type': 'integer',
              'description': 'Maximum number of apps to return (default 20)',
            },
          },
          'required': [],
        },
      ),
      CapabilityTool(
        name: 'usage_stats_current',
        description:
            'Get the currently active foreground app and today\'s total screen time.',
        schema: {
          'type': 'object',
          'properties': {},
          'required': [],
        },
      ),
    ],
  );

  // ─── Accessibility Service (Privileged) ──────

  static const accessibility = Capability(
    id: 'accessibility',
    displayName: 'Accessibility',
    description: 'Read screen content and interact with other apps',
    icon: Icons.accessibility_new,
    color: FerriColors.capAccessibility,
    tier: CapabilityTier.extended,
    privileged: true,
    settingsRoute: 'android.settings.ACCESSIBILITY_SETTINGS',
    permissions: [],
    tools: [
      CapabilityTool(
        name: 'accessibility_read_screen',
        description:
            'Read a structured snapshot of the current screen. Returns the app package name, visible text nodes with bounds, and interactive elements (clickable, scrollable, editable).',
        schema: {
          'type': 'object',
          'properties': {},
          'required': [],
        },
      ),
      CapabilityTool(
        name: 'accessibility_tap',
        destructive: true,
        description:
            'Tap an element on screen. Provide text to match, or x/y coordinates. Use accessibility_read_screen first to find targets.',
        schema: {
          'type': 'object',
          'properties': {
            'text': {
              'type': 'string',
              'description': 'Text of the element to tap (fuzzy match)',
            },
            'x': {
              'type': 'number',
              'description': 'X coordinate (screen pixels) — use if text match fails',
            },
            'y': {
              'type': 'number',
              'description': 'Y coordinate (screen pixels) — use if text match fails',
            },
          },
          'required': [],
        },
      ),
      CapabilityTool(
        name: 'accessibility_scroll',
        destructive: true,
        description:
            'Scroll the current screen. Finds the first scrollable container and scrolls in the specified direction.',
        schema: {
          'type': 'object',
          'properties': {
            'direction': {
              'type': 'string',
              'description': 'Scroll direction: "up", "down", "forward", or "backward" (default: "down")',
            },
          },
          'required': [],
        },
      ),
      CapabilityTool(
        name: 'accessibility_type',
        destructive: true,
        description:
            'Type text into an input field. Targets the focused editable field, or searches by field_label.',
        schema: {
          'type': 'object',
          'properties': {
            'text': {
              'type': 'string',
              'description': 'Text to type into the field',
            },
            'field_label': {
              'type': 'string',
              'description': 'Optional label of the target input field',
            },
          },
          'required': ['text'],
        },
      ),
    ],
  );

  // ─── Notifications ─────────────────────────────────

  static const notifications = Capability(
    id: 'notifications',
    displayName: 'Notifications',
    description: 'Send and schedule device notifications',
    icon: Icons.notifications_active,
    color: FerriColors.capNotifications,
    tier: CapabilityTier.core,
    permissions: [
      'android.permission.POST_NOTIFICATIONS',
    ],
    tools: [
      CapabilityTool(
        name: 'notification_send',
        description:
            'Send a notification to the user\'s device immediately. Returns the notification ID.',
        schema: {
          'type': 'object',
          'properties': {
            'title': {
              'type': 'string',
              'description': 'Notification title (default: "Ferri")',
            },
            'body': {
              'type': 'string',
              'description': 'Notification body text',
            },
          },
          'required': ['body'],
        },
      ),
      CapabilityTool(
        name: 'notification_schedule',
        description:
            'Schedule a notification to be sent after a delay. Returns the scheduled notification ID.',
        schema: {
          'type': 'object',
          'properties': {
            'title': {
              'type': 'string',
              'description': 'Notification title (default: "Ferri")',
            },
            'body': {
              'type': 'string',
              'description': 'Notification body text',
            },
            'delay_seconds': {
              'type': 'integer',
              'description':
                  'Delay in seconds before sending (default: 60)',
            },
          },
          'required': ['body'],
        },
      ),
    ],
  );

  // ─── Camera ───────────────────────────────────────

  static const camera = Capability(
    id: 'camera',
    displayName: 'Camera',
    description: 'Capture photos and pick images from gallery',
    icon: Icons.camera_alt,
    color: FerriColors.capCamera,
    tier: CapabilityTier.extended,
    permissions: [
      'android.permission.CAMERA',
    ],
    tools: [
      CapabilityTool(
        name: 'camera_capture_photo',
        description:
            'Open the camera to capture a photo. Returns the file path, name, and size. The user will be prompted to take a photo.',
        schema: {
          'type': 'object',
          'properties': {
            'quality': {
              'type': 'integer',
              'description':
                  'Image quality (1-100, default 85). Lower = smaller file.',
            },
          },
          'required': [],
        },
      ),
      CapabilityTool(
        name: 'camera_pick_image',
        description:
            'Open the gallery to pick an existing image. Returns the file path, name, and size.',
        schema: {
          'type': 'object',
          'properties': {
            'quality': {
              'type': 'integer',
              'description':
                  'Image quality (1-100, default 85). Lower = smaller file.',
            },
          },
          'required': [],
        },
      ),
    ],
  );

  // ─── Voice I/O ────────────────────────────────────

  static const voice = Capability(
    id: 'voice',
    displayName: 'Voice',
    description: 'Text-to-speech and speech-to-text',
    icon: Icons.record_voice_over,
    color: FerriColors.capVoice,
    tier: CapabilityTier.extended,
    permissions: [
      'android.permission.RECORD_AUDIO',
    ],
    tools: [
      CapabilityTool(
        name: 'voice_speak',
        description:
            'Speak text aloud using text-to-speech. Use this to read content to the user audibly.',
        schema: {
          'type': 'object',
          'properties': {
            'text': {
              'type': 'string',
              'description': 'Text to speak aloud',
            },
            'language': {
              'type': 'string',
              'description': 'Language code (default: "en-US")',
            },
            'rate': {
              'type': 'number',
              'description':
                  'Speech rate (0.0-1.0, default 0.5). Higher = faster.',
            },
          },
          'required': ['text'],
        },
      ),
      CapabilityTool(
        name: 'voice_listen',
        description:
            'Listen for speech and transcribe to text. Activates the microphone for the specified duration.',
        schema: {
          'type': 'object',
          'properties': {
            'language': {
              'type': 'string',
              'description': 'Language code (default: "en-US")',
            },
            'duration_seconds': {
              'type': 'integer',
              'description':
                  'Maximum listening duration in seconds (default: 10)',
            },
          },
          'required': [],
        },
      ),
    ],
  );

  // ─── Health ──────────────────────────────────────

  static const health = Capability(
    id: 'health',
    displayName: 'Health',
    description: 'Read step count, heart rate, and health data',
    icon: Icons.monitor_heart,
    color: FerriColors.capHealth,
    tier: CapabilityTier.extended,
    permissions: [
      'android.permission.ACTIVITY_RECOGNITION',
    ],
    tools: [
      CapabilityTool(
        name: 'health_check_availability',
        description:
            'Check if Health Connect (Android) or HealthKit (iOS) is available on this device.',
        schema: {
          'type': 'object',
          'properties': {},
          'required': [],
        },
      ),
      CapabilityTool(
        name: 'health_read_steps',
        description:
            'Read the total step count for a date range. Defaults to today if no dates provided.',
        schema: {
          'type': 'object',
          'properties': {
            'start_date': {
              'type': 'string',
              'description':
                  'Start date in ISO 8601 format (e.g. 2026-02-19T00:00:00). Defaults to today midnight.',
            },
            'end_date': {
              'type': 'string',
              'description':
                  'End date in ISO 8601 format. Defaults to now.',
            },
          },
          'required': [],
        },
      ),
      CapabilityTool(
        name: 'health_read_heart_rate',
        description:
            'Read heart rate measurements for a date range. Returns BPM readings with timestamps. Defaults to last 24 hours.',
        schema: {
          'type': 'object',
          'properties': {
            'start_date': {
              'type': 'string',
              'description':
                  'Start date in ISO 8601 format. Defaults to 24 hours ago.',
            },
            'end_date': {
              'type': 'string',
              'description':
                  'End date in ISO 8601 format. Defaults to now.',
            },
          },
          'required': [],
        },
      ),
      CapabilityTool(
        name: 'health_read_data',
        description:
            'Read arbitrary health data by type. Supported types: steps, heart_rate, weight, blood_glucose, blood_pressure_systolic, blood_pressure_diastolic, body_temperature, blood_oxygen, sleep_session, workout.',
        schema: {
          'type': 'object',
          'properties': {
            'data_type': {
              'type': 'string',
              'description':
                  'Health data type to read (e.g. "weight", "blood_glucose", "sleep_session")',
            },
            'start_date': {
              'type': 'string',
              'description':
                  'Start date in ISO 8601 format. Defaults to 24 hours ago.',
            },
            'end_date': {
              'type': 'string',
              'description':
                  'End date in ISO 8601 format. Defaults to now.',
            },
            'limit': {
              'type': 'integer',
              'description': 'Maximum data points to return (default 50)',
            },
          },
          'required': ['data_type'],
        },
      ),
    ],
  );

  // ─── Alarms ─────────────────────────────────────

  static const alarms = Capability(
    id: 'alarms',
    displayName: 'Alarms',
    description: 'Set alarms, timers, and view system alarms',
    icon: Icons.alarm,
    color: FerriColors.capAlarms,
    tier: CapabilityTier.core,
    permissions: [], // SET_ALARM is a normal permission, auto-granted
    tools: [
      CapabilityTool(
        name: 'alarm_set',
        description:
            'Set an alarm at a specific time. Uses the system alarm app. The alarm will ring even if Ferri is closed.',
        schema: {
          'type': 'object',
          'properties': {
            'hour': {
              'type': 'integer',
              'description': 'Hour in 24-hour format (0-23)',
            },
            'minute': {
              'type': 'integer',
              'description': 'Minute (0-59)',
            },
            'message': {
              'type': 'string',
              'description': 'Optional label for the alarm',
            },
          },
          'required': ['hour', 'minute'],
        },
      ),
      CapabilityTool(
        name: 'alarm_set_timer',
        description:
            'Set a countdown timer for a specified number of seconds. Uses the system clock app.',
        schema: {
          'type': 'object',
          'properties': {
            'seconds': {
              'type': 'integer',
              'description':
                  'Timer duration in seconds (e.g. 300 for 5 minutes)',
            },
            'message': {
              'type': 'string',
              'description': 'Optional label for the timer',
            },
          },
          'required': ['seconds'],
        },
      ),
      CapabilityTool(
        name: 'alarm_show',
        description: 'Open the system alarms app to view all alarms.',
        schema: {
          'type': 'object',
          'properties': {},
          'required': [],
        },
      ),
    ],
  );

  // ─── Reminders ─────────────────────────────────

  static const reminders = Capability(
    id: 'reminders',
    displayName: 'Reminders',
    description: 'Set, list, and cancel reminders with notifications',
    icon: Icons.notifications_active,
    color: FerriColors.capReminders,
    tier: CapabilityTier.core,
    permissions: [
      'android.permission.POST_NOTIFICATIONS',
    ],
    tools: [
      CapabilityTool(
        name: 'reminder_set',
        description:
            'Set a reminder that will notify the user at a specific time or after a delay. '
            'Use at_time for an exact datetime, or delay_seconds for relative timing.',
        schema: {
          'type': 'object',
          'properties': {
            'message': {
              'type': 'string',
              'description': 'Reminder message text',
            },
            'title': {
              'type': 'string',
              'description':
                  'Optional title (default: "Ferri Reminder")',
            },
            'at_time': {
              'type': 'string',
              'description':
                  'Trigger time in ISO 8601 format (e.g. 2026-02-19T15:00:00)',
            },
            'delay_seconds': {
              'type': 'integer',
              'description':
                  'Trigger after this many seconds from now (e.g. 1800 for 30 minutes)',
            },
          },
          'required': ['message'],
        },
      ),
      CapabilityTool(
        name: 'reminder_list',
        description:
            'List all pending reminders. Returns reminder ID, message, and trigger time.',
        schema: {
          'type': 'object',
          'properties': {},
          'required': [],
        },
      ),
      CapabilityTool(
        name: 'reminder_cancel',
        destructive: true,
        description: 'Cancel a pending reminder by its ID.',
        schema: {
          'type': 'object',
          'properties': {
            'reminder_id': {
              'type': 'integer',
              'description': 'The ID of the reminder to cancel',
            },
          },
          'required': ['reminder_id'],
        },
      ),
    ],
  );

  // ─── Clipboard ─────────────────────────────────

  static const clipboard = Capability(
    id: 'clipboard',
    displayName: 'Clipboard',
    description: 'Read from and write to the device clipboard',
    icon: Icons.content_paste,
    color: FerriColors.capClipboard,
    tier: CapabilityTier.core,
    permissions: [], // No permissions needed
    tools: [
      CapabilityTool(
        name: 'clipboard_read',
        description:
            'Read the current text content of the device clipboard.',
        schema: {
          'type': 'object',
          'properties': {},
          'required': [],
        },
      ),
      CapabilityTool(
        name: 'clipboard_write',
        description:
            'Write text to the device clipboard so the user can paste it elsewhere.',
        schema: {
          'type': 'object',
          'properties': {
            'text': {
              'type': 'string',
              'description': 'Text to copy to clipboard',
            },
          },
          'required': ['text'],
        },
      ),
    ],
  );

  // ─── App Launcher ──────────────────────────────

  static const appLauncher = Capability(
    id: 'app_launcher',
    displayName: 'App Launcher',
    description: 'Launch apps and list installed applications',
    icon: Icons.apps,
    color: FerriColors.capAppLauncher,
    tier: CapabilityTier.core,
    permissions: [], // Uses implicit intent, no special permission needed
    tools: [
      CapabilityTool(
        name: 'app_launch',
        description:
            'Launch an app by name or package name. Use app_name for a fuzzy name search (e.g. "Spotify"), '
            'or package_name for an exact match (e.g. "com.spotify.music").',
        schema: {
          'type': 'object',
          'properties': {
            'app_name': {
              'type': 'string',
              'description':
                  'App name to search for (e.g. "Chrome", "Spotify", "Settings")',
            },
            'package_name': {
              'type': 'string',
              'description':
                  'Exact Android package name (e.g. "com.google.android.gm")',
            },
          },
          'required': [],
        },
      ),
      CapabilityTool(
        name: 'app_list',
        description:
            'List installed apps. Optionally filter by name. Returns app name and package name.',
        schema: {
          'type': 'object',
          'properties': {
            'query': {
              'type': 'string',
              'description':
                  'Optional search query to filter apps by name',
            },
            'limit': {
              'type': 'integer',
              'description':
                  'Maximum number of results (default 30)',
            },
          },
          'required': [],
        },
      ),
    ],
  );

  // ─── Phone Dial ───────────────────────────────

  static const phoneDial = Capability(
    id: 'phone_dial',
    displayName: 'Phone',
    description: 'Open the phone dialer with a pre-filled number',
    icon: Icons.phone,
    color: FerriColors.capPhoneDial,
    tier: CapabilityTier.core,
    permissions: [],
    tools: [
      CapabilityTool(
        name: 'phone_dial',
        description:
            'Open the phone dialer with a pre-filled number. If direct is true and CALL_PHONE permission is granted, initiates the call directly. Otherwise opens the dialer UI for the user to confirm.',
        schema: {
          'type': 'object',
          'properties': {
            'number': {
              'type': 'string',
              'description': 'Phone number to dial (e.g. "+1-555-123-4567")',
            },
            'direct': {
              'type': 'boolean',
              'description': 'If true, call directly (requires CALL_PHONE permission). Default false (opens dialer).',
            },
          },
          'required': ['number'],
        },
      ),
    ],
  );

  // ─── Email Compose ────────────────────────────────
  static const emailCompose = Capability(
    id: 'email_compose',
    displayName: 'Email',
    description: 'Compose emails with pre-filled fields',
    icon: Icons.email,
    color: FerriColors.capEmail,
    tier: CapabilityTier.core,
    permissions: [],
    tools: [
      CapabilityTool(
        name: 'email_compose',
        description:
            'Open the default email app with pre-filled to, cc, subject, and body. User reviews and sends manually.',
        schema: {
          'type': 'object',
          'properties': {
            'to': {
              'type': 'string',
              'description': 'Recipient email address',
            },
            'cc': {
              'type': 'string',
              'description': 'CC email address (optional)',
            },
            'subject': {
              'type': 'string',
              'description': 'Email subject line',
            },
            'body': {
              'type': 'string',
              'description': 'Email body text',
            },
          },
          'required': ['to'],
        },
      ),
    ],
  );

  // ─── Maps/Navigation ──────────────────────────
  static const mapsNav = Capability(
    id: 'maps_nav',
    displayName: 'Maps',
    description: 'Open locations in maps and start navigation',
    icon: Icons.map,
    color: FerriColors.capMapsNav,
    tier: CapabilityTier.core,
    permissions: [],
    tools: [
      CapabilityTool(
        name: 'maps_open',
        description:
            'Open a location in the maps app by coordinates, address, or search query.',
        schema: {
          'type': 'object',
          'properties': {
            'query': {
              'type': 'string',
              'description': 'Search query or address (e.g. "coffee shops near me", "1600 Amphitheatre Parkway")',
            },
            'latitude': {
              'type': 'number',
              'description': 'Latitude coordinate (use with longitude)',
            },
            'longitude': {
              'type': 'number',
              'description': 'Longitude coordinate (use with latitude)',
            },
          },
          'required': [],
        },
      ),
      CapabilityTool(
        name: 'maps_navigate',
        description:
            'Start turn-by-turn navigation to a destination. Supports driving, walking, bicycling, and transit modes.',
        schema: {
          'type': 'object',
          'properties': {
            'destination': {
              'type': 'string',
              'description': 'Destination address or place name',
            },
            'mode': {
              'type': 'string',
              'description': 'Navigation mode: "driving" (default), "walking", "bicycling", "transit"',
            },
          },
          'required': ['destination'],
        },
      ),
    ],
  );

  // ─── Sharing ──────────────────────────────────
  static const sharing = Capability(
    id: 'sharing',
    displayName: 'Sharing',
    description: 'Share text and files to other apps via the system Sharesheet',
    icon: Icons.share,
    color: FerriColors.capSharing,
    tier: CapabilityTier.core,
    permissions: [],
    tools: [
      CapabilityTool(
        name: 'share_text',
        description:
            'Share text content via the Android Sharesheet. User picks the target app. Optional subject line for email apps.',
        schema: {
          'type': 'object',
          'properties': {
            'text': {
              'type': 'string',
              'description': 'Text content to share',
            },
            'subject': {
              'type': 'string',
              'description': 'Optional subject line (used by email apps)',
            },
          },
          'required': ['text'],
        },
      ),
      CapabilityTool(
        name: 'share_file',
        description:
            'Share a file from workspace via the Android Sharesheet. Uses FileProvider for secure URI generation. User picks the target app.',
        schema: {
          'type': 'object',
          'properties': {
            'path': {
              'type': 'string',
              'description': 'File path to share (within workspace directory)',
            },
            'mime_type': {
              'type': 'string',
              'description':
                  'MIME type of the file (e.g. "image/png", "application/pdf"). Default: "*/*"',
            },
          },
          'required': ['path'],
        },
      ),
    ],
  );

  // ─── Audio/Media Control ──────────────────────────
  static const audio = Capability(
    id: 'audio',
    displayName: 'Audio',
    description: 'Volume control, ringer mode, DND, and media playback',
    icon: Icons.volume_up,
    color: FerriColors.capAudio,
    tier: CapabilityTier.core,
    permissions: ['android.permission.MODIFY_AUDIO_SETTINGS'],
    tools: [
      CapabilityTool(
        name: 'audio_get_volume',
        description:
            'Get current volume levels for all streams (music, ring, alarm, notification, call) with current, max, and percentage values.',
        schema: {
          'type': 'object',
          'properties': {},
          'required': [],
        },
      ),
      CapabilityTool(
        name: 'audio_set_volume',
        destructive: true,
        description:
            'Set volume for a specific stream as a percentage (0-100). Streams: music, ring, alarm, notification, call.',
        schema: {
          'type': 'object',
          'properties': {
            'stream': {
              'type': 'string',
              'description': 'Audio stream: "music" (default), "ring", "alarm", "notification", "call"',
            },
            'percent': {
              'type': 'integer',
              'description': 'Volume percentage (0-100)',
            },
          },
          'required': ['percent'],
        },
      ),
      CapabilityTool(
        name: 'audio_get_mode',
        description:
            'Get current ringer mode (normal/vibrate/silent) and DND (Do Not Disturb) status.',
        schema: {
          'type': 'object',
          'properties': {},
          'required': [],
        },
      ),
      CapabilityTool(
        name: 'audio_set_mode',
        destructive: true,
        description:
            'Set ringer mode (normal/vibrate/silent) or toggle DND. DND requires notification policy access permission.',
        schema: {
          'type': 'object',
          'properties': {
            'mode': {
              'type': 'string',
              'description': 'Ringer mode: "normal", "vibrate", or "silent"',
            },
            'dnd': {
              'type': 'boolean',
              'description': 'Enable (true) or disable (false) Do Not Disturb',
            },
          },
          'required': [],
        },
      ),
      CapabilityTool(
        name: 'audio_media_control',
        destructive: true,
        description:
            'Control current media playback: play, pause, play_pause, stop, skip_next, skip_previous. Returns now-playing metadata if available.',
        schema: {
          'type': 'object',
          'properties': {
            'action': {
              'type': 'string',
              'description': 'Media action: "play", "pause", "play_pause", "stop", "skip_next", "skip_previous"',
            },
          },
          'required': ['action'],
        },
      ),
    ],
  );

  // ─── Wi-Fi ────────────────────────────────────
  static const wifi = Capability(
    id: 'wifi',
    displayName: 'Wi-Fi',
    description: 'View Wi-Fi connection info and scan for networks',
    icon: Icons.wifi,
    color: FerriColors.capWifi,
    tier: CapabilityTier.core,
    permissions: ['android.permission.ACCESS_FINE_LOCATION'],
    tools: [
      CapabilityTool(
        name: 'wifi_get_info',
        description:
            'Get current Wi-Fi connection details: SSID, BSSID, signal strength (RSSI in dBm), link speed, frequency, and IP address.',
        schema: {
          'type': 'object',
          'properties': {},
          'required': [],
        },
      ),
      CapabilityTool(
        name: 'wifi_scan',
        description:
            'List nearby Wi-Fi networks from the last scan. Returns SSID, BSSID, signal strength, frequency, and security capabilities for each network.',
        schema: {
          'type': 'object',
          'properties': {},
          'required': [],
        },
      ),
      CapabilityTool(
        name: 'wifi_get_state',
        description:
            'Check if Wi-Fi is enabled/disabled and whether currently connected to a network.',
        schema: {
          'type': 'object',
          'properties': {},
          'required': [],
        },
      ),
    ],
  );

  // ─── Sensors ──────────────────────────────────
  static const sensors = Capability(
    id: 'sensors',
    displayName: 'Sensors',
    description: 'Read device hardware sensors on demand',
    icon: Icons.sensors,
    color: FerriColors.capSensors,
    tier: CapabilityTier.core,
    permissions: [],
    tools: [
      CapabilityTool(
        name: 'sensor_list',
        description:
            'List all available hardware sensors on this device with name, type, vendor, resolution, max range, and power consumption.',
        schema: {
          'type': 'object',
          'properties': {},
          'required': [],
        },
      ),
      CapabilityTool(
        name: 'sensor_read',
        description:
            'Read a single value from a hardware sensor. Supported: accelerometer, gyroscope, magnetometer (compass heading), proximity, ambient_light, pressure (barometer), step_counter, gravity.',
        schema: {
          'type': 'object',
          'properties': {
            'sensor': {
              'type': 'string',
              'description':
                  'Sensor type: "accelerometer", "gyroscope", "magnetometer", "proximity", "ambient_light", "pressure", "step_counter", "gravity"',
            },
          },
          'required': ['sensor'],
        },
      ),
    ],
  );

  // ─── Files & Documents ───────────────────────
  static const files = Capability(
    id: 'files',
    displayName: 'Files',
    description: 'Read, write, and pick files from the device',
    icon: Icons.folder,
    color: FerriColors.capFiles,
    tier: CapabilityTier.core,
    permissions: [],
    tools: [
      CapabilityTool(
        name: 'files_list',
        description:
            'List files in the workspace directory. Returns name, path, size, modified date, and type for each entry.',
        schema: {
          'type': 'object',
          'properties': {
            'directory': {
              'type': 'string',
              'description':
                  'Subdirectory within workspace to list (default: root)',
            },
          },
          'required': [],
        },
      ),
      CapabilityTool(
        name: 'files_read',
        description:
            'Read a file from workspace. Text files return content directly. Binary files return metadata and path.',
        schema: {
          'type': 'object',
          'properties': {
            'name': {
              'type': 'string',
              'description': 'File name or path within workspace',
            },
          },
          'required': ['name'],
        },
      ),
      CapabilityTool(
        name: 'files_write',
        destructive: true,
        description:
            'Create or overwrite a text file in the workspace directory.',
        schema: {
          'type': 'object',
          'properties': {
            'name': {
              'type': 'string',
              'description': 'File name (with optional subdirectory path)',
            },
            'content': {
              'type': 'string',
              'description': 'Text content to write',
            },
          },
          'required': ['name', 'content'],
        },
      ),
      CapabilityTool(
        name: 'files_pick',
        description:
            'Open the system file picker. User selects a file. Returns name, size, MIME type, and URI. Text files also return content. Images are copied to workspace.',
        schema: {
          'type': 'object',
          'properties': {
            'mime_type': {
              'type': 'string',
              'description':
                  'MIME type filter (e.g. "image/*", "application/pdf"). Default: "*/*"',
            },
          },
          'required': [],
        },
      ),
      CapabilityTool(
        name: 'files_delete',
        destructive: true,
        description: 'Delete a file from the workspace directory.',
        schema: {
          'type': 'object',
          'properties': {
            'name': {
              'type': 'string',
              'description':
                  'File name or path within workspace to delete',
            },
          },
          'required': ['name'],
        },
      ),
    ],
  );

  // ─── NFC ──────────────────────────────────────
  static const nfc = Capability(
    id: 'nfc',
    displayName: 'NFC',
    description: 'Read and write NFC tags',
    icon: Icons.nfc,
    color: FerriColors.capNfc,
    tier: CapabilityTier.extended,
    permissions: ['android.permission.NFC'],
    tools: [
      CapabilityTool(
        name: 'nfc_read',
        description:
            'Enable NFC reader mode and wait for the next tag tap (30s timeout). Returns tag ID, technology type, and NDEF records (text, URLs, raw data).',
        schema: {
          'type': 'object',
          'properties': {},
          'required': [],
        },
      ),
      CapabilityTool(
        name: 'nfc_write',
        destructive: true,
        description:
            'Write an NDEF message (text or URL) to the next tapped NFC tag (30s timeout). Returns success/failure and tag ID.',
        schema: {
          'type': 'object',
          'properties': {
            'text': {
              'type': 'string',
              'description': 'Text to write to the NFC tag',
            },
            'url': {
              'type': 'string',
              'description': 'URL to write to the NFC tag (takes priority over text)',
            },
          },
          'required': [],
        },
      ),
    ],
  );

  // ─── Geofence ─────────────────────────────────
  static const geofence = Capability(
    id: 'geofence',
    displayName: 'Geofence',
    description: 'Location-based automation triggers',
    icon: Icons.fence,
    color: FerriColors.capGeofence,
    tier: CapabilityTier.extended,
    permissions: [
      'android.permission.ACCESS_FINE_LOCATION',
      'android.permission.ACCESS_BACKGROUND_LOCATION',
    ],
    tools: [
      CapabilityTool(
        name: 'geofence_create',
        destructive: true,
        description:
            'Create a geofence at a location. Accepts lat/lng coordinates OR a location name (geocoded automatically). Triggers on enter, exit, or dwell.',
        schema: {
          'type': 'object',
          'properties': {
            'id': {
              'type': 'string',
              'description': 'Unique geofence ID (auto-generated if omitted)',
            },
            'latitude': {
              'type': 'number',
              'description': 'Latitude (use with longitude, or provide location_name instead)',
            },
            'longitude': {
              'type': 'number',
              'description': 'Longitude (use with latitude)',
            },
            'location_name': {
              'type': 'string',
              'description': 'Location name or address (geocoded to coordinates if lat/lng not provided)',
            },
            'radius': {
              'type': 'number',
              'description': 'Geofence radius in meters (default: 100)',
            },
            'trigger': {
              'type': 'string',
              'description': 'Trigger type: "enter" (default), "exit", or "dwell"',
            },
          },
          'required': [],
        },
      ),
      CapabilityTool(
        name: 'geofence_list',
        description:
            'List all active geofences with coordinates, radius, and trigger type.',
        schema: {
          'type': 'object',
          'properties': {},
          'required': [],
        },
      ),
      CapabilityTool(
        name: 'geofence_remove',
        destructive: true,
        description: 'Remove a geofence by its ID.',
        schema: {
          'type': 'object',
          'properties': {
            'id': {
              'type': 'string',
              'description': 'The geofence ID to remove',
            },
          },
          'required': ['id'],
        },
      ),
    ],
  );

  // ─── Device Info ───────────────────────────────

  static const deviceInfo = Capability(
    id: 'device_info',
    displayName: 'Device',
    description: 'Battery, storage, connectivity, flashlight, and brightness',
    icon: Icons.phone_android,
    color: FerriColors.capDeviceInfo,
    tier: CapabilityTier.core,
    permissions: [], // Basic device info needs no permissions
    tools: [
      CapabilityTool(
        name: 'device_info',
        description:
            'Get device information: manufacturer, model, Android version, SDK version.',
        schema: {
          'type': 'object',
          'properties': {},
          'required': [],
        },
      ),
      CapabilityTool(
        name: 'device_battery',
        description:
            'Get battery status: level percentage, charging state, charging source, and temperature.',
        schema: {
          'type': 'object',
          'properties': {},
          'required': [],
        },
      ),
      CapabilityTool(
        name: 'device_storage',
        description:
            'Get storage information: total, used, and free space in GB.',
        schema: {
          'type': 'object',
          'properties': {},
          'required': [],
        },
      ),
      CapabilityTool(
        name: 'device_connectivity',
        description:
            'Get current network connectivity: connected status and type (wifi, cellular, ethernet).',
        schema: {
          'type': 'object',
          'properties': {},
          'required': [],
        },
      ),
      CapabilityTool(
        name: 'device_flashlight',
        description:
            'Turn the device flashlight (torch) on or off.',
        schema: {
          'type': 'object',
          'properties': {
            'enabled': {
              'type': 'boolean',
              'description': 'true to turn on, false to turn off',
            },
          },
          'required': ['enabled'],
        },
      ),
      CapabilityTool(
        name: 'device_brightness',
        description:
            'Set the screen brightness level (0-255). Switches to manual brightness mode.',
        schema: {
          'type': 'object',
          'properties': {
            'level': {
              'type': 'integer',
              'description':
                  'Brightness level (0-255). 0 = dimmest, 255 = brightest.',
            },
          },
          'required': ['level'],
        },
      ),
    ],
  );

  /// All registered capabilities. Add new entries here.
  static const List<Capability> allCapabilities = [
    calendar,
    contacts,
    location,
    sms,
    callLog,
    bluetooth,
    notificationListener,
    usageStats,
    accessibility,
    notifications,
    camera,
    voice,
    health,
    alarms,
    reminders,
    clipboard,
    appLauncher,
    phoneDial,
    emailCompose,
    mapsNav,
    sharing,
    audio,
    wifi,
    sensors,
    files,
    nfc,
    geofence,
    deviceInfo,
  ];

  /// Look up a capability by its ID.
  static Capability? byId(String id) {
    for (final cap in allCapabilities) {
      if (cap.id == id) return cap;
    }
    return null;
  }
}
