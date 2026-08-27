import 'package:flutter/material.dart';
import 'package:ubsoft_pdks/core/extensions/context_x.dart';
import 'package:ubsoft_pdks/core/theme/app_colors.dart';
import 'package:ubsoft_pdks/core/theme/app_spacing.dart';
import 'package:ubsoft_pdks/core/theme/app_typography.dart';
import 'package:ubsoft_pdks/core/utils/geo.dart';
import 'package:ubsoft_pdks/domain/entities/attendance_event.dart';
import 'package:ubsoft_pdks/domain/enums/location_verdict.dart';
import 'package:ubsoft_pdks/presentation/formatters/enum_labels.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_card.dart';
import 'package:ubsoft_pdks/presentation/widgets/status_chip.dart';

/// Tek bir okutma satırı: saat, yön, nokta ve konum rozeti.
///
/// Konum rozeti her satırda görünür — okutmanın kanıt değeri buradadır.
/// Doğrulanmış bir okutmada da gösterilir: yalnız sorunlular işaretlenirse,
/// rozetin yokluğu "henüz bakılmadı" mı yoksa "sorun yok" mu belli olmaz.
class PunchEventTile extends StatelessWidget {
  const PunchEventTile({
    required this.event,
    this.showUser = false,
    this.showLocation = true,
    this.onDelete,
    super.key,
  });

  final AttendanceEvent event;

  /// Yönetici listelerinde personel adı da yazılır.
  final bool showUser;

  /// Konum rozeti ve noktaya uzaklık gösterilsin mi? Personelin kendi
  /// ekranında kapatılır.
  final bool showLocation;

  /// Verildiğinde satırın sonunda silme düğmesi çıkar.
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final bool dark = context.isDark;
    final Color directionColor = event.type.isEntry
        ? (dark ? AppColors.entryOnDark : AppColors.entry)
        : (dark ? AppColors.exitOnDark : AppColors.exit);

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          Icon(
            EnumLabels.iconOfPunch(event.type),
            size: 20,
            color: directionColor,
          ),
          AppSpacing.hSm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      event.timeLabel,
                      style: AppTypography.bodyStrong(directionColor),
                    ),
                    AppSpacing.hXs,
                    Text(
                      event.type.label,
                      style: AppTypography.small(
                        context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                AppSpacing.vXxs,
                Text(
                  <String>[
                    if (showUser) event.userName,
                    event.checkpointName,
                    if (showLocation) _distanceLabel(),
                  ].where((String s) => s.isNotEmpty).join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.small(context.colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (showLocation) ...<Widget>[
            AppSpacing.hXs,
            StatusChip(
              label: event.verdict.label,
              tone: EnumLabels.toneOfVerdict(event.verdict),
              icon: EnumLabels.iconOfVerdict(event.verdict),
              compact: true,
            ),
          ],
          if (onDelete != null)
            IconButton(
              tooltip: 'Okutmayı sil',
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }

  /// `18 m` — yalnız ölçüm varsa.
  String _distanceLabel() {
    final double? distance = event.distanceMeters;
    if (distance == null || event.verdict == LocationVerdict.unavailable) {
      return '';
    }
    return Geo.formatDistance(distance);
  }
}
