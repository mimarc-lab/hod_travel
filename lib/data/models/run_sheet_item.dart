import 'package:flutter/material.dart';
import 'itinerary_models.dart';
import 'run_sheet_instruction_template.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RunSheetRow — DB row DTO (lives here so provider/mapper import only the model)
// ─────────────────────────────────────────────────────────────────────────────

class RunSheetRow {
  final String  id;
  final String  tripId;
  final String  dayId;
  final String? itineraryItemId;
  final RunSheetStatus status;
  final String? primaryContactName;
  final String? primaryContactPhone;
  final String? backupContactName;
  final String? backupContactPhone;
  final String? responsibleName;
  final String? responsibleUserId;
  final String? opsNotes;
  final String? logisticsNotes;
  final String? transportNotes;  // driver-specific notes (visible in driver view)
  final String? guideNotes;      // guide-specific notes (visible in guide view)
  final int     sortOrder;

  // Operational instructions
  final String?              operationalInstructions;
  final String?              contingencyInstructions;
  final String?              escalationInstructions;
  final InstructionsSource?  instructionsSource;
  final String?              instructionsApprovedBy;
  final DateTime?            instructionsApprovedAt;

  const RunSheetRow({
    required this.id,
    required this.tripId,
    required this.dayId,
    this.itineraryItemId,
    this.status = RunSheetStatus.upcoming,
    this.primaryContactName,
    this.primaryContactPhone,
    this.backupContactName,
    this.backupContactPhone,
    this.responsibleName,
    this.responsibleUserId,
    this.opsNotes,
    this.logisticsNotes,
    this.transportNotes,
    this.guideNotes,
    this.sortOrder = 0,
    this.operationalInstructions,
    this.contingencyInstructions,
    this.escalationInstructions,
    this.instructionsSource,
    this.instructionsApprovedBy,
    this.instructionsApprovedAt,
  });

  factory RunSheetRow.fromJson(Map<String, dynamic> r) => RunSheetRow(
        id:                       r['id']                    as String,
        tripId:                   r['trip_id']               as String,
        dayId:                    r['trip_day_id']           as String,
        itineraryItemId:          r['itinerary_item_id']     as String?,
        status:                   RunSheetStatusDisplay.fromDb(r['status'] as String? ?? 'upcoming'),
        primaryContactName:       r['primary_contact_name']  as String?,
        primaryContactPhone:      r['primary_contact_phone'] as String?,
        backupContactName:        r['backup_contact_name']   as String?,
        backupContactPhone:       r['backup_contact_phone']  as String?,
        responsibleName:          r['responsible_name']      as String?,
        responsibleUserId:        r['responsible_user_id']   as String?,
        opsNotes:                 r['ops_notes']             as String?,
        logisticsNotes:           r['logistics_notes']       as String?,
        transportNotes:           r['transport_notes']       as String?,
        guideNotes:               r['guide_notes']           as String?,
        sortOrder:                r['sort_order']            as int? ?? 0,
        operationalInstructions:  r['operational_instructions'] as String?,
        contingencyInstructions:  r['contingency_instructions'] as String?,
        escalationInstructions:   r['escalation_instructions']  as String?,
        instructionsSource:       InstructionsSource.fromDb(r['instructions_source'] as String?),
        instructionsApprovedBy:   r['instructions_approved_by'] as String?,
        instructionsApprovedAt:   r['instructions_approved_at'] != null
            ? DateTime.parse(r['instructions_approved_at'] as String)
            : null,
      );

  Map<String, dynamic> toJson({String? teamId}) => {
        'id':                       id,
        'trip_id':                  tripId,
        'trip_day_id':              dayId,
        'team_id':                  teamId,
        'itinerary_item_id':        itineraryItemId,
        'status':                   status.dbValue,
        'primary_contact_name':     primaryContactName,
        'primary_contact_phone':    primaryContactPhone,
        'backup_contact_name':      backupContactName,
        'backup_contact_phone':     backupContactPhone,
        'responsible_name':         responsibleName,
        'responsible_user_id':      responsibleUserId,
        'ops_notes':                opsNotes,
        'logistics_notes':          logisticsNotes,
        'transport_notes':          transportNotes,
        'guide_notes':              guideNotes,
        'sort_order':               sortOrder,
        'operational_instructions': operationalInstructions,
        'contingency_instructions': contingencyInstructions,
        'escalation_instructions':  escalationInstructions,
        'instructions_source':      instructionsSource?.dbValue,
        'instructions_approved_by': instructionsApprovedBy,
        'instructions_approved_at': instructionsApprovedAt?.toIso8601String(),
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// RunSheetStatus — operational execution status (separate from ItemStatus)
// ─────────────────────────────────────────────────────────────────────────────

enum RunSheetStatus {
  upcoming,
  inProgress,
  completed,
  delayed,
  issueFlagged,
  cancelled,
}

extension RunSheetStatusDisplay on RunSheetStatus {
  String get label => switch (this) {
        RunSheetStatus.upcoming     => 'Upcoming',
        RunSheetStatus.inProgress   => 'In Progress',
        RunSheetStatus.completed    => 'Completed',
        RunSheetStatus.delayed      => 'Delayed',
        RunSheetStatus.issueFlagged => 'Issue',
        RunSheetStatus.cancelled    => 'Cancelled',
      };

  String get dbValue => switch (this) {
        RunSheetStatus.upcoming     => 'upcoming',
        RunSheetStatus.inProgress   => 'in_progress',
        RunSheetStatus.completed    => 'completed',
        RunSheetStatus.delayed      => 'delayed',
        RunSheetStatus.issueFlagged => 'issue_flagged',
        RunSheetStatus.cancelled    => 'cancelled',
      };

  Color get color => switch (this) {
        RunSheetStatus.upcoming     => const Color(0xFF6B7280),
        RunSheetStatus.inProgress   => const Color(0xFF1D4ED8),
        RunSheetStatus.completed    => const Color(0xFF065F46),
        RunSheetStatus.delayed      => const Color(0xFF92400E),
        RunSheetStatus.issueFlagged => const Color(0xFF991B1B),
        RunSheetStatus.cancelled    => const Color(0xFF6B7280),
      };

  Color get bgColor => switch (this) {
        RunSheetStatus.upcoming     => const Color(0xFFE5E7EB),
        RunSheetStatus.inProgress   => const Color(0xFFDBEAFE),
        RunSheetStatus.completed    => const Color(0xFFD1FAE5),
        RunSheetStatus.delayed      => const Color(0xFFFEF3C7),
        RunSheetStatus.issueFlagged => const Color(0xFFFEE2E2),
        RunSheetStatus.cancelled    => const Color(0xFFF3F4F6),
      };

  IconData get icon => switch (this) {
        RunSheetStatus.upcoming     => Icons.schedule_rounded,
        RunSheetStatus.inProgress   => Icons.play_circle_outline_rounded,
        RunSheetStatus.completed    => Icons.check_circle_outline_rounded,
        RunSheetStatus.delayed      => Icons.watch_later_outlined,
        RunSheetStatus.issueFlagged => Icons.warning_amber_rounded,
        RunSheetStatus.cancelled    => Icons.cancel_outlined,
      };

  static RunSheetStatus fromDb(String raw) => switch (raw) {
        'in_progress'   => RunSheetStatus.inProgress,
        'completed'     => RunSheetStatus.completed,
        'delayed'       => RunSheetStatus.delayed,
        'issue_flagged' => RunSheetStatus.issueFlagged,
        'cancelled'     => RunSheetStatus.cancelled,
        _               => RunSheetStatus.upcoming,
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// RunSheetItem
//
// Merged view of an ItineraryItem + operational execution overlay.
// The mapper service produces these from the two data sources.
// ─────────────────────────────────────────────────────────────────────────────

class RunSheetItem {
  // Identity
  final String  id;               // run_sheet_items.id (or synthetic if no DB record)
  final String? itineraryItemId;  // FK → itinerary_items.id
  final String  tripId;
  final String  dayId;

  // Core item fields (from ItineraryItem)
  final String     title;
  final ItemType   type;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final TimeBlock  timeBlock;
  final String?    location;
  final String?    supplierId;
  final String?    supplierName;
  final String?    description;

  // Execution overlay (from run_sheet_items)
  final RunSheetStatus status;
  final String?    primaryContactName;
  final String?    primaryContactPhone;
  final String?    backupContactName;
  final String?    backupContactPhone;
  final String?    responsibleName;
  final String?    responsibleUserId;
  final String?    opsNotes;
  final String?    logisticsNotes;
  final String?    transportNotes;  // driver-specific notes
  final String?    guideNotes;      // guide-specific notes
  final int        sortOrder;

  // Operational instructions
  final String?             operationalInstructions;
  final String?             contingencyInstructions;
  final String?             escalationInstructions;
  final InstructionsSource? instructionsSource;
  final String?             instructionsApprovedBy;
  final DateTime?           instructionsApprovedAt;

  const RunSheetItem({
    required this.id,
    this.itineraryItemId,
    required this.tripId,
    required this.dayId,
    required this.title,
    required this.type,
    this.startTime,
    this.endTime,
    required this.timeBlock,
    this.location,
    this.supplierId,
    this.supplierName,
    this.description,
    this.status = RunSheetStatus.upcoming,
    this.primaryContactName,
    this.primaryContactPhone,
    this.backupContactName,
    this.backupContactPhone,
    this.responsibleName,
    this.responsibleUserId,
    this.opsNotes,
    this.logisticsNotes,
    this.transportNotes,
    this.guideNotes,
    this.sortOrder = 0,
    this.operationalInstructions,
    this.contingencyInstructions,
    this.escalationInstructions,
    this.instructionsSource,
    this.instructionsApprovedBy,
    this.instructionsApprovedAt,
  });

  RunSheetItem copyWith({
    String?               id,
    RunSheetStatus?       status,
    String?               primaryContactName,
    String?               primaryContactPhone,
    String?               backupContactName,
    String?               backupContactPhone,
    String?               responsibleName,
    String?               opsNotes,
    String?               logisticsNotes,
    String?               transportNotes,
    String?               guideNotes,
    String?               operationalInstructions,
    String?               contingencyInstructions,
    String?               escalationInstructions,
    InstructionsSource?   instructionsSource,
    String?               instructionsApprovedBy,
    DateTime?             instructionsApprovedAt,
  }) {
    return RunSheetItem(
      id:                       id                       ?? this.id,
      itineraryItemId:          itineraryItemId,
      tripId:                   tripId,
      dayId:                    dayId,
      title:                    title,
      type:                     type,
      startTime:                startTime,
      endTime:                  endTime,
      timeBlock:                timeBlock,
      location:                 location,
      supplierId:               supplierId,
      supplierName:             supplierName,
      description:              description,
      status:                   status                   ?? this.status,
      primaryContactName:       primaryContactName       ?? this.primaryContactName,
      primaryContactPhone:      primaryContactPhone      ?? this.primaryContactPhone,
      backupContactName:        backupContactName        ?? this.backupContactName,
      backupContactPhone:       backupContactPhone       ?? this.backupContactPhone,
      responsibleName:          responsibleName          ?? this.responsibleName,
      responsibleUserId:        responsibleUserId,
      opsNotes:                 opsNotes                 ?? this.opsNotes,
      logisticsNotes:           logisticsNotes           ?? this.logisticsNotes,
      transportNotes:           transportNotes           ?? this.transportNotes,
      guideNotes:               guideNotes               ?? this.guideNotes,
      sortOrder:                sortOrder,
      operationalInstructions:  operationalInstructions  ?? this.operationalInstructions,
      contingencyInstructions:  contingencyInstructions  ?? this.contingencyInstructions,
      escalationInstructions:   escalationInstructions   ?? this.escalationInstructions,
      instructionsSource:       instructionsSource       ?? this.instructionsSource,
      instructionsApprovedBy:   instructionsApprovedBy   ?? this.instructionsApprovedBy,
      instructionsApprovedAt:   instructionsApprovedAt   ?? this.instructionsApprovedAt,
    );
  }

  /// True if this item has a DB-backed run_sheet_items record.
  bool get isPersisted => id.isNotEmpty && !id.startsWith('_synth_');

  /// True if there is any contact information.
  bool get hasContacts =>
      (primaryContactName?.isNotEmpty  ?? false) ||
      (primaryContactPhone?.isNotEmpty ?? false) ||
      (backupContactName?.isNotEmpty   ?? false);

  bool get hasLogistics       => logisticsNotes?.isNotEmpty         ?? false;
  bool get hasOpsNotes        => opsNotes?.isNotEmpty               ?? false;
  bool get hasTransportNotes  => transportNotes?.isNotEmpty         ?? false;
  bool get hasGuideNotes      => guideNotes?.isNotEmpty             ?? false;
  bool get hasInstructions    =>
      (operationalInstructions?.isNotEmpty ?? false) ||
      (contingencyInstructions?.isNotEmpty ?? false) ||
      (escalationInstructions?.isNotEmpty  ?? false);
}
