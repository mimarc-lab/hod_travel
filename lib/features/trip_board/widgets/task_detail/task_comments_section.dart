import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../data/models/task_comment_model.dart';
import '../../../../features/trip_board/providers/board_provider.dart';
import '../../../../shared/widgets/user_avatar.dart';
import 'task_info_section.dart';

class TaskCommentsSection extends StatelessWidget {
  final String taskId;
  final BoardProvider provider;

  const TaskCommentsSection({
    super.key,
    required this.taskId,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PanelSectionHeader(label: 'ACTIVITY & COMMENTS'),
        // Rebuild only this section when provider notifies
        ListenableBuilder(
          listenable: provider,
          builder: (context, _) {
            final items = provider.commentsFor(taskId);
            return Column(
              children: [
                if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.base),
                    child: Text(
                      'No activity yet. Add a comment below.',
                      style: AppTextStyles.bodySmall,
                    ),
                  )
                else
                  ...items.map((item) => _CommentItem(item: item)),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        _CommentComposer(
          onSubmit: (msg) => provider.addComment(taskId, msg),
        ),
      ],
    );
  }
}

// ── Individual comment / activity item ────────────────────────────────────────

class _CommentItem extends StatelessWidget {
  final TaskComment item;
  const _CommentItem({required this.item});

  @override
  Widget build(BuildContext context) {
    if (item.isActivity) return _ActivityLine(item: item);
    return _UserComment(item: item);
  }
}

/// System-generated activity line — compact, muted.
class _ActivityLine extends StatelessWidget {
  final TaskComment item;
  const _ActivityLine({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 2,
            height: 32,
            margin: const EdgeInsets.only(left: 11, right: 13),
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: AppTextStyles.bodySmall,
                    children: [
                      TextSpan(
                        text: item.author.name.split(' ').first,
                        style: AppTextStyles.bodySmall.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      TextSpan(text: ' · ${item.message}'),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(_formatTime(item.createdAt), style: AppTextStyles.labelSmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// User-typed comment — full card with avatar.
class _UserComment extends StatelessWidget {
  final TaskComment item;
  const _UserComment({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserAvatar(user: item.author, size: 26),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      item.author.name,
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(_formatTime(item.createdAt), style: AppTextStyles.labelSmall),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(item.message, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Comment composer ──────────────────────────────────────────────────────────

class _CommentComposer extends StatefulWidget {
  final void Function(String) onSubmit;
  const _CommentComposer({required this.onSubmit});

  @override
  State<_CommentComposer> createState() => _CommentComposerState();
}

class _CommentComposerState extends State<_CommentComposer> {
  final _ctrl = TextEditingController();
  bool _hasText = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_ctrl.text.trim().isEmpty) return;
    widget.onSubmit(_ctrl.text);
    _ctrl.clear();
    setState(() => _hasText = false);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: TextField(
            controller: _ctrl,
            maxLines: null,
            minLines: 1,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
            onChanged: (v) => setState(() => _hasText = v.trim().isNotEmpty),
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              hintText: 'Add a comment…',
              hintStyle: AppTextStyles.bodySmall,
              filled: true,
              fillColor: AppColors.surfaceAlt,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        AnimatedOpacity(
          opacity: _hasText ? 1.0 : 0.4,
          duration: const Duration(milliseconds: 150),
          child: GestureDetector(
            onTap: _hasText ? _submit : null,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _hasText ? AppColors.accent : AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.send_rounded,
                size: 16,
                color: _hasText ? Colors.white : AppColors.textMuted,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _formatTime(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1)  return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24)   return '${diff.inHours}h ago';
  if (diff.inDays < 7)     return '${diff.inDays}d ago';
  return '${time.day}/${time.month}/${time.year}';
}
