import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubsoft_pdks/application/auth/session_provider.dart';
import 'package:ubsoft_pdks/application/checkpoint/checkpoint_providers.dart';
import 'package:ubsoft_pdks/core/extensions/context_x.dart';
import 'package:ubsoft_pdks/core/theme/app_colors.dart';
import 'package:ubsoft_pdks/core/theme/app_radius.dart';
import 'package:ubsoft_pdks/core/theme/app_spacing.dart';
import 'package:ubsoft_pdks/core/theme/app_typography.dart';
import 'package:ubsoft_pdks/domain/entities/checkpoint.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_card.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_scaffold.dart';
import 'package:ubsoft_pdks/presentation/widgets/async_value_view.dart';
import 'package:ubsoft_pdks/presentation/widgets/empty_state.dart';
import 'package:ubsoft_pdks/presentation/widgets/info_hint.dart';

/// Bir noktanın yazdırılabilir QR etiketi.
///
/// Etiket **her zaman beyaz zemin üzerine siyah** çizilir; koyu temada bile
/// değişmez. QR okuyucular ters kontrastta güvenilir çalışmaz ve bu görsel
/// ekranda kalmak için değil, kâğıda basılmak içindir.
class CheckpointQrPage extends ConsumerWidget {
  const CheckpointQrPage({required this.checkpointId, super.key});

  final String checkpointId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppScaffold(
      title: 'QR Etiketi',
      showBackButton: true,
      scrollable: true,
      body: AsyncValueView<Checkpoint?>(
        value: ref.watch(checkpointProvider(checkpointId)),
        builder: (Checkpoint? checkpoint) => checkpoint == null
            ? const EmptyState(
                icon: Icons.qr_code_2_outlined,
                title: 'Nokta bulunamadı',
                description: 'Bu nokta silinmiş olabilir.',
              )
            : _QrBody(checkpoint: checkpoint),
      ),
    );
  }
}

class _QrBody extends ConsumerWidget {
  const _QrBody({required this.checkpoint});

  final Checkpoint checkpoint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String company = ref.watch(currentTenantProvider)?.name ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppSpacing.vLg,
        Center(
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: AppRadius.allLg,
              border: Border.all(color: AppColors.gray300),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (company.isNotEmpty) ...<Widget>[
                  Text(
                    company,
                    textAlign: TextAlign.center,
                    style: AppTypography.caption(AppColors.gray600),
                  ),
                  AppSpacing.vXs,
                ],
                Text(
                  checkpoint.name,
                  textAlign: TextAlign.center,
                  style: AppTypography.h3(AppColors.gray900),
                ),
                AppSpacing.vXs,
                Text(
                  checkpoint.kind.label,
                  textAlign: TextAlign.center,
                  style: AppTypography.small(AppColors.gray600),
                ),
                AppSpacing.vMd,
                BarcodeWidget(
                  barcode: Barcode.qrCode(),
                  data: checkpoint.code,
                  width: 220,
                  height: 220,
                  drawText: false,
                  color: AppColors.gray950,
                  backgroundColor: AppColors.white,
                ),
                AppSpacing.vMd,
                Text(
                  checkpoint.code,
                  style: AppTypography.metric(AppColors.gray900),
                ),
              ],
            ),
          ),
        ),
        AppSpacing.vLg,

        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _Row(label: 'Kod', value: checkpoint.code),
              _Row(label: 'Tür', value: checkpoint.kind.label),
              _Row(
                label: 'Konum',
                value: checkpoint.hasLocation
                    ? checkpoint.coordinateLabel
                    : 'Girilmemiş',
              ),
              _Row(label: 'Yarıçap', value: '${checkpoint.radiusMeters} m'),
            ],
          ),
        ),

        AppSpacing.vMd,
        const InfoNote(
          icon: Icons.print_outlined,
          message:
              'Yazdırmak için tarayıcınızın yazdırma özelliğini kullanın '
              '(Ctrl+P). Etiketi noktanın hemen yanına, göz hizasına asın; '
              'ıslanmaya karşı şeffaf bantla kaplamak ömrünü uzatır.',
        ),
        AppSpacing.vXl,
      ],
    );
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
            width: 90,
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
