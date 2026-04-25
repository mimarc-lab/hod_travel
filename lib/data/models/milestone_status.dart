import 'package:flutter/material.dart';

enum MilestoneId {
  intakeComplete,
  sourcingComplete,
  proposalReady,
  finalPresentationApproved,
  opsHandoffComplete,
}

enum MilestoneCompletion { pending, atRisk, complete }

extension MilestoneIdDisplay on MilestoneId {
  String get title => switch (this) {
    MilestoneId.intakeComplete              => 'Intake Complete',
    MilestoneId.sourcingComplete            => 'Sourcing Complete',
    MilestoneId.proposalReady               => 'Proposal Ready',
    MilestoneId.finalPresentationApproved   => 'Final Presentation Approved',
    MilestoneId.opsHandoffComplete          => 'Ops Handoff Complete',
  };

  String get description => switch (this) {
    MilestoneId.intakeComplete            => 'Questionnaire received and intake task completed.',
    MilestoneId.sourcingComplete          => 'Accommodation and experience components sourced and approved.',
    MilestoneId.proposalReady             => 'Itinerary and pricing prepared for client.',
    MilestoneId.finalPresentationApproved => 'Final itinerary approved by client.',
    MilestoneId.opsHandoffComplete        => 'All components confirmed and run sheet created.',
  };
}

extension MilestoneCompletionDisplay on MilestoneCompletion {
  String get label => switch (this) {
    MilestoneCompletion.pending  => 'Pending',
    MilestoneCompletion.atRisk   => 'At Risk',
    MilestoneCompletion.complete => 'Complete',
  };

  Color get color => switch (this) {
    MilestoneCompletion.pending  => const Color(0xFF9CA3AF),
    MilestoneCompletion.atRisk   => const Color(0xFFF59E0B),
    MilestoneCompletion.complete => const Color(0xFF10B981),
  };

  Color get bgColor => switch (this) {
    MilestoneCompletion.pending  => const Color(0xFFF3F4F6),
    MilestoneCompletion.atRisk   => const Color(0xFFFEF3C7),
    MilestoneCompletion.complete => const Color(0xFFECFDF5),
  };
}

class MilestoneStatus {
  final MilestoneId id;
  final MilestoneCompletion completion;
  final List<String> pendingCriteria;

  const MilestoneStatus({
    required this.id,
    required this.completion,
    this.pendingCriteria = const [],
  });

  String get title       => id.title;
  String get description => id.description;
}
