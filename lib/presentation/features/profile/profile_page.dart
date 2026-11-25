import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ubsoft_pdks/application/auth/auth_controller.dart';
import 'package:ubsoft_pdks/application/auth/session_provider.dart';
import 'package:ubsoft_pdks/core/config/company_info.dart';
import 'package:ubsoft_pdks/core/extensions/context_x.dart';
import 'package:ubsoft_pdks/core/routing/app_routes.dart';
import 'package:ubsoft_pdks/core/theme/app_colors.dart';
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
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        color: AppColors.primarySurface,
                        borderRadius: AppRadius.allMd,
                      ),
                      child: const Icon(
                        Icons.person_outline_rounded,
                        size: 28,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            user.displayName,
                            style: AppTypography.h2(context.colors.onSurface),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user.email,
                            style: AppTypography.small(
                              context.colors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          StatusChip(
                            label: user.role.label,
                            tone: StatusTone.info,
                            compact: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 28),
                if (tenant != null)
                  _InfoRow(
                    icon: Icons.apartment_outlined,
                    label: 'Yurt',
                    value: tenant.name,
                  ),
                if (user.studentNumber.isNotEmpty)
                  _InfoRow(
                    icon: Icons.badge_outlined,
                    label: 'Öğrenci no',
                    value: user.studentNumber,
                  ),
                if (user.room.isNotEmpty)
                  _InfoRow(
                    icon: Icons.meeting_room_outlined,
                    label: 'Oda',
                    value: user.room,
                  ),
                if ((user.note ?? '').isNotEmpty)
                  _InfoRow(
                    icon: Icons.info_outline_rounded,
                    label: 'Açıklama',
                    value: user.note!,
                  ),
                if ((user.phone ?? '').isNotEmpty)
                  _InfoRow(
                    icon: Icons.phone_outlined,
                    label: 'Telefon',
                    value: user.phone!,
                  ),
                if (user.lastLoginAt case final DateTime value)
                  _InfoRow(
                    icon: Icons.access_time_rounded,
                    label: 'Son giriş',
                    value: AppDate.dateTime(value),
                  ),
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
                const Divider(height: 1),
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
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 17, color: context.colors.onSurfaceVariant),
          const SizedBox(width: 10),
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: AppTypography.small(context.colors.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.bodyStrong(
                context.colors.onSurface,
              ).copyWith(fontSize: 13.5),
            ),
          ),
        ],
      ),
    );
  }
}
