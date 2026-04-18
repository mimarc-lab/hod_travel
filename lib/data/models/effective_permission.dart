// Permission keys — match DB values exactly
abstract class DossierPermissionKey {
  static const viewDossier         = 'can_view_dossier';
  static const editDossier         = 'can_edit_dossier';
  static const viewSensitiveNotes  = 'can_view_sensitive_notes';

  static const all = [viewDossier, editDossier, viewSensitiveNotes];
}

class EffectivePermission {
  final bool canViewDossier;
  final bool canEditDossier;
  final bool canViewSensitiveNotes;

  const EffectivePermission({
    required this.canViewDossier,
    required this.canEditDossier,
    required this.canViewSensitiveNotes,
  });

  static const denied = EffectivePermission(
    canViewDossier:        false,
    canEditDossier:        false,
    canViewSensitiveNotes: false,
  );

  static const fullAccess = EffectivePermission(
    canViewDossier:        true,
    canEditDossier:        true,
    canViewSensitiveNotes: true,
  );

  bool check(String permissionKey) => switch (permissionKey) {
    DossierPermissionKey.viewDossier        => canViewDossier,
    DossierPermissionKey.editDossier        => canEditDossier,
    DossierPermissionKey.viewSensitiveNotes => canViewSensitiveNotes,
    _                                       => false,
  };

  @override
  String toString() =>
      'EffectivePermission(view=$canViewDossier, edit=$canEditDossier, sensitive=$canViewSensitiveNotes)';
}
