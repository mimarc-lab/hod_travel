import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/responsive.dart';
import 'app_header.dart';

/// Clean placeholder for sections not yet built.
class PlaceholderScreen extends StatelessWidget {
  final String title;
  final IconData icon;

  const PlaceholderScreen({
    super.key,
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppHeader(
        title: title,
        showMenuButton: isMobile,
        onMenuTap: () => Scaffold.of(context).openDrawer(),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.accentFaint,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: AppColors.accent, size: 30),
            ),
            const SizedBox(height: 20),
            Text('$title coming soon', style: AppTextStyles.heading2),
            const SizedBox(height: 8),
            Text(
              'This section will be built in an upcoming phase.',
              style: AppTextStyles.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
