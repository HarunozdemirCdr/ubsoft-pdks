import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ubsoft_pdks/core/error/error_mapper.dart';
import 'package:ubsoft_pdks/core/error/failure.dart';
import 'package:ubsoft_pdks/core/extensions/context_x.dart';
import 'package:ubsoft_pdks/core/theme/app_colors.dart';
import 'package:ubsoft_pdks/core/theme/app_radius.dart';
import 'package:ubsoft_pdks/core/theme/app_spacing.dart';
import 'package:ubsoft_pdks/core/theme/app_typography.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_button.dart';

/// Hata durumu görünümü.
///
/// Ham hata nesnesini kabul eder ve [ErrorMapper] üzerinden kullanıcıya
/// gösterilebilir Türkçe mesaja çevirir. Teknik ayrıntı yalnız hata ayıklama
/// derlemesinde, katlanabilir bir alanda gösterilir.
class ErrorView extends StatelessWidget {
  const ErrorView({
    required this.error,
    this.onRetry,
    this.compact = false,
    super.key,
  });

  final Object error;
  final VoidCallback? onRetry;

  /// `true` ise kart içi dar yerleşim kullanılır.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final Failure failure = ErrorMapper.map(error);
    final bool dark = context.isDark;
    final Color danger = dark ? AppColors.dangerOnDark : AppColors.danger;

    final IconData icon = switch (failure) {
      NetworkFailure() => Icons.wifi_off_rounded,
      PermissionFailure() => Icons.lock_outline_rounded,
      NotFoundFailure() => Icons.search_off_rounded,
      SubscriptionFailure() => Icons.workspace_premium_outlined,
      _ => Icons.error_outline_rounded,
    };

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
                    ? AppColors.danger.withValues(alpha: 0.15)
                    : AppColors.dangerSurface,
                borderRadius: AppRadius.allLg,
              ),
              child: Icon(icon, size: 28, color: danger),
            ),
            AppSpacing.vMd,
            Text(
              'Bir sorun oluştu',
              textAlign: TextAlign.center,
              style: AppTypography.h3(context.colors.onSurface),
            ),
            AppSpacing.vXs,
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Text(
                failure.message,
                textAlign: TextAlign.center,
                style: AppTypography.small(context.colors.onSurfaceVariant),
              ),
            ),
            if (onRetry != null) ...<Widget>[
              AppSpacing.vLg,
              AppButton(
                label: 'Tekrar dene',
                onPressed: onRetry,
                variant: AppButtonVariant.outline,
                icon: Icons.refresh_rounded,
              ),
            ],
            if (failure.technical case final String detail) ...<Widget>[
              AppSpacing.vMd,
              _TechnicalDetail(detail: detail),
            ],
          ],
        ),
      ),
    );
  }
}

/// Yalnız hata ayıklama derlemesinde görünen teknik ayrıntı.
class _TechnicalDetail extends StatelessWidget {
  const _TechnicalDetail({required this.detail});

  final String detail;

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Theme(
        data: context.theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text(
            'Teknik ayrıntı',
            style: AppTypography.caption(context.colors.onSurfaceVariant),
          ),
          children: <Widget>[
            Text(
              detail,
              style: AppTypography.mono(
                context.colors.onSurfaceVariant,
              ).copyWith(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
