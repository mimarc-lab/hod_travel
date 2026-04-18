import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/supabase/app_db.dart';
import '../../../core/utils/responsive.dart';
import '../../../data/models/team_model.dart';
import '../../../data/models/trip_model.dart';
import '../../../data/models/user_model.dart';
import '../providers/trip_provider.dart';
import '../widgets/trip_destinations_editor.dart';
import '../widgets/trip_form_fields.dart';

// ─────────────────────────────────────────────────────────────────────────────
// EditTripScreen
//
// Prefills all fields from the existing trip and saves changes via the
// repository. If a TripProvider is supplied (from TripsListScreen), the
// in-memory list is updated automatically. When launched from TripBoardScreen
// (no provider), the updated Trip is returned as the pop result so the board
// can update its local header state.
// ─────────────────────────────────────────────────────────────────────────────

class EditTripScreen extends StatefulWidget {
  final Trip trip;

  /// When provided the provider's in-memory list is kept in sync.
  final TripProvider? tripProvider;

  const EditTripScreen({
    super.key,
    required this.trip,
    this.tripProvider,
  });

  @override
  State<EditTripScreen> createState() => _EditTripScreenState();
}

class _EditTripScreenState extends State<EditTripScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _tripNameCtrl;
  late final TextEditingController _clientNameCtrl;
  late final TextEditingController _notesCtrl;

  late DateTime? _startDate;
  late DateTime? _endDate;
  late int _guests;
  String? _leadId;
  late List<String> _destinations;

  bool _submitting = false;
  List<TeamMember> _teamMembers = [];

  @override
  void initState() {
    super.initState();
    final t = widget.trip;
    _tripNameCtrl   = TextEditingController(text: t.name);
    _clientNameCtrl = TextEditingController(text: t.clientName);
    _notesCtrl      = TextEditingController(text: t.notes ?? '');
    _startDate      = t.startDate;
    _endDate        = t.endDate;
    _guests         = t.guestCount;
    _leadId         = t.tripLead.id == 'unknown' ? null : t.tripLead.id;
    _destinations   = List.from(t.destinations);
    _loadTeamMembers();
  }

  @override
  void dispose() {
    _tripNameCtrl.dispose();
    _clientNameCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
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

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? _startDate : _endDate) ??
          DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx)
              .colorScheme
              .copyWith(primary: AppColors.accent),
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

  // ── Change detection ───────────────────────────────────────────────────────

  bool get _datesChanged =>
      _startDate != widget.trip.startDate ||
      _endDate != widget.trip.endDate;

  bool get _destinationsChanged {
    final orig = widget.trip.destinations;
    if (orig.length != _destinations.length) return true;
    for (int i = 0; i < orig.length; i++) {
      if (orig[i] != _destinations[i]) return true;
    }
    return false;
  }

  // ── Submit ─────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select start and end dates.')),
      );
      return;
    }
    if (_startDate!.isAfter(_endDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Start date must be before end date.')),
      );
      return;
    }

    setState(() => _submitting = true);

    // Resolve lead — keep original if not changed
    AppUser leadUser = widget.trip.tripLead;
    if (_leadId != null) {
      final member =
          _teamMembers.where((m) => m.userId == _leadId).firstOrNull;
      if (member?.profile != null) leadUser = member!.profile!;
    }

    final notesText = _notesCtrl.text.trim();
    final updatedTrip = widget.trip.copyWith(
      name:         _tripNameCtrl.text.trim(),
      clientName:   _clientNameCtrl.text.trim(),
      startDate:    _startDate,
      endDate:      _endDate,
      destinations: _destinations,
      guestCount:   _guests,
      tripLead:     leadUser,
      notes:        notesText.isEmpty ? null : notesText,
      clearNotes:   notesText.isEmpty,
    );

    Trip? saved;
    try {
      if (widget.tripProvider != null) {
        // Provider call: updates the repo + keeps in-memory list fresh.
        await widget.tripProvider!.updateTrip(updatedTrip);
        saved = widget.tripProvider!.findById(updatedTrip.id) ?? updatedTrip;
      } else {
        // No provider (e.g. launched from TripBoardScreen) — hit repo directly.
        saved = await AppRepositories.instance?.trips.update(updatedTrip);
      }
    } catch (_) {
      saved = null;
    }

    setState(() => _submitting = false);
    if (!mounted) return;

    if (saved != null) {
      final extras = <String>[];
      if (_datesChanged) {
        extras.add('Task and itinerary dates may need review.');
      }
      if (_destinationsChanged) {
        extras.add('Itinerary context may need review.');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            extras.isEmpty
                ? 'Trip updated.'
                : 'Trip updated. ${extras.join(' ')}',
          ),
          backgroundColor: AppColors.statusDoneText,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: extras.isEmpty ? 2 : 5),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      // ignore: use_build_context_synchronously
      Navigator.of(context).pop(saved);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save changes. Please try again.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

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
        title: Text('Edit Trip', style: AppTextStyles.heading1),
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
                  // ── Trip name ─────────────────────────────────────────────
                  const TripSectionLabel(label: 'Trip Name *'),
                  const SizedBox(height: AppSpacing.sm),
                  TripFormTextField(
                    controller: _tripNameCtrl,
                    hint: 'e.g. Amalfi & Sicily Summer Escape',
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Trip name is required'
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.base),

                  // ── Client name ───────────────────────────────────────────
                  const TripSectionLabel(label: 'Client Name *'),
                  const SizedBox(height: AppSpacing.sm),
                  TripFormTextField(
                    controller: _clientNameCtrl,
                    hint: 'e.g. The Hartwell Family',
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Client name is required'
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.base),

                  // ── Dates ─────────────────────────────────────────────────
                  isMobile
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const TripSectionLabel(label: 'Start Date *'),
                            const SizedBox(height: AppSpacing.sm),
                            TripDateButton(
                              date: _startDate,
                              hint: 'Select start date',
                              onTap: () => _pickDate(isStart: true),
                            ),
                            const SizedBox(height: AppSpacing.base),
                            const TripSectionLabel(label: 'End Date *'),
                            const SizedBox(height: AppSpacing.sm),
                            TripDateButton(
                              date: _endDate,
                              hint: 'Select end date',
                              onTap: () => _pickDate(isStart: false),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const TripSectionLabel(
                                      label: 'Start Date *'),
                                  const SizedBox(height: AppSpacing.sm),
                                  TripDateButton(
                                    date: _startDate,
                                    hint: 'Select start date',
                                    onTap: () => _pickDate(isStart: true),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.base),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const TripSectionLabel(label: 'End Date *'),
                                  const SizedBox(height: AppSpacing.sm),
                                  TripDateButton(
                                    date: _endDate,
                                    hint: 'Select end date',
                                    onTap: () => _pickDate(isStart: false),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                  const SizedBox(height: AppSpacing.base),

                  // ── Destinations ──────────────────────────────────────────
                  const TripSectionLabel(label: 'Destinations'),
                  const SizedBox(height: AppSpacing.sm),
                  TripDestinationsEditor(
                    initialDestinations: widget.trip.destinations,
                    onChanged: (updated) =>
                        _destinations = List.from(updated),
                  ),
                  const SizedBox(height: AppSpacing.base),

                  // ── Guests + Lead ─────────────────────────────────────────
                  isMobile
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const TripSectionLabel(
                                label: 'Number of Guests'),
                            const SizedBox(height: AppSpacing.sm),
                            TripGuestCounter(
                              value: _guests,
                              onChanged: (v) => setState(() => _guests = v),
                            ),
                            const SizedBox(height: AppSpacing.base),
                            const TripSectionLabel(label: 'Trip Lead'),
                            const SizedBox(height: AppSpacing.sm),
                            TripLeadDropdown(
                              selected: _leadId,
                              members: _teamMembers,
                              onChanged: (id) =>
                                  setState(() => _leadId = id),
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
                                  const TripSectionLabel(
                                      label: 'Number of Guests'),
                                  const SizedBox(height: AppSpacing.sm),
                                  TripGuestCounter(
                                    value: _guests,
                                    onChanged: (v) =>
                                        setState(() => _guests = v),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.base),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const TripSectionLabel(
                                      label: 'Trip Lead'),
                                  const SizedBox(height: AppSpacing.sm),
                                  TripLeadDropdown(
                                    selected: _leadId,
                                    members: _teamMembers,
                                    onChanged: (id) =>
                                        setState(() => _leadId = id),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                  const SizedBox(height: AppSpacing.base),

                  // ── Notes ─────────────────────────────────────────────────
                  const TripSectionLabel(label: 'Notes'),
                  const SizedBox(height: AppSpacing.sm),
                  TripFormTextField(
                    controller: _notesCtrl,
                    hint: 'Client preferences, special requirements…',
                    maxLines: 4,
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  // ── Actions ───────────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                            side: const BorderSide(color: AppColors.border),
                            padding:
                                const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  AppSpacing.buttonRadius),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: AppTextStyles.bodyMedium
                                .copyWith(color: AppColors.textSecondary),
                          ),
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
                            padding:
                                const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  AppSpacing.buttonRadius),
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
                                  'Save Changes',
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
