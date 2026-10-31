import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ubsoft_pdks/application/auth/auth_controller.dart';
import 'package:ubsoft_pdks/core/config/app_config.dart';
import 'package:ubsoft_pdks/core/config/company_info.dart';
import 'package:ubsoft_pdks/core/error/failure.dart';
import 'package:ubsoft_pdks/core/extensions/context_x.dart';
import 'package:ubsoft_pdks/core/routing/app_routes.dart';
import 'package:ubsoft_pdks/core/theme/app_spacing.dart';
import 'package:ubsoft_pdks/core/theme/app_typography.dart';
import 'package:ubsoft_pdks/core/utils/validators.dart';
import 'package:ubsoft_pdks/presentation/features/auth/widgets/auth_layout.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_button.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_text_field.dart';

/// Giriş ekranı.
///
/// Giriş başarılı olduğunda burada yönlendirme yapılmaz: oturum akışı
/// güncellenir ve `RouteGuard` kullanıcıyı rolüne uygun sayfaya taşır.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();
    await ref
        .read(authControllerProvider.notifier)
        .signIn(email: _email.text, password: _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final AuthFormState state = ref.watch(authControllerProvider);

    return AuthLayout(
      title: AppConfig.appName,
      subtitle: 'Öğrenci giriş-çıkış takibi',
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            CompanyInfo.legalName,
            textAlign: TextAlign.center,
            style: AppTypography.caption(context.colors.onSurfaceVariant),
          ),
          AppSpacing.vXxs,
          Text(
            CompanyInfo.displayVersion,
            textAlign: TextAlign.center,
            style: AppTypography.caption(context.colors.onSurfaceVariant),
          ),
        ],
      ),
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (state.failure case final Failure failure) ...<Widget>[
                AuthMessageBox(message: failure.message),
                AppSpacing.vMd,
              ],
              AppTextField(
                label: 'E-posta',
                controller: _email,
                hint: 'ogrenci@ornek.com',
                validator: Validators.email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                prefixIcon: Icons.alternate_email_rounded,
                autofillHints: const <String>[AutofillHints.email],
                onChanged: (_) =>
                    ref.read(authControllerProvider.notifier).clearMessages(),
                isRequired: true,
                autofocus: true,
              ),
              AppSpacing.vMd,
              AppPasswordField(
                label: 'Şifre',
                controller: _password,
                validator: Validators.password,
                textInputAction: TextInputAction.done,
                autofillHints: const <String>[AutofillHints.password],
                onSubmitted: (_) => _submit(),
              ),
              AppSpacing.vXs,
              Align(
                alignment: Alignment.centerRight,
                child: AppButton(
                  label: 'Şifremi unuttum',
                  onPressed: () => context.push(AppRoutes.forgotPassword),
                  variant: AppButtonVariant.text,
                  size: AppButtonSize.small,
                ),
              ),
              AppSpacing.vSm,
              AppButton.primaryWide(
                label: 'Giriş Yap',
                onPressed: _submit,
                isLoading: state.isSubmitting,
              ),
              // Aydınlatma metni giriş yapmadan da okunabilmeli: işten
              // ayrılmış bir öğrenci de haklarını görebilsin.
              AppSpacing.vSm,
              Center(
                child: AppButton(
                  label: 'KVKK Aydınlatma Metni',
                  onPressed: () => context.push(AppRoutes.privacy),
                  variant: AppButtonVariant.text,
                  size: AppButtonSize.small,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
