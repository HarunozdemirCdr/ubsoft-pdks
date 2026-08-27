import 'package:flutter/widgets.dart';

/// Ekran boyutu sınıfları.
///
/// Uygulama mobile-first tasarlandı: tüm varsayılan değerler [ScreenSize.mobile]
/// içindir, daha geniş ekranlarda üzerine eklenir.
enum ScreenSize {
  /// < 640px — telefon tarayıcısı. Birincil hedef.
  mobile,

  /// 640–1023px — tablet, dar masaüstü penceresi.
  tablet,

  /// >= 1024px — masaüstü.
  desktop;

  bool get isMobile => this == ScreenSize.mobile;
  bool get isTablet => this == ScreenSize.tablet;
  bool get isDesktop => this == ScreenSize.desktop;

  /// Tablet ve üstü — yan menü (rail) gösterilir.
  bool get isWide => this != ScreenSize.mobile;
}

abstract final class Breakpoints {
  static const double tablet = 640;
  static const double desktop = 1024;

  static ScreenSize of(double width) {
    if (width >= desktop) return ScreenSize.desktop;
    if (width >= tablet) return ScreenSize.tablet;
    return ScreenSize.mobile;
  }

  static ScreenSize fromContext(BuildContext context) =>
      of(MediaQuery.sizeOf(context).width);
}
