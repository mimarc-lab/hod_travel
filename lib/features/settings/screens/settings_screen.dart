import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/role_service.dart';
import '../../../core/supabase/app_db.dart';
import '../../../core/utils/responsive.dart';
import '../../../data/models/team_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/services/seed_service.dart';
import '../../../features/ai_suggestions/services/ai_config.dart';
import '../../../features/ai_suggestions/services/ai_key_store.dart';
import '../../../features/templates/screens/template_manager_screen.dart';
import '../../../shared/widgets/role_badge.dart';
import '../../../shared/widgets/user_avatar.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final hPad = Responsive.isMobile(context)
        ? AppSpacing.pagePaddingHMobile
        : AppSpacing.pagePaddingH;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _SettingsHeader(hPad: hPad),
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(
                horizontal: hPad, vertical: AppSpacing.xl),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _SectionCard(
                  title: 'TEAM',
                  children: [_TeamSection()],
                ),
                const SizedBox(height: AppSpacing.lg),
                _SectionCard(
                  title: 'ADD TEAM MEMBER',
                  subtitle: 'Add a Supabase user to your team by their email address. They must have signed in at least once first.',
                  children: const [_AddMemberSection()],
                ),
                const SizedBox(height: AppSpacing.lg),
                _SectionCard(
                  title: 'DEMO — ROLE SWITCHER',
                  subtitle:
                      'Switch your active role to preview permission-based UI changes across the app.',
                  children: [_RoleSwitcher()],
                ),
                const SizedBox(height: AppSpacing.lg),
                _SectionCard(
                  title: 'PERMISSIONS OVERVIEW',
                  children: const [_PermissionsTable()],
                ),
                const SizedBox(height: AppSpacing.lg),
                _SectionCard(
                  title: 'TRIP TEMPLATES',
                  subtitle: 'Create and manage reusable task templates for new trips.',
                  children: [_TemplatesSection()],
                ),
                const SizedBox(height: AppSpacing.lg),
                _SectionCard(
                  title: 'DEMO DATA',
                  subtitle: 'Populate your workspace with sample trips, tasks, suppliers, budget items, and itinerary for testing.',
                  children: const [_SeedSection()],
                ),
                const SizedBox(height: AppSpacing.lg),
                _SectionCard(
                  title: 'AI ASSISTANT',
                  subtitle: 'Connect an Anthropic API key to enable AI-powered suggestions, itinerary drafting, and trip analysis.',
                  children: const [_AiSection()],
                ),
                const SizedBox(height: AppSpacing.lg),
                _SectionCard(
                  title: 'APP',
                  children: const [_AppInfoSection()],
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _SettingsHeader extends StatelessWidget {
  final double hPad;
  const _SettingsHeader({required this.hPad});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Settings', style: AppTextStyles.displayMedium),
          Text('Team, roles, and app configuration',
              style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }
}

// ── Section card ──────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.base, AppSpacing.base,
                AppSpacing.base, AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.overline),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitle!,
                      style: AppTextStyles.labelSmall
                          .copyWith(color: AppColors.textSecondary)),
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          ...children,
        ],
      ),
    );
  }
}

// ── Team section ──────────────────────────────────────────────────────────────

class _TeamSection extends StatefulWidget {
  @override
  State<_TeamSection> createState() => _TeamSectionState();
}

class _TeamSectionState extends State<_TeamSection> {
  List<TeamMember> _members = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repos  = AppRepositories.instance;
    final teamId = repos?.currentTeamId;
    if (repos == null || teamId == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final members = await repos.teams.fetchMembers(teamId);
      if (mounted) setState(() { _members = members; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _changeRole(TeamMember member, AppRole newRole) async {
    final repos  = AppRepositories.instance;
    final teamId = repos?.currentTeamId;
    if (repos == null || teamId == null) return;
    try {
      await repos.teams.updateMemberRole(
        teamId: teamId,
        userId: member.userId,
        role:   newRole,
      );
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update role.')),
        );
      }
    }
  }

  Future<void> _removeMember(TeamMember member) async {
    final repos  = AppRepositories.instance;
    final teamId = repos?.currentTeamId;
    if (repos == null || teamId == null) return;

    final name = member.profile?.name ?? 'this member';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius)),
        title: Text('Remove $name?', style: AppTextStyles.heading3),
        content: Text(
          'They will lose access to this team immediately.',
          style: AppTextStyles.bodySmall
              .copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
                foregroundColor: AppColors.statusBlockedText),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await repos.teams.deactivateMember(
        teamId: teamId,
        userId: member.userId,
      );
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not remove member.')),
        );
      }
    }
  }

  Future<void> _editName(TeamMember member) async {
    final repos = AppRepositories.instance;
    if (repos == null) return;

    final current = member.profile?.name ?? '';
    final ctrl    = TextEditingController(text: current);

    final newName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius)),
        title: Text('Edit display name', style: AppTextStyles.heading3),
        content: TextField(
          controller: ctrl,
          autofocus:  true,
          style:      AppTextStyles.bodyMedium,
          decoration: InputDecoration(
            hintText: 'Full name',
            hintStyle: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textMuted),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.md),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
              borderSide:
                  const BorderSide(color: AppColors.accent, width: 1.5),
            ),
            filled:    true,
            fillColor: AppColors.surface,
          ),
          onSubmitted: (v) => Navigator.pop(context, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppSpacing.buttonRadius)),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (newName == null || newName.isEmpty || newName == current) return;

    try {
      // Direct update — no pre-fetch required.
      // Requires an RLS policy that allows the caller to UPDATE this row.
      // Run this in Supabase SQL editor if admins need to edit others' names:
      //   create policy "Admins can update member profiles" on profiles
      //     for update using (
      //       exists (
      //         select 1 from team_members a
      //         join team_members t on a.team_id = t.team_id
      //         where a.user_id = auth.uid() and a.role = 'admin'
      //           and a.is_active = true
      //           and t.user_id = profiles.id and t.is_active = true
      //       )
      //     );
      await db
          .from('profiles')
          .update({'full_name': newName})
          .eq('id', member.userId);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Name updated to "$newName".'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not update name: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.statusBlockedText,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rs = RoleScope.of(context);

    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.base),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_members.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.base),
        child: Text('No team members found.',
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textMuted)),
      );
    }

    return ListenableBuilder(
      listenable: rs,
      builder: (context, _) {
        final isAdmin   = rs.role == AppRole.admin;
        final currentId = rs.user.id;
        return Column(
          children: _members.map((m) {
            final user = m.profile ??
                AppUser(
                  id:          m.userId,
                  name:        m.userId,
                  initials:    '?',
                  avatarColor: avatarColorFor(0),
                  role:        m.role.label,
                  appRole:     m.role,
                );
            final isMe = m.userId == currentId;
            return _TeamMemberRow(
              member:        m,
              user:          user,
              isCurrentUser: isMe,
              isAdmin:       isAdmin,
              onChangeRole:  isAdmin
                  ? (r) => _changeRole(m, r)
                  : null,
              onRemove:      isAdmin && !isMe
                  ? () => _removeMember(m)
                  : null,
              onEditName:    (isAdmin || isMe)
                  ? () => _editName(m)
                  : null,
            );
          }).toList(),
        );
      },
    );
  }
}

class _TeamMemberRow extends StatelessWidget {
  final TeamMember             member;
  final AppUser                user;
  final bool                   isCurrentUser;
  final bool                   isAdmin;
  final ValueChanged<AppRole>? onChangeRole;
  final VoidCallback?          onRemove;
  final VoidCallback?          onEditName;

  const _TeamMemberRow({
    required this.member,
    required this.user,
    required this.isCurrentUser,
    required this.isAdmin,
    this.onChangeRole,
    this.onRemove,
    this.onEditName,
  });

  @override
  Widget build(BuildContext context) {
    final canDoAnything = onChangeRole != null ||
        onRemove != null ||
        onEditName != null;

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base, vertical: AppSpacing.md),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          UserAvatar(user: user, size: 36),
          const SizedBox(width: AppSpacing.md),

          // Name + role label
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(user.name,
                        style: AppTextStyles.bodyMedium
                            .copyWith(fontWeight: FontWeight.w500)),
                    if (isCurrentUser) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accentLight,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('You',
                            style: AppTextStyles.labelSmall.copyWith(
                                color: AppColors.accentDark,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ],
                ),
                Text(user.role, style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),

          // Role badge — tappable dropdown when admin
          if (onChangeRole != null)
            PopupMenuButton<AppRole>(
              initialValue: user.appRole,
              onSelected:   onChangeRole,
              tooltip:      'Change role',
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              itemBuilder: (_) => AppRole.values.map((r) {
                final active = r == user.appRole;
                return PopupMenuItem(
                  value: r,
                  child: Row(
                    children: [
                      RoleBadge(role: r),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(r.description,
                            style: AppTextStyles.labelSmall.copyWith(
                                color: AppColors.textSecondary)),
                      ),
                      if (active)
                        const Icon(Icons.check_rounded,
                            size: 13, color: AppColors.accent),
                    ],
                  ),
                );
              }).toList(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RoleBadge(role: user.appRole),
                  const SizedBox(width: 2),
                  const Icon(Icons.keyboard_arrow_down_rounded,
                      size: 14, color: AppColors.textMuted),
                ],
              ),
            )
          else
            RoleBadge(role: user.appRole),

          // Three-dot overflow menu
          if (canDoAnything) ...[
            const SizedBox(width: AppSpacing.sm),
            PopupMenuButton<_MemberAction>(
              onSelected: (action) {
                switch (action) {
                  case _MemberAction.editName:
                    onEditName?.call();
                  case _MemberAction.remove:
                    onRemove?.call();
                }
              },
              tooltip:  'More options',
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              icon: const Icon(Icons.more_vert_rounded,
                  size: 18, color: AppColors.textMuted),
              itemBuilder: (_) => [
                if (onEditName != null)
                  const PopupMenuItem(
                    value: _MemberAction.editName,
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined,
                            size: 15, color: AppColors.textSecondary),
                        SizedBox(width: 10),
                        Text('Edit name'),
                      ],
                    ),
                  ),
                if (onRemove != null)
                  PopupMenuItem(
                    value: _MemberAction.remove,
                    child: Row(
                      children: [
                        Icon(Icons.person_remove_outlined,
                            size: 15, color: AppColors.statusBlockedText),
                        const SizedBox(width: 10),
                        Text('Remove from team',
                            style: TextStyle(
                                color: AppColors.statusBlockedText)),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

enum _MemberAction { editName, remove }

// ── Role switcher ─────────────────────────────────────────────────────────────

class _RoleSwitcher extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final rs = RoleScope.of(context);
    return ListenableBuilder(
      listenable: rs,
      builder: (context, _) {
        return Column(
          children: AppRole.values.map((role) {
            final isActive = rs.role == role;
            return GestureDetector(
              onTap: () => rs.switchRole(role),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.base, vertical: AppSpacing.md),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.accentFaint : Colors.transparent,
                  border: const Border(
                      bottom: BorderSide(color: AppColors.divider)),
                ),
                child: Row(
                  children: [
                    RoleBadge(role: role),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(role.description,
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textSecondary)),
                    ),
                    if (isActive)
                      const Icon(Icons.check_rounded,
                          size: 16, color: AppColors.accent),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// ── Permissions overview ──────────────────────────────────────────────────────

class _PermissionsTable extends StatelessWidget {
  const _PermissionsTable();

  static const _permissions = [
    ('View all modules', true, true, true, true),
    ('Approve tasks & itinerary', true, true, false, false),
    ('Approve cost items', true, false, false, true),
    ('Edit pricing & markup', true, false, false, true),
    ('Manage suppliers', true, true, false, false),
    ('Manage team & settings', true, false, false, false),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        _PermRow(
          label: 'Permission',
          admin: 'Admin',
          tripLead: 'Trip Lead',
          staff: 'Staff',
          finance: 'Finance',
          isHeader: true,
        ),
        ..._permissions.map((p) => _PermRow(
              label: p.$1,
              admin: p.$2 ? '✓' : '–',
              tripLead: p.$3 ? '✓' : '–',
              staff: p.$4 ? '✓' : '–',
              finance: p.$5 ? '✓' : '–',
              adminTick: p.$2,
              tripLeadTick: p.$3,
              staffTick: p.$4,
              financeTick: p.$5,
            )),
      ],
    );
  }
}

class _PermRow extends StatelessWidget {
  final String label;
  final String admin;
  final String tripLead;
  final String staff;
  final String finance;
  final bool isHeader;
  final bool adminTick;
  final bool tripLeadTick;
  final bool staffTick;
  final bool financeTick;

  const _PermRow({
    required this.label,
    required this.admin,
    required this.tripLead,
    required this.staff,
    required this.finance,
    this.isHeader = false,
    this.adminTick = false,
    this.tripLeadTick = false,
    this.staffTick = false,
    this.financeTick = false,
  });

  @override
  Widget build(BuildContext context) {
    final labelStyle = isHeader
        ? AppTextStyles.overline
        : AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary);

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base, vertical: AppSpacing.sm),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: labelStyle)),
          _Cell(admin, isHeader: isHeader, tick: adminTick),
          _Cell(tripLead, isHeader: isHeader, tick: tripLeadTick),
          _Cell(staff, isHeader: isHeader, tick: staffTick),
          _Cell(finance, isHeader: isHeader, tick: financeTick),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  final String text;
  final bool isHeader;
  final bool tick;

  const _Cell(this.text, {this.isHeader = false, this.tick = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      child: Center(
        child: isHeader
            ? Text(text, style: AppTextStyles.overline)
            : Icon(
                tick ? Icons.check_rounded : Icons.remove_rounded,
                size: 14,
                color: tick ? AppColors.statusDoneText : AppColors.textMuted,
              ),
      ),
    );
  }
}

// ── Add member section ────────────────────────────────────────────────────────

class _AddMemberSection extends StatefulWidget {
  const _AddMemberSection();

  @override
  State<_AddMemberSection> createState() => _AddMemberSectionState();
}

class _AddMemberSectionState extends State<_AddMemberSection> {
  final _emailCtrl = TextEditingController();
  AppRole _role    = AppRole.staff;
  bool _busy       = false;
  String _status   = '';
  bool _isError    = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _addMember() async {
    final email  = _emailCtrl.text.trim().toLowerCase();
    if (email.isEmpty) return;

    final repos  = AppRepositories.instance;
    final teamId = repos?.currentTeamId;
    if (repos == null || teamId == null) {
      setState(() { _status = 'Not signed in or no team.'; _isError = true; });
      return;
    }

    setState(() { _busy = true; _status = 'Looking up user…'; _isError = false; });

    try {
      // Find the profile by email
      final rows = await db
          .from('profiles')
          .select('id, full_name')
          .eq('email', email)
          .limit(1) as List;

      if (rows.isEmpty) {
        setState(() {
          _status = 'No profile found for $email. Ask them to sign in to the app once first.';
          _isError = true;
          _busy = false;
        });
        return;
      }

      final userId   = (rows.first as Map<String, dynamic>)['id'] as String;
      final fullName = (rows.first as Map<String, dynamic>)['full_name'] as String? ?? email;

      await repos.teams.addMember(teamId: teamId, userId: userId, role: _role);

      if (mounted) {
        setState(() {
          _status  = '$fullName added to the team as ${_role.label}.';
          _isError = false;
          _busy    = false;
        });
        _emailCtrl.clear();
      }
    } catch (e) {
      if (mounted) {
        setState(() { _status = 'Failed: $e'; _isError = true; _busy = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style: AppTextStyles.bodyMedium,
                  decoration: InputDecoration(
                    hintText: 'colleague@houseofdreammaker.com',
                    hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: AppSpacing.md),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                      borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
                    ),
                    filled: true,
                    fillColor: AppColors.surface,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              DropdownButton<AppRole>(
                value: _role,
                underline: const SizedBox(),
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
                items: const [
                  DropdownMenuItem(value: AppRole.admin,    child: Text('Admin')),
                  DropdownMenuItem(value: AppRole.tripLead, child: Text('Trip Lead')),
                  DropdownMenuItem(value: AppRole.staff,    child: Text('Staff')),
                  DropdownMenuItem(value: AppRole.finance,  child: Text('Finance')),
                ],
                onChanged: _busy ? null : (v) { if (v != null) setState(() => _role = v); },
              ),
              const SizedBox(width: AppSpacing.sm),
              FilledButton(
                onPressed: _busy ? null : _addMember,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
                  ),
                ),
                child: Text(_busy ? 'Adding…' : 'Add'),
              ),
            ],
          ),
          if (_status.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _status,
              style: AppTextStyles.bodySmall.copyWith(
                color: _isError ? AppColors.statusBlockedText : AppColors.statusDoneText,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Seed section ─────────────────────────────────────────────────────────────

// ── Templates section ─────────────────────────────────────────────────────────

class _TemplatesSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.base),
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const TemplateManagerScreen(),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.content_copy_outlined,
                  size: 15, color: Colors.white),
              const SizedBox(width: 6),
              Text('Manage Templates',
                  style: AppTextStyles.labelMedium
                      .copyWith(color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Seed section ──────────────────────────────────────────────────────────────

class _SeedSection extends StatefulWidget {
  const _SeedSection();

  @override
  State<_SeedSection> createState() => _SeedSectionState();
}

class _SeedSectionState extends State<_SeedSection> {
  bool   _busy     = false;
  String _status   = '';
  bool   _isError  = false;
  bool   _done     = false;

  Future<void> _clearAndSeed() async {
    setState(() { _busy = true; _status = 'Clearing existing data…'; _isError = false; _done = false; });

    bool cleared = true;
    await SeedService.clearAll(
      onProgress: (msg) { if (mounted) setState(() => _status = msg); },
      onError: (err) {
        cleared = false;
        if (mounted) setState(() { _status = err; _isError = true; _busy = false; });
      },
    );
    if (!cleared || !mounted) return;

    setState(() => _status = 'Starting seed…');
    await SeedService.seed(
      onProgress: (msg) { if (mounted) setState(() => _status = msg); },
      onError: (err) {
        if (mounted) setState(() { _status = err; _isError = true; _busy = false; });
      },
    );

    if (mounted && !_isError) setState(() { _busy = false; _done = true; });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Loads 5 trips, 16 tasks, 18 suppliers, 20 cost items, and a full '
            'itinerary for the Amalfi & Sicily trip. Clears any existing team data first.',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.base),
          if (_status.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.base),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                color: _isError
                    ? AppColors.statusBlockedText.withAlpha(20)
                    : _done
                        ? AppColors.statusDone
                        : AppColors.surfaceAlt,
                border: Border.all(
                  color: _isError
                      ? AppColors.statusBlockedText
                      : _done
                          ? AppColors.statusDoneText
                          : AppColors.border,
                ),
                borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
              ),
              child: Row(
                children: [
                  if (_busy)
                    const SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.accent),
                    ),
                  if (_busy) const SizedBox(width: AppSpacing.sm),
                  if (_done)
                    const Icon(Icons.check_circle_outline_rounded,
                        size: 16, color: AppColors.statusDoneText),
                  if (_done) const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      _status,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: _isError
                            ? AppColors.statusBlockedText
                            : _done
                                ? AppColors.statusDoneText
                                : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          FilledButton.icon(
            onPressed: _busy ? null : _clearAndSeed,
            icon: const Icon(Icons.upload_rounded, size: 16),
            label: Text(_busy ? 'Working…' : 'Load Demo Data'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── AI section ────────────────────────────────────────────────────────────────

class _AiSection extends StatefulWidget {
  const _AiSection();

  @override
  State<_AiSection> createState() => _AiSectionState();
}

class _AiSectionState extends State<_AiSection> {
  final _keyCtrl   = TextEditingController();
  final _modelCtrl = TextEditingController();
  bool _obscure    = true;
  bool _busy       = false;
  String _status   = '';
  bool _isError    = false;
  bool _isSuccess  = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    _modelCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final stored = await AiKeyStore.read();
    if (!mounted) return;
    if (stored != null && stored.isNotEmpty) {
      _keyCtrl.text = stored;
    }
    _modelCtrl.text = AiConfig.instance.model;
    setState(() {});
  }

  Future<void> _save() async {
    final key   = _keyCtrl.text.trim();
    final model = _modelCtrl.text.trim();
    if (key.isEmpty) {
      setState(() { _status = 'Please enter an API key.'; _isError = true; _isSuccess = false; });
      return;
    }
    setState(() { _busy = true; _status = ''; _isError = false; _isSuccess = false; });
    try {
      await AiKeyStore.save(apiKey: key, model: model.isEmpty ? null : model);
      if (mounted) {
        setState(() {
          _busy      = false;
          _status    = 'API key saved. AI suggestions are now active.';
          _isError   = false;
          _isSuccess = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _busy = false; _status = 'Failed to save: $e'; _isError = true; _isSuccess = false; });
      }
    }
  }

  Future<void> _clear() async {
    setState(() { _busy = true; _status = ''; _isError = false; _isSuccess = false; });
    try {
      await AiKeyStore.clear();
      if (mounted) {
        _keyCtrl.clear();
        _modelCtrl.clear();
        setState(() {
          _busy      = false;
          _status    = 'API key removed. AI features are disabled.';
          _isError   = false;
          _isSuccess = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _busy = false; _status = 'Failed to clear: $e'; _isError = true; _isSuccess = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConfigured = AiConfig.instance.isConfigured;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isConfigured
                      ? const Color(0xFFD2F5E4)
                      : const Color(0xFFF1F0EE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isConfigured
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 12,
                      color: isConfigured
                          ? const Color(0xFF065F46)
                          : AppColors.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isConfigured ? 'Connected' : 'Not configured',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: isConfigured
                            ? const Color(0xFF065F46)
                            : AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.base),

          // API Key field
          Text('Anthropic API Key',
              style: AppTextStyles.labelMedium
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _keyCtrl,
            obscureText: _obscure,
            style: AppTextStyles.bodyMedium
                .copyWith(fontFamily: 'monospace'),
            decoration: InputDecoration(
              hintText: 'sk-ant-api03-…',
              hintStyle: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textMuted),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.md),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                borderSide:
                    const BorderSide(color: AppColors.accent, width: 1.5),
              ),
              filled: true,
              fillColor: AppColors.surface,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  size: 18,
                  color: AppColors.textMuted,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Model field (optional)
          Text('Model (optional)',
              style: AppTextStyles.labelMedium
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _modelCtrl,
            style: AppTextStyles.bodyMedium,
            decoration: InputDecoration(
              hintText: 'claude-haiku-4-5-20251001 (default)',
              hintStyle: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textMuted),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.md),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                borderSide:
                    const BorderSide(color: AppColors.accent, width: 1.5),
              ),
              filled: true,
              fillColor: AppColors.surface,
            ),
          ),
          const SizedBox(height: AppSpacing.base),

          // Buttons
          Row(
            children: [
              FilledButton(
                onPressed: _busy ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
                  ),
                ),
                child: Text(_busy ? 'Saving…' : 'Save Key'),
              ),
              if (isConfigured) ...[
                const SizedBox(width: AppSpacing.sm),
                OutlinedButton(
                  onPressed: _busy ? null : _clear,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.statusBlockedText,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.buttonRadius),
                    ),
                  ),
                  child: const Text('Remove Key'),
                ),
              ],
            ],
          ),

          // Status message
          if (_status.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _status,
              style: AppTextStyles.bodySmall.copyWith(
                color: _isError
                    ? AppColors.statusBlockedText
                    : _isSuccess
                        ? AppColors.statusDoneText
                        : AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── App info ──────────────────────────────────────────────────────────────────

class _AppInfoSection extends StatelessWidget {
  const _AppInfoSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _InfoRow(label: 'App',      value: 'HOD Travel Management'),
        _InfoRow(label: 'Backend',  value: 'Supabase'),
        _InfoRow(label: 'Team ID',  value: AppRepositories.instance?.currentTeamId ?? '—'),
        _InfoRow(label: 'Platform', value: 'Flutter Web & Desktop'),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base, vertical: AppSpacing.md),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          SizedBox(
              width: 120,
              child: Text(label,
                  style: AppTextStyles.labelMedium
                      .copyWith(color: AppColors.textSecondary))),
          Expanded(child: Text(value, style: AppTextStyles.bodySmall)),
        ],
      ),
    );
  }
}
