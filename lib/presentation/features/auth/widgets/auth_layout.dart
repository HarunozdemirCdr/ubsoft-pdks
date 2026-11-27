import 'package:flutter/material.dart';
import 'package:ubsoft_pdks/core/config/app_config.dart';
import 'package:ubsoft_pdks/core/config/company_info.dart';
import 'package:ubsoft_pdks/core/extensions/context_x.dart';
import 'package:ubsoft_pdks/core/theme/app_colors.dart';
import 'package:ubsoft_pdks/core/theme/app_radius.dart';
import 'package:ubsoft_pdks/core/theme/app_spacing.dart';
import 'package:ubsoft_pdks/core/theme/app_typography.dart';

/// Giriş, şifre sıfırlama ve erişim engeli ekranlarının kurumsal yerleşimi.
///
/// Geniş ekranda (`>= 960px`) sol tarafta lacivert kurumsal vitrin paneli ve
/// sağ tarafta güvenli oturum çalışma alanı; mobil/tablet ekranda bankacılık
/// standartlarında derin lacivert üst bant ve üzerine taşan kart mimarisi.
class AuthLayout extends StatelessWidget {
  const AuthLayout({
    required this.title,
    required this.child,
    this.subtitle,
    this.cardTitle,
    this.cardSubtitle,
    this.badgeText = 'KURUMSAL PORTAL',
    this.footer,
    this.icon = Icons.shield_outlined,
    super.key,
  });

  final String title;
  final String? subtitle;
  final String? cardTitle;
  final String? cardSubtitle;
  final String badgeText;
  final Widget child;
  final Widget? footer;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final bool isDark = context.isDark;
    final Color pageBg = isDark ? AppColors.surfaceDark : AppColors.canvas;

    return Scaffold(
      backgroundColor: pageBg,
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          if (constraints.maxWidth >= 960) {
            return _DesktopSplitAuth(
              title: title,
              subtitle: subtitle,
              cardTitle: cardTitle,
              cardSubtitle: cardSubtitle,
              badgeText: badgeText,
              footer: footer,
              icon: icon,
              child: child,
            );
          }
          return _MobileCorporateAuth(
            title: title,
            subtitle: subtitle,
            cardTitle: cardTitle,
            cardSubtitle: cardSubtitle,
            badgeText: badgeText,
            footer: footer,
            icon: icon,
            child: child,
          );
        },
      ),
    );
  }
}

class _DesktopSplitAuth extends StatelessWidget {
  const _DesktopSplitAuth({
    required this.title,
    required this.subtitle,
    required this.cardTitle,
    required this.cardSubtitle,
    required this.badgeText,
    required this.footer,
    required this.icon,
    required this.child,
  });

  final String title;
  final String? subtitle;
  final String? cardTitle;
  final String? cardSubtitle;
  final String badgeText;
  final Widget? footer;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Sol kurumsal vitrin paneli
        Expanded(
          flex: 11,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  AppColors.navyDeep,
                  AppColors.navy,
                  AppColors.primary,
                ],
                stops: <double>[0.0, 0.55, 1.0],
              ),
            ),
            child: Stack(
              children: <Widget>[
                const Positioned.fill(
                  child: CustomPaint(painter: _CorporatePatternPainter()),
                ),
                // İnce dikey ayırıcı vurgu
                Positioned(
                  top: 0,
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 1,
                    color: AppColors.white.withValues(alpha: 0.12),
                  ),
                ),
                SafeArea(
                  child: LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints leftBounds) {
                      final double hPad = leftBounds.maxWidth >= 580 ? 52 : 34;
                      return SingleChildScrollView(
                        padding: EdgeInsets.symmetric(
                          horizontal: hPad,
                          vertical: 38,
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: (leftBounds.maxHeight - 76).clamp(
                              0,
                              double.infinity,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              // Üst marka şeridi
                              SizedBox(
                                width: double.infinity,
                                child: Wrap(
                                  spacing: 12,
                                  runSpacing: 10,
                                  alignment: WrapAlignment.spaceBetween,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: <Widget>[
                                    const _UbsCrestBadge(logoWidth: 184),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.white.withValues(
                                          alpha: 0.08,
                                        ),
                                        borderRadius: const BorderRadius.all(
                                          Radius.circular(AppRadius.full),
                                        ),
                                        border: Border.all(
                                          color: AppColors.white.withValues(
                                            alpha: 0.16,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: <Widget>[
                                          Container(
                                            width: 7,
                                            height: 7,
                                            decoration: const BoxDecoration(
                                              color: AppColors.entryOnDark,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'SİSTEM AKTİF · ${CompanyInfo.displayVersion}',
                                            style: AppTypography.eyebrow(
                                              AppColors.white.withValues(
                                                alpha: 0.88,
                                              ),
                                            ).copyWith(fontSize: 10.5),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Ana kurumsal başlık & değer önermesi
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 32,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Container(
                                      width: 48,
                                      height: 3,
                                      decoration: BoxDecoration(
                                        color: AppColors.brandAccent,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    Text(
                                      AppConfig.appName,
                                      style: AppTypography.display(
                                        AppColors.white,
                                      ).copyWith(
                                        fontSize: 34,
                                        height: 1.16,
                                        letterSpacing: -0.9,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 480,
                                      ),
                                      child: Text(
                                        'Öğrenci güvenliği, akıllı turnike geçiş kontrolü, anlık oda doluluğu ve izin denetimi için tasarlanmış kurumsal yönetim platformu.',
                                        style: AppTypography.body(
                                          AppColors.white.withValues(
                                            alpha: 0.78,
                                          ),
                                        ).copyWith(fontSize: 15, height: 1.6),
                                      ),
                                    ),
                                    const SizedBox(height: 30),
                                    const _FeaturePillar(
                                      icon: Icons.qr_code_scanner_rounded,
                                      title:
                                          'Akıllı Turnike ve Konum Doğrulama',
                                      subtitle:
                                          'QR okutma, GPS mesafe kontrolü ve anlık turnike röle tetikleme altyapısı.',
                                    ),
                                    const SizedBox(height: 12),
                                    const _FeaturePillar(
                                      icon: Icons.notifications_active_outlined,
                                      title:
                                          'Proaktif Güvenlik ve İzin Denetimi',
                                      subtitle:
                                          'İzni bitip dönmeyen veya giriş saatini aşan öğrenciler için otomatik uyarı merkezi.',
                                    ),
                                    const SizedBox(height: 12),
                                    const _FeaturePillar(
                                      icon: Icons.analytics_outlined,
                                      title:
                                          'Kurumsal Raporlama ve Hedefli Duyurular',
                                      subtitle:
                                          'Kat ve oda bazlı duyuru gönderimi, saatlik yoğunluk analizi, PDF ve Excel çıktısı.',
                                    ),
                                  ],
                                ),
                              ),
                              // Alt güven şeridi
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Divider(
                                    height: 1,
                                    color: AppColors.white.withValues(
                                      alpha: 0.14,
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  Row(
                                    children: <Widget>[
                                      Expanded(
                                        child: Text(
                                          '${CompanyInfo.legalName} · ${CompanyInfo.website}',
                                          style: AppTypography.caption(
                                            AppColors.white.withValues(
                                              alpha: 0.72,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        // Sağ oturum açma çalışma alanı
        Expanded(
          flex: 10,
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 32,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: _AuthEntrance(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: _SecurityEyebrowPill(label: badgeText),
                        ),
                        const SizedBox(height: 16),
                        _ExecutiveAuthCard(
                          icon: icon,
                          title: cardTitle ?? title,
                          subtitle: cardSubtitle ?? subtitle,
                          child: child,
                        ),
                        if (footer case final Widget value) ...<Widget>[
                          const SizedBox(height: 20),
                          value,
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MobileCorporateAuth extends StatelessWidget {
  const _MobileCorporateAuth({
    required this.title,
    required this.subtitle,
    required this.cardTitle,
    required this.cardSubtitle,
    required this.badgeText,
    required this.footer,
    required this.icon,
    required this.child,
  });

  final String title;
  final String? subtitle;
  final String? cardTitle;
  final String? cardSubtitle;
  final String badgeText;
  final Widget? footer;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final double topInset = MediaQuery.paddingOf(context).top;

    return SingleChildScrollView(
      child: Stack(
        children: <Widget>[
          // Bankacılık tarzı derin lacivert üst mimari bant
          Container(
            height: 268 + topInset,
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  AppColors.navyDeep,
                  AppColors.navy,
                  AppColors.primary,
                ],
                stops: <double>[0.0, 0.58, 1.0],
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            child: const ClipRRect(
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(28),
              ),
              child: CustomPaint(painter: _CorporatePatternPainter()),
            ),
          ),
          // İçerik katmanı
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 22, 16, 28),
                  child: _AuthEntrance(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        // Üst marka başlığı
                        Column(
                          children: <Widget>[
                            const _UbsCrestBadge(logoWidth: 176),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 11,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.white.withValues(alpha: 0.1),
                                borderRadius: const BorderRadius.all(Radius.circular(AppRadius.full)),
                                border: Border.all(
                                  color: AppColors.white.withValues(alpha: 0.18),
                                ),
                              ),
                              child: Text(
                                badgeText,
                                style: AppTypography.eyebrow(
                                  AppColors.white.withValues(alpha: 0.9),
                                ).copyWith(fontSize: 10),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              title,
                              textAlign: TextAlign.center,
                              style: AppTypography.h1(AppColors.white).copyWith(
                                fontSize: 22,
                                letterSpacing: -0.4,
                              ),
                            ),
                            if (subtitle case final String value) ...<Widget>[
                              const SizedBox(height: 4),
                              Text(
                                value,
                                textAlign: TextAlign.center,
                                style: AppTypography.small(
                                  AppColors.white.withValues(alpha: 0.78),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 22),
                        // Yüzen kurumsal giriş kartı
                        _ExecutiveAuthCard(
                          icon: icon,
                          title: cardTitle ?? title,
                          subtitle: cardSubtitle,
                          child: child,
                        ),
                        if (footer case final Widget value) ...<Widget>[
                          const SizedBox(height: 18),
                          value,
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExecutiveAuthCard extends StatelessWidget {
  const _ExecutiveAuthCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bool isDark = context.isDark;
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadius.allLg,
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.border,
        ),
        boxShadow: isDark
            ? const <BoxShadow>[]
            : const <BoxShadow>[
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 24,
                  offset: Offset(0, 10),
                ),
                BoxShadow(
                  color: AppColors.shadowStrong,
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: AppRadius.allLg,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Üst kurumsal marka çizgisi (kırmızı vurgu + lacivert şerit)
            SizedBox(
              height: 4,
              child: Row(
                children: <Widget>[
                  Container(width: 72, color: AppColors.brandAccent),
                  Expanded(child: Container(color: AppColors.primary)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(26, 26, 26, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.primarySurfaceDark
                              : AppColors.primarySurface,
                          borderRadius: AppRadius.allMd,
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.14),
                          ),
                        ),
                        child: Icon(
                          icon,
                          size: 22,
                          color: isDark
                              ? AppColors.primaryOnDark
                              : AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              title,
                              style: AppTypography.h2(
                                context.colors.onSurface,
                              ).copyWith(fontSize: 21),
                            ),
                            if (subtitle != null &&
                                subtitle!.trim().isNotEmpty) ...<Widget>[
                              const SizedBox(height: 2),
                              Text(
                                subtitle!,
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
                  const SizedBox(height: 22),
                  const Divider(height: 1),
                  const SizedBox(height: 22),
                  child,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UbsCrestBadge extends StatelessWidget {
  const _UbsCrestBadge({required this.logoWidth});

  final double logoWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: AppRadius.allMd,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.navyDeep.withValues(alpha: 0.28),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Image.asset(
        'assets/images/ubs_logo.png',
        width: logoWidth,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        semanticLabel: CompanyInfo.legalName,
      ),
    );
  }
}

class _SecurityEyebrowPill extends StatelessWidget {
  const _SecurityEyebrowPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final bool isDark = context.isDark;
    final Color fg = isDark ? AppColors.primaryOnDark : AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.primarySurfaceDark : AppColors.primarySurface,
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.full)),
        border: Border.all(color: fg.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.lock_outline_rounded, size: 13, color: fg),
          const SizedBox(width: 6),
          Text(label, style: AppTypography.eyebrow(fg).copyWith(fontSize: 10.5)),
        ],
      ),
    );
  }
}

class _FeaturePillar extends StatelessWidget {
  const _FeaturePillar({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.06),
        borderRadius: AppRadius.allMd,
        border: Border.all(color: AppColors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.1),
              borderRadius: AppRadius.allSm,
            ),
            child: Icon(icon, size: 19, color: AppColors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: AppTypography.bodyStrong(
                    AppColors.white,
                  ).copyWith(fontSize: 14),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: AppTypography.caption(
                    AppColors.white.withValues(alpha: 0.72),
                  ).copyWith(height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthEntrance extends StatelessWidget {
  const _AuthEntrance({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 340),
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double value, Widget? inner) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, (1 - value) * 14),
          child: inner,
        ),
      ),
      child: child,
    );
  }
}

/// Derin lacivert arka plan üzerine incelikli mimari ızgara ve eş merkezli
/// güvenlik halkaları çizer.
class _CorporatePatternPainter extends CustomPainter {
  const _CorporatePatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint gridPaint = Paint()
      ..color = AppColors.white.withValues(alpha: 0.035)
      ..strokeWidth = 1;

    const double step = 44;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final Paint ringPaint = Paint()
      ..color = AppColors.white.withValues(alpha: 0.055)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final Offset anchorTop = Offset(size.width * 0.92, size.height * 0.14);
    for (final double r in const <double>[110, 190, 280, 380]) {
      canvas.drawCircle(anchorTop, r, ringPaint);
    }

    final Paint accentRing = Paint()
      ..color = AppColors.brandAccent.withValues(alpha: 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(
      Offset(size.width * 0.08, size.height * 0.92),
      150,
      accentRing,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.allMd,
        border: Border.all(color: fg.withValues(alpha: 0.25)),
      ),
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
