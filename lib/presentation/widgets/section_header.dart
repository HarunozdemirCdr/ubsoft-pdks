import 'package:flutter/material.dart';
import 'package:ubsoft_pdks/core/extensions/context_x.dart';
import 'package:ubsoft_pdks/core/theme/app_spacing.dart';
import 'package:ubsoft_pdks/core/theme/app_typography.dart';

/// Bölüm başlığı: küçük mavi etiket → başlık → açıklama.
///
/// Hiyerarşi her sayfada aynı olsun diye tek bileşene bağlandı.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    this.eyebrow,
    this.description,
    this.trailing,
    this.dense = false,
    super.key,
  });

  /// Üstte görünen küçük büyük harfli etiket (ör. `BÖLGELER`).
  final String? eyebrow;

  final String title;
  final String? description;

  /// Sağ tarafa yerleşen eylem (buton, menü).
  final Widget? trailing;

  /// `true` ise başlık bir kademe küçülür — kart içi bölümler için.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final Widget texts = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (eyebrow case final String value) ...<Widget>[
          Text(
            value.toUpperCase(),
            style: AppTypography.eyebrow(context.colors.primary),
          ),
          AppSpacing.vXs,
        ],
        Text(
          title,
          style: dense
              ? AppTypography.h3(context.colors.onSurface)
              : AppTypography.h2(context.colors.onSurface),
        ),
        if (description case final String value) ...<Widget>[
          AppSpacing.vXxs,
          Text(
            value,
            style: AppTypography.small(context.colors.onSurfaceVariant),
          ),
        ],
      ],
    );

    if (trailing == null) return texts;

    return Row(
      children: <Widget>[
        Expanded(child: texts),
        AppSpacing.hMd,
        trailing!,
      ],
    );
  }
}
