import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/supabase/app_db.dart';
import '../../../core/utils/responsive.dart';
import '../../../data/models/team_model.dart';
import '../../../data/models/trip_model.dart';
import '../../../data/models/trip_template_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/scheduled_task_result.dart';
import '../../../data/services/trip_templates.dart';
import '../../../features/workflow_scheduling/backward_planning_service.dart';
import '../../../features/workflow_scheduling/planning_deadline_helper.dart';
import '../providers/trip_provider.dart';
import '../widgets/trip_form_fields.dart';

class CreateTripScreen extends StatefulWidget {
  /// When provided, newly created trip is added to this provider.
  final TripProvider? tripProvider;

  const CreateTripScreen({super.key, this.tripProvider});

  @override
  State<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends State<CreateTripScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tripNameCtrl = TextEditingController();
  final _clientNameCtrl = TextEditingController();
  final _destinationsCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  int _guests = 2;
  String? _leadId;
  String? _templateId;
  bool _submitting = false;

  // Team members loaded for lead dropdown
  List<TeamMember> _teamMembers = [];

  // Saved templates loaded from Supabase
  List<TripTemplate> _savedTemplates = [];

  static const _templates = [
    _Template('none', 'Blank Trip'),
    _Template('luxury_city', 'Luxury City Break'),
    _Template('adventure', 'Adventure Expedition'),
    _Template('beach', 'Beach & Island'),
    _Template('cultural', 'Cultural Immersion'),
  ];

  @override
  void initState() {
    super.initState();
    _loadTeamMembers();
    _loadSavedTemplates();
  }

  Future<void> _loadTeamMembers() async {
    final teamId = AppRepositories.instance?.currentTeamId;
    if (teamId == null) return;
    try {
      final members =
          await AppRepositories.instance!.teams.fetchMembers(teamId);
      if (mounted) setState(() => _teamMembers = members);
    } catch (_) {}
  }

  Future<void> _loadSavedTemplates() async {
    final repos  = AppRepositories.instance;
    final teamId = repos?.currentTeamId;
    if (repos == null || teamId == null) return;
    try {
      final saved = await repos.templates.fetchAll(teamId);
      if (mounted) setState(() => _savedTemplates = saved);
    } catch (_) {}
  }

  @override
  void dispose() {
    _tripNameCtrl.dispose();
    _clientNameCtrl.dispose();
    _destinationsCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? _startDate : _endDate) ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: AppColors.accent),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(picked)) _endDate = null;
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select start and end dates.')),
      );
      return;
    }

    final repos   = AppRepositories.instance;
    final teamId  = repos?.currentTeamId;
    final tripProv = widget.tripProvider;

    if (repos == null || teamId == null || teamId.isEmpty || tripProv == null) {
      // No backend configured — just pop
      if (mounted) Navigator.of(context).pop();
      return;
    }

    setState(() => _submitting = true);

    // Resolve trip lead from selection or fall back to current user
    AppUser leadUser = repos.currentAppUser ??
        AppUser(
          id: 'unknown', name: 'Unknown', initials: '?',
          avatarColor: avatarColorFor(0), role: 'Staff',
        );
    if (_leadId != null) {
      final member = _teamMembers
          .where((m) => m.userId == _leadId)
          .firstOrNull;
      if (member?.profile != null) leadUser = member!.profile!;
    }

    // Parse destination cities from comma-separated input
    final destinations = _destinationsCtrl.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final newTrip = Trip(
      id:           '',
      teamId:       teamId,
      name:         _tripNameCtrl.text.trim(),
      clientName:   _clientNameCtrl.text.trim(),
      startDate:    _startDate,
      endDate:      _endDate,
      destinations: destinations,
      guestCount:   _guests,
      tripLead:     leadUser,
      status:       TripStatus.planning,
      notes:        _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );

    final created = await tripProv.addTrip(newTrip);

    // Auto-generate template tasks if a template was selected
    int seededTaskCount = 0;
    String? templateError;
    if (created != null && _templateId != null && _templateId != 'none') {
      try {
        // Check if it's a saved template (UUID) or a built-in key
        final saved = _savedTemplates
            .where((t) => t.id == _templateId)
            .firstOrNull;

        final List<Map<String, dynamic>> tasks;
        if (saved != null) {
          tasks = saved.tasks.map((t) => <String, dynamic>{
            'group':       t.groupName,
            'title':       t.title,
            'priority':    t.priority,
            'duration':    t.estimatedDurationDays,
            'assignee_id': t.defaultAssigneeId,
          }).toList();
        } else {
          tasks = templateTasks(_templateId);
        }

        if (tasks.isNotEmpty) {
          seededTaskCount = await _insertTemplateTasks(
            tripId:    created.id,
            teamId:    teamId,
            tasks:     tasks,
            startDate: created.startDate,
          );
        }
      } catch (e) {
        templateError = e.toString();
      }
    }

    setState(() => _submitting = false);

    if (!mounted) return;
    if (created != null) {
      final taskMsg = seededTaskCount > 0
          ? ' $seededTaskCount tasks added from template.'
          : templateError != null
              ? ' (Template tasks failed: $templateError)'
              : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Trip "${created.name}" created.$taskMsg'),
          backgroundColor: templateError != null
              ? Colors.orange
              : AppColors.statusDoneText,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      Navigator.of(context).pop(created);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not create trip. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Fetches board groups, runs backward planning if startDate is set,
  /// and inserts tasks with calculated dates. Retries twice for the DB trigger.
  /// Returns the number of tasks inserted.
  Future<int> _insertTemplateTasks({
    required String tripId,
    required String teamId,
    required List<Map<String, dynamic>> tasks,
    DateTime? startDate,
  }) async {
    final client = db;
    final userId = client.auth.currentUser?.id ?? '';

    // Fetch groups — retry up to 2 times if trigger hasn't fired yet
    var groupRows = await client
        .from('board_groups')
        .select('id, name')
        .eq('trip_id', tripId) as List;

    if (groupRows.isEmpty) {
      await Future.delayed(const Duration(milliseconds: 1200));
      groupRows = await client
          .from('board_groups')
          .select('id, name')
          .eq('trip_id', tripId) as List;
    }

    if (groupRows.isEmpty) {
      await Future.delayed(const Duration(milliseconds: 1500));
      groupRows = await client
          .from('board_groups')
          .select('id, name')
          .eq('trip_id', tripId) as List;
    }

    if (groupRows.isEmpty) {
      throw Exception('Board groups not found for trip. Check DB trigger.');
    }

    final groupIdByName = <String, String>{};
    for (final r in groupRows) {
      final row = r as Map<String, dynamic>;
      groupIdByName[row['name'] as String] = row['id'] as String;
    }

    // Run backward planning when a start date is available.
    Map<int, ScheduledTaskResult> scheduleByIndex = {};
    ScheduleAnalysis? analysis;

    if (startDate != null) {
      analysis = BackwardPlanningService.scheduleFromTemplateMaps(
        templateTasks:      tasks,
        tripStartDate:      startDate,
        planningBufferDays: PlanningDeadlineHelper.defaultBufferDays,
      );
      scheduleByIndex = {
        for (final r in analysis.tasks) r.sortOrder: r,
      };
      debugPrint(
        '[Scheduling] startDate=$startDate  '
        'deadline=${analysis.planningDeadline}  '
        'results=${analysis.tasks.length}  '
        'possible=${analysis.isPossible}  '
        'compressed=${analysis.isCompressed}',
      );
    } else {
      debugPrint('[Scheduling] startDate is null — skipping engine');
    }

    final rows = <Map<String, dynamic>>[];
    int scheduledCount = 0;

    for (var i = 0; i < tasks.length; i++) {
      final t       = tasks[i];
      final groupId = groupIdByName[t['group'] as String? ?? ''];
      if (groupId == null) {
        debugPrint('[Scheduling] task[$i] "${t['title']}" — group "${t['group']}" not found in board groups');
        continue;
      }

      final scheduled = scheduleByIndex[i];
      if (scheduled != null) scheduledCount++;

      rows.add({
        'trip_id':           tripId,
        'team_id':           teamId,
        'created_by':        userId,
        'board_group_id':    groupId,
        'title':             t['title'],
        'status':            'not_started',
        'priority':          t['priority'] ?? 'medium',
        'cost_status':       'pending',
        'approval_status':   'draft',
        'is_client_visible': false,
        'sort_order':        i,
        if (scheduled != null) ...{
          'travel_date':             scheduled.scheduledStartDate
              .toIso8601String().substring(0, 10),
          'due_date':                scheduled.dueDate
              .toIso8601String().substring(0, 10),
          'estimated_duration_days': scheduled.estimatedDurationDays,
        },
      });
    }

    debugPrint('[Scheduling] inserting ${rows.length} tasks, $scheduledCount with scheduled dates');

    if (rows.isNotEmpty) {
      await client.from('tasks').insert(rows);
    }

    // Show post-navigation snackbar with schedule result
    if (analysis != null && mounted) {
      final msg = analysis.hasWarnings
          ? analysis.warnings.first
          : '$scheduledCount/${rows.length} tasks scheduled '
            '(${_fmtDate(analysis.planningDeadline)} deadline)';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              backgroundColor: analysis!.isCompressed
                  ? Colors.orange.shade700
                  : Colors.blue.shade700,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 6),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          );
        }
      });
    }

    return rows.length;
  }

  static String _fmtDate(DateTime d) {
    const m = ['','Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${m[d.month]} ${d.day}';
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final maxWidth = isMobile ? double.infinity : 640.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 20),
          color: AppColors.textSecondary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Create Trip', style: AppTextStyles.heading1),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? AppSpacing.base : AppSpacing.xl,
              vertical: AppSpacing.pagePaddingV,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Template selector
                  TripSectionLabel(label: 'Template'),
                  const SizedBox(height: AppSpacing.sm),
                  _TemplateSelector(
                    selected: _templateId ?? 'none',
                    onSelected: (id) => setState(() => _templateId = id),
                    savedTemplates: _savedTemplates,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const Divider(color: AppColors.divider),
                  const SizedBox(height: AppSpacing.xl),

                  // Trip name
                  TripSectionLabel(label: 'Trip Name *'),
                  const SizedBox(height: AppSpacing.sm),
                  TripFormTextField(
                    controller: _tripNameCtrl,
                    hint: 'e.g. Amalfi & Sicily Summer Escape',
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Trip name is required' : null,
                  ),
                  const SizedBox(height: AppSpacing.base),

                  // Client name
                  TripSectionLabel(label: 'Client Name *'),
                  const SizedBox(height: AppSpacing.sm),
                  TripFormTextField(
                    controller: _clientNameCtrl,
                    hint: 'e.g. The Hartwell Family',
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Client name is required' : null,
                  ),
                  const SizedBox(height: AppSpacing.base),

                  // Dates row
                  isMobile
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TripSectionLabel(label: 'Start Date *'),
                            const SizedBox(height: AppSpacing.sm),
                            TripDateButton(date: _startDate, hint: 'Select start date', onTap: () => _pickDate(isStart: true)),
                            const SizedBox(height: AppSpacing.base),
                            TripSectionLabel(label: 'End Date *'),
                            const SizedBox(height: AppSpacing.sm),
                            TripDateButton(date: _endDate, hint: 'Select end date', onTap: () => _pickDate(isStart: false)),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TripSectionLabel(label: 'Start Date *'),
                                  const SizedBox(height: AppSpacing.sm),
                                  TripDateButton(date: _startDate, hint: 'Select start date', onTap: () => _pickDate(isStart: true)),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.base),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TripSectionLabel(label: 'End Date *'),
                                  const SizedBox(height: AppSpacing.sm),
                                  TripDateButton(date: _endDate, hint: 'Select end date', onTap: () => _pickDate(isStart: false)),
                                ],
                              ),
                            ),
                          ],
                        ),
                  const SizedBox(height: AppSpacing.base),

                  // Destinations
                  TripSectionLabel(label: 'Destinations'),
                  const SizedBox(height: AppSpacing.sm),
                  TripFormTextField(
                    controller: _destinationsCtrl,
                    hint: 'e.g. Naples, Positano, Palermo',
                  ),
                  const SizedBox(height: AppSpacing.base),

                  // Guests + Lead row
                  isMobile
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TripSectionLabel(label: 'Number of Guests'),
                            const SizedBox(height: AppSpacing.sm),
                            TripGuestCounter(value: _guests, onChanged: (v) => setState(() => _guests = v)),
                            const SizedBox(height: AppSpacing.base),
                            TripSectionLabel(label: 'Trip Lead'),
                            const SizedBox(height: AppSpacing.sm),
                            TripLeadDropdown(
                              selected: _leadId,
                              members: _teamMembers,
                              onChanged: (id) => setState(() => _leadId = id),
                            ),
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TripSectionLabel(label: 'Number of Guests'),
                                  const SizedBox(height: AppSpacing.sm),
                                  TripGuestCounter(value: _guests, onChanged: (v) => setState(() => _guests = v)),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.base),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TripSectionLabel(label: 'Trip Lead'),
                                  const SizedBox(height: AppSpacing.sm),
                                  TripLeadDropdown(
                                    selected: _leadId,
                                    members: _teamMembers,
                                    onChanged: (id) => setState(() => _leadId = id),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                  const SizedBox(height: AppSpacing.base),

                  // Notes
                  TripSectionLabel(label: 'Notes'),
                  const SizedBox(height: AppSpacing.sm),
                  TripFormTextField(
                    controller: _notesCtrl,
                    hint: 'Client preferences, special requirements…',
                    maxLines: 4,
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                            side: const BorderSide(color: AppColors.border),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
                            ),
                          ),
                          child: Text('Cancel', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _submitting ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
                            ),
                          ),
                          child: _submitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  'Create Trip',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.massive),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Template selector (create-only) ──────────────────────────────────────────

class _TemplateSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;
  final List<TripTemplate> savedTemplates;

  const _TemplateSelector({
    required this.selected,
    required this.onSelected,
    required this.savedTemplates,
  });

  Widget _chip(String id, String name) {
    final isSelected = selected == id;
    return GestureDetector(
      onTap: () => onSelected(id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentLight : AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          name,
          style: AppTextStyles.labelMedium.copyWith(
            color: isSelected ? AppColors.accentDark : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        // Built-in templates
        ..._CreateTripScreenState._templates.map((t) => _chip(t.id, t.name)),
        // Saved (custom) templates — shown with a star prefix
        ...savedTemplates.map((t) => _chip(t.id, '★ ${t.name}')),
      ],
    );
  }
}

class _Template {
  final String id;
  final String name;
  const _Template(this.id, this.name);
}
