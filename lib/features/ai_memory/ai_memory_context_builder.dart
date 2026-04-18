import '../../data/models/ai_memory_record.dart';
import '../../data/repositories/ai_memory_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AiMemoryContextBuilder
//
// Formats memory records and inferred signals into a structured string that
// can be prepended to AI prompts.  No raw DB dumps — only curated signals.
// ─────────────────────────────────────────────────────────────────────────────

class AiMemoryContextBuilder {
  final AiMemoryRepository _repo;

  const AiMemoryContextBuilder(this._repo);

  Future<String> buildForDossier(String dossierId) async {
    final signals = await _repo.fetchSignalsForDossier(dossierId);
    final memory  = await _repo.fetchMemoryForDossier(dossierId);

    if (signals.isEmpty && memory.isEmpty) return '';

    final buffer = StringBuffer();
    buffer.writeln('=== CLIENT MEMORY & LEARNED PREFERENCES ===');

    // ── Inferred preference signals ──────────────────────────────────────────
    if (signals.isNotEmpty) {
      buffer.writeln('\n[Inferred Client Preferences]');
      for (final s in signals) {
        final conf = s.confidence.label.toLowerCase();
        buffer.writeln('• ${s.humanLabel}: ${s.signalValue} ($conf confidence, '
            '${s.evidenceCount} data point${s.evidenceCount == 1 ? '' : 's'})');
      }
    }

    // ── Experience patterns ──────────────────────────────────────────────────
    final expPatterns = memory
        .where((m) => m.memoryType == MemoryType.experiencePattern)
        .toList();
    if (expPatterns.isNotEmpty) {
      final preferred = expPatterns
          .where((m) => m.signalValue['preference'] == 'preferred')
          .map((m) => m.signalValue['category'] as String?)
          .whereType<String>()
          .toList();
      final avoided = expPatterns
          .where((m) => m.signalValue['preference'] == 'avoided')
          .map((m) => m.signalValue['category'] as String?)
          .whereType<String>()
          .toList();

      if (preferred.isNotEmpty) {
        buffer.writeln('\n[Preferred Experience Categories]');
        buffer.writeln(preferred.map((e) => '• $e').join('\n'));
      }
      if (avoided.isNotEmpty) {
        buffer.writeln('\n[Experiences to Avoid]');
        buffer.writeln(avoided.map((e) => '• $e').join('\n'));
      }
    }

    // ── Supplier patterns ────────────────────────────────────────────────────
    final supplierPatterns = memory
        .where((m) => m.memoryType == MemoryType.supplierPattern)
        .toList();
    if (supplierPatterns.isNotEmpty) {
      final preferred = supplierPatterns
          .where((m) => m.signalValue['preference'] == 'preferred')
          .map((m) => _supplierLabel(m.signalValue))
          .toList();
      final avoided = supplierPatterns
          .where((m) => m.signalValue['preference'] == 'avoided')
          .map((m) => _supplierLabel(m.signalValue))
          .toList();

      if (preferred.isNotEmpty) {
        buffer.writeln('\n[Preferred Suppliers]');
        buffer.writeln(preferred.map((s) => '• $s').join('\n'));
      }
      if (avoided.isNotEmpty) {
        buffer.writeln('\n[Suppliers to Avoid]');
        buffer.writeln(avoided.map((s) => '• $s').join('\n'));
      }
    }

    buffer.writeln('\n===========================================');
    return buffer.toString();
  }

  String _supplierLabel(Map<String, dynamic> v) {
    final name = v['supplier_name'] ?? 'Unknown';
    final type = v['supplier_type'];
    return type != null ? '$name ($type)' : name;
  }
}
