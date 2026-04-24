import 'package:flutter/material.dart';
import '../../data/models/user_model.dart';
import 'user_avatar.dart';

/// Overlapping row of user avatars with an overflow badge.
class StackedAvatars extends StatelessWidget {
  final List<AppUser> users;
  final double size;
  final int maxVisible;
  final double overlap;

  const StackedAvatars({
    super.key,
    required this.users,
    this.size = 24,
    this.maxVisible = 3,
    this.overlap = 7,
  });

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) return const SizedBox.shrink();

    final visible = users.take(maxVisible).toList();
    final overflowCount = users.length - maxVisible;
    final itemCount = overflowCount > 0 ? visible.length + 1 : visible.length;
    const double border = 1.5;
    final totalWidth = size + (itemCount - 1) * (size - overlap) + border * 2;

    return SizedBox(
      width: totalWidth,
      height: size + border * 2,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (int i = 0; i < visible.length; i++)
            Positioned(
              left: i * (size - overlap) + border,
              top: border,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: border),
                ),
                child: UserAvatar(user: visible[i], size: size),
              ),
            ),
          if (overflowCount > 0)
            Positioned(
              left: visible.length * (size - overlap) + border,
              top: border,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: border),
                ),
                alignment: Alignment.center,
                child: Text(
                  '+$overflowCount',
                  style: TextStyle(
                    fontSize: size * 0.3,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
