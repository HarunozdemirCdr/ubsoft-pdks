import 'package:flutter/material.dart';
import 'package:ubsoft_pdks/core/responsive/breakpoints.dart';
import 'package:ubsoft_pdks/core/theme/app_spacing.dart';

/// [BuildContext] kısayolları — her ekranda tekrar eden `Theme.of(context)`
/// zincirlerini kısaltır.
extension ContextX on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  Size get screenSize => MediaQuery.sizeOf(this);
  ScreenSize get breakpoint => Breakpoints.fromContext(this);
  bool get isMobile => breakpoint.isMobile;
  bool get isWide => breakpoint.isWide;

  /// Ekran genişliğine uygun sayfa kenar boşluğu.
  EdgeInsets get pagePadding => EdgeInsets.symmetric(
    horizontal: isMobile ? AppSpacing.pageH : AppSpacing.pageHWide,
  );

  /// Klavye açıkken alt boşluk (mobil tarayıcıda form kaymasın).
  double get keyboardInset => MediaQuery.viewInsetsOf(this).bottom;
}
