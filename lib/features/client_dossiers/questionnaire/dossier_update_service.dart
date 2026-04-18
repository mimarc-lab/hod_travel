import '../../../data/models/client_dossier_model.dart';
import 'questionnaire_to_dossier_mapper.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DossierUpdateService
//
// Chains approved DossierFieldProposals onto a ClientDossier.
// Each proposal's applyFn is a closure over the typed value — no reflection,
// no dynamic dispatch, no blind overwrites.
// ─────────────────────────────────────────────────────────────────────────────

class DossierUpdateService {
  static ClientDossier apply(
    ClientDossier dossier,
    List<DossierFieldProposal> proposals,
  ) {
    var updated = dossier;
    for (final p in proposals) {
      if (p.apply) updated = p.applyFn(updated);
    }
    return updated;
  }

  static int countSelected(List<DossierFieldProposal> proposals) =>
      proposals.where((p) => p.apply).length;

  static List<String> selectedSummary(List<DossierFieldProposal> proposals) =>
      proposals
          .where((p) => p.apply)
          .map((p) => '${p.questionLabel}: ${p.proposedDisplay}')
          .toList();
}
