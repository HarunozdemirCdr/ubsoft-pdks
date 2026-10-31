import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ubsoft_pdks/application/auth/session_provider.dart';
import 'package:ubsoft_pdks/application/user/user_providers.dart';
import 'package:ubsoft_pdks/core/extensions/context_x.dart';
import 'package:ubsoft_pdks/core/routing/app_routes.dart';
import 'package:ubsoft_pdks/core/theme/app_radius.dart';
import 'package:ubsoft_pdks/core/theme/app_spacing.dart';
import 'package:ubsoft_pdks/core/theme/app_typography.dart';
import 'package:ubsoft_pdks/domain/entities/app_user.dart';
import 'package:ubsoft_pdks/domain/entities/tenant.dart';
import 'package:ubsoft_pdks/domain/permissions/app_permission.dart';
import 'package:ubsoft_pdks/presentation/formatters/enum_labels.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_button.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_card.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_scaffold.dart';
import 'package:ubsoft_pdks/presentation/widgets/async_value_view.dart';
import 'package:ubsoft_pdks/presentation/widgets/empty_state.dart';
import 'package:ubsoft_pdks/presentation/widgets/section_header.dart';
import 'package:ubsoft_pdks/presentation/widgets/status_chip.dart';

/// Personel listesi.
class UserListPage extends ConsumerWidget {
  const UserListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool canCreate = ref.watch(canProvider(AppPermission.userCreate));
    final Tenant? tenant = ref.watch(currentTenantProvider);

    return AppScaffold(
      title: 'Öğrenciler',
      maxContentWidth: AppWidths.wide,
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppSpacing.vSm,
          SectionHeader(
            title: 'Kullanıcılar',
            description: tenant == null
                ? null
                : '${tenant.counters.userCount} / '
                      '${tenant.subscription.maxUsers} kullanıcı',
            trailing: canCreate
                ? AppButton(
                    label: 'Yeni',
                    icon: Icons.add_rounded,
                    size: AppButtonSize.small,
                    onPressed: () => context.go(AppRoutes.userNewPath),
                  )
                : null,
          ),
          AppSpacing.vLg,

          AsyncValueView<List<AppUser>>(
            value: ref.watch(usersProvider),
            builder: (List<AppUser> users) => users.isEmpty
                ? EmptyState(
                    icon: Icons.people_outline_rounded,
                    title: 'Henüz öğrenci yok',
                    description:
                        'Öğrenci ekleyin; e-posta ve şifresiyle giriş yapıp '
                        'QR okutmaya başlasın.',
                    actionLabel: canCreate ? 'Öğrenci ekle' : null,
                    onAction: () => context.go(AppRoutes.userNewPath),
                  )
                : Column(
                    children: <Widget>[
                      for (final AppUser user in users)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                          child: _UserTile(user: user),
                        ),
                    ],
                  ),
          ),
          AppSpacing.vXl,
        ],
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => context.go(AppRoutes.userEditPath(user.uid)),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.colors.primaryContainer,
              borderRadius: AppRadius.allMd,
            ),
            child: Text(
              user.initials,
              style: AppTypography.caption(context.colors.primary),
            ),
          ),
          AppSpacing.hSm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  user.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyStrong(context.colors.onSurface),
                ),
                AppSpacing.vXxs,
                Text(
                  user.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.small(context.colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          AppSpacing.hXs,
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              StatusChip(
                label: user.role.label,
                tone: user.role.isAdmin ? StatusTone.info : StatusTone.neutral,
                compact: true,
              ),
              if (!user.status.isActive) ...<Widget>[
                AppSpacing.vXxs,
                StatusChip(
                  label: user.status.label,
                  tone: EnumLabels.toneOfUser(user.status),
                  compact: true,
                ),
              ],
            ],
          ),
          AppSpacing.hXxs,
          Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: context.colors.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}
