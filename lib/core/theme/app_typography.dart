import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tipografi ölçeği — Plus Jakarta Sans.
///
/// Ölçek mobil web için ayarlandı: tarayıcıda 72px display gereksiz, en büyük
/// başlık 32'de tutuldu. Başlıklarda `letter-spacing: -0.02em`, gövdede
/// `line-height: 1.625`.
///
/// Font [PdfReportService] tarafından da kullanılır ve `assets/fonts` altında
/// gömülü durur; PDF'in yerleşik Helvetica'sında Türkçe harfler yoktur.
abstract final class AppTypography {
  static const String fontFamily = 'Plus Jakarta Sans';

  static const double _tight = -0.02;

  /// Ekranın en büyük başlığı (giriş ekranı, boş durum).
  static TextStyle display(Color color) => GoogleFonts.plusJakartaSans(
    fontSize: 32,
    height: 1.15,
    fontWeight: FontWeight.w700,
    letterSpacing: 32 * _tight,
    color: color,
  );

  /// Sayfa başlığı.
  static TextStyle h1(Color color) => GoogleFonts.plusJakartaSans(
    fontSize: 26,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: 26 * _tight,
    color: color,
  );

  /// Bölüm başlığı.
  static TextStyle h2(Color color) => GoogleFonts.plusJakartaSans(
    fontSize: 20,
    height: 1.25,
    fontWeight: FontWeight.w700,
    letterSpacing: 20 * _tight,
    color: color,
  );

  /// Kart başlığı.
  static TextStyle h3(Color color) => GoogleFonts.plusJakartaSans(
    fontSize: 17,
    height: 1.3,
    fontWeight: FontWeight.w600,
    color: color,
  );

  /// Gövde metni.
  static TextStyle body(Color color) => GoogleFonts.plusJakartaSans(
    fontSize: 15,
    height: 1.625,
    fontWeight: FontWeight.w400,
    color: color,
  );

  /// Vurgulu gövde.
  static TextStyle bodyStrong(Color color) => GoogleFonts.plusJakartaSans(
    fontSize: 15,
    height: 1.5,
    fontWeight: FontWeight.w600,
    color: color,
  );

  /// Yardımcı metin, alt açıklama.
  static TextStyle small(Color color) => GoogleFonts.plusJakartaSans(
    fontSize: 13,
    height: 1.5,
    fontWeight: FontWeight.w400,
    color: color,
  );

  /// Form etiketi, buton metni.
  static TextStyle label(Color color) => GoogleFonts.plusJakartaSans(
    fontSize: 14,
    height: 1.3,
    fontWeight: FontWeight.w600,
    color: color,
  );

  /// Rozet, sayaç gibi çok küçük öğeler.
  static TextStyle caption(Color color) => GoogleFonts.plusJakartaSans(
    fontSize: 12,
    height: 1.35,
    fontWeight: FontWeight.w600,
    color: color,
  );

  /// Bölüm üstü küçük etiket — UPPERCASE, geniş harf aralığı, vurgu rengi.
  static TextStyle eyebrow(Color color) => GoogleFonts.plusJakartaSans(
    fontSize: 12,
    height: 1.3,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
    color: color,
  );

  /// Sayısal metrik (dashboard kartları, süre sayacı).
  static TextStyle metric(Color color) => GoogleFonts.plusJakartaSans(
    fontSize: 28,
    height: 1.1,
    fontWeight: FontWeight.w800,
    letterSpacing: 28 * _tight,
    color: color,
  );

  /// Tabular figürler gerektiren yerler (süre, QR kodu).
  static TextStyle mono(Color color) => GoogleFonts.robotoMono(
    fontSize: 14,
    height: 1.4,
    fontWeight: FontWeight.w500,
    color: color,
  );

  /// Material [TextTheme] karşılığı — [ThemeData] içinde kullanılır.
  static TextTheme textTheme({
    required Color primary,
    required Color body,
    required Color muted,
  }) => TextTheme(
    displayLarge: display(primary),
    displayMedium: h1(primary),
    displaySmall: h2(primary),
    headlineLarge: h1(primary),
    headlineMedium: h2(primary),
    headlineSmall: h3(primary),
    titleLarge: h2(primary),
    titleMedium: h3(primary),
    titleSmall: label(primary),
    bodyLarge: AppTypography.body(body),
    bodyMedium: AppTypography.body(body),
    bodySmall: small(muted),
    labelLarge: label(primary),
    labelMedium: label(body),
    labelSmall: caption(muted),
  );
}
