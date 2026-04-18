import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/supabase/app_db.dart';
import '../../data/models/effective_permission.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DossierAccessGuard
//
// Wraps any widget tree that requires a specific dossier permission.
// Shows a loading indicator while resolving, the child if allowed,
// or a "Access Restricted" state if denied.
//
// Usage:
//   DossierAccessGuard(
//     permissionKey: DossierPermissionKey.viewDossier,
//     child: ClientDossierListScreen(),
//   )
// ─────────────────────────────────────────────────────────────────────────────

class DossierAccessGuard extends StatefulWidget {
  final String permissionKey;
  final Widget child;
  final Widget? fallback;

  const DossierAccessGuard({
    super.key,
    required this.permissionKey,
    required this.child,
    this.fallback,
  });

  @override
  State<DossierAccessGuard> createState() => _DossierAccessGuardState();
}

class _DossierAccessGuardState extends State<DossierAccessGuard> {
  EffectivePermission? _perm;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final svc    = AppRepositories.instance?.permissions;
    final teamId = AppRepositories.instance?.currentTeamId ?? '';
    if (svc == null || teamId.isEmpty) {
      if (mounted) setState(() => _perm = EffectivePermission.denied);
      return;
    }
    final perm = await svc.resolve(teamId);
    if (mounted) setState(() => _perm = perm);
  }

  @override
  Widget build(BuildContext context) {
    final perm = _perm;

    if (perm == null) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
      );
    }

    if (!perm.check(widget.permissionKey)) {
      return widget.fallback ?? const _RestrictedState();
    }

    return widget.child;
  }
}

// ── Inline guard (no loading state — for sections within an already-loaded screen)
// Useful when permissions are already resolved and passed down.

class PermissionGate extends StatelessWidget {
  final bool allowed;
  final Widget child;
  final Widget? fallback;

  const PermissionGate({
    super.key,
    required this.allowed,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    if (!allowed) return fallback ?? const SizedBox.shrink();
    return child;
  }
}

// ── Default restricted state ──────────────────────────────────────────────────

class _RestrictedState extends StatelessWidget {
  const _RestrictedState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color:        AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
                border:       Border.all(color: AppColors.border),
              ),
              child: const Icon(Icons.lock_outline_rounded,
                  color: AppColors.textMuted, size: 22),
            ),
            const SizedBox(height: AppSpacing.base),
            Text('Access Restricted', style: AppTextStyles.heading2),
            const SizedBox(height: 6),
            Text(
              'You do not have permission to view this section.\nContact your team administrator.',
              style: AppTextStyles.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
