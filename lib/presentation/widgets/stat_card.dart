import 'package:flutter/material.dart';
import 'package:ubsoft_pdks/core/extensions/context_x.dart';
import 'package:ubsoft_pdks/core/theme/app_colors.dart';
import 'package:ubsoft_pdks/core/theme/app_radius.dart';
import 'package:ubsoft_pdks/core/theme/app_spacing.dart';
import 'package:ubsoft_pdks/core/theme/app_typography.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_card.dart';
import 'package:ubsoft_pdks/presentation/widgets/status_chip.dart';

/// Panel metrik kartı — sayı + etiket + ikon.
///
/// Dashboard'daki "Bugünkü Tur", "Tamamlanan", "Devam Eden", "Eksik"
/// kartlarında kullanılır.
class StatCard extends StatelessWidget {
  const StatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.tone = StatusTone.info,
    this.caption,
    this.onTap,
    this.isLoading = false,
    super.key,
  });

  final String label;
  final String value;
  final IconData icon;
  final StatusTone tone;

  /// Sayının altında görünen küçük açıklama.
  final String? caption;

  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final bool dark = context.isDark;
    final (Color fg, Color bg) = switch (tone) {
      StatusTone.info => (
        dark ? AppColors.primaryOnDark : AppColors.primary,
        dark ? AppColors.primarySurfaceDark : AppColors.primarySurface,
      ),
      StatusTone.success => (
        dark ? AppColors.successOnDark : AppColors.success,
        dark
            ? AppColors.success.withValues(alpha: 0.18)
            : AppColors.successSurface,
      ),
      StatusTone.warning => (
        dark ? AppColors.warningOnDark : AppColors.warning,
        dark
            ? AppColors.warning.withValues(alpha: 0.18)
            : AppColors.warningSurface,
      ),
      StatusTone.danger => (
        dark ? AppColors.dangerOnDark : AppColors.danger,
        dark
            ? AppColors.danger.withValues(alpha: 0.18)
            : AppColors.dangerSurface,
      ),
      StatusTone.neutral => (
        dark ? AppColors.gray400 : AppColors.gray600,
        dark ? AppColors.surfaceMutedDark : AppColors.neutralSurface,
      ),
    };

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: AppRadius.allMd,
                ),
                child: Icon(icon, size: 18, color: fg),
              ),
              const Spacer(),
              if (onTap != null)
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: context.colors.onSurfaceVariant,
                ),
            ],
          ),
          AppSpacing.vSm,
          if (isLoading)
            SizedBox(
              height: 30,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 44,
                  height: 24,
                  decoration: BoxDecoration(
                    color: dark
                        ? AppColors.surfaceMutedDark
                        : AppColors.gray100,
                    borderRadius: AppRadius.allSm,
                  ),
                ),
              ),
            )
          else
            Text(value, style: AppTypography.metric(context.colors.onSurface)),
          AppSpacing.vXxs,
          Text(
            label,
            style: AppTypography.small(context.colors.onSurfaceVariant),
          ),
          if (caption case final String value) ...<Widget>[
            AppSpacing.vXxs,
            Text(value, style: AppTypography.caption(fg)),
          ],
        ],
      ),
    );
  }
}
