import 'package:flutter/material.dart';

// ── DocumentType ──────────────────────────────────────────────────────────────

enum DocumentType {
  bookingConfirmation,
  invoice,
  voucher,
  contract,
  permit,
  receipt,
  paymentConfirmation,
  insurance,
  waiver,
  supplierTerms,
  passportOrId,
  other;

  String get dbValue {
    switch (this) {
      case DocumentType.bookingConfirmation: return 'booking_confirmation';
      case DocumentType.invoice:             return 'invoice';
      case DocumentType.voucher:             return 'voucher';
      case DocumentType.contract:            return 'contract';
      case DocumentType.permit:              return 'permit';
      case DocumentType.receipt:             return 'receipt';
      case DocumentType.paymentConfirmation: return 'payment_confirmation';
      case DocumentType.insurance:           return 'insurance';
      case DocumentType.waiver:              return 'waiver';
      case DocumentType.supplierTerms:       return 'supplier_terms';
      case DocumentType.passportOrId:        return 'passport_or_id';
      case DocumentType.other:               return 'other';
    }
  }

  String get label {
    switch (this) {
      case DocumentType.bookingConfirmation: return 'Booking Confirmation';
      case DocumentType.invoice:             return 'Invoice';
      case DocumentType.voucher:             return 'Voucher';
      case DocumentType.contract:            return 'Contract';
      case DocumentType.permit:              return 'Permit';
      case DocumentType.receipt:             return 'Receipt';
      case DocumentType.paymentConfirmation: return 'Payment Confirmation';
      case DocumentType.insurance:           return 'Insurance';
      case DocumentType.waiver:              return 'Waiver';
      case DocumentType.supplierTerms:       return 'Supplier Terms';
      case DocumentType.passportOrId:        return 'Passport / ID';
      case DocumentType.other:               return 'Other';
    }
  }

  IconData get icon {
    switch (this) {
      case DocumentType.bookingConfirmation: return Icons.confirmation_number_outlined;
      case DocumentType.invoice:             return Icons.receipt_long_outlined;
      case DocumentType.voucher:             return Icons.card_giftcard_outlined;
      case DocumentType.contract:            return Icons.description_outlined;
      case DocumentType.permit:              return Icons.approval_outlined;
      case DocumentType.receipt:             return Icons.receipt_outlined;
      case DocumentType.paymentConfirmation: return Icons.payment_outlined;
      case DocumentType.insurance:           return Icons.shield_outlined;
      case DocumentType.waiver:              return Icons.handshake_outlined;
      case DocumentType.supplierTerms:       return Icons.gavel_outlined;
      case DocumentType.passportOrId:        return Icons.badge_outlined;
      case DocumentType.other:               return Icons.attach_file_rounded;
    }
  }

  Color get color {
    switch (this) {
      case DocumentType.bookingConfirmation: return const Color(0xFF0891B2);
      case DocumentType.invoice:             return const Color(0xFFEA580C);
      case DocumentType.voucher:             return const Color(0xFF059669);
      case DocumentType.contract:            return const Color(0xFF7C3AED);
      case DocumentType.permit:              return const Color(0xFFD97706);
      case DocumentType.receipt:             return const Color(0xFF0369A1);
      case DocumentType.paymentConfirmation: return const Color(0xFF16A34A);
      case DocumentType.insurance:           return const Color(0xFF0F766E);
      case DocumentType.waiver:              return const Color(0xFFCA8A04);
      case DocumentType.supplierTerms:       return const Color(0xFF6B7280);
      case DocumentType.passportOrId:        return const Color(0xFFDC2626);
      case DocumentType.other:               return const Color(0xFF6B7280);
    }
  }

  Color get bgColor => color.withAlpha(20);

  static DocumentType fromDb(String v) {
    switch (v) {
      case 'booking_confirmation': return DocumentType.bookingConfirmation;
      case 'invoice':              return DocumentType.invoice;
      case 'voucher':              return DocumentType.voucher;
      case 'contract':             return DocumentType.contract;
      case 'permit':               return DocumentType.permit;
      case 'receipt':              return DocumentType.receipt;
      case 'payment_confirmation': return DocumentType.paymentConfirmation;
      case 'insurance':            return DocumentType.insurance;
      case 'waiver':               return DocumentType.waiver;
      case 'supplier_terms':       return DocumentType.supplierTerms;
      case 'passport_or_id':       return DocumentType.passportOrId;
      default:                     return DocumentType.other;
    }
  }
}

// ── DocumentStatus ────────────────────────────────────────────────────────────

enum DocumentStatus {
  uploaded,
  reviewed,
  approved,
  expired,
  missing,
  archived;

  String get dbValue {
    switch (this) {
      case DocumentStatus.uploaded: return 'uploaded';
      case DocumentStatus.reviewed: return 'reviewed';
      case DocumentStatus.approved: return 'approved';
      case DocumentStatus.expired:  return 'expired';
      case DocumentStatus.missing:  return 'missing';
      case DocumentStatus.archived: return 'archived';
    }
  }

  String get label {
    switch (this) {
      case DocumentStatus.uploaded: return 'Uploaded';
      case DocumentStatus.reviewed: return 'Reviewed';
      case DocumentStatus.approved: return 'Approved';
      case DocumentStatus.expired:  return 'Expired';
      case DocumentStatus.missing:  return 'Missing';
      case DocumentStatus.archived: return 'Archived';
    }
  }

  Color get color {
    switch (this) {
      case DocumentStatus.uploaded: return const Color(0xFF0891B2);
      case DocumentStatus.reviewed: return const Color(0xFF7C3AED);
      case DocumentStatus.approved: return const Color(0xFF16A34A);
      case DocumentStatus.expired:  return const Color(0xFFDC2626);
      case DocumentStatus.missing:  return const Color(0xFFD97706);
      case DocumentStatus.archived: return const Color(0xFF6B7280);
    }
  }

  Color get bgColor => color.withAlpha(20);

  static DocumentStatus fromDb(String v) {
    switch (v) {
      case 'uploaded': return DocumentStatus.uploaded;
      case 'reviewed': return DocumentStatus.reviewed;
      case 'approved': return DocumentStatus.approved;
      case 'expired':  return DocumentStatus.expired;
      case 'missing':  return DocumentStatus.missing;
      case 'archived': return DocumentStatus.archived;
      default:         return DocumentStatus.uploaded;
    }
  }
}

// ── TripDocument ──────────────────────────────────────────────────────────────

class TripDocument {
  final String id;
  final String teamId;
  final String tripId;

  // Link fields
  final String? componentId;
  final String? costItemId;
  final String? runSheetItemId;
  final String? supplierId;
  final String? itineraryItemId;

  // Document fields
  final DocumentType  documentType;
  final String        title;
  final String        fileUrl;
  final String?       fileName;
  final int?          fileSize;
  final String?       mimeType;
  final String?       storagePath;

  // Status
  final DocumentStatus status;
  final bool           isClientVisible;

  // Dates
  final DateTime? issueDate;
  final DateTime? expiryDate;
  final DateTime  uploadedAt;
  final DateTime? reviewedAt;
  final DateTime? approvedAt;

  // Ownership
  final String  uploadedBy;
  final String? reviewedBy;
  final String? approvedBy;

  // Notes
  final String? notesInternal;
  final String? notesClient;

  const TripDocument({
    required this.id,
    required this.teamId,
    required this.tripId,
    this.componentId,
    this.costItemId,
    this.runSheetItemId,
    this.supplierId,
    this.itineraryItemId,
    required this.documentType,
    required this.title,
    required this.fileUrl,
    this.fileName,
    this.fileSize,
    this.mimeType,
    this.storagePath,
    required this.status,
    this.isClientVisible = false,
    this.issueDate,
    this.expiryDate,
    required this.uploadedAt,
    this.reviewedAt,
    this.approvedAt,
    required this.uploadedBy,
    this.reviewedBy,
    this.approvedBy,
    this.notesInternal,
    this.notesClient,
  });

  bool get isPdf =>
      mimeType?.toLowerCase() == 'application/pdf' ||
      (fileName?.toLowerCase().endsWith('.pdf') ?? false) ||
      fileUrl.toLowerCase().contains('.pdf');

  bool get isExpired {
    if (expiryDate == null) return false;
    return expiryDate!.isBefore(DateTime.now());
  }

  bool get isExpiringSoon {
    if (expiryDate == null || isExpired) return false;
    return expiryDate!.isBefore(DateTime.now().add(const Duration(days: 30)));
  }

  String get fileSizeLabel {
    if (fileSize == null) return '';
    final kb = fileSize! / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(0)} KB';
    return '${(kb / 1024).toStringAsFixed(1)} MB';
  }

  TripDocument copyWith({
    String?        id,
    String?        teamId,
    String?        tripId,
    String?        componentId,       bool clearComponentId       = false,
    String?        costItemId,        bool clearCostItemId        = false,
    String?        runSheetItemId,    bool clearRunSheetItemId    = false,
    String?        supplierId,        bool clearSupplierId        = false,
    String?        itineraryItemId,   bool clearItineraryItemId   = false,
    DocumentType?  documentType,
    String?        title,
    String?        fileUrl,
    String?        fileName,          bool clearFileName          = false,
    int?           fileSize,          bool clearFileSize          = false,
    String?        mimeType,          bool clearMimeType          = false,
    String?        storagePath,       bool clearStoragePath       = false,
    DocumentStatus? status,
    bool?          isClientVisible,
    DateTime?      issueDate,         bool clearIssueDate         = false,
    DateTime?      expiryDate,        bool clearExpiryDate        = false,
    DateTime?      uploadedAt,
    DateTime?      reviewedAt,        bool clearReviewedAt        = false,
    DateTime?      approvedAt,        bool clearApprovedAt        = false,
    String?        uploadedBy,
    String?        reviewedBy,        bool clearReviewedBy        = false,
    String?        approvedBy,        bool clearApprovedBy        = false,
    String?        notesInternal,     bool clearNotesInternal     = false,
    String?        notesClient,       bool clearNotesClient       = false,
  }) =>
      TripDocument(
        id:              id              ?? this.id,
        teamId:          teamId          ?? this.teamId,
        tripId:          tripId          ?? this.tripId,
        componentId:     clearComponentId    ? null : componentId    ?? this.componentId,
        costItemId:      clearCostItemId     ? null : costItemId     ?? this.costItemId,
        runSheetItemId:  clearRunSheetItemId ? null : runSheetItemId ?? this.runSheetItemId,
        supplierId:      clearSupplierId     ? null : supplierId     ?? this.supplierId,
        itineraryItemId: clearItineraryItemId ? null : itineraryItemId ?? this.itineraryItemId,
        documentType:    documentType    ?? this.documentType,
        title:           title           ?? this.title,
        fileUrl:         fileUrl         ?? this.fileUrl,
        fileName:        clearFileName   ? null : fileName     ?? this.fileName,
        fileSize:        clearFileSize   ? null : fileSize     ?? this.fileSize,
        mimeType:        clearMimeType   ? null : mimeType     ?? this.mimeType,
        storagePath:     clearStoragePath ? null : storagePath ?? this.storagePath,
        status:          status          ?? this.status,
        isClientVisible: isClientVisible ?? this.isClientVisible,
        issueDate:       clearIssueDate  ? null : issueDate    ?? this.issueDate,
        expiryDate:      clearExpiryDate ? null : expiryDate   ?? this.expiryDate,
        uploadedAt:      uploadedAt      ?? this.uploadedAt,
        reviewedAt:      clearReviewedAt ? null : reviewedAt   ?? this.reviewedAt,
        approvedAt:      clearApprovedAt ? null : approvedAt   ?? this.approvedAt,
        uploadedBy:      uploadedBy      ?? this.uploadedBy,
        reviewedBy:      clearReviewedBy ? null : reviewedBy   ?? this.reviewedBy,
        approvedBy:      clearApprovedBy ? null : approvedBy   ?? this.approvedBy,
        notesInternal:   clearNotesInternal ? null : notesInternal ?? this.notesInternal,
        notesClient:     clearNotesClient   ? null : notesClient   ?? this.notesClient,
      );
}
