import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ubsoft_pdks/application/admin/tenant_providers.dart';
import 'package:ubsoft_pdks/core/extensions/context_x.dart';
import 'package:ubsoft_pdks/core/result/result.dart';
import 'package:ubsoft_pdks/core/routing/app_routes.dart';
import 'package:ubsoft_pdks/core/theme/app_spacing.dart';
import 'package:ubsoft_pdks/core/theme/app_typography.dart';
import 'package:ubsoft_pdks/core/utils/date_x.dart';
import 'package:ubsoft_pdks/domain/entities/app_user.dart';
import 'package:ubsoft_pdks/domain/entities/tenant.dart';
import 'package:ubsoft_pdks/domain/enums/tenant_status.dart';
import 'package:ubsoft_pdks/presentation/formatters/enum_labels.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_button.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_card.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_scaffold.dart';
import 'package:ubsoft_pdks/presentation/widgets/async_value_view.dart';
import 'package:ubsoft_pdks/presentation/widgets/confirm_dialog.dart';
import 'package:ubsoft_pdks/presentation/widgets/section_header.dart';
import 'package:ubsoft_pdks/presentation/widgets/status_chip.dart';
import 'package:ubsoft_pdks/services/notification/toast_service.dart';

/// Bir müşterinin süper admin görünümü: abonelik, durum, kullanıcılar.
class TenantDetailPage extends ConsumerWidget {
  const TenantDetailPage({required this.tenantId, super.key});

  final String tenantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppScaffold(
      title: 'Müşteri',
      showBackButton: true,
      maxContentWidth: AppWidths.wide,
      scrollable: true,
      body: AsyncValueView<Tenant?>(
        value: ref.watch(tenantProvider(tenantId)),
        builder: (Tenant? tenant) => tenant == null
            ? const Center(child: Text('Müşteri bulunamadı.'))
            : _Body(tenant: tenant),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.tenant});

  final Tenant tenant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Subscription subscription = tenant.subscription;
    final TenantController controller = ref.read(
      tenantControllerProvider.notifier,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppSpacing.vSm,
        SectionHeader(
          eyebrow: tenant.slug,
          title: tenant.name,
          description: '${AppDate.date(tenant.createdAt)} tarihinde açıldı',
          trailing: StatusChip(
            label: subscription.isExpired
                ? 'Süresi doldu'
                : tenant.status.label,
            tone: subscription.isExpired
                ? StatusTone.danger
                : EnumLabels.toneOfTenant(tenant.status),
          ),
        ),
        AppSpacing.vLg,

        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _Row(label: 'Plan', value: subscription.plan.label),
              _Row(label: 'Bitiş', value: AppDate.date(subscription.expiresAt)),
              _Row(
                label: 'Kullanıcı',
                value:
                    '${tenant.counters.userCount} / ${subscription.maxUsers}',
              ),
              _Row(
                label: 'QR noktası',
                value:
                    '${tenant.counters.checkpointCount} / '
                    '${subscription.maxCheckpoints}',
              ),
              AppSpacing.vSm,
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: <Widget>[
                  AppButton(
                    label: '1 ay uzat',
                    size: AppButtonSize.small,
                    variant: AppButtonVariant.outline,
                    onPressed: () => _extend(context, controller, days: 30),
                  ),
                  AppButton(
                    label: '1 yıl uzat',
                    size: AppButtonSize.small,
                    variant: AppButtonVariant.outline,
                    onPressed: () => _extend(context, controller, days: 365),
                  ),
                ],
              ),
            ],
          ),
        ),

        AppSpacing.vLg,
        const SectionHeader(title: 'Durum', dense: true),
        AppSpacing.vSm,
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SegmentedButton<TenantStatus>(
                segments: <ButtonSegment<TenantStatus>>[
                  for (final TenantStatus status in TenantStatus.values)
                    ButtonSegment<TenantStatus>(
                      value: status,
                      label: Text(status.label),
                    ),
                ],
                selected: <TenantStatus>{tenant.status},
                onSelectionChanged: (Set<TenantStatus> selection) async {
                  final Result<void> result = await controller.updateStatus(
                    tenantId: tenant.id,
                    status: selection.first,
                  );
                  Toast.result(result, successMessage: 'Durum güncellendi.');
                },
              ),
              AppSpacing.vXs,
              Text(
                'Askıya alınan hesap salt okunur olur: veri silinmez, yalnız '
                'yeni okutma kaydedilemez.',
                style: AppTypography.small(context.colors.onSurfaceVariant),
              ),
            ],
          ),
        ),

        AppSpacing.vLg,
        const SectionHeader(title: 'Kullanıcılar', dense: true),
        AppSpacing.vSm,
        AsyncValueView<List<AppUser>>(
          value: ref.watch(tenantUsersProvider(tenant.id)),
          compact: true,
          builder: (List<AppUser> users) => AppCard(
            child: Column(
              children: <Widget>[
                if (users.isEmpty)
                  Text(
                    'Bu müşteride kullanıcı yok.',
                    style: AppTypography.small(context.colors.onSurfaceVariant),
                  )
                else
                  for (final AppUser user in users)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(user.displayName),
                      subtitle: Text(user.email),
                      trailing: StatusChip(
                        label: user.role.label,
                        tone: user.role.isAdmin
                            ? StatusTone.info
                            : StatusTone.neutral,
                        compact: true,
                      ),
                    ),
              ],
            ),
          ),
        ),

        AppSpacing.vLg,
        const SectionHeader(title: 'Bakım', dense: true),
        AppSpacing.vSm,
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.rule_rounded),
                title: const Text('Rol varsayılanlarını tazele'),
                subtitle: const Text(
                  'İzin kataloğu genişlediğinde eski müşterilerde yeni '
                  'izinler kapalı kalır; bu düğme farkı kapatır.',
                ),
                onTap: () async {
                  final Result<void> result = await controller
                      .refreshRoleDefaults(tenant.id);
                  Toast.result(
                    result,
                    successMessage: 'Rol varsayılanları güncellendi.',
                  );
                },
              ),
              const Divider(),
              AppButton(
                label: 'Müşteriyi ve tüm verisini sil',
                icon: Icons.delete_forever_rounded,
                variant: AppButtonVariant.danger,
                expand: true,
                onPressed: () => _confirmDelete(context, controller),
              ),
            ],
          ),
        ),
        AppSpacing.vXl,
      ],
    );
  }

  Future<void> _extend(
    BuildContext context,
    TenantController controller, {
    required int days,
  }) async {
    // Uzatma bugünden değil, MEVCUT bitişten başlar — süresi dolmamış bir
    // aboneliği uzatmak, kalan günleri silip yerine yenisini koymamalı.
    final DateTime base = tenant.subscription.isExpired
        ? DateTime.now()
        : tenant.subscription.expiresAt;

    final Result<void> result = await controller.updateSubscription(
      tenantId: tenant.id,
      subscription: tenant.subscription.copyWith(
        expiresAt: base.add(Duration(days: days)),
      ),
    );
    Toast.result(result, successMessage: 'Abonelik uzatıldı.');
  }

  Future<void> _confirmDelete(
    BuildContext context,
    TenantController controller,
  ) async {
    final bool ok = await ConfirmDialog.show(
      context,
      title: 'Müşteri silinsin mi?',
      message:
          '${tenant.name} ve tüm verisi (personel, QR noktaları, devam '
          'kayıtları) kalıcı olarak silinecek. Bu işlem geri alınamaz.',
      confirmLabel: 'Kalıcı olarak sil',
      isDestructive: true,
    );
    if (!ok || !context.mounted) return;

    final Result<void> result = await controller.deleteTenant(tenant.id);
    if (!context.mounted) return;

    Toast.result(result, successMessage: 'Müşteri silindi.');
    if (result.isOk) context.go(AppRoutes.tenants);
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 110,
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
