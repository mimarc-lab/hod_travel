import '../../../data/models/supplier_enrichment_model.dart';
import '../../../data/models/supplier_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SupplierMergeService — applies selected enrichment fields to a Supplier.
//
// Field-level merge: the caller passes a set of [MergeField] values indicating
// which extracted fields should overwrite the existing supplier values.
// All other fields are preserved unchanged.
//
// Rules:
//   • Never overwrites a field unless the caller explicitly includes it in
//     [fieldsToApply] — prevents accidental destructive updates.
//   • Skips a selected field if the extracted value is null or empty.
//   • Tags are union-merged when selected (extracted tags added to existing).
// ─────────────────────────────────────────────────────────────────────────────

/// The mergeable fields shown in the comparison view.
enum MergeField {
  name,
  category,
  city,
  country,
  location,
  contactName,
  contactEmail,
  contactPhone,
  website,
  notes,
  tags,
}

extension MergeFieldLabel on MergeField {
  String get label => switch (this) {
        MergeField.name         => 'Name',
        MergeField.category     => 'Category',
        MergeField.city         => 'City',
        MergeField.country      => 'Country',
        MergeField.location     => 'Location',
        MergeField.contactName  => 'Contact',
        MergeField.contactEmail => 'Email',
        MergeField.contactPhone => 'Phone',
        MergeField.website      => 'Website',
        MergeField.notes        => 'Notes',
        MergeField.tags         => 'Tags',
      };
}

class SupplierMergeService {
  const SupplierMergeService();

  /// Returns the current value of [field] from [supplier] as a display string.
  String? currentValue(MergeField field, Supplier supplier) => switch (field) {
        MergeField.name         => supplier.name,
        MergeField.category     => supplier.category.label,
        MergeField.city         => supplier.city,
        MergeField.country      => supplier.country,
        MergeField.location     => supplier.location,
        MergeField.contactName  => supplier.contactName,
        MergeField.contactEmail => supplier.contactEmail,
        MergeField.contactPhone => supplier.contactPhone,
        MergeField.website      => supplier.website,
        MergeField.notes        => supplier.notes,
        MergeField.tags =>
            supplier.tags.isEmpty ? null : supplier.tags.join(', '),
      };

  /// Returns the extracted value of [field] from [enrichment] as a display
  /// string, or null if the enrichment has no value for that field.
  String? extractedValue(MergeField field, SupplierEnrichment enrichment) =>
      switch (field) {
        MergeField.name         => enrichment.name,
        MergeField.category     => enrichment.category?.label,
        MergeField.city         => enrichment.city,
        MergeField.country      => enrichment.country,
        MergeField.location     => enrichment.location,
        MergeField.contactName  => enrichment.contactName,
        MergeField.contactEmail => enrichment.contactEmail,
        MergeField.contactPhone => enrichment.contactPhone,
        MergeField.website      => enrichment.website,
        MergeField.notes        => enrichment.shortSummary ?? enrichment.summary,
        MergeField.tags =>
            enrichment.tags.isEmpty ? null : enrichment.tags.join(', '),
      };

  /// Builds the default set of fields that should be pre-selected for merging:
  /// fields where the enrichment has a value that differs from the current one.
  Map<MergeField, bool> defaultToggles(
    Supplier supplier,
    SupplierEnrichment enrichment,
  ) {
    return {
      for (final f in MergeField.values)
        f: () {
          final extracted = extractedValue(f, enrichment);
          final current = currentValue(f, supplier);
          return extracted != null &&
              extracted.isNotEmpty &&
              extracted != current;
        }(),
    };
  }

  /// Applies [fieldsToApply] from [enrichment] onto [supplier] and returns
  /// the updated copy. Fields not in [fieldsToApply] are unchanged.
  Supplier apply({
    required Supplier supplier,
    required SupplierEnrichment enrichment,
    required Set<MergeField> fieldsToApply,
  }) {
    var updated = supplier;

    for (final field in fieldsToApply) {
      final val = extractedValue(field, enrichment);
      if (val == null || val.isEmpty) continue;

      updated = switch (field) {
        MergeField.name         => updated.copyWith(name: val),
        MergeField.category     => updated.copyWith(
            category: enrichment.category ?? updated.category),
        MergeField.city         => updated.copyWith(city: val),
        MergeField.country      => updated.copyWith(country: val),
        MergeField.location     => updated.copyWith(location: val),
        MergeField.contactName  => updated.copyWith(contactName: val),
        MergeField.contactEmail => updated.copyWith(contactEmail: val),
        MergeField.contactPhone => updated.copyWith(contactPhone: val),
        MergeField.website      => updated.copyWith(website: val),
        MergeField.notes        => updated.copyWith(notes: val),
        MergeField.tags => updated.copyWith(
            tags: _mergeTags(updated.tags, enrichment.tags)),
      };
    }

    return updated;
  }

  /// Union-merges tag lists, preserving existing tags and appending new ones.
  List<String> _mergeTags(List<String> existing, List<String> extracted) {
    final seen = <String>{...existing.map((t) => t.toLowerCase())};
    final result = List<String>.from(existing);
    for (final tag in extracted) {
      if (!seen.contains(tag.toLowerCase())) {
        result.add(tag);
        seen.add(tag.toLowerCase());
      }
    }
    return result;
  }
}
