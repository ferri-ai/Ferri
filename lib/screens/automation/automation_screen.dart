import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/automation_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/colors.dart';

class AutomationScreen extends ConsumerStatefulWidget {
  const AutomationScreen({super.key});

  @override
  ConsumerState<AutomationScreen> createState() => _AutomationScreenState();
}

class _AutomationScreenState extends ConsumerState<AutomationScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(automationProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auto = ref.watch(automationProvider);
    final showFab = ref.watch(settingsProvider).showVisualBuilder;

    return Scaffold(
      backgroundColor: FerriColors.bg,
      floatingActionButton: showFab
          ? Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: FloatingActionButton.extended(
                onPressed: () => _showCreateSheet(context),
                backgroundColor: FerriColors.primary,
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text(
                  'New Automation',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
          : null,
      body: SafeArea(
        child: auto.loading
            ? const Center(
                child: CircularProgressIndicator(color: FerriColors.primary),
              )
            : RefreshIndicator(
                color: FerriColors.primary,
                backgroundColor: FerriColors.bgCard,
                onRefresh: () async {
                  ref.read(automationProvider.notifier).refresh();
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.only(bottom: 100),
                  children: [
                    // Header
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
                      child: Text(
                        'Automations',
                        style: TextStyle(
                          color: FerriColors.text,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        'Tasks that Ferri runs on your behalf.',
                        style: TextStyle(
                          color: FerriColors.textSoft,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Heartbeat card
                    _HeartbeatCard(
                      heartbeat: auto.heartbeat,
                      prompt: auto.heartbeatPrompt,
                    ),

                    const SizedBox(height: 24),

                    // Scheduled section
                    _buildSectionHeader('SCHEDULED'),
                    const SizedBox(height: 8),
                    if (auto.scheduledJobs.isEmpty)
                      _buildEmptyState('No scheduled automations')
                    else
                      ...auto.scheduledJobs.map((job) => _JobCard(
                            job: job,
                            accentColor: FerriColors.primary,
                          )),

                    const SizedBox(height: 24),

                    // Geofences section
                    _buildSectionHeader('GEOFENCES'),
                    const SizedBox(height: 8),
                    if (auto.geofenceJobs.isEmpty)
                      _buildEmptyState('No geofence automations')
                    else
                      ...auto.geofenceJobs.map((job) => _JobCard(
                            job: job,
                            accentColor: FerriColors.success,
                          )),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        title,
        style: const TextStyle(
          color: FerriColors.textFaint,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Text(
        message,
        style: const TextStyle(
          color: FerriColors.textFaint,
          fontSize: 14,
        ),
      ),
    );
  }

  // ─── Create automation bottom sheet ──────────────────────────

  void _showCreateSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: FerriColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _CreateAutomationSheet(parentRef: ref),
    );
  }
}

// ─── Heartbeat Card ────────────────────────────────────────────

class _HeartbeatCard extends ConsumerStatefulWidget {
  final HeartbeatStatus heartbeat;
  final String prompt;

  const _HeartbeatCard({required this.heartbeat, required this.prompt});

  @override
  ConsumerState<_HeartbeatCard> createState() => _HeartbeatCardState();
}

class _HeartbeatCardState extends ConsumerState<_HeartbeatCard> {
  bool _expanded = false;
  late TextEditingController _promptController;
  int _selectedInterval = 30;

  @override
  void initState() {
    super.initState();
    _promptController = TextEditingController(text: widget.prompt);
    _selectedInterval = widget.heartbeat.intervalMinutes;
  }

  @override
  void didUpdateWidget(covariant _HeartbeatCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.prompt != widget.prompt &&
        _promptController.text != widget.prompt) {
      _promptController.text = widget.prompt;
    }
    if (oldWidget.heartbeat.intervalMinutes !=
        widget.heartbeat.intervalMinutes) {
      _selectedInterval = widget.heartbeat.intervalMinutes;
    }
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Color get _statusColor {
    if (!widget.heartbeat.enabled) return FerriColors.textFaint;
    return FerriColors.success;
  }

  String get _statusText {
    if (!widget.heartbeat.enabled) return 'Disabled \u2014 tap to set up';
    final m = widget.heartbeat.intervalMinutes;
    final intervalStr = m >= 60 ? '${m ~/ 60}h' : '${m}m';
    return 'Enabled \u2014 every $intervalStr';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: FerriColors.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.heartbeat.enabled
                ? FerriColors.success.withValues(alpha: 0.3)
                : FerriColors.border,
          ),
        ),
        child: Column(
          children: [
            // Header
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: FerriColors.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.wb_sunny,
                        color: FerriColors.warning,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Check-in',
                            style: TextStyle(
                              color: FerriColors.text,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: _statusColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _statusText,
                                  style: TextStyle(
                                    color: _statusColor,
                                    fontSize: 12,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: FerriColors.textSoft,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),

            // Expanded section
            if (_expanded)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(color: FerriColors.border, height: 1),
                    const SizedBox(height: 12),

                    // Prompt editor
                    const Text(
                      'Prompt',
                      style: TextStyle(
                        color: FerriColors.textSoft,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _promptController,
                      maxLines: 6,
                      minLines: 3,
                      style: const TextStyle(
                        color: FerriColors.text,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        hintText: 'What should Ferri brief you on?',
                        hintStyle:
                            const TextStyle(color: FerriColors.textFaint),
                        filled: true,
                        fillColor: FerriColors.bgInput,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: FerriColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: FerriColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: FerriColors.borderFocus),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Save prompt button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          ref
                              .read(automationProvider.notifier)
                              .setHeartbeatPrompt(
                                  _promptController.text.trim());
                          FocusScope.of(context).unfocus();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Prompt saved'),
                              backgroundColor: FerriColors.success,
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              FerriColors.primary.withValues(alpha: 0.2),
                          foregroundColor: FerriColors.primary,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Save Prompt',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Interval selector
                    const Text(
                      'Check-in interval',
                      style: TextStyle(
                        color: FerriColors.textSoft,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildIntervalChip(15, '15m'),
                        const SizedBox(width: 8),
                        _buildIntervalChip(30, '30m'),
                        const SizedBox(width: 8),
                        _buildIntervalChip(60, '1h'),
                        const SizedBox(width: 8),
                        _buildIntervalChip(240, '4h'),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Enable/Disable button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          final notifier = ref.read(automationProvider.notifier);
                          if (!widget.heartbeat.enabled) {
                            // Send interval before enabling
                            notifier.setHeartbeatInterval(_selectedInterval);
                            notifier.setHeartbeatEnabled(true);

                            // Nudge if background service is off
                            final bgEnabled = ref
                                .read(settingsProvider)
                                .backgroundServiceEnabled;
                            if (!bgEnabled && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text(
                                    'Enable Background Service in Settings so check-ins run even when the app is closed.',
                                  ),
                                  backgroundColor: FerriColors.warning,
                                  duration: const Duration(seconds: 5),
                                  action: SnackBarAction(
                                    label: 'Settings',
                                    textColor: FerriColors.text,
                                    onPressed: () {
                                      // Navigate to Settings tab (index 3)
                                      final scaffold = Scaffold.maybeOf(context);
                                      if (scaffold != null) {
                                        Navigator.of(context).popUntil(
                                            (route) => route.isFirst);
                                      }
                                    },
                                  ),
                                ),
                              );
                            }
                          } else {
                            notifier.setHeartbeatEnabled(false);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.heartbeat.enabled
                              ? FerriColors.danger.withValues(alpha: 0.2)
                              : FerriColors.success.withValues(alpha: 0.2),
                          foregroundColor: widget.heartbeat.enabled
                              ? FerriColors.danger
                              : FerriColors.success,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          widget.heartbeat.enabled ? 'Disable' : 'Enable',
                          style:
                              const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntervalChip(int minutes, String label) {
    final selected = _selectedInterval == minutes;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedInterval = minutes);
          ref.read(automationProvider.notifier).setHeartbeatInterval(minutes);
        },
        child: Container(
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? FerriColors.primary.withValues(alpha: 0.2)
                : FerriColors.bgInput,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? FerriColors.primary.withValues(alpha: 0.5)
                  : FerriColors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? FerriColors.primary : FerriColors.textSoft,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Job Card ──────────────────────────────────────────────────

class _JobCard extends ConsumerWidget {
  final CronJobModel job;
  final Color accentColor;

  const _JobCard({required this.job, required this.accentColor});

  Color _statusDotColor() {
    if (!job.enabled) return FerriColors.textFaint;
    if (job.state.lastStatus == null) return FerriColors.warning;
    if (job.state.lastStatus == 'ok' || job.state.lastStatus == 'success') {
      return FerriColors.success;
    }
    return FerriColors.warning;
  }

  String _relativeTime(int? ms) {
    if (ms == null) return 'Never';
    final now = DateTime.now().millisecondsSinceEpoch;
    final diff = now - ms;
    if (diff < 60000) return 'Just now';
    if (diff < 3600000) return '${diff ~/ 60000}m ago';
    if (diff < 86400000) return '${diff ~/ 3600000}h ago';
    return '${diff ~/ 86400000}d ago';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: FerriColors.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: job.enabled
                ? accentColor.withValues(alpha: 0.3)
                : FerriColors.border,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Status dot
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _statusDotColor(),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),

              // Name + schedule + last run
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.name,
                      style: const TextStyle(
                        color: FerriColors.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      job.schedule.displayText,
                      style: TextStyle(
                        color: accentColor.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                    if (job.state.lastRunAtMs != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Last run: ${_relativeTime(job.state.lastRunAtMs)}',
                        style: const TextStyle(
                          color: FerriColors.textFaint,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Toggle switch
              Switch.adaptive(
                value: job.enabled,
                activeTrackColor: accentColor,
                onChanged: (v) {
                  ref
                      .read(automationProvider.notifier)
                      .toggleJob(job.id, v);
                },
              ),

              // Delete button
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: FerriColors.textFaint,
                ),
                onPressed: () => _confirmDelete(context, ref),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FerriColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Delete automation?',
          style: TextStyle(color: FerriColors.text, fontSize: 16),
        ),
        content: Text(
          'This will permanently remove "${job.name}".',
          style: const TextStyle(color: FerriColors.textSoft, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: FerriColors.textSoft),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(automationProvider.notifier).deleteJob(job.id);
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: FerriColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Create Automation Sheet ───────────────────────────────────

enum _TriggerType { schedule, location }

enum _ScheduleKind { every, at, cron }

class _CreateAutomationSheet extends StatefulWidget {
  final WidgetRef parentRef;

  const _CreateAutomationSheet({required this.parentRef});

  @override
  State<_CreateAutomationSheet> createState() => _CreateAutomationSheetState();
}

class _CreateAutomationSheetState extends State<_CreateAutomationSheet> {
  final _nameController = TextEditingController();
  final _messageController = TextEditingController();
  final _valueController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _radiusController = TextEditingController(text: '200');

  _TriggerType _trigger = _TriggerType.schedule;
  _ScheduleKind _scheduleKind = _ScheduleKind.every;
  bool _geofenceEnter = true;

  @override
  void dispose() {
    _nameController.dispose();
    _messageController.dispose();
    _valueController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  void _create() {
    final name = _nameController.text.trim();
    final message = _messageController.text.trim();
    if (name.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Name and message are required'),
          backgroundColor: FerriColors.danger,
        ),
      );
      return;
    }

    CronScheduleModel schedule;
    if (_trigger == _TriggerType.schedule) {
      final val = _valueController.text.trim();
      switch (_scheduleKind) {
        case _ScheduleKind.every:
          final minutes = int.tryParse(val);
          if (minutes == null || minutes <= 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Enter a valid number of minutes'),
                backgroundColor: FerriColors.danger,
              ),
            );
            return;
          }
          schedule = CronScheduleModel(
            kind: 'every',
            everyMs: minutes * 60000,
          );
          break;
        case _ScheduleKind.at:
          final hour = int.tryParse(val);
          if (hour == null || hour < 0 || hour > 23) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Enter a valid hour (0-23)'),
                backgroundColor: FerriColors.danger,
              ),
            );
            return;
          }
          schedule = CronScheduleModel(
            kind: 'cron',
            expr: '0 $hour * * *',
          );
          break;
        case _ScheduleKind.cron:
          if (val.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Enter a cron expression'),
                backgroundColor: FerriColors.danger,
              ),
            );
            return;
          }
          schedule = CronScheduleModel(
            kind: 'cron',
            expr: val,
          );
          break;
      }
    } else {
      final lat = double.tryParse(_latController.text.trim());
      final lng = double.tryParse(_lngController.text.trim());
      final radius = int.tryParse(_radiusController.text.trim());
      if (lat == null || lng == null || radius == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enter valid lat, lng, and radius'),
            backgroundColor: FerriColors.danger,
          ),
        );
        return;
      }
      schedule = CronScheduleModel(
        kind: 'geofence',
        lat: lat,
        lng: lng,
        radiusMeters: radius,
        trigger: _geofenceEnter ? 'enter' : 'exit',
      );
    }

    widget.parentRef.read(automationProvider.notifier).createJob(
          name: name,
          schedule: schedule,
          message: message,
        );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: FerriColors.textFaint,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'New Automation',
              style: TextStyle(
                color: FerriColors.text,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),

            // Name field
            _buildLabel('Name'),
            const SizedBox(height: 6),
            _buildTextField(_nameController, 'e.g. Daily standup'),
            const SizedBox(height: 16),

            // Trigger type toggle
            _buildLabel('Trigger'),
            const SizedBox(height: 6),
            Row(
              children: [
                _buildToggle(
                  'Schedule',
                  _trigger == _TriggerType.schedule,
                  () => setState(() => _trigger = _TriggerType.schedule),
                ),
                const SizedBox(width: 8),
                _buildToggle(
                  'Location',
                  _trigger == _TriggerType.location,
                  () => setState(() => _trigger = _TriggerType.location),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Schedule options
            if (_trigger == _TriggerType.schedule) ...[
              Row(
                children: [
                  _buildToggle(
                    'Every X min',
                    _scheduleKind == _ScheduleKind.every,
                    () =>
                        setState(() => _scheduleKind = _ScheduleKind.every),
                  ),
                  const SizedBox(width: 8),
                  _buildToggle(
                    'Daily at hour',
                    _scheduleKind == _ScheduleKind.at,
                    () => setState(() => _scheduleKind = _ScheduleKind.at),
                  ),
                  const SizedBox(width: 8),
                  _buildToggle(
                    'Cron',
                    _scheduleKind == _ScheduleKind.cron,
                    () =>
                        setState(() => _scheduleKind = _ScheduleKind.cron),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildTextField(
                _valueController,
                _scheduleKind == _ScheduleKind.every
                    ? 'Minutes (e.g. 30)'
                    : _scheduleKind == _ScheduleKind.at
                        ? 'Hour (0-23)'
                        : 'Cron expression (e.g. */15 * * * *)',
                keyboardType: _scheduleKind == _ScheduleKind.cron
                    ? TextInputType.text
                    : TextInputType.number,
              ),
            ],

            // Location options
            if (_trigger == _TriggerType.location) ...[
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Latitude'),
                        const SizedBox(height: 4),
                        _buildTextField(_latController, 'e.g. 37.7749',
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true, signed: true)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Longitude'),
                        const SizedBox(height: 4),
                        _buildTextField(_lngController, 'e.g. -122.4194',
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true, signed: true)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Radius (m)'),
                        const SizedBox(height: 4),
                        _buildTextField(_radiusController, '200',
                            keyboardType: TextInputType.number),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Trigger on'),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _buildToggle(
                              'Enter',
                              _geofenceEnter,
                              () => setState(() => _geofenceEnter = true),
                            ),
                            const SizedBox(width: 8),
                            _buildToggle(
                              'Exit',
                              !_geofenceEnter,
                              () => setState(() => _geofenceEnter = false),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),

            // Message field
            _buildLabel('Message'),
            const SizedBox(height: 6),
            _buildTextField(
              _messageController,
              'What should Ferri do?',
              maxLines: 3,
            ),
            const SizedBox(height: 20),

            // Create button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _create,
                style: ElevatedButton.styleFrom(
                  backgroundColor: FerriColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Create',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: FerriColors.textSoft,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint, {
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(color: FerriColors.text, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: FerriColors.textFaint),
        filled: true,
        fillColor: FerriColors.bgInput,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: FerriColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: FerriColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: FerriColors.borderFocus),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }

  Widget _buildToggle(String label, bool selected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? FerriColors.primary.withValues(alpha: 0.2)
                : FerriColors.bgInput,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? FerriColors.primary.withValues(alpha: 0.5)
                  : FerriColors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? FerriColors.primary : FerriColors.textSoft,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}
