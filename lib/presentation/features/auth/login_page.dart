import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ubsoft_pdks/application/auth/auth_controller.dart';
import 'package:ubsoft_pdks/core/config/app_config.dart';
import 'package:ubsoft_pdks/core/config/company_info.dart';
import 'package:ubsoft_pdks/core/error/failure.dart';
import 'package:ubsoft_pdks/core/extensions/context_x.dart';
import 'package:ubsoft_pdks/core/routing/app_routes.dart';
import 'package:ubsoft_pdks/core/theme/app_colors.dart';
import 'package:ubsoft_pdks/core/theme/app_radius.dart';
import 'package:ubsoft_pdks/core/theme/app_spacing.dart';
import 'package:ubsoft_pdks/core/theme/app_typography.dart';
import 'package:ubsoft_pdks/core/utils/validators.dart';
import 'package:ubsoft_pdks/presentation/features/auth/widgets/auth_layout.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_button.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_text_field.dart';

/// Kurumsal giriş ekranı.
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
    final bool isDark = context.isDark;

    return AuthLayout(
      icon: Icons.verified_user_outlined,
      badgeText: 'GÜVENLİ KURUMSAL GİRİŞ',
      title: AppConfig.appName,
      subtitle: 'Kurumsal öğrenci takip ve turnike yönetim platformu',
      cardTitle: 'Hoş Geldiniz',
      cardSubtitle: 'Devam etmek için kurumsal hesap bilgilerinizle giriş yapın.',
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            '${CompanyInfo.legalName} · ${CompanyInfo.displayVersion}',
            textAlign: TextAlign.center,
            style: AppTypography.caption(context.colors.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            CompanyInfo.website,
            textAlign: TextAlign.center,
            style: AppTypography.caption(
              context.colors.onSurfaceVariant.withValues(alpha: 0.8),
            ),
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
                label: 'Kurumsal E-posta',
                controller: _email,
                hint: 'ad.soyad@ubs.com',
                validator: Validators.email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                prefixIcon: Icons.mail_outline_rounded,
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
                label: 'Güvenli Giriş Yap',
                icon: Icons.login_rounded,
                onPressed: _submit,
                isLoading: state.isSubmitting,
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.surfaceAltDark
                      : AppColors.surfaceAlt,
                  borderRadius: AppRadius.allSm,
                  border: Border.all(
                    color: isDark ? AppColors.borderDark : AppColors.border,
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: isDark
                          ? AppColors.primaryOnDark
                          : AppColors.primary,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Yönetici ve öğrenci hesapları aynı ekrandan otomatik olarak ilgili panele yönlendirilir.',
                        style: AppTypography.caption(
                          context.colors.onSurfaceVariant,
                        ).copyWith(height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Center(
                child: AppButton(
                  label: 'KVKK Aydınlatma Metni',
                  icon: Icons.gavel_outlined,
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
