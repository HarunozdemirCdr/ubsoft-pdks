import 'package:flutter/material.dart';

/// Uygulamanın tek renk kaynağı.
///
/// Kural: Hiçbir widget dosyasında `Color(0x...)` yazılmaz. Renk gereken her
/// yerde bu sınıftaki token'lar kullanılır. Böylece tema değişimi, beyaz etiket
/// (white-label) desteği ve karanlık mod tek noktadan yönetilir.
///
/// **Palet neden lacivert + sıcak nötr?** Lacivert, devam kontrol
/// yazılımlarının alıştırdığı renktir; kurumsal durur ve ekranın işine
/// karışmaz. Doygunluğu düşük olduğu için giriş/çıkış'ın yeşil–kırmızı
/// ikilisiyle yarışmaz — parlak bir mavi seçilseydi üç doygun renk aynı
/// anda dikkat isterdi.
///
/// Aynı kurumun devriye ürünü de mavi kullanır (`#2563EB`, canlı bir
/// mavi). İki uygulamanın tek uygulama gibi görünmemesi için ayrım
/// bilinçli olarak üç yerde birden kurulur: **ton** (lacivert `#1E3A8A`,
/// canlı maviden belirgin biçimde koyu), **nötr skala** (soğuk gri değil
/// sıcak taş) ve **tipografi** (Manrope değil Plus Jakarta Sans). Tek
/// başına renk farkı yeterli olmazdı.
abstract final class AppColors {
  // ─────────────────────────── Vurgu (Primary) ───────────────────────────
  /// Birincil vurgu rengi. Butonlar, aktif durumlar, bağlantılar.
  static const Color primary = Color(0xFF1E3A8A);

  /// Hover / basılı durum.
  static const Color primaryHover = Color(0xFF172554);

  /// Koyu zemin üzerinde okunabilir vurgu tonu.
  static const Color primaryOnDark = Color(0xFF93C5FD);

  /// Açık ikon arkaplanı (light tema).
  static const Color primarySurface = Color(0xFFDBEAFE);

  /// Koyu tema ikon arkaplanı (primary @ %20 opaklık).
  static const Color primarySurfaceDark = Color(0x331E3A8A);

  // ─────────────────────────── Nötr skala ───────────────────────────
  //
  // Sıcak taş (stone) tonları. Adları `gray…` kalır çünkü token'ın işi
  // "nötr basamak" olmaktır; hangi sıcaklıkta olduğu burada bir kez seçilir.
  static const Color white = Color(0xFFFFFFFF);
  static const Color gray50 = Color(0xFFFAFAF9);
  static const Color gray100 = Color(0xFFF5F5F4);
  static const Color gray200 = Color(0xFFE7E5E4);
  static const Color gray300 = Color(0xFFD6D3D1);
  static const Color gray400 = Color(0xFFA8A29E);
  static const Color gray500 = Color(0xFF78716C);
  static const Color gray600 = Color(0xFF57534E);
  static const Color gray700 = Color(0xFF44403C);
  static const Color gray800 = Color(0xFF292524);
  static const Color gray900 = Color(0xFF1C1917);
  static const Color gray950 = Color(0xFF0C0A09);

  // ─────────────────────────── Açık tema yüzeyleri ───────────────────────────
  static const Color surface = white;
  static const Color surfaceAlt = gray50;
  static const Color surfaceMuted = gray100;
  static const Color border = gray200;
  static const Color borderStrong = gray300;

  static const Color textPrimary = gray900;
  static const Color textBody = gray600;
  static const Color textMuted = gray500;
  static const Color textPlaceholder = gray400;

  // ─────────────────────────── Koyu tema yüzeyleri ───────────────────────────
  static const Color surfaceDark = gray950;
  static const Color surfaceAltDark = gray900;
  static const Color surfaceMutedDark = gray800;
  static const Color borderDark = Color(0xFF292524);
  static const Color borderStrongDark = Color(0xFF44403C);

  static const Color textPrimaryDark = Color(0xFFFAFAF9);
  static const Color textBodyDark = Color(0xFFD6D3D1);
  static const Color textMutedDark = gray400;

  // ─────────────────────────── Durum renkleri ───────────────────────────
  //
  // Tasarım sistemi "üç renk yeter" der; ancak devam durumu semantik bir
  // bilgidir ve yalnız tipografiyle ayrıştırılamaz. Bu yüzden durum paleti
  // bilinçli tek istisnadır ve sadece rozet/ikon gibi küçük alanlarda kullanılır.
  //
  // [entry] ve [exit] bu paletin en çok görülen çiftidir: giriş yeşil, çıkış
  // kırmızı. Saatin kendisi de bu renkte yazılır — listeye bakan kişi metni
  // okumadan yönü görmelidir.
  /// Tamamlandı.
  static const Color success = Color(0xFF059669);
  static const Color successSurface = Color(0xFFD1FAE5);
  static const Color successOnDark = Color(0xFF34D399);

  /// Eksik / Geç.
  static const Color warning = Color(0xFFD97706);
  static const Color warningSurface = Color(0xFFFEF3C7);
  static const Color warningOnDark = Color(0xFFFBBF24);

  /// Hata / yıkıcı işlem.
  static const Color danger = Color(0xFFDC2626);
  static const Color dangerSurface = Color(0xFFFEE2E2);
  static const Color dangerOnDark = Color(0xFFF87171);

  /// İptal / nötr durum.
  static const Color neutral = gray500;
  static const Color neutralSurface = gray100;

  // ─────────────────────────── Giriş / çıkış ───────────────────────────
  /// Giriş okutması. Yeşil, [success] ile aynı ailede ama biraz daha koyu:
  /// küçük punto saat metninde okunaklı kalması gerekir.
  static const Color entry = Color(0xFF047857);
  static const Color entrySurface = Color(0xFFD1FAE5);
  static const Color entryOnDark = Color(0xFF6EE7B7);

  /// Çıkış okutması.
  static const Color exit = Color(0xFFB91C1C);
  static const Color exitSurface = Color(0xFFFEE2E2);
  static const Color exitOnDark = Color(0xFFFCA5A5);

  // ─────────────────────────── Gölge ───────────────────────────
  static const Color shadow = Color(0x14000000);
  static const Color shadowStrong = Color(0x1F000000);
  static const Color scrim = Color(0x66030712);
}
