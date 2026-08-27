import 'package:flutter/material.dart';
import 'package:ubsoft_pdks/core/extensions/context_x.dart';
import 'package:ubsoft_pdks/core/theme/app_colors.dart';
import 'package:ubsoft_pdks/core/theme/app_radius.dart';
import 'package:ubsoft_pdks/core/theme/app_spacing.dart';
import 'package:ubsoft_pdks/core/theme/app_typography.dart';

/// Giriş, şifre sıfırlama ve erişim engeli ekranlarının ortak yerleşimi.
///
/// Mobil tarayıcıda tek sütun, geniş ekranda ortalanmış dar bir kart.
/// Klavye açıldığında içerik yukarı kayar, buton klavyenin altında kalmaz.
class AuthLayout extends StatelessWidget {
  const AuthLayout({
    required this.title,
    required this.child,
    this.subtitle,
    this.footer,
    this.icon = Icons.badge_outlined,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? footer;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.isDark
          ? AppColors.surfaceDark
          : AppColors.surfaceAlt,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Center(
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: AppRadius.allLg,
                      ),
                      child: Icon(icon, size: 28, color: AppColors.white),
                    ),
                  ),
                  AppSpacing.vLg,
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: AppTypography.h1(context.colors.onSurface),
                  ),
                  if (subtitle case final String value) ...<Widget>[
                    AppSpacing.vXs,
                    Text(
                      value,
                      textAlign: TextAlign.center,
                      style: AppTypography.body(
                        context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                  AppSpacing.vXl,
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      borderRadius: AppRadius.allXl,
                      border: Border.all(color: context.colors.outline),
                    ),
                    child: child,
                  ),
                  if (footer case final Widget value) ...<Widget>[
                    AppSpacing.vMd,
                    value,
                  ],
                  AppSpacing.vLg,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Form üstünde gösterilen hata ya da bilgi kutusu.
class AuthMessageBox extends StatelessWidget {
  const AuthMessageBox({required this.message, this.isError = true, super.key});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final bool dark = context.isDark;
    final Color fg = isError
        ? (dark ? AppColors.dangerOnDark : AppColors.danger)
        : (dark ? AppColors.successOnDark : AppColors.success);
    final Color bg = isError
        ? (dark
              ? AppColors.danger.withValues(alpha: 0.15)
              : AppColors.dangerSurface)
        : (dark
              ? AppColors.success.withValues(alpha: 0.15)
              : AppColors.successSurface);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(color: bg, borderRadius: AppRadius.allMd),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            isError
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            size: 18,
            color: fg,
          ),
          AppSpacing.hXs,
          Expanded(child: Text(message, style: AppTypography.small(fg))),
        ],
      ),
    );
  }
}
