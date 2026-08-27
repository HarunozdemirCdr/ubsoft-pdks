import 'package:flutter/material.dart';
import 'package:ubsoft_pdks/core/extensions/context_x.dart';
import 'package:ubsoft_pdks/core/theme/app_colors.dart';
import 'package:ubsoft_pdks/core/theme/app_spacing.dart';

/// Buton türleri.
enum AppButtonVariant {
  /// Dolgulu mavi — sayfadaki birincil eylem. Ekranda **bir tane** olmalı.
  primary,

  /// Çerçeveli — ikincil eylem.
  outline,

  /// Çerçevesiz — üçüncül eylem, bağlantı benzeri.
  text,

  /// Kırmızı — yıkıcı eylem (silme, iptal).
  danger,
}

enum AppButtonSize {
  /// 40px — liste satırı içi, sıkışık alanlar.
  small,

  /// 48px — varsayılan dokunma hedefi.
  medium,

  /// 56px — sayfa alt eylem çubuğundaki ana eylem.
  large,
}

/// Tek tip buton.
///
/// Yükleme durumunu kendi içinde yönetir: [isLoading] iken buton devre dışı
/// kalır ve metin yerine dönen bir gösterge çizer. Böylece her ekranda ayrı
/// ayrı "butonu kilitle" mantığı yazılmaz.
class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.medium,
    this.icon,
    this.isLoading = false,
    this.expand = false,
    super.key,
  });

  /// Sayfa genişliğini kaplayan birincil eylem kısayolu.
  const AppButton.primaryWide({
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    super.key,
  }) : variant = AppButtonVariant.primary,
       size = AppButtonSize.large,
       expand = true;

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final IconData? icon;
  final bool isLoading;

  /// `true` ise kullanılabilir genişliği kaplar.
  final bool expand;

  double get _height => switch (size) {
    AppButtonSize.small => 40,
    AppButtonSize.medium => AppSpacing.touchTarget,
    AppButtonSize.large => 56,
  };

  @override
  Widget build(BuildContext context) {
    final bool disabled = isLoading || onPressed == null;
    final Widget content = _content(context);

    final ButtonStyle style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll<Size>(
        Size(expand ? double.infinity : 0, _height),
      ),
      padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(
        EdgeInsets.symmetric(
          horizontal: size == AppButtonSize.small
              ? AppSpacing.md
              : AppSpacing.lg,
        ),
      ),
    );

    final Widget button = switch (variant) {
      AppButtonVariant.primary => ElevatedButton(
        onPressed: disabled ? null : onPressed,
        style: style,
        child: content,
      ),
      AppButtonVariant.outline => OutlinedButton(
        onPressed: disabled ? null : onPressed,
        style: style,
        child: content,
      ),
      AppButtonVariant.text => TextButton(
        onPressed: disabled ? null : onPressed,
        style: style,
        child: content,
      ),
      AppButtonVariant.danger => ElevatedButton(
        onPressed: disabled ? null : onPressed,
        style: style.copyWith(
          backgroundColor: WidgetStateProperty.resolveWith<Color>(
            (states) => states.contains(WidgetState.disabled)
                ? (context.isDark ? AppColors.gray800 : AppColors.gray200)
                : AppColors.danger,
          ),
          foregroundColor: const WidgetStatePropertyAll<Color>(AppColors.white),
        ),
        child: content,
      ),
    };

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }

  Widget _content(BuildContext context) {
    if (isLoading) {
      final Color spinner = switch (variant) {
        AppButtonVariant.primary || AppButtonVariant.danger => AppColors.white,
        _ => context.colors.primary,
      };
      return SizedBox(
        height: 18,
        width: 18,
        child: CircularProgressIndicator(strokeWidth: 2, color: spinner),
      );
    }

    if (icon == null) return Text(label);

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Icon(icon, size: 18),
        AppSpacing.hXs,
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}
