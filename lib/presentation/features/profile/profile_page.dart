import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ubsoft_pdks/application/auth/auth_controller.dart';
import 'package:ubsoft_pdks/application/auth/session_provider.dart';
import 'package:ubsoft_pdks/core/config/company_info.dart';
import 'package:ubsoft_pdks/core/extensions/context_x.dart';
import 'package:ubsoft_pdks/core/routing/app_routes.dart';
import 'package:ubsoft_pdks/core/theme/app_radius.dart';
import 'package:ubsoft_pdks/core/theme/app_spacing.dart';
import 'package:ubsoft_pdks/core/theme/app_typography.dart';
import 'package:ubsoft_pdks/core/utils/date_x.dart';
import 'package:ubsoft_pdks/domain/entities/app_user.dart';
import 'package:ubsoft_pdks/domain/entities/tenant.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_button.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_card.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_scaffold.dart';
import 'package:ubsoft_pdks/presentation/widgets/confirm_dialog.dart';
import 'package:ubsoft_pdks/presentation/widgets/section_header.dart';
import 'package:ubsoft_pdks/presentation/widgets/status_chip.dart';

/// Kullanıcının kendi hesabı: kim olduğu, şifre değişimi, çıkış.
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppUser? user = ref.watch(currentUserProvider);
    final Tenant? tenant = ref.watch(currentTenantProvider);

    if (user == null) {
      return const AppScaffold(
        title: 'Profil',
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return AppScaffold(
      title: 'Profil',
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppSpacing.vLg,
          Center(
            child: Column(
              children: <Widget>[
                Container(
                  width: 72,
                  height: 72,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: context.colors.primaryContainer,
                    borderRadius: AppRadius.allXl,
                  ),
                  child: Text(
                    user.initials,
                    style: AppTypography.h1(context.colors.primary),
                  ),
                ),
                AppSpacing.vMd,
                Text(
                  user.displayName,
                  style: AppTypography.h2(context.colors.onSurface),
                ),
                AppSpacing.vXxs,
                Text(
                  user.email,
                  style: AppTypography.small(context.colors.onSurfaceVariant),
                ),
                AppSpacing.vXs,
                StatusChip(label: user.role.label, tone: StatusTone.info),
              ],
            ),
          ),
          AppSpacing.vXl,

          AppCard(
            child: Column(
              children: <Widget>[
                if (tenant != null)
                  _InfoRow(label: 'Şirket', value: tenant.name),
                if ((user.note ?? '').isNotEmpty)
                  _InfoRow(label: 'Açıklama', value: user.note!),
                if ((user.phone ?? '').isNotEmpty)
                  _InfoRow(label: 'Telefon', value: user.phone!),
                if (user.lastLoginAt case final DateTime value)
                  _InfoRow(label: 'Son giriş', value: AppDate.dateTime(value)),
              ],
            ),
          ),
          AppSpacing.vLg,

          const SectionHeader(title: 'Hesap', dense: true),
          AppSpacing.vSm,
          AppCard(
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.lock_outline_rounded),
                  title: const Text('Şifremi değiştir'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  contentPadding: EdgeInsets.zero,
                  onTap: () => context.go(AppRoutes.changePasswordPath),
                ),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('KVKK aydınlatma metni'),
                  subtitle: const Text('Konum verisi nasıl işleniyor?'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  contentPadding: EdgeInsets.zero,
                  onTap: () => context.push(AppRoutes.privacy),
                ),
              ],
            ),
          ),
          AppSpacing.vLg,

          AppButton(
            label: 'Çıkış Yap',
            icon: Icons.logout_rounded,
            variant: AppButtonVariant.outline,
            expand: true,
            onPressed: () => _signOut(context, ref),
          ),

          AppSpacing.vXl,
          Text(
            '${CompanyInfo.legalName}\n${CompanyInfo.displayVersion}',
            textAlign: TextAlign.center,
            style: AppTypography.caption(context.colors.onSurfaceVariant),
          ),
          AppSpacing.vXl,
        ],
      ),
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final bool ok = await ConfirmDialog.show(
      context,
      title: 'Çıkış yapılsın mı?',
      message: 'Tekrar giriş yapmak için e-posta ve şifreniz gerekecek.',
      confirmLabel: 'Çıkış yap',
    );
    if (!ok) return;

    await ref.read(authControllerProvider.notifier).signOut();
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: AppTypography.small(context.colors.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.body(context.colors.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}
