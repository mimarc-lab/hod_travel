import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../providers/auth_provider.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final AuthProvider authProvider;
  const ForgotPasswordScreen({super.key, required this.authProvider});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _loading = false;
  bool _sent    = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    final ok = await widget.authProvider.sendPasswordReset(_emailCtrl.text.trim());
    if (mounted) setState(() { _loading = false; _sent = ok; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: BackButton(color: AppColors.textSecondary),
        title: Text('Reset Password', style: AppTextStyles.heading3),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                border: Border.all(color: AppColors.border),
              ),
              child: _sent ? _SuccessState() : _FormState(
                formKey:   _formKey,
                emailCtrl: _emailCtrl,
                loading:   _loading,
                onSubmit:  _submit,
                error:     widget.authProvider.errorMessage,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FormState extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl;
  final bool loading;
  final VoidCallback onSubmit;
  final String? error;

  const _FormState({
    required this.formKey,
    required this.emailCtrl,
    required this.loading,
    required this.onSubmit,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Forgot your password?', style: AppTextStyles.displayMedium),
          const SizedBox(height: 4),
          Text(
            'Enter your email and we\'ll send a reset link.',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: AppSpacing.xl),
          TextFormField(
            controller: emailCtrl,
            keyboardType: TextInputType.emailAddress,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'you@hodtravel.com',
              hintStyle: AppTextStyles.bodySmall,
              filled: true,
              fillColor: AppColors.surfaceAlt,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.base, vertical: 12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                  borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                  borderSide: const BorderSide(color: AppColors.border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                  borderSide:
                      const BorderSide(color: AppColors.accent, width: 1.5)),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Email is required';
              if (!v.contains('@')) return 'Enter a valid email';
              return null;
            },
          ),
          if (error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(error!,
                style: AppTextStyles.labelSmall
                    .copyWith(color: const Color(0xFF991B1B))),
          ],
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            height: 44,
            child: ElevatedButton(
              onPressed: loading ? null : onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppSpacing.buttonRadius)),
              ),
              child: loading
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : Text('Send reset link',
                      style: AppTextStyles.labelMedium
                          .copyWith(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuccessState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.mark_email_read_outlined,
            size: 48, color: AppColors.accent),
        const SizedBox(height: AppSpacing.base),
        Text('Check your inbox', style: AppTextStyles.heading2),
        const SizedBox(height: 6),
        Text(
          'A password reset link has been sent to your email address.',
          style: AppTextStyles.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xl),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppSpacing.buttonRadius)),
            ),
            child: Text('Back to sign in',
                style: AppTextStyles.labelMedium),
          ),
        ),
      ],
    );
  }
}
