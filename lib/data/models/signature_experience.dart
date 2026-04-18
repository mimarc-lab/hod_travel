import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Enums
// ─────────────────────────────────────────────────────────────────────────────

enum ExperienceStatus { draft, tested, approved, flagship, archived }

extension ExperienceStatusX on ExperienceStatus {
  String get label {
    switch (this) {
      case ExperienceStatus.draft:     return 'Draft';
      case ExperienceStatus.tested:    return 'Tested';
      case ExperienceStatus.approved:  return 'Approved';
      case ExperienceStatus.flagship:  return 'Flagship';
      case ExperienceStatus.archived:  return 'Archived';
    }
  }

  String get dbValue {
    switch (this) {
      case ExperienceStatus.draft:     return 'draft';
      case ExperienceStatus.tested:    return 'tested';
      case ExperienceStatus.approved:  return 'approved';
      case ExperienceStatus.flagship:  return 'flagship';
      case ExperienceStatus.archived:  return 'archived';
    }
  }

  Color get color {
    switch (this) {
      case ExperienceStatus.draft:     return const Color(0xFF6B7280);
      case ExperienceStatus.tested:    return const Color(0xFF1D4ED8);
      case ExperienceStatus.approved:  return const Color(0xFF065F46);
      case ExperienceStatus.flagship:  return const Color(0xFFB8955A);
      case ExperienceStatus.archived:  return const Color(0xFF9CA3AF);
    }
  }

  Color get backgroundColor {
    switch (this) {
      case ExperienceStatus.draft:     return const Color(0xFFF3F4F6);
      case ExperienceStatus.tested:    return const Color(0xFFDBEAFE);
      case ExperienceStatus.approved:  return const Color(0xFFD1FAE5);
      case ExperienceStatus.flagship:  return const Color(0xFFF7EDD8);
      case ExperienceStatus.archived:  return const Color(0xFFE5E7EB);
    }
  }

  IconData get icon {
    switch (this) {
      case ExperienceStatus.draft:     return Icons.edit_outlined;
      case ExperienceStatus.tested:    return Icons.check_circle_outline_rounded;
      case ExperienceStatus.approved:  return Icons.verified_outlined;
      case ExperienceStatus.flagship:  return Icons.star_rounded;
      case ExperienceStatus.archived:  return Icons.archive_outlined;
    }
  }

  static ExperienceStatus fromDb(String raw) => switch (raw) {
    'tested'   => ExperienceStatus.tested,
    'approved' => ExperienceStatus.approved,
    'flagship' => ExperienceStatus.flagship,
    'archived' => ExperienceStatus.archived,
    _          => ExperienceStatus.draft,
  };
}

// ─────────────────────────────────────────────────────────────────────────────

enum ExperienceCategory {
  cultural,
  culinary,
  political,
  wellness,
  adventure,
  artistic,
  educational,
  immersive,
  exclusive,
  other,
}

extension ExperienceCategoryX on ExperienceCategory {
  String get label {
    switch (this) {
      case ExperienceCategory.cultural:     return 'Cultural';
      case ExperienceCategory.culinary:     return 'Culinary';
      case ExperienceCategory.political:    return 'Political';
      case ExperienceCategory.wellness:     return 'Wellness';
      case ExperienceCategory.adventure:    return 'Adventure';
      case ExperienceCategory.artistic:     return 'Artistic';
      case ExperienceCategory.educational:  return 'Educational';
      case ExperienceCategory.immersive:    return 'Immersive';
      case ExperienceCategory.exclusive:    return 'Exclusive Access';
      case ExperienceCategory.other:        return 'Other';
    }
  }

  IconData get icon {
    switch (this) {
      case ExperienceCategory.cultural:     return Icons.account_balance_outlined;
      case ExperienceCategory.culinary:     return Icons.restaurant_outlined;
      case ExperienceCategory.political:    return Icons.gavel_outlined;
      case ExperienceCategory.wellness:     return Icons.self_improvement_outlined;
      case ExperienceCategory.adventure:    return Icons.terrain_outlined;
      case ExperienceCategory.artistic:     return Icons.palette_outlined;
      case ExperienceCategory.educational:  return Icons.school_outlined;
      case ExperienceCategory.immersive:    return Icons.layers_outlined;
      case ExperienceCategory.exclusive:    return Icons.vpn_key_outlined;
      case ExperienceCategory.other:        return Icons.category_outlined;
    }
  }

  Color get color {
    switch (this) {
      case ExperienceCategory.cultural:     return const Color(0xFF7C6FAB);
      case ExperienceCategory.culinary:     return const Color(0xFFD4845A);
      case ExperienceCategory.political:    return const Color(0xFF4A6FA4);
      case ExperienceCategory.wellness:     return const Color(0xFF5A9E6F);
      case ExperienceCategory.adventure:    return const Color(0xFF7A9E4A);
      case ExperienceCategory.artistic:     return const Color(0xFFB05A8A);
      case ExperienceCategory.educational:  return const Color(0xFF4A90A4);
      case ExperienceCategory.immersive:    return const Color(0xFF6E7FAB);
      case ExperienceCategory.exclusive:    return const Color(0xFFC9A96E);
      case ExperienceCategory.other:        return const Color(0xFF8A8A8A);
    }
  }

  String get dbValue {
    switch (this) {
      case ExperienceCategory.cultural:     return 'cultural';
      case ExperienceCategory.culinary:     return 'culinary';
      case ExperienceCategory.political:    return 'political';
      case ExperienceCategory.wellness:     return 'wellness';
      case ExperienceCategory.adventure:    return 'adventure';
      case ExperienceCategory.artistic:     return 'artistic';
      case ExperienceCategory.educational:  return 'educational';
      case ExperienceCategory.immersive:    return 'immersive';
      case ExperienceCategory.exclusive:    return 'exclusive';
      case ExperienceCategory.other:        return 'other';
    }
  }

  static ExperienceCategory fromDb(String raw) => switch (raw) {
    'cultural'    => ExperienceCategory.cultural,
    'culinary'    => ExperienceCategory.culinary,
    'political'   => ExperienceCategory.political,
    'wellness'    => ExperienceCategory.wellness,
    'adventure'   => ExperienceCategory.adventure,
    'artistic'    => ExperienceCategory.artistic,
    'educational' => ExperienceCategory.educational,
    'immersive'   => ExperienceCategory.immersive,
    'exclusive'   => ExperienceCategory.exclusive,
    _             => ExperienceCategory.other,
  };
}

// ─────────────────────────────────────────────────────────────────────────────

enum ExperienceType { private, group, family, executive, educational, immersive, other }

extension ExperienceTypeX on ExperienceType {
  String get label {
    switch (this) {
      case ExperienceType.private:     return 'Private';
      case ExperienceType.group:       return 'Group';
      case ExperienceType.family:      return 'Family';
      case ExperienceType.executive:   return 'Executive';
      case ExperienceType.educational: return 'Educational';
      case ExperienceType.immersive:   return 'Immersive';
      case ExperienceType.other:       return 'Other';
    }
  }

  String get dbValue {
    switch (this) {
      case ExperienceType.private:     return 'private';
      case ExperienceType.group:       return 'group';
      case ExperienceType.family:      return 'family';
      case ExperienceType.executive:   return 'executive';
      case ExperienceType.educational: return 'educational';
      case ExperienceType.immersive:   return 'immersive';
      case ExperienceType.other:       return 'other';
    }
  }

  static ExperienceType fromDb(String raw) => switch (raw) {
    'group'       => ExperienceType.group,
    'family'      => ExperienceType.family,
    'executive'   => ExperienceType.executive,
    'educational' => ExperienceType.educational,
    'immersive'   => ExperienceType.immersive,
    'other'       => ExperienceType.other,
    _             => ExperienceType.private,
  };
}

// ─────────────────────────────────────────────────────────────────────────────

enum ExperienceFlexibility { fixed, adaptable, global }

extension ExperienceFlexibilityX on ExperienceFlexibility {
  String get label {
    switch (this) {
      case ExperienceFlexibility.fixed:     return 'Location-Fixed';
      case ExperienceFlexibility.adaptable: return 'Adaptable';
      case ExperienceFlexibility.global:    return 'Global';
    }
  }

  String get description {
    switch (this) {
      case ExperienceFlexibility.fixed:     return 'Requires a specific destination';
      case ExperienceFlexibility.adaptable: return 'Can be adapted for different locations';
      case ExperienceFlexibility.global:    return 'Designed to work anywhere in the world';
    }
  }

  IconData get icon {
    switch (this) {
      case ExperienceFlexibility.fixed:     return Icons.location_on_outlined;
      case ExperienceFlexibility.adaptable: return Icons.tune_rounded;
      case ExperienceFlexibility.global:    return Icons.public_outlined;
    }
  }

  String get dbValue {
    switch (this) {
      case ExperienceFlexibility.fixed:     return 'fixed';
      case ExperienceFlexibility.adaptable: return 'adaptable';
      case ExperienceFlexibility.global:    return 'global';
    }
  }

  static ExperienceFlexibility fromDb(String raw) => switch (raw) {
    'fixed'  => ExperienceFlexibility.fixed,
    'global' => ExperienceFlexibility.global,
    _        => ExperienceFlexibility.adaptable,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// SignatureExperience model
// ─────────────────────────────────────────────────────────────────────────────

class SignatureExperience {
  final String id;
  final String? teamId;

  // Core identity
  final String title;
  final ExperienceStatus status;
  final ExperienceCategory category;
  final ExperienceType experienceType;

  // Description (client-facing vs internal)
  final String? shortDescriptionClient;
  final String? longDescriptionInternal;
  final String? conceptSummary;

  // Audience & logistics
  final List<String> audienceSuitability;
  final ExperienceFlexibility destinationFlexibility;
  final List<String> tags;
  final String? durationLabel;
  final int? idealGroupSizeMin;
  final int? idealGroupSizeMax;
  final String? indoorOutdoorType;
  final String? locationNotes;

  // Operational
  final String? productionNotes;
  final String? setupRequirements;
  final String? executionComplexity;
  final List<String> requiredStaffRoles;
  final List<String> requiredSuppliers;

  // Commercial & sensitivity
  final String? costingNotes;
  final String? pricingNotes;
  final String? culturalSensitivityNotes;
  final String? politicalSensitivityNotes;
  final String? securityNotes;

  // Media & reference
  final List<String> mediaLinks;
  final String? briefingNotes;

  // Metadata
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const SignatureExperience({
    required this.id,
    this.teamId,
    required this.title,
    required this.status,
    required this.category,
    required this.experienceType,
    this.shortDescriptionClient,
    this.longDescriptionInternal,
    this.conceptSummary,
    this.audienceSuitability = const [],
    this.destinationFlexibility = ExperienceFlexibility.adaptable,
    this.tags = const [],
    this.durationLabel,
    this.idealGroupSizeMin,
    this.idealGroupSizeMax,
    this.indoorOutdoorType,
    this.locationNotes,
    this.productionNotes,
    this.setupRequirements,
    this.executionComplexity,
    this.requiredStaffRoles = const [],
    this.requiredSuppliers = const [],
    this.costingNotes,
    this.pricingNotes,
    this.culturalSensitivityNotes,
    this.politicalSensitivityNotes,
    this.securityNotes,
    this.mediaLinks = const [],
    this.briefingNotes,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  /// Convenience: a display-friendly group size string, e.g. "4–12 guests".
  String get groupSizeLabel {
    if (idealGroupSizeMin == null && idealGroupSizeMax == null) return 'Any size';
    if (idealGroupSizeMin != null && idealGroupSizeMax != null) {
      return '$idealGroupSizeMin–$idealGroupSizeMax guests';
    }
    if (idealGroupSizeMin != null) return '$idealGroupSizeMin+ guests';
    return 'Up to $idealGroupSizeMax guests';
  }

  SignatureExperience copyWith({
    String? title,
    ExperienceStatus? status,
    ExperienceCategory? category,
    ExperienceType? experienceType,
    String? shortDescriptionClient,
    bool clearShortDescriptionClient = false,
    String? longDescriptionInternal,
    bool clearLongDescriptionInternal = false,
    String? conceptSummary,
    bool clearConceptSummary = false,
    List<String>? audienceSuitability,
    ExperienceFlexibility? destinationFlexibility,
    List<String>? tags,
    String? durationLabel,
    bool clearDurationLabel = false,
    int? idealGroupSizeMin,
    bool clearGroupSizeMin = false,
    int? idealGroupSizeMax,
    bool clearGroupSizeMax = false,
    String? indoorOutdoorType,
    bool clearIndoorOutdoorType = false,
    String? locationNotes,
    bool clearLocationNotes = false,
    String? productionNotes,
    bool clearProductionNotes = false,
    String? setupRequirements,
    bool clearSetupRequirements = false,
    String? executionComplexity,
    bool clearExecutionComplexity = false,
    List<String>? requiredStaffRoles,
    List<String>? requiredSuppliers,
    String? costingNotes,
    bool clearCostingNotes = false,
    String? pricingNotes,
    bool clearPricingNotes = false,
    String? culturalSensitivityNotes,
    bool clearCulturalSensitivityNotes = false,
    String? politicalSensitivityNotes,
    bool clearPoliticalSensitivityNotes = false,
    String? securityNotes,
    bool clearSecurityNotes = false,
    List<String>? mediaLinks,
    String? briefingNotes,
    bool clearBriefingNotes = false,
  }) {
    return SignatureExperience(
      id:                           id,
      teamId:                       teamId,
      title:                        title                        ?? this.title,
      status:                       status                       ?? this.status,
      category:                     category                     ?? this.category,
      experienceType:               experienceType               ?? this.experienceType,
      shortDescriptionClient:       clearShortDescriptionClient       ? null : (shortDescriptionClient       ?? this.shortDescriptionClient),
      longDescriptionInternal:      clearLongDescriptionInternal      ? null : (longDescriptionInternal      ?? this.longDescriptionInternal),
      conceptSummary:               clearConceptSummary               ? null : (conceptSummary               ?? this.conceptSummary),
      audienceSuitability:          audienceSuitability          ?? this.audienceSuitability,
      destinationFlexibility:       destinationFlexibility       ?? this.destinationFlexibility,
      tags:                         tags                         ?? this.tags,
      durationLabel:                clearDurationLabel                ? null : (durationLabel                ?? this.durationLabel),
      idealGroupSizeMin:            clearGroupSizeMin                 ? null : (idealGroupSizeMin            ?? this.idealGroupSizeMin),
      idealGroupSizeMax:            clearGroupSizeMax                 ? null : (idealGroupSizeMax            ?? this.idealGroupSizeMax),
      indoorOutdoorType:            clearIndoorOutdoorType            ? null : (indoorOutdoorType            ?? this.indoorOutdoorType),
      locationNotes:                clearLocationNotes                ? null : (locationNotes                ?? this.locationNotes),
      productionNotes:              clearProductionNotes              ? null : (productionNotes              ?? this.productionNotes),
      setupRequirements:            clearSetupRequirements            ? null : (setupRequirements            ?? this.setupRequirements),
      executionComplexity:          clearExecutionComplexity          ? null : (executionComplexity          ?? this.executionComplexity),
      requiredStaffRoles:           requiredStaffRoles           ?? this.requiredStaffRoles,
      requiredSuppliers:            requiredSuppliers            ?? this.requiredSuppliers,
      costingNotes:                 clearCostingNotes                 ? null : (costingNotes                 ?? this.costingNotes),
      pricingNotes:                 clearPricingNotes                 ? null : (pricingNotes                 ?? this.pricingNotes),
      culturalSensitivityNotes:     clearCulturalSensitivityNotes     ? null : (culturalSensitivityNotes     ?? this.culturalSensitivityNotes),
      politicalSensitivityNotes:    clearPoliticalSensitivityNotes    ? null : (politicalSensitivityNotes    ?? this.politicalSensitivityNotes),
      securityNotes:                clearSecurityNotes                ? null : (securityNotes                ?? this.securityNotes),
      mediaLinks:                   mediaLinks                   ?? this.mediaLinks,
      briefingNotes:                clearBriefingNotes                ? null : (briefingNotes                ?? this.briefingNotes),
      createdBy:                    createdBy,
      createdAt:                    createdAt,
      updatedAt:                    updatedAt,
    );
  }
}
