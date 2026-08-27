import 'package:flutter/material.dart';
import 'package:ubsoft_pdks/core/extensions/context_x.dart';
import 'package:ubsoft_pdks/core/theme/app_colors.dart';
import 'package:ubsoft_pdks/core/theme/app_radius.dart';
import 'package:ubsoft_pdks/core/theme/app_shadows.dart';
import 'package:ubsoft_pdks/core/theme/app_spacing.dart';

/// Uygulamanın temel yüzeyi.
///
/// Temelde gölgesizdir; tıklanabilir olduğunda imleç üzerine geldiğinde tek bir
/// yumuşak gölge belirir (300ms). Bu, tasarım sistemindeki "animasyon görünmez
/// kalır, hissedilir" ilkesinin karşılığıdır.
class AppCard extends StatefulWidget {
  const AppCard({
    required this.child,
    this.onTap,
    this.padding,
    this.margin,
    this.background,
    this.borderColor,
    this.borderRadius = AppRadius.allLg,
    this.showBorder = true,
    this.spacious = false,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? background;
  final Color? borderColor;
  final BorderRadius borderRadius;
  final bool showBorder;

  /// `true` ise 24px, aksi halde 16px iç boşluk.
  final bool spacious;

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bool interactive = widget.onTap != null;
    final Color bg = widget.background ?? context.colors.surface;
    final Color border = widget.borderColor ?? context.colors.outline;

    final Widget content = AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      padding:
          widget.padding ??
          EdgeInsets.all(
            widget.spacious ? AppSpacing.cardSpacious : AppSpacing.cardCompact,
          ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: widget.borderRadius,
        border: widget.showBorder ? Border.all(color: border) : null,
        boxShadow: _hovered && interactive ? AppShadows.card : AppShadows.none,
      ),
      child: widget.child,
    );

    if (!interactive) {
      return Padding(padding: widget.margin ?? EdgeInsets.zero, child: content);
    }

    return Padding(
      padding: widget.margin ?? EdgeInsets.zero,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: widget.borderRadius,
            splashColor: AppColors.primary.withValues(alpha: 0.06),
            highlightColor: AppColors.primary.withValues(alpha: 0.04),
            child: content,
          ),
        ),
      ),
    );
  }
}

/// İkon için yuvarlatılmış kare kutu — 48×48, 12 radius.
class AppIconBox extends StatelessWidget {
  const AppIconBox({
    required this.icon,
    this.size = 48,
    this.iconSize = 22,
    this.background,
    this.foreground,
    super.key,
  });

  final IconData icon;
  final double size;
  final double iconSize;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final bool dark = context.isDark;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color:
            background ??
            (dark ? AppColors.primarySurfaceDark : AppColors.primarySurface),
        borderRadius: AppRadius.allMd,
      ),
      child: Icon(
        icon,
        size: iconSize,
        color:
            foreground ?? (dark ? AppColors.primaryOnDark : AppColors.primary),
      ),
    );
  }
}
