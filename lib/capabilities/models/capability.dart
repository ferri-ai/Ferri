import 'package:flutter/material.dart';

/// Privacy-sensitivity tier for grouping capabilities.
enum CapabilityTier {
  core,     // Calendar, Contacts — standard OS permissions
  extended, // Home automation, voice — may need additional setup
}

/// Runtime status of a capability.
enum CapabilityStatus {
  disabled,           // User has not enabled
  permissionRequired, // Enabled but OS permission not yet granted
  enabled,            // Fully active, tools registered with Go engine
}

/// Describes a single tool that a capability provides to the LLM.
class CapabilityTool {
  final String name;
  final String description;
  final Map<String, dynamic> schema;
  final bool destructive; // If true, may require user approval before execution

  const CapabilityTool({
    required this.name,
    required this.description,
    required this.schema,
    this.destructive = false,
  });
}

/// Static definition of a capability (e.g. Calendar, Contacts).
class Capability {
  final String id;
  final String displayName;
  final String description;
  final IconData icon;
  final Color color;
  final CapabilityTier tier;
  final List<String> permissions; // Android permission names
  final List<CapabilityTool> tools;
  final bool privileged;         // Requires manual system settings grant
  final String? settingsRoute;   // Android settings Intent action

  const Capability({
    required this.id,
    required this.displayName,
    required this.description,
    required this.icon,
    required this.color,
    required this.tier,
    required this.permissions,
    required this.tools,
    this.privileged = false,
    this.settingsRoute,
  });
}
