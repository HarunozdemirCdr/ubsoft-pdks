import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ubsoft_pdks/application/auth/auth_controller.dart';
import 'package:ubsoft_pdks/core/result/result.dart';
import 'package:ubsoft_pdks/core/routing/app_routes.dart';
import 'package:ubsoft_pdks/core/theme/app_spacing.dart';
import 'package:ubsoft_pdks/core/utils/validators.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_button.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_scaffold.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_text_field.dart';
import 'package:ubsoft_pdks/presentation/widgets/info_hint.dart';
import 'package:ubsoft_pdks/presentation/widgets/section_header.dart';
import 'package:ubsoft_pdks/services/notification/toast_service.dart';

/// Kullanıcının kendi şifresini değiştirmesi.
class ChangePasswordPage extends ConsumerStatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  ConsumerState<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends ConsumerState<ChangePasswordPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _current = TextEditingController();
  final TextEditingController _next = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  bool _busy = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    setState(() => _busy = true);
    final Result<void> result = await ref
        .read(authControllerProvider.notifier)
        .changePassword(
          currentPassword: _current.text,
          newPassword: _next.text,
        );

    if (!mounted) return;
    setState(() => _busy = false);

    Toast.result(result, successMessage: 'Şifreniz değiştirildi.');
    if (result.isOk) context.go(AppRoutes.profile);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Şifre Değiştir',
      showBackButton: true,
      scrollable: true,
      maxContentWidth: AppWidths.narrow,
      bottomBar: AppButton.primaryWide(
        label: 'Şifreyi değiştir',
        isLoading: _busy,
        onPressed: _submit,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppSpacing.vLg,
            const SectionHeader(
              title: 'Yeni şifre',
              dense: true,
              description:
                  'Güvenlik için mevcut şifreniz de sorulur; oturumunuz '
                  'uzun süredir açıksa Firebase bunu şart koşar.',
            ),
            AppSpacing.vLg,

            AppPasswordField(
              label: 'Mevcut şifre',
              controller: _current,
              validator: (String? v) =>
                  Validators.required(v, field: 'Mevcut şifre'),
            ),
            AppSpacing.vMd,
            AppPasswordField(
              label: 'Yeni şifre',
              controller: _next,
              validator: Validators.password,
            ),
            AppSpacing.vMd,
            AppPasswordField(
              label: 'Yeni şifre (tekrar)',
              controller: _confirm,
              validator: (String? v) =>
                  Validators.passwordConfirm(v, _next.text),
            ),
            AppSpacing.vLg,
            const InfoNote(
              message:
                  'Şifrenizi unutursanız giriş ekranındaki "Şifremi unuttum" '
                  'bağlantısını kullanabilir ya da yöneticinizden sıfırlama '
                  'bağlantısı isteyebilirsiniz.',
            ),
            AppSpacing.vXl,
          ],
        ),
      ),
    );
  }
}
