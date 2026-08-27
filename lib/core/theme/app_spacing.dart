import 'package:flutter/widgets.dart';

/// Boşluk token'ları — 4'ün katları.
///
/// Kural: `EdgeInsets.all(17)` gibi serbest değer yazılmaz.
abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double xxxl = 64;

  /// Sayfa yatay kenar boşluğu (mobil).
  static const double pageH = 16;

  /// Sayfa yatay kenar boşluğu (tablet ve üstü).
  static const double pageHWide = 32;

  /// Kart iç boşluğu — sıkışık.
  static const double cardCompact = 16;

  /// Kart iç boşluğu — ferah.
  static const double cardSpacious = 24;

  /// Minimum dokunma hedefi.
  static const double touchTarget = 48;

  // ─────────────────────────── Hazır aralıklar ───────────────────────────
  static const SizedBox gapXxs = SizedBox(height: xxs, width: xxs);
  static const SizedBox gapXs = SizedBox(height: xs, width: xs);
  static const SizedBox gapSm = SizedBox(height: sm, width: sm);
  static const SizedBox gapMd = SizedBox(height: md, width: md);
  static const SizedBox gapLg = SizedBox(height: lg, width: lg);
  static const SizedBox gapXl = SizedBox(height: xl, width: xl);

  static const SizedBox vXxs = SizedBox(height: xxs);
  static const SizedBox vXs = SizedBox(height: xs);
  static const SizedBox vSm = SizedBox(height: sm);
  static const SizedBox vMd = SizedBox(height: md);
  static const SizedBox vLg = SizedBox(height: lg);
  static const SizedBox vXl = SizedBox(height: xl);
  static const SizedBox vXxl = SizedBox(height: xxl);

  static const SizedBox hXxs = SizedBox(width: xxs);
  static const SizedBox hXs = SizedBox(width: xs);
  static const SizedBox hSm = SizedBox(width: sm);
  static const SizedBox hMd = SizedBox(width: md);
  static const SizedBox hLg = SizedBox(width: lg);
  static const SizedBox hXl = SizedBox(width: xl);
}

/// İçerik genişlik sınırları.
///
/// Web'de içerik ekranın tamamına yayılmaz; okunabilirlik için sınırlanır.
abstract final class AppWidths {
  /// Form / liste içeriği.
  static const double content = 720;

  /// Ayar sayfaları, tablolu içerik.
  static const double wide = 896;

  /// Rapor tablosu, dashboard ızgarası.
  static const double page = 1280;

  /// Giriş kartı gibi dar bloklar.
  static const double narrow = 420;
}
