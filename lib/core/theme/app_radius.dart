import 'package:flutter/widgets.dart';

/// Köşe yuvarlama token'ları.
///
/// Kural: küçük öğe 10, kart 14, panel/alt sayfa 20. Ara değer üretmek yasak —
/// yeni bir ihtiyaç varsa buraya token eklenir.
///
/// Ölçek bilinçli olarak dardır ve butonlar tam yuvarlak (pill) **değildir**:
/// bu ürün gün gün saat okunan bir tabloya bakar; keskin köşeler satırları
/// hizalı gösterir ve yumuşak, tamamen yuvarlak bir dil buradaki yoğunlukla
/// çelişirdi.
abstract final class AppRadius {
  static const double xs = 2;
  static const double sm = 6;
  static const double md = 10;
  static const double lg = 14;
  static const double xl = 20;
  static const double full = 9999;

  static const BorderRadius allXs = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius allSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius allMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius allLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius allXl = BorderRadius.all(Radius.circular(xl));

  /// Alt sayfalar (bottom sheet) için yalnız üst köşeler.
  static const BorderRadius topXl = BorderRadius.vertical(
    top: Radius.circular(xl),
  );

  /// Soldan açılan menü (drawer) için yalnız sağ köşeler.
  static const BorderRadius rightXl = BorderRadius.horizontal(
    right: Radius.circular(xl),
  );
}
