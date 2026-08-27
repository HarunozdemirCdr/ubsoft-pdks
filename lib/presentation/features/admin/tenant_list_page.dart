import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ubsoft_pdks/application/admin/tenant_providers.dart';
import 'package:ubsoft_pdks/core/extensions/context_x.dart';
import 'package:ubsoft_pdks/core/routing/app_routes.dart';
import 'package:ubsoft_pdks/core/theme/app_spacing.dart';
import 'package:ubsoft_pdks/core/theme/app_typography.dart';
import 'package:ubsoft_pdks/core/utils/date_x.dart';
import 'package:ubsoft_pdks/domain/entities/tenant.dart';
import 'package:ubsoft_pdks/presentation/formatters/enum_labels.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_button.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_card.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_scaffold.dart';
import 'package:ubsoft_pdks/presentation/widgets/async_value_view.dart';
import 'package:ubsoft_pdks/presentation/widgets/empty_state.dart';
import 'package:ubsoft_pdks/presentation/widgets/section_header.dart';
import 'package:ubsoft_pdks/presentation/widgets/status_chip.dart';

/// Süper admin müşteri listesi.
class TenantListPage extends ConsumerWidget {
  const TenantListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppScaffold(
      title: 'Müşteriler',
      maxContentWidth: AppWidths.wide,
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppSpacing.vSm,
          SectionHeader(
            eyebrow: 'Sistem yönetimi',
            title: 'Müşteriler',
            description: 'Abonelik açın, uzatın ya da askıya alın.',
            trailing: AppButton(
              label: 'Yeni',
              icon: Icons.add_rounded,
              size: AppButtonSize.small,
              onPressed: () => context.go(AppRoutes.tenantNewPath),
            ),
          ),
          AppSpacing.vLg,

          AsyncValueView<List<Tenant>>(
            value: ref.watch(tenantsProvider),
            builder: (List<Tenant> tenants) => tenants.isEmpty
                ? EmptyState(
                    icon: Icons.business_outlined,
                    title: 'Henüz müşteri yok',
                    description:
                        'İlk müşteriyi açtığınızda yöneticisi de birlikte '
                        'oluşturulur.',
                    actionLabel: 'Müşteri aç',
                    onAction: () => context.go(AppRoutes.tenantNewPath),
                  )
                : Column(
                    children: <Widget>[
                      for (final Tenant tenant in tenants)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                          child: _TenantTile(tenant: tenant),
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

class _TenantTile extends StatelessWidget {
  const _TenantTile({required this.tenant});

  final Tenant tenant;

  @override
  Widget build(BuildContext context) {
    final Subscription subscription = tenant.subscription;
    final bool expired = subscription.isExpired;

    return AppCard(
      onTap: () => context.go(AppRoutes.tenantDetailPath(tenant.id)),
      child: Row(
        children: <Widget>[
          const AppIconBox(icon: Icons.business_rounded),
          AppSpacing.hSm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  tenant.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyStrong(context.colors.onSurface),
                ),
                AppSpacing.vXxs,
                Text(
                  '${subscription.plan.label} · '
                  '${tenant.counters.userCount} kullanıcı · '
                  '${expired ? 'doldu' : 'bitiş'} '
                  '${AppDate.dateShort(subscription.expiresAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.small(context.colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          AppSpacing.hXs,
          StatusChip(
            label: expired ? 'Süresi doldu' : tenant.status.label,
            tone: expired
                ? StatusTone.danger
                : EnumLabels.toneOfTenant(tenant.status),
            compact: true,
          ),
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
