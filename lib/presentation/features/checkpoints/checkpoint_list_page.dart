import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ubsoft_pdks/application/auth/session_provider.dart';
import 'package:ubsoft_pdks/application/checkpoint/checkpoint_providers.dart';
import 'package:ubsoft_pdks/core/extensions/context_x.dart';
import 'package:ubsoft_pdks/core/routing/app_routes.dart';
import 'package:ubsoft_pdks/core/theme/app_spacing.dart';
import 'package:ubsoft_pdks/core/theme/app_typography.dart';
import 'package:ubsoft_pdks/core/utils/geo.dart';
import 'package:ubsoft_pdks/domain/entities/checkpoint.dart';
import 'package:ubsoft_pdks/domain/permissions/app_permission.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_button.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_card.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_scaffold.dart';
import 'package:ubsoft_pdks/presentation/widgets/async_value_view.dart';
import 'package:ubsoft_pdks/presentation/widgets/empty_state.dart';
import 'package:ubsoft_pdks/presentation/widgets/section_header.dart';
import 'package:ubsoft_pdks/presentation/widgets/status_chip.dart';

/// QR noktaları listesi.
class CheckpointListPage extends ConsumerWidget {
  const CheckpointListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool canCreate = ref.watch(
      canProvider(AppPermission.checkpointCreate),
    );

    return AppScaffold(
      title: 'QR Noktaları',
      maxContentWidth: AppWidths.wide,
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppSpacing.vSm,
          SectionHeader(
            title: 'Noktalar',
            description:
                'Her nokta bir QR etiketidir. Konumu, okutmanın gerçekten '
                'orada yapılıp yapılmadığını belirler.',
            trailing: canCreate
                ? AppButton(
                    label: 'Yeni',
                    icon: Icons.add_rounded,
                    size: AppButtonSize.small,
                    onPressed: () => context.go(AppRoutes.checkpointNewPath),
                  )
                : null,
          ),
          if (ref.watch(currentUserProvider)?.role.isAdmin == true)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: OutlinedButton.icon(
                onPressed: () => context.go('/noktalar/turnike'),
                icon: const Icon(Icons.memory_rounded),
                label: const Text('Turnike kartı · 8 röle'),
              ),
            ),
          AppSpacing.vLg,

          AsyncValueView<List<Checkpoint>>(
            value: ref.watch(checkpointsProvider),
            builder: (List<Checkpoint> items) => items.isEmpty
                ? EmptyState(
                    icon: Icons.qr_code_2_outlined,
                    title: 'Henüz QR noktası yok',
                    description:
                        'Giriş ve çıkış için birer nokta oluşturun, '
                        'konumlarını girin ve QR etiketlerini yazdırın.',
                    actionLabel: canCreate ? 'İlk noktayı oluştur' : null,
                    onAction: () => context.go(AppRoutes.checkpointNewPath),
                  )
                : Column(
                    children: <Widget>[
                      for (final Checkpoint item in items)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                          child: _CheckpointTile(checkpoint: item),
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

class _CheckpointTile extends StatelessWidget {
  const _CheckpointTile({required this.checkpoint});

  final Checkpoint checkpoint;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => context.go(AppRoutes.checkpointEditPath(checkpoint.id)),
      child: Row(
        children: <Widget>[
          AppIconBox(
            icon: switch (checkpoint.kind.key) {
              'in' => Icons.login_rounded,
              'out' => Icons.logout_rounded,
              _ => Icons.swap_horiz_rounded,
            },
          ),
          AppSpacing.hSm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        checkpoint.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyStrong(
                          context.colors.onSurface,
                        ),
                      ),
                    ),
                    AppSpacing.hXs,
                    Text(
                      '#${checkpoint.code}',
                      style: AppTypography.mono(
                        context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                AppSpacing.vXxs,
                Text(
                  <String>[
                    checkpoint.kind.label,
                    if (checkpoint.hasLocation)
                      '${checkpoint.radiusMeters} m yarıçap'
                    else
                      'Konum girilmemiş',
                    if (checkpoint.hasLocation) checkpoint.coordinateLabel,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.small(context.colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          AppSpacing.hXs,
          if (!checkpoint.active)
            const StatusChip(
              label: 'Pasif',
              tone: StatusTone.neutral,
              compact: true,
            )
          else if (!checkpoint.hasLocation)
            const StatusChip(
              label: 'Konum yok',
              tone: StatusTone.warning,
              compact: true,
            ),
          IconButton(
            tooltip: 'QR kodunu göster',
            icon: const Icon(Icons.qr_code_rounded),
            onPressed: () =>
                context.go(AppRoutes.checkpointQrPath(checkpoint.id)),
          ),
        ],
      ),
    );
  }
}

/// Yarıçapı okunur biçimde veren yardımcı — liste ve form aynı metni yazsın.
String describeRadius(int meters) => Geo.formatDistance(meters.toDouble());
