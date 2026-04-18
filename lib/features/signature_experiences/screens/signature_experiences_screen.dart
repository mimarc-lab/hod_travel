import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/supabase/app_db.dart';
import '../../../core/utils/responsive.dart';
import '../../../data/models/signature_experience.dart';
import '../../../shared/widgets/app_header.dart';
import '../../../shared/widgets/empty_state.dart';
import '../providers/signature_experience_provider.dart';
import '../widgets/signature_experience_card.dart';
import '../widgets/signature_experience_filter_bar.dart';
import 'signature_experience_detail_screen.dart';
import 'signature_experience_form_screen.dart';

class SignatureExperiencesScreen extends StatefulWidget {
  const SignatureExperiencesScreen({super.key});

  @override
  State<SignatureExperiencesScreen> createState() =>
      _SignatureExperiencesScreenState();
}

class _SignatureExperiencesScreenState
    extends State<SignatureExperiencesScreen> {
  late final SignatureExperienceProvider _provider;
  String _search = '';
  ExperienceStatus? _filterStatus;
  ExperienceCategory? _filterCategory;

  @override
  void initState() {
    super.initState();
    _provider = SignatureExperienceProvider(
      repository: AppRepositories.instance?.signatureExperiences,
      teamId: AppRepositories.instance?.currentTeamId ?? '',
    );
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  List<SignatureExperience> get _filtered {
    return _provider.experiences.where((e) {
      final q = _search.toLowerCase();
      final matchSearch = _search.isEmpty ||
          e.title.toLowerCase().contains(q) ||
          (e.shortDescriptionClient?.toLowerCase().contains(q) ?? false) ||
          (e.conceptSummary?.toLowerCase().contains(q) ?? false) ||
          e.tags.any((t) => t.toLowerCase().contains(q));
      final matchStatus = _filterStatus == null || e.status == _filterStatus;
      final matchCategory =
          _filterCategory == null || e.category == _filterCategory;
      return matchSearch && matchStatus && matchCategory;
    }).toList();
  }

  void _openCreate() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SignatureExperienceFormScreen(provider: _provider),
      ),
    );
  }

  void _openDetail(SignatureExperience e) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            SignatureExperienceDetailScreen(experience: e, provider: _provider),
      ),
    );
  }

  void _openEdit(SignatureExperience e) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SignatureExperienceFormScreen(
          provider: _provider,
          existing: e,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(SignatureExperience e) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete experience?'),
        content: Text(
          'This will permanently delete "${e.title}". This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = await _provider.delete(e.id);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final hPad = isMobile ? AppSpacing.pagePaddingHMobile : AppSpacing.pagePaddingH;
    final crossAxisCount = isMobile ? 1 : (MediaQuery.of(context).size.width > 1200 ? 3 : 2);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppHeader(
        title: 'Experience Library',
        showMenuButton: isMobile,
        onMenuTap: () => Scaffold.of(context).openDrawer(),
        actions: [_CreateButton(onTap: _openCreate)],
      ),
      body: ListenableBuilder(
        listenable: _provider,
        builder: (context, _) {
          if (_provider.isLoading && _provider.experiences.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(
                  color: AppColors.accent, strokeWidth: 2),
            );
          }

          if (_provider.error != null && _provider.experiences.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.wifi_off_rounded,
                      size: 40, color: AppColors.textMuted),
                  const SizedBox(height: AppSpacing.base),
                  Text(_provider.error!, style: AppTextStyles.bodySmall),
                  const SizedBox(height: AppSpacing.base),
                  GestureDetector(
                    onTap: _provider.reload,
                    child: Text('Retry',
                        style: AppTextStyles.labelMedium
                            .copyWith(color: AppColors.accent)),
                  ),
                ],
              ),
            );
          }

          final filtered = _filtered;

          return Padding(
            padding: EdgeInsets.symmetric(
              horizontal: hPad,
              vertical: AppSpacing.pagePaddingV,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Page title + count
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'DreamMaker Experiences',
                            style: AppTextStyles.displayMedium,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_provider.experiences.length} experiences in the library',
                            style: AppTextStyles.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),

                // Filters
                SignatureExperienceFilterBar(
                  search: _search,
                  onSearchChanged: (v) => setState(() => _search = v),
                  filterStatus: _filterStatus,
                  onStatusChanged: (s) => setState(() => _filterStatus = s),
                  filterCategory: _filterCategory,
                  onCategoryChanged: (c) => setState(() => _filterCategory = c),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Grid
                Expanded(
                  child: filtered.isEmpty
                      ? EmptyState(
                          icon: Icons.auto_awesome_outlined,
                          title: 'No experiences found',
                          subtitle: _search.isNotEmpty ||
                                  _filterStatus != null ||
                                  _filterCategory != null
                              ? 'Try adjusting your search or filters.'
                              : 'Add your first DreamMaker experience to build the library.',
                          actionLabel: (_search.isEmpty &&
                                  _filterStatus == null &&
                                  _filterCategory == null)
                              ? 'Create Experience'
                              : null,
                          onAction: _openCreate,
                        )
                      : GridView.builder(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            mainAxisSpacing: AppSpacing.base,
                            crossAxisSpacing: AppSpacing.base,
                            childAspectRatio: 1.05,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) {
                            final e = filtered[i];
                            return SignatureExperienceCard(
                              experience: e,
                              onTap: () => _openDetail(e),
                              onEdit: () => _openEdit(e),
                              onDelete: () => _confirmDelete(e),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Create button ─────────────────────────────────────────────────────────────

class _CreateButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CreateButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.base, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              'New Experience',
              style: AppTextStyles.bodySmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
