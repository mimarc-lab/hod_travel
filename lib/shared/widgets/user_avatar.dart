import 'package:flutter/material.dart';
import '../../core/constants/app_text_styles.dart';
import '../../data/models/user_model.dart';

class UserAvatar extends StatelessWidget {
  final AppUser user;
  final double size;

  const UserAvatar({super.key, required this.user, this.size = 28});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: user.avatarColor,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          user.initials,
          style: AppTextStyles.labelSmall.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: size * 0.32,
          ),
        ),
      ),
    );
  }
}
