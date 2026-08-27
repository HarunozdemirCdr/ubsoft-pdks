import 'package:flutter/material.dart';
import 'package:ubsoft_pdks/core/extensions/context_x.dart';
import 'package:ubsoft_pdks/core/theme/app_colors.dart';
import 'package:ubsoft_pdks/core/theme/app_radius.dart';
import 'package:ubsoft_pdks/core/theme/app_spacing.dart';
import 'package:ubsoft_pdks/core/theme/app_typography.dart';

/// Rozet renk tonları.
///
/// Doğrudan renk değil ton verilir; açık/koyu tema karşılıkları burada
/// çözülür. Böylece bir durumun rengi tüm uygulamada aynı kalır.
enum StatusTone {
  /// Devam eden, bilgilendirici (mavi).
  info,

  /// Başarılı, tamamlanmış (yeşil).
  success,

  /// Dikkat gerektiren, eksik veya geç (kehribar).
  warning,

  /// Hatalı, başarısız (kırmızı).
  danger,

  /// Etkisiz, iptal edilmiş (gri).
  neutral,
}

/// Durum rozeti — tur durumu, kullanıcı durumu, abonelik durumu.
class StatusChip extends StatelessWidget {
  const StatusChip({
    required this.label,
    required this.tone,
    this.icon,
    this.compact = false,
    super.key,
  });

  final String label;
  final StatusTone tone;
  final IconData? icon;

  /// `true` ise daha küçük ve dar — liste satırı içinde kullanılır.
  final bool compact;

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

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppSpacing.xs : AppSpacing.sm,
        vertical: compact ? 3 : AppSpacing.xxs + 1,
      ),
      decoration: BoxDecoration(
        color: bg,
        // Hap değil, yumuşak dikdörtgen: rozetler çoğu zaman satır sonunda
        // saatlerle aynı hizada durur ve yuvarlak kenar o hizayı bulanıklaştırır.
        borderRadius: AppRadius.allSm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon case final IconData value) ...<Widget>[
            Icon(value, size: compact ? 12 : 14, color: fg),
            const SizedBox(width: AppSpacing.xxs + 1),
          ],
          Text(
            label,
            style: AppTypography.caption(
              fg,
            ).copyWith(fontSize: compact ? 11 : 12),
          ),
        ],
      ),
    );
  }
}
