import 'package:flutter/material.dart';
import 'package:ubsoft_pdks/core/extensions/context_x.dart';
import 'package:ubsoft_pdks/core/theme/app_radius.dart';
import 'package:ubsoft_pdks/core/theme/app_spacing.dart';
import 'package:ubsoft_pdks/core/theme/app_typography.dart';

/// Tam genişlikte, tek tip, seçilebilir satır.
///
/// Yan yana dizilen farklı boyutlardaki çipler dar ekranda dağınık görünüyordu.
/// Bunun yerine seçenekler alt alta, aynı boyutta ve sola hizalı satırlar
/// hâlinde listelenir; dokunmak seçer ya da kaldırır. Filtreler, bekçi ataması
/// ve bölge seçimi aynı görünümü paylaşır.
class SelectableTile extends StatelessWidget {
  const SelectableTile({
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
    super.key,
  });

  final String label;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
      child: Material(
        color: selected
            ? context.colors.primaryContainer
            : context.colors.surfaceContainerLow,
        borderRadius: AppRadius.allMd,
        child: InkWell(
          borderRadius: AppRadius.allMd,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  selected
                      ? Icons.check_box_rounded
                      : Icons.check_box_outline_blank_rounded,
                  size: 20,
                  color: selected
                      ? context.colors.primary
                      : context.colors.onSurfaceVariant,
                ),
                AppSpacing.hSm,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        label,
                        style: selected
                            ? AppTypography.bodyStrong(context.colors.onSurface)
                            : AppTypography.body(context.colors.onSurface),
                      ),
                      if (subtitle case final String value) ...<Widget>[
                        AppSpacing.vXxs,
                        Text(
                          value,
                          style: AppTypography.small(
                            context.colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
