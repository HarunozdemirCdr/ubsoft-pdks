import 'package:flutter/material.dart';
import 'package:ubsoft_pdks/core/extensions/context_x.dart';
import 'package:ubsoft_pdks/core/theme/app_colors.dart';
import 'package:ubsoft_pdks/core/theme/app_radius.dart';
import 'package:ubsoft_pdks/core/theme/app_spacing.dart';
import 'package:ubsoft_pdks/core/theme/app_typography.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_button.dart';

/// Boş liste durumu.
///
/// Kullanıcıya "burada bir şey yok" demekle yetinmez; ne yapabileceğini de
/// söyler. Bu yüzden [actionLabel] verildiğinde bir eylem butonu çizilir.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.title,
    this.description,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
    this.compact = false,
    super.key,
  });

  final String title;
  final String? description;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// `true` ise dikey boşluklar daralır — kart içinde kullanılır.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final bool dark = context.isDark;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: compact ? AppSpacing.lg : AppSpacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: dark
                    ? AppColors.surfaceMutedDark
                    : AppColors.surfaceMuted,
                borderRadius: AppRadius.allLg,
              ),
              child: Icon(
                icon,
                size: 28,
                color: dark ? AppColors.gray400 : AppColors.gray400,
              ),
            ),
            AppSpacing.vMd,
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.h3(context.colors.onSurface),
            ),
            if (description case final String value) ...<Widget>[
              AppSpacing.vXs,
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Text(
                  value,
                  textAlign: TextAlign.center,
                  style: AppTypography.small(context.colors.onSurfaceVariant),
                ),
              ),
            ],
            if (actionLabel case final String value) ...<Widget>[
              AppSpacing.vLg,
              AppButton(
                label: value,
                onPressed: onAction,
                variant: AppButtonVariant.outline,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
