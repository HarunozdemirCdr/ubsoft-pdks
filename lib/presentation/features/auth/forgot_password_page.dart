import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ubsoft_pdks/application/auth/auth_controller.dart';
import 'package:ubsoft_pdks/core/error/failure.dart';
import 'package:ubsoft_pdks/core/routing/app_routes.dart';
import 'package:ubsoft_pdks/core/theme/app_spacing.dart';
import 'package:ubsoft_pdks/core/utils/validators.dart';
import 'package:ubsoft_pdks/presentation/features/auth/widgets/auth_layout.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_button.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_text_field.dart';

/// Şifre sıfırlama.
///
/// E-posta sistemde kayıtlı olmasa bile başarı mesajı gösterilir; aksi hâlde
/// bu ekran hangi adreslerin sistemde olduğunu öğrenmek için kullanılabilirdi.
class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    await ref
        .read(authControllerProvider.notifier)
        .sendPasswordReset(_email.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final AuthFormState state = ref.watch(authControllerProvider);
    final bool sent = state.infoMessage != null;

    return AuthLayout(
      icon: Icons.lock_reset_rounded,
      title: 'Şifremi Unuttum',
      subtitle: sent
          ? null
          : 'Kayıtlı e-posta adresinizi girin, sıfırlama bağlantısı '
                'gönderelim.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (state.failure case final Failure failure) ...<Widget>[
              AuthMessageBox(message: failure.message),
              AppSpacing.vMd,
            ],
            if (state.infoMessage case final String message) ...<Widget>[
              AuthMessageBox(message: message, isError: false),
              AppSpacing.vLg,
              AppButton.primaryWide(
                label: 'Giriş ekranına dön',
                onPressed: () => context.go(AppRoutes.login),
              ),
            ] else ...<Widget>[
              AppTextField(
                label: 'E-posta',
                controller: _email,
                hint: 'ornek@sirket.com',
                validator: Validators.email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                prefixIcon: Icons.alternate_email_rounded,
                onSubmitted: (_) => _submit(),
                onChanged: (_) =>
                    ref.read(authControllerProvider.notifier).clearMessages(),
                isRequired: true,
                autofocus: true,
              ),
              AppSpacing.vLg,
              AppButton.primaryWide(
                label: 'Bağlantı Gönder',
                onPressed: _submit,
                isLoading: state.isSubmitting,
              ),
              AppSpacing.vXs,
              AppButton(
                label: 'Vazgeç',
                onPressed: () => context.go(AppRoutes.login),
                variant: AppButtonVariant.text,
                expand: true,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
